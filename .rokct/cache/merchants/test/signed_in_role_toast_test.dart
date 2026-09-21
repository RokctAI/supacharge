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

// The "Signed in as <role>" toast the manager shell shows once per
// session now that the session_policy admits admin beside seller (Ray
// 2026-09-02 15:56Z). Pure-logic test over the helper's two seams: the
// message text and the once-per-token gate.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:merchants_sdk/src/manager/presentation/main/signed_in_role_toast.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SignedInRoleToast.reset();
  });

  test('message names the role the backend sent, in English by default', () {
    expect(SignedInRoleToast.messageFor('seller'), 'Signed in as seller');
    expect(SignedInRoleToast.messageFor('admin'), 'Signed in as admin');
    // The real login (users' api.user.login primary_role) sends the
    // Frappe role name verbatim for the tenant owner.
    expect(
      SignedInRoleToast.messageFor('System Manager'),
      'Signed in as System Manager',
    );
  });

  test('a role-less session has nothing to say', () {
    expect(SignedInRoleToast.messageFor(null), isNull);
    expect(SignedInRoleToast.messageFor(''), isNull);
    expect(SignedInRoleToast.messageFor('   '), isNull);
  });

  test('one toast per session token; a new sign-in shows it again', () {
    expect(SignedInRoleToast.claim('tok-1'), isTrue);
    expect(
      SignedInRoleToast.claim('tok-1'),
      isFalse,
      reason: 're-mounting the shell must not repeat the toast',
    );
    expect(
      SignedInRoleToast.claim('tok-2'),
      isTrue,
      reason: 'a fresh sign-in (new token) is a new session',
    );
    expect(
      SignedInRoleToast.claim(''),
      isFalse,
      reason: 'no session, no toast',
    );
  });

  test('manifest admits seller, admin AND System Manager on /main, no '
      'fallback, and '
      'declares the signedInAs tr_key beside them', () {
    final manifest =
        jsonDecode(File('manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final manager =
        (manifest['app_type'] as Map<String, dynamic>)['manager']
            as Map<String, dynamic>;
    final policy = manager['session_policy'] as Map<String, dynamic>;
    final roles = (policy['allowed_roles'] as List)
        .cast<Map<String, dynamic>>()
        .map((e) => '${e['role']}->${e['landing_route']}')
        .toList();
    // 'admin' is what auth_sdk's demo MockAuthRepository maps
    // admin@demo.rokct.ai to (the guided tour); 'System Manager' is the
    // role string users' real api.user.login puts in the response for
    // the tenant owner - both must be admitted for admin to sign in.
    expect(roles, ['seller->/main', 'admin->/main', 'System Manager->/main']);
    expect(policy['rejection_message_tr_key'], 'access.denied');
    expect(policy['rejection_route'], '/login');
    expect(
      (manager['tr_keys'] as Map<String, dynamic>)['signedInAs'],
      'Signed in as',
    );
  });
}
