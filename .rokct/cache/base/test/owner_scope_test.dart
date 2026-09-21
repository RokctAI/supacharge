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

import 'package:base_sdk/src/database/owner_scope.dart';
import 'package:base_sdk/src/models/data/profile_data.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/secure_storage.dart';

/// Keeps `LocalStorage.setToken` / `logout` off the platform channel the real
/// secure store rides on; same fake profile_notifier_logout_test.dart uses.
class _MemorySecureStore implements SecureStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Who a row written now belongs to.
///
/// The three cases that decide whether the scoping is honest: a normal
/// backend session, a TEMP-LOCAL session (which stores no user at all, so the
/// obvious `LocalStorage.getUser()?.id` is null for the whole of it), and the
/// moment after a sign-out has already cleared both.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.init();
    SecureStorage.store = _MemorySecureStore();
    OwnerScope.instance.debugReset();
  });

  tearDown(() => OwnerScope.instance.debugReset());

  group('OwnerScope.defaultResolver', () {
    test('a backend session owns its rows by account id', () async {
      await LocalStorage.setToken('a-server-issued-session');
      await LocalStorage.setUser(ProfileData(id: '4217', firstname: 'Ray'));

      expect(OwnerScope.defaultResolver(), '4217');
      expect(OwnerScope.instance.current, '4217');
    });

    test(
      'a temp-local session owns its rows by its offline token, because it '
      'stores no user',
      () async {
        // Exactly what OfflineAuthService.registerOffline / loginOffline do:
        // a token and nothing else.
        await LocalStorage.setToken('offline:1789234000000123');

        expect(LocalStorage.getUser(), isNull);
        expect(OwnerScope.instance.current, 'offline:1789234000000123');
      },
    );

    test('a stored account wins over the token when both are present',
        () async {
      await LocalStorage.setToken('offline:1789234000000123');
      await LocalStorage.setUser(ProfileData(id: '4217'));

      expect(OwnerScope.instance.current, '4217');
    });

    test('a device nobody has signed into writes unowned rows', () {
      expect(LocalStorage.getToken(), isEmpty);
      expect(OwnerScope.instance.current, kUnownedOwner);
    });

    test('a real bearer token is never used as an owner', () async {
      // Only the `offline:` form is read off the token. Anything else stays
      // out of the database entirely.
      await LocalStorage.setToken('not-an-offline-token');

      expect(OwnerScope.defaultResolver(), isNull);
      expect(OwnerScope.instance.current, kUnownedOwner);
    });
  });

  group('the sign-out teardown window', () {
    test(
      'a write after the session is cleared still belongs to the account that '
      'left, not to nobody',
      () async {
        await LocalStorage.setToken('a-server-issued-session');
        await LocalStorage.setUser(ProfileData(id: '4217'));
        expect(OwnerScope.instance.current, '4217');

        // What every session-end hook runs after: LocalStorage.logout() has
        // already dropped the stored user AND the token.
        LocalStorage.logout();
        expect(LocalStorage.getUser(), isNull);
        expect(LocalStorage.getToken(), isEmpty);

        // The dangerous answer here is kUnownedOwner: an unowned row is
        // visible to whoever signs in next, so a teardown write would hand
        // the departing user's data to the next one.
        expect(OwnerScope.instance.current, '4217');
        expect(OwnerScope.instance.current, isNot(kUnownedOwner));
      },
    );

    test('the next account signing in takes over immediately', () async {
      await LocalStorage.setUser(ProfileData(id: '4217'));
      expect(OwnerScope.instance.current, '4217');
      LocalStorage.logout();

      await LocalStorage.setUser(ProfileData(id: '9001'));

      expect(OwnerScope.instance.current, '9001');
    });

    test('a temp-local account signing in after a sign-out takes over too',
        () async {
      await LocalStorage.setUser(ProfileData(id: '4217'));
      expect(OwnerScope.instance.current, '4217');
      LocalStorage.logout();

      await LocalStorage.setToken('offline:1789234000000999');

      expect(OwnerScope.instance.current, 'offline:1789234000000999');
    });

    test('a fresh process with no session at all is unowned, not stale', () {
      // The cache is per process by design: a relaunch of a signed-out app
      // must read like the first launch of a signed-out app.
      expect(OwnerScope.instance.current, kUnownedOwner);
    });
  });
}
