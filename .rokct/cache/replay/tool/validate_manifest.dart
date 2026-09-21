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


// Validates a Level-6-produced manifest against the REAL ReplaySDK
// ManifestParser (not a reimplementation). Pure-Dart import graph, so it
// runs under `dart run` without Flutter.
//
//   dart run tool/validate_manifest.dart <path-to-manifest.json>
//
// Exits 0 and prints a parsed summary on success; exits 1 on any parse or
// contract failure.
import 'dart:io';
import '../lib/src/controllers/manifest_parser.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: validate_manifest.dart <manifest.json>');
    exit(2);
  }
  final file = File(args[0]);
  if (!file.existsSync()) {
    stderr.writeln('no such file: ${args[0]}');
    exit(2);
  }

  final parser = ManifestParser();
  final manifest = parser.parse(file.readAsStringSync());

  // Exercise the same accessors the player uses at runtime.
  final firstProfile =
      manifest.tracks.where((e) => e.type == 'profile').toList();
  final subtopicEnds =
      manifest.tracks.where((e) => e.type == 'subtopic_end').toList();
  final eventsAtStart = parser.getEventsUpTo(manifest, 0.0);
  final eventsByEnd =
      parser.getEventsUpTo(manifest, manifest.audio.durationSeconds.toDouble());

  print('OK ManifestParser.parse succeeded');
  print('  version            : ${manifest.version}');
  print('  session_id         : ${manifest.sessionId}');
  print('  subject/grade/topic: ${manifest.subject} / '
      '${manifest.grade} / ${manifest.topic}');
  print('  lesson_number      : ${manifest.lessonNumber}');
  print('  door_close_seconds : ${manifest.doorCloseSeconds}');
  print('  scheduled_at       : ${manifest.scheduledAt.toIso8601String()}');
  print('  audio              : ${manifest.audio.lesson} '
      '(${manifest.audio.format}, ${manifest.audio.durationSeconds}s)');
  print('  assets             : ${manifest.assets}');
  print('  tracks             : ${manifest.tracks.length}');
  print('  profile events     : ${firstProfile.length}');
  print('  subtopic_end events: ${subtopicEnds.length}');
  print('  getEventsUpTo(0.0) : ${eventsAtStart.length}');
  print('  getEventsUpTo(end) : ${eventsByEnd.length}');

  // Contract sanity the parser itself does not enforce.
  final problems = <String>[];
  if (manifest.tracks.isEmpty) problems.add('no track events');
  if (manifest.audio.durationSeconds <= 0) problems.add('audio duration <= 0');
  for (var i = 1; i < manifest.tracks.length; i++) {
    if (manifest.tracks[i].time < manifest.tracks[i - 1].time) {
      problems.add('tracks not monotonically ordered at index $i');
      break;
    }
  }
  // Every subtopic_end must reference known exercise ids (list may be empty
  // but must be a list — rawData preserves it).
  for (final end in subtopicEnds) {
    final ex = end.rawData['exercise'];
    if (ex is! List) {
      problems.add('subtopic_end ${end.rawData['ref']} exercise is not a list');
    }
  }

  if (problems.isNotEmpty) {
    stderr.writeln('CONTRACT FAILURES:');
    for (final p in problems) {
      stderr.writeln('  - $p');
    }
    exit(1);
  }
  print('OK all contract checks passed');
}
