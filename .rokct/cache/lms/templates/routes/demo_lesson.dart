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


// Demo lesson constants + asset seeder — proves the factory -> app content
// path end to end with REAL Level 6 pipeline output.
//
// The bundled triple in assets/demo_lesson/ (manifest.json / audio.mp3 /
// animations.json) is genuine `lesson_manifest.py` output for the evaluated
// Grade 11 "Quadratic Equations — Factoring method" card (sapi TTS — the
// production voice decision is separate and open). On first open it is
// seeded into replay_sdk's AssetStore session directory, from where the
// REAL playback path (SessionGatekeeper -> ManifestParser -> AudioSync ->
// WhiteboardPlayer) treats it exactly like a downloaded session. Nothing in
// the player knows it is a demo.
//
// This file exports only the constants and the seeder; the demo-mode
// wiring (schedule, plans, skills, library, access gating) lives in
// lms_route_pages.dart's own demo-gated classes.
import 'dart:io';

import 'package:base_sdk/base_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get_it/get_it.dart';
import 'package:replay_sdk/replay_sdk.dart';

/// Session id of the bundled demo lesson — the factory card id, which must
/// match the manifest's `session_id` (AssetStore keys the on-device session
/// directory by it).
const String kDemoLessonSessionId =
    'maths_g11_quadratic_equations_factoring_method_31d165';

/// Tutor persona named by the demo manifest's `profile` track.
const String kDemoLessonTutorName = 'Grandmaster';

/// Session ids for the mocked "later this week" rows (decision-#22 demo
/// week) — distinct from [kDemoLessonSessionId] and from each other, so
/// attendance/skip state (keyed by sessionId in ScheduleNotifier) stays
/// independent per row instead of every row overwriting the same shared
/// state. Each one gets the SAME seeded content as the real demo lesson
/// (there is only one recorded asset triple), just under its own directory.
List<String> demoWeekMockSessionIds() =>
    [for (var i = 1; i <= 4; i++) '${kDemoLessonSessionId}_mockday$i'];

/// Copies the bundled demo triple into the AssetStore session directory —
/// the real demo session id, plus every mocked "later this week" id so Join
/// works from any row, not just the hero. Always overwrites: the bundled
/// content is the source of truth and does get regenerated (band-layout
/// re-exports); playback state (library entries etc.) lives elsewhere and
/// is unaffected.
Future<void> seedDemoLessonAssets() async {
  // Belt-and-braces: demo assets must never materialize outside a demo
  // session, whatever future call sites appear.
  if (!DemoSession.demoActive) {
    debugPrint('==> demo lesson: seeding skipped (no demo session)');
    return;
  }
  final getIt = GetIt.instance;
  if (!getIt.isRegistered<AssetStore>()) {
    ReplaySdkDependencies.register(getIt);
  }
  final store = getIt.get<AssetStore>();
  final root = await store.assetsRoot();
  for (final sessionId in [
    kDemoLessonSessionId,
    ...demoWeekMockSessionIds(),
  ]) {
    final targets = <String, String>{
      AssetStore.manifestFileName: store.manifestPath(root, sessionId),
      AssetStore.audioFileName: store.audioPath(root, sessionId),
      AssetStore.animationFileName: store.animationPath(root, sessionId),
    };
    for (final entry in targets.entries) {
      // Always overwrite: the bundled demo content is the source of truth
      // and does get regenerated (band-layout re-exports); a stale seeded
      // copy silently shadowing it cost a debugging round once already.
      final bytes = await rootBundle.load('assets/demo_lesson/${entry.key}');
      final file = File(entry.value);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      debugPrint('==> demo lesson: seeded ${entry.key} -> ${entry.value}');
    }
  }
}
