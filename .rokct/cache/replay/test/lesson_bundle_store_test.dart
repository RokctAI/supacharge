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


// LessonBundleStore + LessonStorageManager — seal/materialize lifecycle and
// the storage-manager machinery (decision #7's per-lesson
// size/delete/re-download, #46's app-side zipping).
// compliance-ignore-file: flutter-http-timeout (test double: Dio uses a scripted in-memory adapter, no real network)
// compliance-ignore-file: obs-flutter-trace (test double: no real network; trace propagation is exercised in the app wiring, not here)

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:replay_sdk/src/common/controllers/lesson_storage_manager.dart';
import 'package:replay_sdk/src/common/controllers/session_gatekeeper.dart';
import 'package:replay_sdk/src/common/infrastructure/services/asset_store.dart';
import 'package:replay_sdk/src/common/infrastructure/services/lesson_bundle.dart';
import 'package:replay_sdk/src/common/infrastructure/services/lesson_bundle_store.dart';

/// AssetStore whose downloadFile writes canned bytes instead of touching the
/// network — the manager's download plumbing without a server.
class _FakeDownloadAssetStore extends AssetStore {
  final Map<String, String> cannedByUrl;
  final List<String> downloadedUrls = [];

  _FakeDownloadAssetStore({required String root, required this.cannedByUrl})
      : super(client: Dio(), rootOverride: root);

  @override
  Future<void> downloadFile({
    required String url,
    required String destinationPath,
    String? expectedSha256,
    int? expectedSizeBytes,
    int maxAttempts = 3,
  }) async {
    final content = cannedByUrl[url];
    if (content == null) {
      throw AssetDownloadException(url, 'no canned content');
    }
    downloadedUrls.add(url);
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }
}

void main() {
  late Directory temp;
  late AssetStore assetStore;
  late LessonBundleStore store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('rok_store_test');
    assetStore = AssetStore(client: Dio(), rootOverride: temp.path);
    store = LessonBundleStore(
      assetStore: assetStore,
      codec: LessonBundleCodec(accountKey: () => 'student-1'),
    );
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<void> writeLooseAssets(String sessionId) async {
    final root = await assetStore.assetsRoot();
    final dir = Directory(assetStore.sessionDirPath(root, sessionId));
    await dir.create(recursive: true);
    await File(assetStore.manifestPath(root, sessionId))
        .writeAsString('{"id": "$sessionId"}');
    await File(assetStore.audioPath(root, sessionId)).writeAsString('audio');
    await File(assetStore.animationPath(root, sessionId))
        .writeAsString('[]');
  }

  group('seal + materialize', () {
    test('seal replaces the loose folder with one .rok file', () async {
      await writeLooseAssets('s1');
      await store.seal('s1');

      final root = await assetStore.assetsRoot();
      expect(await store.isBundled('s1'), isTrue);
      expect(
          await Directory(assetStore.sessionDirPath(root, 's1')).exists(),
          isFalse,
          reason: 'loose files are removed once the bundle is verified');
    });

    test('materialize restores the exact loose layout the player reads',
        () async {
      await writeLooseAssets('s2');
      await store.seal('s2');

      expect(await store.materialize('s2'), isTrue);

      final root = await assetStore.assetsRoot();
      expect(
          await File(assetStore.manifestPath(root, 's2')).readAsString(),
          '{"id": "s2"}');
      expect(await File(assetStore.audioPath(root, 's2')).readAsString(),
          'audio');
      expect(
          await File(assetStore.animationPath(root, 's2')).readAsString(),
          '[]');
    });

    test('materialize is a no-op when loose assets already exist', () async {
      await writeLooseAssets('s3');
      expect(await store.materialize('s3'), isTrue);
    });

    test('materialize answers false when nothing is stored', () async {
      expect(await store.materialize('missing'), isFalse);
    });

    test('gatekeeper readiness passes on a sealed-only session', () async {
      await writeLooseAssets('s4');
      await store.seal('s4');

      final gatekeeper =
          SessionGatekeeper(assetStore: assetStore, bundleStore: store);
      final readiness = await gatekeeper.verifySessionReady('s4');
      expect(readiness.isReady, isTrue,
          reason: 'a sealed bundle must answer ready exactly like loose files');
    });
  });

  group('sizes, listing, delete', () {
    test('storedSessionIds sees sealed and loose sessions once each',
        () async {
      await writeLooseAssets('loose-1');
      await writeLooseAssets('sealed-1');
      await store.seal('sealed-1');

      expect(await store.storedSessionIds(), ['loose-1', 'sealed-1']);
    });

    test('lessonSizeBytes reports the bundle size for sealed lessons',
        () async {
      await writeLooseAssets('s5');
      await store.seal('s5');
      final root = await assetStore.assetsRoot();
      final expected =
          await File(assetStore.bundlePath(root, 's5')).length();
      expect(await store.lessonSizeBytes('s5'), expected);
      expect(await store.lessonSizeBytes('missing'), 0);
    });

    test('deleteLesson removes bundle and loose files', () async {
      await writeLooseAssets('s6');
      await store.seal('s6');
      await store.materialize('s6'); // both forms on disk
      await store.deleteLesson('s6');

      expect(await store.storedSessionIds(), isEmpty);
      expect(await store.lessonSizeBytes('s6'), 0);
    });
  });

  group('LessonStorageManager', () {
    test('listDownloads reports size, bundled state and metadata', () async {
      await writeLooseAssets('s7');
      await store.seal('s7');
      final manager = LessonStorageManager(
        assetStore: assetStore,
        bundleStore: store,
        gateway: (cmd, payload) async => throw StateError('not used'),
        metadataLookup: () async => {
          's7': StoredLessonMeta(
              subject: 'maths', scheduledAt: DateTime(2026, 8, 10)),
        },
      );

      final records = await manager.listDownloads();
      expect(records, hasLength(1));
      expect(records.first.sessionId, 's7');
      expect(records.first.bundled, isTrue);
      expect(records.first.sizeBytes, greaterThan(0));
      expect(records.first.meta.subject, 'maths');
    });

    test('deleteDownload refuses an actively playing session', () async {
      await writeLooseAssets('s8');
      await store.seal('s8');
      final manager = LessonStorageManager(
        assetStore: assetStore,
        bundleStore: store,
        gateway: (cmd, payload) async => throw StateError('not used'),
      );

      ActiveSessionRegistry.markActive('s8');
      addTearDown(() => ActiveSessionRegistry.release('s8'));
      expect(() => manager.deleteDownload('s8'),
          throwsA(isA<LessonStorageException>()));

      ActiveSessionRegistry.release('s8');
      await manager.deleteDownload('s8');
      expect(await store.storedSessionIds(), isEmpty);
    });

    test('redownload asks the gateway, downloads the triple and seals it',
        () async {
      final fakeStore = _FakeDownloadAssetStore(
        root: temp.path,
        cannedByUrl: {
          'https://backend/m.json': '{"id": "s9"}',
          'https://backend/a.mp3': 'audio-bytes',
          'https://backend/anim.json': '[]',
        },
      );
      final fakeBundles = LessonBundleStore(
        assetStore: fakeStore,
        codec: LessonBundleCodec(accountKey: () => 'student-1'),
      );
      String? seenCmd;
      Map<String, dynamic>? seenPayload;
      final manager = LessonStorageManager(
        assetStore: fakeStore,
        bundleStore: fakeBundles,
        gateway: (cmd, payload) async {
          seenCmd = cmd;
          seenPayload = payload;
          return {
            'message': {
              'session_id': 's9',
              'subject': 'science',
              'scheduled_at': '2026-08-10T09:00:00Z',
              'manifest_url': 'https://backend/m.json',
              'audio_url': 'https://backend/a.mp3',
              'animation_url': 'https://backend/anim.json',
            },
          };
        },
      );

      final record = await manager.redownload('s9');

      expect(seenCmd, 'api.replay.get_session_assets',
          reason: 'prefix-free cmd through the universal gateway');
      expect(seenPayload, {'session_id': 's9'});
      expect(fakeStore.downloadedUrls, hasLength(3));
      expect(record.bundled, isTrue);
      expect(await fakeBundles.isBundled('s9'), isTrue);
    });

    test('a failed redownload leaves no half-lesson behind', () async {
      final fakeStore = _FakeDownloadAssetStore(
        root: temp.path,
        cannedByUrl: {
          // manifest succeeds, audio is missing -> download fails midway
          'https://backend/m.json': '{"id": "s10"}',
        },
      );
      final fakeBundles = LessonBundleStore(
        assetStore: fakeStore,
        codec: LessonBundleCodec(accountKey: () => 'student-1'),
      );
      final manager = LessonStorageManager(
        assetStore: fakeStore,
        bundleStore: fakeBundles,
        gateway: (cmd, payload) async => {
          'message': {
            'session_id': 's10',
            'subject': 'science',
            'scheduled_at': '2026-08-10T09:00:00Z',
            'manifest_url': 'https://backend/m.json',
            'audio_url': 'https://backend/missing.mp3',
            'animation_url': 'https://backend/missing.json',
          },
        },
      );

      await expectLater(manager.redownload('s10'),
          throwsA(isA<LessonStorageException>()));
      expect(await fakeBundles.storedSessionIds(), isEmpty,
          reason: 'decision #7: the whole bundle arrives or none of it');
    });

    test('a malformed gateway answer is a storage exception', () async {
      final manager = LessonStorageManager(
        assetStore: assetStore,
        bundleStore: store,
        gateway: (cmd, payload) async => 'not-a-map',
      );
      expect(() => manager.redownload('s11'),
          throwsA(isA<LessonStorageException>()));
    });
  });
}
