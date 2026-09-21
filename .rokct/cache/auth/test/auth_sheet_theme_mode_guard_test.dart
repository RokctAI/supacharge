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

// Three auth sheets — the OTP confirmation sheet, the phone-verify sheet and
// the reset-password sheet — follow a theme-mode flip while they stay open
// (Ray, 2026-09-19: "glance doesnt change test immediately untill you come
// back if you switched theme mode" — the same defect, found here by the fleet
// audit that followed). Each one decided its colours from AppStyle's
// mode-resolving statics, which are not inherited widgets, and read nothing
// else from its BuildContext that a theme-mode flip touches, so the flip
// scheduled no rebuild and the previous mode's colours stayed on screen.
//
// WHY THIS IS A SOURCE GUARD AND NOT A WIDGET TEST, unlike the sibling
// set_password_theme_mode_test.dart and registration_steps_theme_mode_test.dart
// -------------------------------------------------------------------------
// All three of these pages pull in
// lib/src/common/infrastructure/services/offline_auth_service.dart — the
// confirmation sheet through registerConfirmationProvider, and the other two
// through their import of the confirmation sheet itself, which they push on
// success. That service talks to base_sdk's drift AppDatabase through
// `_db.offlineUsersTable`, `OfflineUsersTableCompanion` and
// `OfflineUserEntity`, none of which exist in this package's own checkout:
// they are generated only after the COMPOSER injects auth_sdk's
// OfflineUsersTable (manifest.json "database") into base_sdk's
// @DriftDatabase and re-runs drift, which happens in a composed app's
// .rokct cache and not here. So any test that imports one of these three
// pages fails to compile in this package, with the same errors that already
// keep auth_sync_handler_demo_session_test.dart and
// demo_account_session_test.dart red on a clean checkout. A widget test is
// therefore impossible for these three until that seam changes; nothing was
// skipped, disabled or quarantined to get here.
//
// What this guard does instead is check, on the source itself, the two
// halves of the fix: the build takes its mode from the inherited theme
// (Theme.of(context).brightness, read once and outside every inner builder),
// and no colour still comes from a mode-resolving AppStyle static that has a
// brightness-taking helper. It fails on the pre-fix source and passes after.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The mode-resolving statics on AppStyle that base_sdk gives a
/// brightness-taking counterpart for (inkFor, secondaryInkFor, faintFor,
/// surfaceFor). A build that still reads one of these decides a colour from
/// the app-wide AppStyle.isDark flag.
const List<String> _resolvedByHelper = <String>[
  'AppStyle.isDark',
  'AppStyle.surfaceDark',
  'AppStyle.textPrimary',
  'AppStyle.textDarkSecondary',
  'AppStyle.textDarkFaint',
];

/// The file with its `//` comments removed, so the prose above a fix cannot
/// satisfy or trip a check that is about code.
String _code(String path) {
  final File file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  return file
      .readAsLinesSync()
      .map((String line) {
        final int marker = line.indexOf('//');
        return marker == -1 ? line : line.substring(0, marker);
      })
      .join('\n');
}

void main() {
  const Map<String, String> subjects = <String, String>{
    '_RegisterConfirmationPageState':
        'lib/src/common/presentation/pages/auth/confirmation/'
            'register_confirmation_page.dart',
    'PhoneVerify': 'lib/src/common/presentation/pages/auth/phone_verify.dart',
    'ResetPasswordPage':
        'lib/src/common/presentation/pages/auth/reset/reset_password_page.dart',
  };

  /// Every static colour role the three sheets are expected to name through a
  /// helper, per file, so a regression that swaps one back is caught by name.
  const Map<String, List<String>> expectedHelperCalls = <String, List<String>>{
    '_RegisterConfirmationPageState': <String>[
      'AppStyle.surfaceFor(brightness)',
      'AppStyle.secondaryInkFor(brightness)',
    ],
    'PhoneVerify': <String>[
      'AppStyle.surfaceFor(brightness)',
      'AppStyle.inkFor(brightness)',
    ],
    'ResetPasswordPage': <String>[
      'AppStyle.surfaceFor(brightness)',
      'AppStyle.secondaryInkFor(brightness)',
      'AppStyle.inkFor(brightness)',
    ],
  };

  subjects.forEach((String subject, String path) {
    group(subject, () {
      test('takes its mode from the inherited theme, once, in build', () {
        final String code = _code(path);

        // Exactly one read, so there is one source of truth for the mode.
        expect(
          RegExp(r'Theme\.of\(context\)\.brightness').allMatches(code).length,
          1,
          reason: '$subject must read Theme.of(context).brightness exactly '
              'once in its build — a theme-mode flip reschedules nothing '
              'that reads only AppStyle.isDark',
        );

        // Assigned to a local at the build method's own nesting level (four
        // spaces), i.e. outside every inner builder, so nested builders
        // cannot each resolve their own mode.
        expect(
          code,
          contains(
              '\n    final Brightness brightness = '
              'Theme.of(context).brightness;'),
          reason: '$subject must bind the brightness once at the top of '
              'build, outside every inner builder',
        );
      });

      test('names no colour through a mode-resolving AppStyle static that has '
          'a brightness-taking helper', () {
        final String code = _code(path);

        for (final String static in _resolvedByHelper) {
          expect(
            code.contains(static),
            isFalse,
            reason: '$subject still reads $static, which resolves against the '
                'app-wide AppStyle.isDark flag instead of this build\'s '
                'brightness',
          );
        }
      });

      test('passes that brightness to the AppStyle role helpers', () {
        final String code = _code(path);

        for (final String call in expectedHelperCalls[subject]!) {
          expect(code, contains(call),
              reason: '$subject should name its colour roles through $call');
        }
      });

      test('introduces no colour literal of its own', () {
        // The fix must not change a colour value in either mode, and a page
        // never spells a colour out: every value stays in AppStyle, where
        // the brand palette is injected.
        expect(_code(path).contains('0x'), isFalse,
            reason: '$subject must not spell a colour out — the values live '
                'in AppStyle');
      });
    });
  });
}
