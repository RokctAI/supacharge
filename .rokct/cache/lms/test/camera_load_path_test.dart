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


import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';

/// Regression for the production camera bug (factory 2026-07-20): the Level 6
/// exporter emitted camera pans in a SIBLING top-level `camera` array, but the
/// app loads ONLY `decoded['primitives']` (ReplayLessonEngine) and detects
/// camera events by primitive TYPE inside that list. So every camera event was
/// dropped on load and the band camera never panned.
///
/// This test drives the ACTUAL load path — parse `decoded['primitives']`,
/// build ManimPrimitives, feed them to a real WhiteboardPlayer exactly as the
/// engine does — instead of checking the exporter output and the parser
/// separately (the gap that let the bug ship). It asserts the camera reaches
/// every band, and proves the old sibling-array shape does NOT (so the test
/// discriminates).
void main() {
  // Mirrors ReplayLessonEngine.prepare: primitives come from the top-level
  // `primitives` list, nothing else.
  List<ManimPrimitive> loadAsEngineDoes(String animationsJson) {
    final decoded = jsonDecode(animationsJson) as Map<String, dynamic>;
    return ((decoded['primitives'] as List?) ?? const [])
        .map((p) => ManimPrimitive.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
  }

  // Feed the loaded primitives to the player in time order, catch-up style,
  // as the engine's render loop does. Returns the camera's final normalized
  // y — 0 means it never left the first band.
  double driveAndReturnCameraY(List<ManimPrimitive> prims) {
    final player = WhiteboardPlayer()..init(400, 800);
    for (final p in prims) {
      player.renderPrimitiveInstant(p); // instant = no ticker needed in test
    }
    return player.cameraY;
  }

  // FIXED shape: camera events inlined into `primitives` as camera_move
  // events (what lesson_manifest.py now writes).
  const fixed = '''
  {
    "version": "1",
    "duration_seconds": 400,
    "primitives": [
      {"primitive": "text", "time": 1.0, "position": {"x": 0.2, "y": 0.1}, "text": "band 0"},
      {"primitive": "camera_move", "time": 60.0, "target": {"x": 0.5, "y": 1.5}, "duration_ms": 800},
      {"primitive": "text", "time": 61.0, "position": {"x": 0.2, "y": 1.1}, "text": "band 1"},
      {"primitive": "camera_move", "time": 120.0, "target": {"x": 0.5, "y": 2.5}, "duration_ms": 800},
      {"primitive": "text", "time": 121.0, "position": {"x": 0.2, "y": 2.1}, "text": "band 2"},
      {"primitive": "camera_move", "time": 180.0, "target": {"x": 0.5, "y": 3.5}, "duration_ms": 800},
      {"primitive": "text", "time": 181.0, "position": {"x": 0.2, "y": 3.1}, "text": "band 3"}
    ]
  }
  ''';

  // BROKEN shape: identical content, but camera events in a SIBLING array the
  // engine never reads (the shipped bug).
  const broken = '''
  {
    "version": "1",
    "duration_seconds": 400,
    "primitives": [
      {"primitive": "text", "time": 1.0, "position": {"x": 0.2, "y": 0.1}, "text": "band 0"},
      {"primitive": "text", "time": 61.0, "position": {"x": 0.2, "y": 1.1}, "text": "band 1"},
      {"primitive": "text", "time": 121.0, "position": {"x": 0.2, "y": 2.1}, "text": "band 2"},
      {"primitive": "text", "time": 181.0, "position": {"x": 0.2, "y": 3.1}, "text": "band 3"}
    ],
    "camera": [
      {"time": 60.0, "target": {"x": 0.5, "y": 1.5}},
      {"time": 120.0, "target": {"x": 0.5, "y": 2.5}},
      {"time": 180.0, "target": {"x": 0.5, "y": 3.5}}
    ]
  }
  ''';

  group('camera load-path contract', () {
    test('inline camera_move events pan the camera through every band', () {
      final prims = loadAsEngineDoes(fixed);
      // Camera events must survive the load and be recognised as such.
      expect(prims.where((p) => p.isCameraEvent).length, 3,
          reason: 'inline camera_move events must load from primitives');
      // Camera pans all the way to the last target (y = 3.5): it moved.
      expect(driveAndReturnCameraY(prims), closeTo(3.5, 0.001),
          reason: 'camera should follow the inline camera_move events');
    });

    test('sibling camera array is dropped on load (the shipped bug)', () {
      final prims = loadAsEngineDoes(broken);
      expect(prims.where((p) => p.isCameraEvent), isEmpty,
          reason: 'a sibling camera array never reaches the engine');
      // Camera never leaves the origin — exactly the production symptom.
      expect(driveAndReturnCameraY(prims), 0,
          reason: 'without inline camera events the board never pans');
    });
  });
}
