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

// SavedCardModel carries a handle, never a credential.
//
// `Saved Card.token` is the gateway reuse credential: presenting it to
// the gateway charges that card again. pay made it a Frappe `Password`
// field, so `get_saved_cards` and `tokenize_card` stopped returning it
// and the charge endpoints key on the Saved Card docname instead. This
// model is the fleet's card shape, so it is where a credential field
// would come back if anyone reintroduced one.
//
// The model no longer declares `token` at all, which makes the compiler
// the first line of defence: a caller reaching for it does not build.
// These tests cover what the compiler cannot -- that a payload carrying
// a stray credential is ignored rather than absorbed, that the docname
// arrives under either wire name, and that nothing prints a secret.
//
// No real credential value appears here. The stand-ins are a literal row
// of asterisks (what a Password column actually holds) and an obvious
// dummy string.

import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/models/data/saved_card.dart';

void main() {
  // Exactly what a masked Password column contains, and an obviously
  // fake credential-shaped string. Neither is a real value.
  const mask = '************************************';
  const strayCredential = 'not-a-real-credential-0000';

  group('SavedCardModel', () {
    test('takes the docname from `name`, the wire field the API sends', () {
      final card = SavedCardModel.fromJson(const {
        'name': 'SAVED-CARD-0001',
        'last_four': '4242',
        'card_type': 'Visa',
        'expiry_date': '12/29',
        'card_holder_name': 'A Buyer',
      });

      expect(card.id, 'SAVED-CARD-0001',
          reason: 'get_saved_cards/tokenize_card name the docname `name`; '
              'without this the charge handle is empty and every saved-card '
              'payment is refused');
      expect(card.lastFour, '4242');
      expect(card.cardType, 'Visa');
    });

    test('still accepts a normalised `id`, and prefers it', () {
      final card = SavedCardModel.fromJson(const {
        'id': 'SAVED-CARD-0002',
        'name': 'SAVED-CARD-0001',
        'last_four': '4242',
      });

      expect(card.id, 'SAVED-CARD-0002');
    });

    test('ignores a credential in the payload instead of absorbing it', () {
      final card = SavedCardModel.fromJson(const {
        'name': 'SAVED-CARD-0001',
        'token': strayCredential,
        'last_four': '4242',
      });

      expect(card.toJson().containsKey('token'), isFalse,
          reason: 'the model must not carry a gateway reuse credential');
      expect(card.toJson().values, isNot(contains(strayCredential)));
      expect(card.toString(), isNot(contains(strayCredential)));
    });

    test('serialises the handle and the display fields, nothing else', () {
      final card = SavedCardModel(
        id: 'SAVED-CARD-0001',
        lastFour: '4242',
        cardType: 'Visa',
        expiryDate: '12/29',
        cardHolderName: 'A Buyer',
      );

      expect(card.toJson().keys, <String>[
        'id',
        'last_four',
        'card_type',
        'expiry_date',
        'card_holder_name',
        'is_default',
      ]);
    });

    test('toString never prints a secret-shaped value', () {
      final card = SavedCardModel.fromJson(const {
        'name': 'SAVED-CARD-0001',
        'token': mask,
        'last_four': '4242',
      });

      expect(card.toString(), contains('SAVED-CARD-0001'));
      expect(card.toString(), isNot(contains(mask)));
      expect(card.toString(), isNot(contains('token')));
    });

    test('copyWith preserves the handle and cannot reintroduce a token', () {
      final card = SavedCardModel(
        id: 'SAVED-CARD-0001',
        lastFour: '4242',
        cardType: 'Visa',
        expiryDate: '12/29',
        cardHolderName: 'A Buyer',
      );

      final copy = card.copyWith(lastFour: '1881');

      expect(copy.id, 'SAVED-CARD-0001');
      expect(copy.lastFour, '1881');
      expect(copy.toJson().containsKey('token'), isFalse);
    });
  });
}
