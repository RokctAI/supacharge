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

// AppHelpers.appNameStem and friends decide, on the value alone, whether a
// display name folds: a dot with at least one character in front of it
// keeps only what is before the first dot; everything else is left as it
// is. No brand is named here or in the helper - the fixtures are made up.

import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/services/app_helpers.dart';

void main() {
  group('AppHelpers.appNameStem', () {
    test('keeps what is before the first dot', () {
      expect(AppHelpers.appNameStem('acme.school'), 'acme');
      expect(AppHelpers.appNameFolds('acme.school'), isTrue);
      expect(AppHelpers.appNameSuffix('acme.school'), '.school');
    });

    test('leaves a name with no dot unchanged', () {
      expect(AppHelpers.appNameStem('acme'), 'acme');
      expect(AppHelpers.appNameFolds('acme'), isFalse);
      expect(AppHelpers.appNameSuffix('acme'), '');
    });

    test('leaves a leading dot unchanged - nothing to keep in front', () {
      expect(AppHelpers.appNameStem('.acme'), '.acme');
      expect(AppHelpers.appNameFolds('.acme'), isFalse);
      expect(AppHelpers.appNameSuffix('.acme'), '');
    });

    test('folds a trailing dot to the bare stem', () {
      expect(AppHelpers.appNameStem('acme.'), 'acme');
      expect(AppHelpers.appNameFolds('acme.'), isTrue);
      expect(AppHelpers.appNameSuffix('acme.'), '.');
    });

    test('folds at the FIRST dot when there are several', () {
      expect(AppHelpers.appNameStem('acme.co.example'), 'acme');
      expect(AppHelpers.appNameSuffix('acme.co.example'), '.co.example');
    });

    test('leaves an empty name empty', () {
      expect(AppHelpers.appNameStem(''), '');
      expect(AppHelpers.appNameFolds(''), isFalse);
      expect(AppHelpers.appNameSuffix(''), '');
    });

    test('a lone dot is unchanged', () {
      expect(AppHelpers.appNameStem('.'), '.');
      expect(AppHelpers.appNameFolds('.'), isFalse);
    });

    test('stem + suffix always rebuild the name', () {
      for (final name in ['acme.school', 'acme', '.acme', 'acme.', '', 'a.b.c']) {
        expect(
          AppHelpers.appNameStem(name) + AppHelpers.appNameSuffix(name),
          name,
        );
      }
    });
  });
}
