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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/common/translation_seeder.dart';
import 'package:base_sdk/src/models/response/languages_response.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/bundled_en_translations.dart';
import 'package:base_sdk/src/services/bundled_translations.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';

/// Contract under test — the candidate set the seeder offers the
/// (insert-only) backend endpoint:
///
///   * active-locale rows are diffed against the served map (the only
///     locale that CAN be diffed locally);
///   * an `en` row is offered for every key any bundled locale registers,
///     valued with the bundled `en` entry when one is registered and with
///     AppHelpers.humanizeTrKey otherwise — i.e. exactly what the UI
///     renders for the key — and diffed only when `en` is the active
///     locale;
///   * output is (locale, key)-sorted so the persisted fingerprint is
///     stable across launches;
///   * the fingerprint changes when any row or the salt changes.
void main() {
  Map<String, String> rowsFor(
    List<Map<String, String>> rows,
    String locale,
  ) {
    return {
      for (final row in rows)
        if (row['locale'] == locale) row['key']!: row['value']!,
    };
  }

  group('TranslationSeeder.computeCandidateRows', () {
    test('diffs the active locale against the served map', () {
      final af = BundledTranslations.entriesFor('af')!;
      final servedKey = af.keys.first;
      final missingKey = af.keys.skip(1).first;

      final rows = TranslationSeeder.computeCandidateRows(
        servedMap: {servedKey: 'reeds bedien'},
        activeLocale: 'af',
      );

      final afRows = rowsFor(rows, 'af');
      expect(afRows.containsKey(servedKey), isFalse);
      expect(afRows[missingKey], af[missingKey]);
    });

    test('offers humanized en rows for every bundled key, undiffed when '
        'en is not the active locale', () {
      final af = BundledTranslations.entriesFor('af')!;
      final servedKey = af.keys.first;

      final rows = TranslationSeeder.computeCandidateRows(
        servedMap: {servedKey: 'reeds bedien'},
        activeLocale: 'af',
      );

      final enRows = rowsFor(rows, 'en');
      // The served map is Afrikaans — it says nothing about what exists
      // server-side for en, so en rows are offered wholesale.
      expect(enRows[servedKey], AppHelpers.humanizeTrKey(servedKey));
      for (final key in af.keys.take(20)) {
        expect(enRows[key], AppHelpers.humanizeTrKey(key));
      }
    });

    test('prefers a bundled en entry over the humanized key', () {
      final rows = TranslationSeeder.computeCandidateRows(
        servedMap: const {},
        activeLocale: 'af',
      );

      final enRows = rowsFor(rows, 'en');
      // The maintenance keys NAME a string rather than spelling it: the
      // humanized "Maintenance title" is not copy, and seeding it would
      // plant that literal in the backend for every tenant.
      expect(enRows[TrKeys.maintenanceTitle], 'Under maintenance');
      expect(
        enRows[TrKeys.maintenanceBrief],
        'We are doing some maintenance. Please try again shortly.',
      );
      expect(
        enRows[TrKeys.maintenanceTitle],
        isNot(AppHelpers.humanizeTrKey(TrKeys.maintenanceTitle)),
      );
      // A key with no bundled en entry is still humanized.
      final af = BundledTranslations.entriesFor('af')!;
      final plainKey = af.keys.firstWhere(
        (key) => !kBaseEnTranslations.containsKey(key),
      );
      expect(enRows[plainKey], AppHelpers.humanizeTrKey(plainKey));
    });

    test('an SDK-registered en entry wins over the humanized key too', () {
      const key = 'seeder_test_registered_key';
      BundledTranslations.register('en', const {key: 'Registered copy'});
      addTearDown(() => BundledTranslations.register('en', const {key: ''}));

      final rows = TranslationSeeder.computeCandidateRows(
        servedMap: const {},
        activeLocale: 'af',
      );

      expect(rowsFor(rows, 'en')[key], 'Registered copy');
    });

    test('diffs en rows when en IS the active locale', () {
      final af = BundledTranslations.entriesFor('af')!;
      final servedKey = af.keys.first;

      final rows = TranslationSeeder.computeCandidateRows(
        servedMap: {servedKey: 'Already served'},
        activeLocale: 'en',
      );

      final enRows = rowsFor(rows, 'en');
      expect(enRows.containsKey(servedKey), isFalse);
    });

    test('is (locale, key)-sorted for a stable fingerprint', () {
      final rows = TranslationSeeder.computeCandidateRows(
        servedMap: const {},
        activeLocale: 'af',
      );
      final ordered = [
        for (final row in rows) '${row['locale']}${row['key']}',
      ];
      final sorted = [...ordered]..sort();
      expect(ordered, sorted);
    });

    test('humanizeTrKey renders dots/underscores as spaces with a leading '
        'capital', () {
      expect(AppHelpers.humanizeTrKey('add.storeis'), 'Add storeis');
      expect(
        AppHelpers.humanizeTrKey('do_you_want_to_delete_it?'),
        'Do you want to delete it?',
      );
    });

    test('humanizeTrKey breaks camelCase into lower-cased words (the raw '
        'key must never leak into the UI)', () {
      // The exact bug on show in the profile footer: the year key's
      // camelCase value fell through untouched as "DaysInAppThisYear".
      expect(
        AppHelpers.humanizeTrKey('daysInAppThisYear'),
        'Days in app this year',
      );
      expect(AppHelpers.humanizeTrKey('goodAfternoon'), 'Good afternoon');
      // Words already separated keep their own capitalization: only a
      // lowercase/digit-to-uppercase boundary is a camelCase break.
      expect(AppHelpers.humanizeTrKey('good.Morning'), 'Good Morning');
      expect(AppHelpers.humanizeTrKey('Save.for.Later'), 'Save for Later');
    });
  });

  group('bundled en copy', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
    });

    test('en is a bundled locale and English is still listed once', () {
      expect(BundledTranslations.bundledLocales, contains('en'));
      expect(BundledTranslations.entriesFor('en'), isNotNull);
      final english = BundledTranslations.fallbackLanguages()
          .where((l) => l.locale == 'en');
      expect(english.length, 1);
      expect(BundledTranslations.fallbackLanguages().first.locale, 'en');
    });

    test('the maintenance page copy resolves on an unseeded en tenant',
        () async {
      // No served map at all (the tenant's Translation doctype has no en
      // rows) and English selected: getTranslation must reach the bundled
      // copy, not the humanized key the page used to show.
      await LocalStorage.setLanguageData(
        LanguageData(id: 'local-en', title: 'English', locale: 'en'),
      );
      expect(LocalStorage.getTranslations(), isEmpty);
      expect(
        AppHelpers.getTranslation(TrKeys.maintenanceTitle),
        'Under maintenance',
      );
      expect(
        AppHelpers.getTranslation(TrKeys.maintenanceBrief),
        'We are doing some maintenance. Please try again shortly.',
      );
    });

    test('a served en row still wins over the bundled copy', () async {
      await LocalStorage.setLanguageData(
        LanguageData(id: 'local-en', title: 'English', locale: 'en'),
      );
      await LocalStorage.setTranslations(
        {TrKeys.maintenanceTitle: 'Back soon'},
      );
      expect(AppHelpers.getTranslation(TrKeys.maintenanceTitle), 'Back soon');
    });
  });

  group('TranslationSeeder.fingerprint', () {
    test('is stable for equal input and sensitive to rows and salt', () {
      final rows = [
        {'locale': 'en', 'key': 'a.b', 'value': 'A b'},
        {'locale': 'en', 'key': 'c.d', 'value': 'C d'},
      ];
      final same = [
        {'locale': 'en', 'key': 'a.b', 'value': 'A b'},
        {'locale': 'en', 'key': 'c.d', 'value': 'C d'},
      ];
      final changed = [
        {'locale': 'en', 'key': 'a.b', 'value': 'A b!'},
        {'locale': 'en', 'key': 'c.d', 'value': 'C d'},
      ];

      expect(
        TranslationSeeder.fingerprint(rows, '1.0.0+1'),
        TranslationSeeder.fingerprint(same, '1.0.0+1'),
      );
      expect(
        TranslationSeeder.fingerprint(rows, '1.0.0+1'),
        isNot(TranslationSeeder.fingerprint(changed, '1.0.0+1')),
      );
      expect(
        TranslationSeeder.fingerprint(rows, '1.0.0+1'),
        isNot(TranslationSeeder.fingerprint(rows, '1.0.1+2')),
      );
    });
  });
}
