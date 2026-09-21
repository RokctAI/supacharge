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

// The demo profile is what every shell's account still shows. It must read
// like a real person (no Demo / example / placeholder wording reaches a
// screenshot), must not invent a role the sign-in address did not
// establish, and must agree with the address book on the home address.

import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/constants/demo_images.dart';
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/models/response/addresses_response.dart';
import 'package:base_sdk/src/models/response/profile_response.dart';

import 'package:users_sdk/src/common/infrastructure/repositories/mock_address_repository.dart';
import 'package:users_sdk/src/common/infrastructure/repositories/mock_user_repository.dart';

const List<String> _fixtureWords = ['demo', 'example', 'placeholder', 'sample'];

void main() {
  test('demo profile carries a rand wallet that matches the demo ledger',
      () async {
    final result = await MockUserRepository().getProfileDetails();
    final profile = (result as Success<ProfileResponse>).data.data!;

    // Every demo amount prints in rand (base_sdk's DemoCurrency); the
    // wallet must carry the same currency, symbol before the amount, so
    // nothing on the profile can read as a dollar figure.
    expect(profile.wallet?.currency?.id, 'ZAR');
    expect(profile.wallet?.currency?.symbol, 'R');
    expect(profile.wallet?.currency?.position, 'before');
    expect(profile.wallet?.uuid, 'wallet-1');
    // Net of wallet_sdk's demo ledger (+1,500 - 185.50 - 300 - 264 + 42.50).
    expect(profile.wallet?.price, 793.0);
  });

  test('demo profile reads like a real account, not a fixture', () async {
    final result = await MockUserRepository().getProfileDetails();
    expect(result, isA<Success<ProfileResponse>>());
    final profile = (result as Success<ProfileResponse>).data.data!;

    expect(profile.firstname, 'Thandi');
    expect(profile.lastname, 'Mokoena');
    expect(profile.phone, '+27 82 456 7890');
    expect(profile.img, startsWith('data:image/svg+xml'));
    // The one avatar the kernel owns - the same pixels auth_sdk's
    // MockAuthRepository signs in with, so the header never swaps faces
    // between the login user and the fetched profile.
    expect(profile.img, DemoImages.avatar);
    expect(profile.addresses?.first.address?.address, contains('Sandton'));
    // No session was persisted, so no role is invented: the sign-in address
    // decides it (auth_sdk MockAuthRepository._demoRolesByEmail).
    expect(profile.role, isNull);

    final rendered = [
      profile.firstname,
      profile.lastname,
      profile.email,
      profile.phone,
      profile.addresses?.first.address?.address,
    ].join(' ').toLowerCase();
    for (final word in _fixtureWords) {
      expect(
        rendered,
        isNot(contains(word)),
        reason: '"$word" reads as fixture',
      );
    }
  });

  test('address book seeds the same home address as the profile', () async {
    final profileResult = await MockUserRepository().getProfileDetails();
    final profile = (profileResult as Success<ProfileResponse>).data.data!;
    final addressResult = await MockAddressRepository().getUserAddresses();
    expect(addressResult, isA<Success<AddressesResponse>>());
    final addresses =
        (addressResult as Success<AddressesResponse>).data.data!;

    expect(
      addresses.first.address?.address,
      profile.addresses?.first.address?.address,
    );
    expect(addresses.first.location, profile.addresses?.first.location);
    for (final address in addresses) {
      final text = (address.address?.address ?? '').toLowerCase();
      for (final word in _fixtureWords) {
        expect(
          text,
          isNot(contains(word)),
          reason: '"$word" reads as fixture',
        );
      }
    }
  });
}
