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

// The installed route pages paint their ground for the mode the INHERITED
// THEME reports, never for the app-wide AppStyle.isDark flag (Ray,
// 2026-09-19: "glance doesnt change test immediately untill you come back
// if you switched theme mode" — the same defect, found in these pages by
// the audit that followed).
//
// Why this suite reads the templates as SOURCE rather than pumping them:
// the four pages cannot be compiled by this package at all. Each imports
// `auto_route`, tasks_page.dart also imports `comms_sdk`, and all four go
// through the `productivity_sdk.dart` barrel, which needs drift's and
// freezed's generated sources. None of auto_route, comms_sdk or
// build_runner is a dependency here, so a test that imported one of these
// files would not load — the same reason tasks_workspace_test.dart and
// compose_back_clearance_test.dart pump the components and frames instead
// of the installed page, and the same reason vision_cluster_test.dart
// reads manifest.json off disk. The mechanism these tests pin is
// therefore pinned where it lives: each page must name its ground from
// `Theme.of(context).brightness` through AppStyle's mode seam, and must
// not read the mode-resolving statics, because a static registers no
// dependency and a pushed ModalRoute caches its page — so an ancestor
// rebuild provably never reaches it and the ground would keep the
// previous mode's colour until the reader left the screen and came back.
//
// The live, pumped proof of the same mechanism is
// weekly_check_in_strip_theme_mode_test.dart, whose widget does live in
// lib/ and so can be flipped without a remount.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The page's code with its `//` comment lines dropped: a colour named in
/// prose is not a colour the page paints with.
String _code(String path) {
  final File file = File(path);
  expect(file.existsSync(), isTrue, reason: 'missing template: $path');
  return file
      .readAsLinesSync()
      .where((String line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

/// Each page, and the mode-resolving statics it must no longer read.
///
/// `AppStyle.surfaceDark` is the ground every one of the four painted from
/// a static; `AppStyle.textDarkFaint` is listed for the run push because
/// its absent-task line sits in the same method that now receives the
/// mode. The remaining faint reads inside tasks_page.dart's own row
/// helpers are deliberately NOT listed: they are built inside the
/// workspace build that now depends on the inherited theme, so the flip
/// reschedules them and they resolve afresh. Whether they should name the
/// mode explicitly anyway is a separate decision, not a staleness bug.
const Map<String, List<String>> _pages = <String, List<String>>{
  'templates/pages/tasks/tasks_page.dart': <String>['AppStyle.surfaceDark'],
  'templates/pages/tasks/task_run_page.dart': <String>[
    'AppStyle.surfaceDark',
    'AppStyle.textDarkFaint',
  ],
  'templates/pages/vision/personal_mastery_page.dart': <String>[
    'AppStyle.surfaceDark',
  ],
  'templates/pages/vision/plan_on_a_page.dart': <String>[
    'AppStyle.surfaceDark',
  ],
};

void main() {
  const Map<String, String> pages = <String, String>{
    'the tasks workspace': 'templates/pages/tasks/tasks_page.dart',
    'the task run push': 'templates/pages/tasks/task_run_page.dart',
    'personal mastery': 'templates/pages/vision/personal_mastery_page.dart',
    'plan on a page': 'templates/pages/vision/plan_on_a_page.dart',
  };

  pages.forEach((String name, String path) {
    group(name, () {
      test('takes the mode from the inherited theme', () {
        expect(
          _code(path),
          contains('Theme.of(context).brightness'),
          reason:
              '$path decides a colour from the theme mode but asks nothing '
              'inherited for it, so the flip reschedules no rebuild of it',
        );
      });

      test('names its ground through AppStyle.surfaceFor', () {
        expect(
          _code(path),
          contains('AppStyle.surfaceFor('),
          reason: '$path must resolve the page background against an '
              'explicit Brightness, not the app-wide flag',
        );
      });

      test('reads no mode-resolving AppStyle static for the roles it fixed',
          () {
        final String code = _code(path);
        for (final String static in _pages[path]!) {
          expect(
            code,
            isNot(contains(static)),
            reason: '$path still reads $static, which is not an inherited '
                'widget: nothing reschedules this page when the mode flips',
          );
        }
      });
    });
  });
}
