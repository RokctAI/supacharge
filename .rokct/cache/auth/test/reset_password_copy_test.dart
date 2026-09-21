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

// The reset-password sheet's instruction line must promise what the field
// under it collects: every sign-up type used to read the email/link copy,
// so a phone sign-up (a phone field, a code by SMS) told the user to enter
// an email address. The selection lives in resetPasswordCopyKey, pinned
// here for all three types; the sheet itself is not pumped because it
// only compiles inside a composed host (its confirmation step reaches
// OfflineAuthService, whose offlineUsersTable the composer injects into
// the host's AppDatabase), and AppConstants.signUpType is a compile-time
// define that cannot be flipped per test anyway.

import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/constants/app_constants.dart';
import 'package:base_sdk/src/services/bundled_translations.dart';
import 'package:base_sdk/src/services/enums.dart';
import 'package:base_sdk/src/services/tr_keys.dart';

import 'package:auth_sdk/src/common/presentation/pages/auth/reset/reset_password_copy.dart';
import 'package:auth_sdk/src/translations/auth_en_translations.dart';

void main() {
  test('a phone sign-up gets the phone/code key', () {
    expect(
      resetPasswordCopyKey(SignUpType.phone),
      TrKeys.resetPasswordPhoneText,
    );
  });

  test('an email sign-up keeps the email/link key', () {
    expect(resetPasswordCopyKey(SignUpType.email), TrKeys.resetPasswordText);
  });

  test('a both sign-up gets the either key', () {
    expect(
      resetPasswordCopyKey(SignUpType.both),
      TrKeys.resetPasswordEitherText,
    );
  });

  test(
      'the default sign-up type (no SIGN_UP_TYPE define) resolves to the '
      'phone copy, which never mentions email or a link', () {
    // What the sheet renders under this package's own test run.
    expect(AppConstants.signUpType, SignUpType.phone);
    BundledTranslations.register('en', kAuthEnTranslations);
    final copy = BundledTranslations.lookup(
      'en',
      resetPasswordCopyKey(AppConstants.signUpType),
    );
    expect(copy, kAuthEnTranslations[TrKeys.resetPasswordPhoneText]);
    expect(copy, isNot(contains('email')));
    expect(copy, isNot(contains('link')));
  });

  test('every sign-up type has bundled copy and the three differ', () {
    final keys = SignUpType.values.map(resetPasswordCopyKey).toSet();
    expect(keys.length, SignUpType.values.length);
    for (final key in keys) {
      expect(kAuthEnTranslations[key], isNotNull, reason: key);
    }
  });
}
