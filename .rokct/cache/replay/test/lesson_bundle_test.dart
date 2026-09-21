// Copyright (c) 2026 ROKCT INTELLIGENCE (PTY) LTD
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, version 3.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.


// Lesson bundle (.rok) pack/unpack/validate — decision #46's app-side
// zipping with #49's internal type manifest and #7's atomic + scrambling
// requirements. Files are imported directly rather than via the barrel
// (standalone the barrel drags in composed-only drift members).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:replay_sdk/src/common/infrastructure/services/lesson_bundle.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('rok_bundle_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<String> writeSessionDir(String sessionId,
      {Map<String, String>? files}) async {
    final dir = Directory('${temp.path}/$sessionId');
    await dir.create(recursive: true);
    final content = files ??
        {
          'manifest.json': '{"session_id": "$sessionId"}',
          'audio.mp3': 'fake-audio-bytes',
          'animations.json': '[]',
          'mcq.json': '{"questions": []}',
        };
    for (final entry in content.entries) {
      await File('${dir.path}/${entry.key}').writeAsString(entry.value);
    }
    return dir.path;
  }

  LessonBundleCodec codec(
          {RokScramblingLevel level = kDefaultRokScramblingLevel,
          String account = 'student-1'}) =>
      LessonBundleCodec(level: level, accountKey: () => account);

  group('pack/unpack round trip', () {
    for (final level in RokScramblingLevel.values) {
      test('level ${level.name}: every asset survives byte-identical',
          () async {
        final sessionDir = await writeSessionDir('s1');
        final bundlePath = '${temp.path}/s1.rok';
        final c = codec(level: level);

        await c.pack(
            sessionDir: sessionDir, bundlePath: bundlePath, sessionId: 's1');

        final outDir = '${temp.path}/out/s1';
        final info =
            await c.unpack(bundlePath: bundlePath, destinationDir: outDir);

        expect(info.sessionId, 's1');
        expect(info.formatVersion, kRokFormatVersion);
        expect(info.scrambling, level);
        for (final name in [
          'manifest.json',
          'audio.mp3',
          'animations.json',
          'mcq.json'
        ]) {
          expect(info.fileNames, contains(name));
          expect(
            await File('$outDir/$name').readAsString(),
            await File('$sessionDir/$name').readAsString(),
            reason: '$name must survive the round trip byte-identical',
          );
        }
      });
    }

    test('scrambled bundle is not a readable zip on disk', () async {
      final sessionDir = await writeSessionDir('s2');
      final bundlePath = '${temp.path}/s2.rok';
      await codec(level: RokScramblingLevel.light).pack(
          sessionDir: sessionDir, bundlePath: bundlePath, sessionId: 's2');

      final raw = await File(bundlePath).readAsBytes();
      // Zip local-file magic "PK\x03\x04" must not appear at the payload
      // start — casual unzip of the file must fail.
      const headerLength = 4 + 1 + 1 + 32;
      expect(raw.sublist(headerLength, headerLength + 2),
          isNot(equals([0x50, 0x4B])));
    });

    test('level none payload IS a plain zip (setting really changes output)',
        () async {
      final sessionDir = await writeSessionDir('s3');
      final bundlePath = '${temp.path}/s3.rok';
      await codec(level: RokScramblingLevel.none).pack(
          sessionDir: sessionDir, bundlePath: bundlePath, sessionId: 's3');

      final raw = await File(bundlePath).readAsBytes();
      const headerLength = 4 + 1 + 1 + 32;
      expect(raw.sublist(headerLength, headerLength + 2), [0x50, 0x4B]);
    });
  });

  group('account keying', () {
    test('a light bundle does not open under another account key', () async {
      final sessionDir = await writeSessionDir('s4');
      final bundlePath = '${temp.path}/s4.rok';
      await codec(account: 'student-a').pack(
          sessionDir: sessionDir, bundlePath: bundlePath, sessionId: 's4');

      expect(
        () => codec(account: 'student-b').unpack(
            bundlePath: bundlePath, destinationDir: '${temp.path}/out/s4'),
        throwsA(isA<LessonBundleException>()),
      );
      // The rightful account still opens it.
      final info = await codec(account: 'student-a').unpack(
          bundlePath: bundlePath, destinationDir: '${temp.path}/out/s4');
      expect(info.sessionId, 's4');
    });

    test('unpack honours the level stored in the header, not the setting',
        () async {
      final sessionDir = await writeSessionDir('s5');
      final bundlePath = '${temp.path}/s5.rok';
      await codec(level: RokScramblingLevel.none).pack(
          sessionDir: sessionDir, bundlePath: bundlePath, sessionId: 's5');

      // A codec configured for light still opens a none-level bundle: the
      // default can change without stranding already sealed lessons.
      final info = await codec(level: RokScramblingLevel.light).unpack(
          bundlePath: bundlePath, destinationDir: '${temp.path}/out/s5');
      expect(info.scrambling, RokScramblingLevel.none);
    });
  });

  group('integrity (atomic all-or-nothing, decision #7)', () {
    test('a flipped payload byte fails the checksum', () async {
      final sessionDir = await writeSessionDir('s6');
      final bundlePath = '${temp.path}/s6.rok';
      await codec().pack(
          sessionDir: sessionDir, bundlePath: bundlePath, sessionId: 's6');

      final raw = await File(bundlePath).readAsBytes();
      raw[raw.length - 1] ^= 0xFF;
      await File(bundlePath).writeAsBytes(raw);

      expect(
        () => codec().unpack(
            bundlePath: bundlePath, destinationDir: '${temp.path}/out/s6'),
        throwsA(isA<LessonBundleException>()),
      );
      // Nothing partial was left behind.
      expect(await Directory('${temp.path}/out/s6').exists(), isFalse);
    });

    test('a non-bundle file is rejected by magic', () async {
      final path = '${temp.path}/junk.rok';
      await File(path).writeAsString('definitely not a lesson bundle at all');
      expect(() => codec().validate(path),
          throwsA(isA<LessonBundleException>()));
    });

    test('an empty session dir refuses to pack', () async {
      final dir = Directory('${temp.path}/empty');
      await dir.create();
      expect(
        () => codec().pack(
            sessionDir: dir.path,
            bundlePath: '${temp.path}/empty.rok',
            sessionId: 'empty'),
        throwsA(isA<LessonBundleException>()),
      );
      expect(await File('${temp.path}/empty.rok').exists(), isFalse);
    });
  });

  group('internal type manifest (decision #49)', () {
    test('validate answers the same for the sealed file and a loose folder',
        () async {
      final sessionDir = await writeSessionDir('s7');
      final bundlePath = '${temp.path}/s7.rok';
      final c = codec();
      await c.pack(
          sessionDir: sessionDir, bundlePath: bundlePath, sessionId: 's7');
      final unpacked = '${temp.path}/out/s7';
      await c.unpack(bundlePath: bundlePath, destinationDir: unpacked);

      final fromFile = await c.validate(bundlePath);
      final fromFolder = await c.validate(unpacked);
      expect(fromFile.sessionId, fromFolder.sessionId);
      expect(fromFile.formatVersion, fromFolder.formatVersion);
    });

    test('a folder without bundle.json is not a lesson bundle', () async {
      final dir = await writeSessionDir('s8');
      expect(await codec().isLessonBundle(dir), isFalse);
    });

    test('a zip whose manifest claims a foreign type is rejected', () async {
      // The owner's other .rok project poses as this one: right container, wrong
      // internal identity.
      final sessionDir = await writeSessionDir('s9', files: {
        'data.bin': 'other-project-payload',
      });
      final bundlePath = '${temp.path}/s9.rok';
      final c = codec(level: RokScramblingLevel.none);
      await c.pack(
          sessionDir: sessionDir, bundlePath: bundlePath, sessionId: 's9');

      // Rewrite the internal manifest with a foreign type.
      final unpacked = '${temp.path}/out/s9';
      await c.unpack(bundlePath: bundlePath, destinationDir: unpacked);
      await File('$unpacked/$kRokManifestFileName').writeAsString(jsonEncode({
        'type': 'SOME OTHER PROJECT',
        'format_version': 1,
        'session_id': 's9',
      }));
      expect(() => c.validate(unpacked),
          throwsA(isA<LessonBundleException>()));
    });

    test('a future format version is rejected, not misread', () async {
      final dir = Directory('${temp.path}/future');
      await dir.create();
      await File('${dir.path}/$kRokManifestFileName')
          .writeAsString(jsonEncode({
        'type': kRokBundleType,
        'format_version': kRokFormatVersion + 1,
        'session_id': 'future',
      }));
      expect(() => codec().validate(dir.path),
          throwsA(isA<LessonBundleException>()));
    });
  });
}
