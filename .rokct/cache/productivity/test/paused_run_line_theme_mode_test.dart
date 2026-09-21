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

// The paused-run line takes its mode from the INHERITED THEME, never from
// the app-wide AppStyle.isDark flag (Ray, 2026-09-19: "glance doesnt change
// test immediately untill you come back if you switched theme mode" — the
// same defect, found here by the audit that followed).
//
// Why this reads the widget as SOURCE rather than pumping it: chip 859 is
// composed into the HOST's Tasks row and reaches its data through
// `paused_run.dart`, which imports the drift-backed todo repository. Those
// generated sources are not built in this package, so any test that imports
// paused_run_line.dart fails to load — which is exactly why the shipped
// paused_run_line_test.dart is one of this package's standing load
// failures, on main and on this branch alike. The mechanism is therefore
// pinned where it lives, the same fallback
// template_page_theme_mode_test.dart uses for the auto_route pages.
//
// What makes this widget a genuine case rather than a reachable one: its
// only parent here, [PausedRunLine], asks nothing inherited for the mode —
// it watches a store provider — and the row it is composed into lives in
// the host, outside this package, so no rebuild can be shown to reach the
// line at all. A mutable static is not an inherited widget, so with nothing
// asked for the mode the flip scheduled no rebuild of it and the hairline
// and subline kept the previous mode's colours. The live, pumped proof of
// the same mechanism is sheet_theme_mode_test.dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _path = 'lib/src/common/presentation/hub/paused_run_line.dart';

/// The widget's code with its `//` comment lines dropped: a colour named in
/// prose is not a colour the widget paints with.
String _code() {
  final File file = File(_path);
  expect(file.existsSync(), isTrue, reason: 'missing source: $_path');
  return file
      .readAsLinesSync()
      .where((String line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

void main() {
  group('the paused-run line', () {
    test('takes the mode from the inherited theme', () {
      expect(
        _code(),
        contains('Theme.of(context).brightness'),
        reason: '$_path decides a colour from the theme mode but asks '
            'nothing inherited for it, so the flip reschedules no rebuild',
      );
    });

    test('names its hairline and its subline through AppStyle mode seams', () {
      final String code = _code();
      expect(code, contains('AppStyle.subtleStrokeFor('));
      expect(code, contains('AppStyle.faintFor('));
    });

    test('reads no mode-resolving AppStyle static', () {
      final String code = _code();
      for (final String name in <String>[
        'AppStyle.isDark',
        'AppStyle.surfaceDark',
        'AppStyle.cardDark',
        'AppStyle.cardDarkAlt',
        'AppStyle.strokeDark',
        'AppStyle.strokeDarkSubtle',
        'AppStyle.textDarkSecondary',
        'AppStyle.textDarkFaint',
        'AppStyle.textPrimary',
      ]) {
        expect(
          code,
          isNot(contains(name)),
          reason: '$_path still reads $name, which is not an inherited '
              'widget: nothing reschedules this line when the mode flips',
        );
      }
    });
  });
}
