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

// Regression guard for the reset-password sheet's copy. Every app shell's
// guided tour rendered the literal "Reset password text" there: base_sdk
// bundles no `en` map, the demo served map (comms_sdk's
// MockSettingsRepository) never carried `reset_password_text`, and the
// humanized-key fallback only produces real copy for keys named after
// their copy. auth_sdk now bundles the English row and registers it via a
// manifest boot hook; this test pins both halves, because the hook is
// DATA in manifest.json - a typo there is dropped silently at compose
// time, not caught by the analyzer.

import 'dart:convert';
import 'dart:io';

import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/bundled_translations.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auth_sdk/src/translations/auth_en_translations.dart';

void main() {
  group('kAuthEnTranslations', () {
    test('carries the reset-password sheet copy', () {
      expect(
        kAuthEnTranslations[TrKeys.resetPasswordText],
        'Enter the email address for your account and we will send you a '
        'link to reset your password.',
      );
    });

    test(
        'carries a variant per sign-up type, each promising what the '
        'backend sends', () {
      // A phone sign-up resets by code to a number; "both" may get either.
      // The email/link copy above a phone field promised the wrong thing.
      expect(
        kAuthEnTranslations[TrKeys.resetPasswordPhoneText],
        'Enter the phone number for your account and we will send you a '
        'code to reset your password.',
      );
      expect(
        kAuthEnTranslations[TrKeys.resetPasswordEitherText],
        'Enter the email address or phone number for your account and we '
        'will send you a link or a code to reset your password.',
      );
      expect(kAuthEnTranslations[TrKeys.resetPasswordPhoneText],
          isNot(contains('email')));
      expect(kAuthEnTranslations[TrKeys.resetPasswordPhoneText],
          isNot(contains('link')));
    });

    test('every row is real copy, not the humanized key', () {
      // A row whose value equals the humanized key adds nothing over the
      // fallback and hides the keys that actually need copy.
      kAuthEnTranslations.forEach((key, value) {
        expect(value.trim(), isNotEmpty, reason: key);
        expect(value, isNot(AppHelpers.humanizeTrKey(key)), reason: key);
      });
    });

    test('every key is a backend key this SDK renders', () {
      // Keys are backend translation keys (TrKeys VALUES), and each must be
      // referenced from lib/ - a row for a key nothing renders is dead
      // weight the seeder would still offer the backend.
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.contains('/translations/'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      const constantsByKey = <String, String>{
        'reset_password_text': 'resetPasswordText',
        'reset_password_phone_text': 'resetPasswordPhoneText',
        'reset_password_either_text': 'resetPasswordEitherText',
      };
      for (final key in kAuthEnTranslations.keys) {
        final constant = constantsByKey[key];
        expect(constant, isNotNull,
            reason: '$key has no TrKeys constant listed in this test');
        expect(sources, contains('TrKeys.$constant'),
            reason: '$key ($constant) is not rendered anywhere in lib/');
      }
    });

    test('resolves through BundledTranslations once registered', () {
      BundledTranslations.register('en', kAuthEnTranslations);
      expect(
        BundledTranslations.lookup('en', TrKeys.resetPasswordText),
        kAuthEnTranslations[TrKeys.resetPasswordText],
      );
      // fallbackLanguages() lists English once even though `en` now has a
      // bundled map: the picker must not grow a second "English" row.
      final english = BundledTranslations.fallbackLanguages()
          .where((l) => l.locale == 'en');
      expect(english.length, 1);
    });
  });

  group('manifest boot hook', () {
    final manifest = jsonDecode(File('manifest.json').readAsStringSync())
        as Map<String, dynamic>;
    final hooks = ((manifest['boot_hooks'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    test('registers the bundled en map at boot', () {
      final hook = hooks.singleWhere(
        (h) => h['id'] == 'auth_en_bundled_translations',
        orElse: () => <String, dynamic>{},
      );
      expect(hook, isNotEmpty,
          reason: 'boot_hooks lost the auth_en_bundled_translations entry');
      expect(hook['body'],
          "BundledTranslations.register('en', kAuthEnTranslations);");
      // Neither symbol is exported by the auth_sdk barrel every composed
      // main.dart already imports, so the hook must carry its own imports
      // (src paths, the lms_sdk pattern) or the composed shell does not
      // analyze.
      final imports = (hook['imports'] as List).cast<String>();
      expect(
        imports,
        containsAll([
          "import 'package:base_sdk/src/services/bundled_translations.dart';",
          "import 'package:auth_sdk/src/translations/auth_en_translations.dart';",
        ]),
      );
    });

    test('hook ids and orders stay unique', () {
      final ids = hooks.map((h) => h['id']).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate hook id');
      final orders = hooks.map((h) => h['order']).toList();
      expect(orders.toSet().length, orders.length,
          reason: 'duplicate hook order');
    });
  });
}
