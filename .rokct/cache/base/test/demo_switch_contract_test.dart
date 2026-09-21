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


// Source contract for the demo switch. `DemoSession.demoActive` is the one
// question every demo seam asks, and now the only one: the guided-tour
// build (`AppConstants.isTour`, the one build with no backend and no
// sign-in to assert a marker with) OR the runtime session auth_sdk
// activates from the server-asserted demo-account marker. The compile-time
// `AppConstants.isDemo` (`--dart-define=IS_DEMO=true`) is gone - a seam
// that read it served a server-marked demo account the real repositories,
// silently, and a flag no build passes could only ever read false. So: no
// source file in any Dart package of this repo may read
// `AppConstants.isDemo`, and `app_constants.dart` no longer declares it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _read = RegExp(r'\bAppConstants\.isDemo\b');

/// The repo root: the nearest ancestor of the working directory that holds
/// this package's manifest under `base/dart/`. `flutter test` runs with
/// the package root as its working directory, so this is two levels up.
Directory _repoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/base/dart/manifest.json').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('repo root (a directory holding base/dart/manifest.json) not '
          'found above ${Directory.current.path}');
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

/// True when [line] reads the constant in code - comments do not count,
/// a doc comment naming `[AppConstants.isDemo]` is documentation.
bool _readsInCode(String line) {
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('//')) return false;
  final comment = line.indexOf('//');
  final code = comment < 0 ? line : line.substring(0, comment);
  return _read.hasMatch(code);
}

void main() {
  test('no Dart source reads AppConstants.isDemo', () {
    final root = _repoRoot();
    final readers = <String>{};
    for (final file in _sources(root)) {
      final relative = file.path.substring(root.path.length + 1);
      if (file.readAsLinesSync().any(_readsInCode)) readers.add(relative);
    }

    expect(readers, isEmpty,
        reason: 'the constant is gone: read DemoSession.demoActive instead '
            '(the tour build OR a demo session), and listen on '
            'DemoSession.instance where the answer is registered or drawn '
            'once');
  });

  test('app_constants.dart no longer declares the compile-time flag', () {
    final root = _repoRoot();
    final source =
        File('${root.path}/base/dart/lib/src/constants/app_constants.dart')
            .readAsStringSync();
    expect(source, isNot(contains('static const bool isDemo')));
    expect(source, isNot(contains("fromEnvironment('IS_DEMO')")));
    // The tour's own flag stays: it is the build half of [demoActive].
    expect(source, contains("bool.fromEnvironment('TOUR_MODE')"));
  });

  test('DemoSession.demoActive is the only demo switch', () {
    final root = _repoRoot();
    final source =
        File('${root.path}/base/dart/lib/src/services/demo_session.dart')
            .readAsStringSync();
    // The tour build OR the runtime session, and nothing else - no
    // compile-time constant and no test-only stand-in for one.
    const or = 'static bool get demoActive => '
        'AppConstants.isTour || instance.active;';
    expect(source, contains(or));
    expect(source, isNot(contains('isDemoOverride')));
  });
}
