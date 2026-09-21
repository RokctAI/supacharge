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

// Demo login in production: a real account on the production backend,
// marked `is_demo_account` by the backend, signs in through the real
// AuthRepository; only then does the login flow flip the runtime demo
// session. This pins the flip LoginNotifier._establishSession makes
// (applyDemoAccountSession): on for a marked account, off for any other,
// and ended by sign-out.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/models/models.dart';
import 'package:base_sdk/src/services/demo_session.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/secure_storage.dart';

import 'package:auth_sdk/src/common/services/demo_account_session.dart';
import 'package:auth_sdk/src/common/services/session_profile.dart';

/// In-memory SecureStore so logout() never reaches a platform channel.
class _MemorySecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// The user the real backend's login payload decodes to, per role.
UserModel _accepted(String role, {required bool demo}) => UserModel.fromJson({
  'id': '$role-1',
  'firstname': 'Naledi',
  'lastname': 'Dlamini',
  'email': 'naledi.dlamini@outlook.com',
  'role': role,
  'active': 1,
  'is_demo_account': demo ? 1 : 0,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SecureStorage.store = _MemorySecureStore();
    DemoSession.isDemoOverride = false;
  });

  tearDown(() async {
    await DemoSession.instance.clear();
    DemoSession.isDemoOverride = null;
  });

  test('a backend-marked account flips the session, one per role', () async {
    for (final role in ['deliveryman', 'seller', 'admin']) {
      await DemoSession.instance.clear();
      expect(DemoSession.demoActive, isFalse, reason: role);

      await applyDemoAccountSession(_accepted(role, demo: true));

      expect(DemoSession.instance.active, isTrue, reason: role);
      expect(DemoSession.demoActive, isTrue, reason: role);
    }
  });

  test('a normal account never flips it', () async {
    await applyDemoAccountSession(_accepted('deliveryman', demo: false));
    expect(DemoSession.instance.active, isFalse);

    // The marker is the ONLY key: an account without it is real even when
    // its payload is otherwise identical.
    await applyDemoAccountSession(
      UserModel.fromJson({'id': 'x', 'role': 'seller', 'active': 1}),
    );
    expect(DemoSession.instance.active, isFalse);
    expect(DemoSession.demoActive, isFalse);
  });

  test('a normal sign-in ends a demo session left by an earlier one', () async {
    await applyDemoAccountSession(_accepted('seller', demo: true));
    expect(DemoSession.instance.active, isTrue);

    await applyDemoAccountSession(_accepted('seller', demo: false));
    expect(DemoSession.instance.active, isFalse);

    await applyDemoAccountSession(_accepted('admin', demo: true));
    expect(DemoSession.instance.active, isTrue);
    await applyDemoAccountSession(null);
    expect(DemoSession.instance.active, isFalse);
  });

  test('sign-out clears it', () async {
    await applyDemoAccountSession(_accepted('deliveryman', demo: true));
    expect(DemoSession.instance.active, isTrue);

    // Every sign-out path (users_sdk logout / delete-account, the 401
    // auto-logout) ends in LocalStorage.logout.
    LocalStorage.logout();

    expect(DemoSession.instance.active, isFalse);
    expect(DemoSession.demoActive, isFalse);
  });

  test(
    'the stored session carries the marker, and nothing that says demo',
    () async {
      final user = _accepted('deliveryman', demo: true);
      final profile = sessionProfileOf(user);
      expect(profile.isDemoAccount, isTrue);
      expect(
        sessionProfileOf(_accepted('deliveryman', demo: false)).isDemoAccount,
        isFalse,
      );

      // Ray's rule: the account is a real person to the user. The marker is
      // a bool the screens never render; no rendered field may say demo.
      for (final value in [
        profile.firstname,
        profile.lastname,
        profile.email,
        profile.role,
      ]) {
        expect(value?.toLowerCase(), isNot(contains('demo')));
      }
    },
  );
}
