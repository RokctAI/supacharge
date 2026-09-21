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

import 'package:base_sdk/src/domain/interface/auth.dart';
import 'package:base_sdk/src/handlers/token_refresh_service.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/secure_storage.dart';

import 'package:auth_sdk/src/common/domain/interface/session_token_refresh.dart';
import 'package:auth_sdk/src/common/infrastructure/repositories/auth_repository.dart';

/// In-memory [SecureStore] so tests never touch platform channels.
class MemorySecureStore implements SecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SecureStorage.store = MemorySecureStore();
    TokenRefreshService.resetForTesting();
  });

  tearDown(TokenRefreshService.resetForTesting);

  test('AuthRepository exposes the SessionTokenRefresh capability', () {
    final AuthRepositoryFacade repository = AuthRepository();
    // The capability is reached by downcast, like DeferredOtpEmailResend:
    // callers holding only the base_sdk facade probe with `is`.
    expect(repository, isA<SessionTokenRefresh>());
  });

  test(
      'refreshSession delegates to the single-flight service '
      '(no stored refresh token -> false + cleared session)', () async {
    await LocalStorage.setToken('orphan:token');
    var expired = 0;
    TokenRefreshService.onSessionExpired = () => expired++;

    final SessionTokenRefresh capability = AuthRepository();
    expect(await capability.refreshSession(), isFalse);
    // The service treats a missing refresh token as an unrecoverable
    // session: credentials cleared, forced-re-login hook fired.
    expect(LocalStorage.getToken(), isEmpty);
    expect(expired, 1);
  });
}
