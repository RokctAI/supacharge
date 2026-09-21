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

// The language picker's catalogue contract.
//
// `api.language.get_languages` (tenant/api/language/language.py) answers a
// bare Frappe `get_list` result over the `PaaS Language` doctype — a LIST,
// not an `api_response` envelope — whose `backward`/`default`/`active`
// Check fields arrive as the ints 1/0. Both of those used to blow up
// LanguageData; the stock-`Language` endpoint that was called instead
// (`api.system.get_languages`) parsed cleanly but carried neither `title`
// nor `locale`, so the picker drew blank rows and every translation fetch
// fell back to 'en'. All language data below is invented.

import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/models/response/languages_response.dart';

void main() {
  group('api.language.get_languages — the catalogue endpoint', () {
    // Shaped exactly like frappe.get_list("PaaS Language", fields=[...])
    // after the gateway interceptor unwraps `message`: a bare list, Check
    // fields as ints, `name` as the docname.
    final realisticPayload = [
      {
        'name': 'zzq-english',
        'title': 'English',
        'locale': 'en',
        'backward': 0,
        'default': 1,
        'active': 1,
        'img': null,
      },
      {
        'name': 'zzq-zephyrian',
        'title': 'Zephyrian',
        'locale': 'zq',
        'backward': 1,
        'default': 0,
        'active': 1,
        'img': '/files/zephyrian-flag.png',
      },
    ];

    test('parses the bare get_list response into full picker rows', () {
      final response = LanguagesResponse.fromJson(realisticPayload);

      expect(response.data, hasLength(2));

      final english = response.data![0];
      expect(english.id, 'zzq-english');
      expect(english.title, 'English');
      expect(english.locale, 'en');
      expect(english.backward, isFalse);
      expect(english.isDefault, isTrue);
      expect(english.active, isTrue);
      expect(english.img, isNull);

      final zephyrian = response.data![1];
      expect(zephyrian.id, 'zzq-zephyrian');
      expect(zephyrian.title, 'Zephyrian');
      expect(zephyrian.locale, 'zq');
      expect(zephyrian.backward, isTrue);
      expect(zephyrian.isDefault, isFalse);
      expect(zephyrian.img, '/files/zephyrian-flag.png');
    });

    test('every row carries the locale the translations fetch sends', () {
      final response = LanguagesResponse.fromJson(realisticPayload);
      // settings_repository.getMobileTranslations sends
      // `LocalStorage.getLanguage()?.locale ?? 'en'` — a null locale here
      // silently pins every language to English.
      expect(
        response.data!.map((e) => e.locale),
        everyElement(isNotNull),
      );
      expect(response.data!.map((e) => e.locale), ['en', 'zq']);
    });

    test('the default row is findable, so it can be stored on first run',
        () {
      final response = LanguagesResponse.fromJson(realisticPayload);
      final defaults =
          response.data!.where((e) => e.isDefault ?? false).toList();
      expect(defaults, hasLength(1));
      expect(defaults.single.locale, 'en');
    });

    test('a picker row survives the LocalStorage toJson/fromJson round trip',
        () {
      final stored = LanguagesResponse.fromJson(realisticPayload).data![1];
      final restored = LanguageData.fromJson(stored.toJson());
      expect(restored.id, 'zzq-zephyrian');
      expect(restored.title, 'Zephyrian');
      expect(restored.locale, 'zq');
      expect(restored.backward, isTrue);
      expect(restored.isDefault, isFalse);
    });
  });

  group('Check fields arrive as ints, not booleans', () {
    test('int 1/0 coerce to true/false', () {
      final row = LanguageData.fromJson(
        {'name': 'zzq-a', 'title': 'A', 'locale': 'aa', 'backward': 1,
          'default': 0, 'active': 1},
      );
      expect(row.backward, isTrue);
      expect(row.isDefault, isFalse);
      expect(row.active, isTrue);
    });

    test('real booleans still pass straight through', () {
      final row = LanguageData.fromJson(
        {'id': 'zzq-b', 'title': 'B', 'locale': 'bb', 'backward': true,
          'default': false, 'active': true},
      );
      expect(row.backward, isTrue);
      expect(row.isDefault, isFalse);
      expect(row.active, isTrue);
    });

    test('an absent Check field stays null rather than throwing', () {
      final row =
          LanguageData.fromJson({'name': 'zzq-c', 'title': 'C', 'locale': 'cc'});
      expect(row.backward, isNull);
      expect(row.isDefault, isNull);
      expect(row.active, isNull);
    });
  });

  group('the `api_response` envelope still parses', () {
    test('an enveloped payload keeps working alongside the bare list', () {
      final response = LanguagesResponse.fromJson({
        'timestamp': '2026-08-31 09:00:00',
        'status': true,
        'message': 'OK',
        'data': [
          {'id': 'zzq-english', 'title': 'English', 'locale': 'en',
            'backward': false, 'default': true, 'active': true},
        ],
      });
      expect(response.status, isTrue);
      expect(response.message, 'OK');
      expect(response.data, hasLength(1));
      expect(response.data!.single.locale, 'en');
    });
  });

  group('regression: the stock `Language` payload is NOT the catalogue', () {
    test('api.system.get_languages rows have no title and no locale', () {
      // What tenant/api/system/system.py get_languages answers: the stock
      // frappe `Language` doctype, `name` + `language_name` only. It
      // parses without throwing — which is exactly why calling it left
      // the picker silently blank instead of failing over to the bundled
      // language list.
      final response = LanguagesResponse.fromJson({
        'data': [
          {'name': 'en', 'language_name': 'English'},
          {'name': 'zq', 'language_name': 'Zephyrian'},
        ],
        'status_code': 200,
      });
      expect(response.data, hasLength(2));
      expect(response.data!.map((e) => e.title), everyElement(isNull));
      expect(response.data!.map((e) => e.locale), everyElement(isNull));
      expect(response.data!.map((e) => e.isDefault), everyElement(isNull));
    });
  });
}
