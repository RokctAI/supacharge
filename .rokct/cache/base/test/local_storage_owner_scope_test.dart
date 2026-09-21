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
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/secure_storage.dart';

/// Keeps `LocalStorage.setToken` / `logout` off the platform channel the real
/// secure store rides on; same fake owner_scope_test.dart uses.
class _MemorySecureStore implements SecureStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Sign-out hides an account's records; it never deletes them. These pin the
/// two halves of that: the leaving account still has its data when it comes
/// back, and the account that signs in next does not see it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.init();
    SecureStorage.store = _MemorySecureStore();
    OwnerScope.instance.debugReset();
  });

  tearDown(() => OwnerScope.instance.debugReset());

  Future<void> signIn(String token) async {
    await LocalStorage.setToken('offline:$token');
    OwnerScope.instance.debugReset();
  }

  test('a signed-out account finds its own records when it signs back in',
      () async {
    await signIn('ray');
    await LocalStorage.setSavedShopsList(<String>['shop-1', 'shop-2']);
    await LocalStorage.setSearchHistory(<String>['bread']);

    LocalStorage.logout();
    await signIn('ray');

    expect(LocalStorage.getSavedShopsList(), <String>['shop-1', 'shop-2']);
    expect(LocalStorage.getSearchList(), <String>['bread']);
  });

  test('the next account to sign in does not read the previous one\'s records',
      () async {
    await signIn('ray');
    await LocalStorage.setSavedShopsList(<String>['shop-1']);

    LocalStorage.logout();
    await signIn('someone-else');

    expect(LocalStorage.getSavedShopsList(), isEmpty);
  });

  test('an existing install keeps data written before it had an owner',
      () async {
    await LocalStorage.setSavedShopsList(<String>['legacy-shop']);

    await signIn('ray');

    expect(LocalStorage.getSavedShopsList(), <String>['legacy-shop']);
  });
}
