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

// The server-asserted demo marker on the user payload. The login flow
// flips DemoSession on `is_demo_account` alone - so the field must decode
// the shapes the backend can send (a Frappe Check's 0/1, a JSON bool) and
// nothing else must ever read as demo: absent, null or unexpected values
// are a real account.

import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/models/data/profile_data.dart';
import 'package:base_sdk/src/models/data/user.dart';
import 'package:base_sdk/src/models/response/login_response.dart';

void main() {
  group('is_demo_account on the login payload (UserModel)', () {
    test('absent means a real account', () {
      final user = UserModel.fromJson({'id': '7', 'role': 'deliveryman'});
      expect(user.isDemoAccount, isFalse);
    });

    test('decodes the Frappe Check (0/1) and a JSON bool', () {
      expect(UserModel.fromJson({'is_demo_account': 1}).isDemoAccount, isTrue);
      expect(
          UserModel.fromJson({'is_demo_account': 0}).isDemoAccount, isFalse);
      expect(
          UserModel.fromJson({'is_demo_account': true}).isDemoAccount, isTrue);
      expect(UserModel.fromJson({'is_demo_account': false}).isDemoAccount,
          isFalse);
    });

    test('null or an unexpected value is never a demo account', () {
      expect(
          UserModel.fromJson({'is_demo_account': null}).isDemoAccount, isFalse);
      expect(UserModel.fromJson({'is_demo_account': 'yes'}).isDemoAccount,
          isFalse);
      expect(parseDemoAccountMarker('1'), isFalse);
      expect(parseDemoAccountMarker(<String, dynamic>{}), isFalse);
    });

    test('survives the full login contract, toJson and copyWith', () {
      final response = LoginResponse.fromJson({
        'status': true,
        'data': {
          'access_token': 'a:b',
          'token_type': 'Bearer',
          'user': {
            'id': '42',
            'firstname': 'Naledi',
            'role': 'seller',
            'active': 1,
            'is_demo_account': 1,
          },
        },
      });
      final user = response.data!.user!;
      expect(user.isDemoAccount, isTrue);
      expect(user.toJson()['is_demo_account'], isTrue);
      expect(UserModel.fromJson(user.toJson()).isDemoAccount, isTrue);
      expect(user.copyWith(role: 'admin').isDemoAccount, isTrue);
      expect(user.copyWith(isDemoAccount: false).isDemoAccount, isFalse);
      expect(UserModel(id: '1').isDemoAccount, isFalse);
    });
  });

  group('is_demo_account on the profile (ProfileData)', () {
    test('absent means a real account', () {
      expect(ProfileData.fromJson({'id': '7'}).isDemoAccount, isFalse);
      expect(ProfileData(id: '7').isDemoAccount, isFalse);
    });

    test('decodes, round-trips and copies', () {
      final profile = ProfileData.fromJson({'id': '7', 'is_demo_account': 1});
      expect(profile.isDemoAccount, isTrue);
      expect(profile.toJson()['is_demo_account'], isTrue);
      expect(ProfileData.fromJson(profile.toJson()).isDemoAccount, isTrue);
      expect(profile.copyWith(firstname: 'X').isDemoAccount, isTrue);
      expect(
          ProfileData.fromJson({'is_demo_account': 0}).isDemoAccount, isFalse);
    });
  });
}
