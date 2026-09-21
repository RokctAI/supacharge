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

// The post-splash system UI mode. A tour build on a large screen hides the
// system bars (Android hides the launcher taskbar only when the app hides
// its navigation bar, and the taskbar otherwise burns into every tablet
// still); every shipped build and every phone keeps edge-to-edge, exactly
// as before. The flag that decides it (`AppConstants.isTour`) is read in
// the two seams that own it and nowhere else, so a shipped build can never
// grow a third tour seam.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/presentation/adaptive/tour_system_ui.dart';

/// The only files that may read the tour flag, relative to the repo root.
///
/// * `tour_system_ui.dart` turns it into a post-splash system UI mode.
/// * `demo_session.dart` is the demo switch: the tour build is the one
///   build with no backend and no sign-in to assert a demo-account marker
///   with, so `DemoSession.demoActive` is `isTour || instance.active`. It
///   took that half over from the deleted `AppConstants.isDemo`.
const Set<String> _deliberateReaders = {
  'base/dart/lib/src/presentation/adaptive/tour_system_ui.dart',
  'base/dart/lib/src/services/demo_session.dart',
};

final RegExp _read = RegExp(r'\bAppConstants\.isTour\b');

/// The repo root: the nearest ancestor of the working directory that holds
/// this package's manifest under `base/dart/`.
Directory _repoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/base/dart/manifest.json').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail(
        'repo root (a directory holding base/dart/manifest.json) not '
        'found above ${Directory.current.path}',
      );
    }
    dir = parent;
  }
}

/// Every Dart source the packages ship or install: `<sdk>/dart/lib` and
/// `<sdk>/dart/templates`, for every SDK directory in the repo.
Iterable<File> _sources(Directory root) sync* {
  for (final sdk in root.listSync().whereType<Directory>()) {
    for (final sub in const ['lib', 'templates']) {
      final dir = Directory('${sdk.path}/dart/$sub');
      if (!dir.existsSync()) continue;
      yield* dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
    }
  }
}

/// True when [line] reads the flag in code - comments do not count.
bool _readsInCode(String line) {
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('//')) return false;
  final comment = line.indexOf('//');
  final code = comment < 0 ? line : line.substring(0, comment);
  return _read.hasMatch(code);
}

/// Pumps a widget on a [logical]-pixel surface at DPR 1 and applies the
/// post-splash mode from inside it, recording every platform-channel call.
Future<List<MethodCall>> _applyOn(
  WidgetTester tester,
  Size logical, {
  required bool tourMode,
}) async {
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      calls.add(call);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );

  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    Builder(
      builder: (context) {
        expect(MediaQuery.sizeOf(context), logical);
        applyPostSplashSystemUi(context, tourMode: tourMode);
        return const SizedBox.shrink();
      },
    ),
  );
  await tester.pump();
  return calls
      .where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
      .toList();
}

void main() {
  group('postSplashSystemUiMode', () {
    test('a tour build on a portrait tablet goes immersive', () {
      expect(
        postSplashSystemUiMode(size: const Size(1066, 1706), tourMode: true),
        SystemUiMode.immersiveSticky,
      );
    });

    test('a tour build on a landscape tablet goes immersive', () {
      expect(
        postSplashSystemUiMode(size: const Size(1706, 1066), tourMode: true),
        SystemUiMode.immersiveSticky,
      );
    });

    test('a tour build on a small tablet goes immersive', () {
      expect(
        postSplashSystemUiMode(size: const Size(800, 1280), tourMode: true),
        SystemUiMode.immersiveSticky,
      );
    });

    test('a tour build on a phone keeps edge-to-edge', () {
      expect(
        postSplashSystemUiMode(size: const Size(375, 812), tourMode: true),
        SystemUiMode.edgeToEdge,
      );
    });

    test('a shipped build on a tablet keeps edge-to-edge', () {
      expect(
        postSplashSystemUiMode(size: const Size(1066, 1706), tourMode: false),
        SystemUiMode.edgeToEdge,
      );
    });

    test('one logical pixel short of the medium breakpoint is a phone', () {
      expect(
        postSplashSystemUiMode(size: const Size(599, 1000), tourMode: true),
        SystemUiMode.edgeToEdge,
      );
    });

    test('the default answer in a test process is edge-to-edge', () {
      // No TOUR_MODE dart-define here, so the compile-time default must be
      // the shipped answer even on a tablet-sized window.
      expect(
        postSplashSystemUiMode(size: const Size(1066, 1706)),
        SystemUiMode.edgeToEdge,
      );
    });
  });

  group('applyPostSplashSystemUi', () {
    testWidgets('sends exactly one immersive-sticky mode on a tour tablet', (
      tester,
    ) async {
      final calls = await _applyOn(
        tester,
        const Size(1066, 1706),
        tourMode: true,
      );
      expect(calls, hasLength(1));
      // SystemChrome.setEnabledSystemUIMode sends `mode.toString()` for
      // every mode but manual.
      expect(calls.single.arguments, 'SystemUiMode.immersiveSticky');
    });

    testWidgets('sends exactly one edge-to-edge mode on a tour phone', (
      tester,
    ) async {
      final calls = await _applyOn(
        tester,
        const Size(375, 812),
        tourMode: true,
      );
      expect(calls, hasLength(1));
      expect(calls.single.arguments, 'SystemUiMode.edgeToEdge');
    });
  });

  group('source contract', () {
    test('AppConstants.isTour is read in its two own seams only', () {
      final root = _repoRoot();
      final readers = <String>{};
      for (final file in _sources(root)) {
        final relative = file.path.substring(root.path.length + 1);
        if (file.readAsLinesSync().any(_readsInCode)) readers.add(relative);
      }
      expect(
        readers,
        equals(_deliberateReaders),
        reason:
            'the tour flag stays confined to the seam that turns it into a '
            'system UI mode and the demo switch that ORs it with the '
            'runtime session; ask postSplashSystemUiMode or '
            'DemoSession.demoActive instead',
      );
    });
  });
}
