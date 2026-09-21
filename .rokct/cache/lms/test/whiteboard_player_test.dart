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


import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';

/// WhiteboardPlayer whiteboard-camera + removal contract (ADR-009,
/// replaysdk-spec §4): primitives live on a long virtual canvas measured in
/// viewport units, camera events pan the viewport between bands, and the
/// clear vocabulary erases (fade or instant) for pre-band content.
void main() {
  ManimPrimitive prim(Map<String, dynamic> json) =>
      ManimPrimitive.fromJson(json);

  WhiteboardPlayer newPlayer({double w = 400, double h = 800}) {
    final p = WhiteboardPlayer()..init(w, h);
    return p;
  }

  group('CoordinateScaler (full-viewport, band units)', () {
    test('maps each axis independently; y beyond 1 reaches later bands', () {
      final scaler = CoordinateScaler(deviceWidth: 400, deviceHeight: 800);
      final mid = scaler.normalizedToDevice(0.5, 0.25);
      expect(mid.x, 200);
      expect(mid.y, 200);
      final band2 = scaler.normalizedToDevice(0.1, 2.5);
      expect(band2.x, closeTo(40, 0.001));
      expect(band2.y, closeTo(2000, 0.001));
      final back = scaler.deviceToNormalized(40, 2000);
      expect(back.x, closeTo(0.1, 0.001));
      expect(back.y, closeTo(2.5, 0.001));
    });

    test('lengths scale against their own axis', () {
      final scaler = CoordinateScaler(deviceWidth: 400, deviceHeight: 800);
      expect(scaler.lengthX(0.1), closeTo(40, 0.001));
      expect(scaler.lengthY(0.1), closeTo(80, 0.001));
    });
  });

  group('virtual canvas placement', () {
    test('places primitives beyond the first viewport-height', () {
      final player = newPlayer();
      player.renderPrimitive(prim({
        'primitive': 'text',
        'position': {'x': 0.2, 'y': 3.1},
        'text': 'band 3',
      }));
      expect(player.activePrimitives, hasLength(1));
      expect(player.activePrimitives.single.devicePosition.y,
          closeTo(3.1 * 800, 0.001));
    });

    test('drops primitives while paused (engine holds the queue)', () {
      final player = newPlayer()..pauseRendering();
      player.renderPrimitive(prim({
        'primitive': 'dot',
        'position': {'x': 0.5, 'y': 0.5},
      }));
      expect(player.activePrimitives, isEmpty);
    });

    test('re-places content when the surface is re-inited at a new size',
        () {
      final player = newPlayer();
      player.renderPrimitive(prim({
        'primitive': 'dot',
        'position': {'x': 0.5, 'y': 1.5},
      }));
      player.init(200, 400); // resize path
      expect(player.activePrimitives.single.devicePosition.x,
          closeTo(100, 0.001));
      expect(player.activePrimitives.single.devicePosition.y,
          closeTo(600, 0.001));
    });
  });

  group('whiteboard camera', () {
    test('camera_move pans to the target and never lands on the board',
        () async {
      final player = newPlayer();
      player.renderPrimitive(prim({
        'primitive': 'camera_move',
        'target': {'x': 0.0, 'y': 1.96},
        'duration_ms': 40,
      }));
      expect(player.activePrimitives, isEmpty,
          reason: 'camera events must not be drawn');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(player.cameraX, 0);
      expect(player.cameraY, closeTo(1.96, 0.0001));
    });

    test('band_start with only a band int targets {0, band}', () async {
      final player = newPlayer();
      player.renderPrimitive(prim({
        'primitive': 'band_start',
        'band': 2,
        'duration_ms': 40,
      }));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(player.cameraY, closeTo(2.0, 0.0001));
    });

    test('malformed camera event holds the current shot', () {
      final player = newPlayer();
      player.renderPrimitive(prim({'primitive': 'camera_move'}));
      expect(player.cameraY, 0);
    });

    test('instant clearCanvas parks the camera back at origin', () async {
      final player = newPlayer();
      player.renderPrimitive(prim({
        'primitive': 'camera_move',
        'target': {'x': 0.0, 'y': 3.0},
        'duration_ms': 20,
      }));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(player.cameraY, closeTo(3.0, 0.0001));
      player.clearCanvas();
      expect(player.cameraY, 0);
      expect(player.cameraX, 0);
    });
  });

  group('clear vocabulary (pre-band content + explicit erases)', () {
    test('clear all with fade moves content to the fading list, then prunes',
        () async {
      final player = newPlayer();
      player.renderPrimitive(prim({
        'primitive': 'text',
        'position': {'x': 0.1, 'y': 0.1},
        'text': 'a',
      }));
      player.renderPrimitive(prim({
        'primitive': 'clear',
        'target': 'all',
        'animation': 'fade_out',
        'duration_ms': 30,
      }));
      expect(player.activePrimitives, isEmpty);
      expect(player.fadingPrimitives, hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(player.fadingPrimitives, isEmpty);
    });

    test('clear by id removes only the matching element, instantly', () {
      final player = newPlayer();
      player.renderPrimitive(prim({
        'primitive': 'text',
        'id': 'keep',
        'position': {'x': 0.1, 'y': 0.1},
        'text': 'keep',
      }));
      player.renderPrimitive(prim({
        'primitive': 'text',
        'id': 'gone',
        'position': {'x': 0.1, 'y': 0.3},
        'text': 'gone',
      }));
      player.renderPrimitive(prim({
        'primitive': 'clear',
        'target': 'gone',
        'animation': 'instant',
      }));
      expect(player.activePrimitives, hasLength(1));
      expect(player.activePrimitives.single.primitive.id, 'keep');
      expect(player.fadingPrimitives, isEmpty);
    });

    test('clearCanvas(fade: true) animates the wipe', () async {
      final player = newPlayer();
      player.renderPrimitive(prim({
        'primitive': 'dot',
        'position': {'x': 0.5, 'y': 0.5},
      }));
      player.clearCanvas(fade: true);
      expect(player.activePrimitives, isEmpty);
      expect(player.fadingPrimitives, hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(player.fadingPrimitives, isEmpty);
    });
  });
}
