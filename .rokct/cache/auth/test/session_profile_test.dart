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

// The profile header was empty on its first paint: base_sdk's
// GenericProfilePage renders `state.userData ?? LocalStorage.getUser()`,
// and nothing in the login flow ever stored the user - only
// profileProvider's fetch did, later. LoginNotifier now persists the
// account the credential exchange came back with, through
// sessionProfileOf; this pins the lift and the round trip through
// LocalStorage.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/constants/demo_images.dart';
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/models/models.dart';
import 'package:base_sdk/src/models/data/address_information.dart';
import 'package:base_sdk/src/services/local_storage.dart';

import 'package:auth_sdk/src/common/infrastructure/repositories/mock_auth_repository.dart';
import 'package:auth_sdk/src/common/services/session_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  test('lifts every field the login contract carries, one to one', () {
    final user = UserModel(
      id: '7',
      uuid: 'u-7',
      firstname: 'Naledi',
      lastname: 'Dlamini',
      referral: 'NAL7',
      email: 'naledi.dlamini@outlook.com',
      phone: '+27 71 234 5678',
      birthday: '1991-04-12',
      gender: 'female',
      emailVerifiedAt: '2026-01-02 03:04:05',
      registeredAt: '2025-12-31 23:59:59',
      active: true,
      img: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg"/>',
      role: 'seller',
      addresses: [
        AddressNewModel(
          id: '3',
          title: 'Work',
          active: true,
          address: AddressInformation(address: '1 Rivonia Road, Sandton'),
          location: [-26.1, 28.05],
        ),
      ],
    );

    final profile = sessionProfileOf(user);

    expect(profile.id, '7');
    expect(profile.uuid, 'u-7');
    expect(profile.firstname, 'Naledi');
    expect(profile.lastname, 'Dlamini');
    expect(profile.referral, 'NAL7');
    expect(profile.email, 'naledi.dlamini@outlook.com');
    expect(profile.phone, '+27 71 234 5678');
    expect(profile.birthday, '1991-04-12');
    expect(profile.gender, 'female');
    expect(profile.emailVerifiedAt, '2026-01-02 03:04:05');
    expect(profile.registeredAt, '2025-12-31 23:59:59');
    expect(profile.active, isTrue);
    expect(profile.img, user.img);
    expect(profile.role, 'seller');
    expect(profile.addresses?.single.title, 'Work');
    expect(
        profile.addresses?.single.address?.address, '1 Rivonia Road, Sandton');
    // Profile-only fields are left for the profile fetch, never invented.
    expect(profile.wallet, isNull);
    expect(profile.shop, isNull);
    expect(profile.membership, isNull);
  });

  test(
      'the demo sign-in round-trips through LocalStorage with a name, '
      'avatar and role on hand for the first paint', () async {
    final result = await MockAuthRepository().login(
      email: 'manager@demo.rokct.ai',
      password: 'demo-learners-2026',
    );
    final user = (result as Success<LoginResponse>).data.data!.user!;
    expect(LocalStorage.getUser(), isNull);

    await LocalStorage.setUser(sessionProfileOf(user));

    final stored = LocalStorage.getUser();
    expect(stored, isNotNull);
    expect(stored!.firstname, 'Thandi');
    expect(stored.lastname, 'Mokoena');
    // The identity's email, not the typed sign-in address: this stored
    // user is what the profile header renders until the profile fetch
    // lands, and what users_sdk's MockUserRepository adopts when it does.
    expect(stored.email, 'thandi.mokoena@outlook.com');
    expect(stored.role, 'seller');
    expect(stored.img, DemoImages.avatar);
    expect(stored.addresses?.first.address?.address, contains('Sandton'));
  });

  test(
      'the user persisted for the supacharge tour sign-in is the demo '
      'identity: no placeholder email, the kernel avatar, nothing that '
      'reads as fixture', () async {
    // The tour's {demo_email} default. Echoing it back as the account's
    // email is how "demo.student@example.com" / "customer" reached the
    // published profile still under Thandi Mokoena's name.
    final result = await MockAuthRepository().login(
      email: 'demo.student@example.com',
      password: 'demo-learners-2026',
    );
    final user = (result as Success<LoginResponse>).data.data!.user!;
    await LocalStorage.setUser(sessionProfileOf(user));

    final stored = LocalStorage.getUser()!;
    expect(stored.firstname, 'Thandi');
    expect(stored.lastname, 'Mokoena');
    expect(stored.email, 'thandi.mokoena@outlook.com');
    expect(stored.role, 'customer');
    // A non-empty img is what makes the header paint the avatar image
    // rather than its initials fallback; it must be the kernel's avatar.
    expect(stored.img, DemoImages.avatar);

    final rendered = [
      stored.firstname,
      stored.lastname,
      stored.email,
      stored.phone,
      stored.role,
      stored.img,
      stored.addresses?.first.address?.address,
    ].join(' ').toLowerCase();
    for (final word in ['demo', 'example', 'sample', 'placeholder']) {
      expect(rendered, isNot(contains(word)),
          reason: '"$word" reads as fixture');
    }
  });
}
