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

import 'package:auth_sdk/src/common/services/secure_password.dart';

void main() {
  group('generateSecurePassword', () {
    test('encodes 32 random bytes as 43 base64url characters', () {
      final password = generateSecurePassword();
      // 32 bytes -> ceil(32 / 3) * 4 = 44 base64 chars incl. one '='
      // padding char, stripped -> 43.
      expect(password.length, 43);
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(password), isTrue,
          reason: 'must be padding-free base64url');
    });

    test('honors byteLength', () {
      // 48 bytes -> 64 base64url chars, no padding to strip.
      expect(generateSecurePassword(byteLength: 48).length, 64);
    });

    test('is not an epoch-timestamp-shaped value', () {
      // The old sync path sent the local row id — a purely numeric
      // microsecond epoch timestamp — as the backend password. The
      // generated secret must never look like one.
      final password = generateSecurePassword();
      expect(RegExp(r'^[0-9]+$').hasMatch(password), isFalse);
    });

    test('never repeats across calls', () {
      final seen = <String>{};
      for (var i = 0; i < 100; i++) {
        seen.add(generateSecurePassword());
      }
      expect(seen.length, 100);
    });

    test('draws from the full byte range, not a narrow alphabet', () {
      // Sanity check on entropy encoding: across a few generations the
      // union of characters used should easily exceed any timestamp-like
      // or hex-like alphabet.
      final chars = <String>{};
      for (var i = 0; i < 20; i++) {
        chars.addAll(generateSecurePassword().split(''));
      }
      expect(chars.length, greaterThan(30));
    });
  });
}
