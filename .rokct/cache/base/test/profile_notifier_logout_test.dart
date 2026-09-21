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

// `ProfileNotifier.logOut` IS A SIGN-OUT, NOT A FIRE-AND-FORGET REQUEST.
//
// It used to call `_userRepository.logoutAccount(fcm: fcm)` WITHOUT awaiting
// it and without clearing anything locally. Two consequences, both of which
// a profile screen's Log out button walked straight into:
//
//   * it returned while the revoke -- and users_sdk's SessionEndHooks, which
//     each SDK hangs its own on-device user data off -- were still in flight,
//     so the caller navigated away from a session that had not ended;
//   * nothing on this path cleared the session locally at all, so an
//     offline / temp-local user (whose `offline:<id>` token no backend can
//     revoke) stayed signed in with everything the session had put on the
//     device. Ray, 2026-09-19: "if on temp local user you logout all your
//     tasks still show".
//
// Both halves are asserted here: the call is awaited (the repository's future
// has completed by the time `logOut` returns), and the local session is gone
// whether the revoke succeeded or threw.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/application/profile/profile_notifier.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/models/data/profile_data.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/secure_storage.dart';

/// In-memory [SecureStore] so the sign-out never touches a platform channel.
class _MemorySecureStore implements SecureStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// A revoke that takes a turn of the event loop to answer, so an unawaited
/// call is observable: `completed` is still false when `logOut` returns.
class _SlowUserRepository extends Fake implements UserRepositoryFacade {
  _SlowUserRepository({this.throws = false});

  final bool throws;
  int calls = 0;
  bool completed = false;

  @override
  Future<ApiResult<dynamic>> logoutAccount({required String fcm}) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    completed = true;
    if (throws) {
      // What a real `logoutAccount` returns when the revoke was rejected --
      // it reports the failure rather than throwing.
      return ApiResult<dynamic>.failure(
        error: 'revoke rejected',
        statusCode: 401,
      );
    }
    return const ApiResult<dynamic>.success(data: null);
  }
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The token an offline / temp-local account actually carries.
  const String offlineToken = 'offline:local-user-1';

  Future<void> signIn() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.init();
    SecureStorage.store = _MemorySecureStore();
    await LocalStorage.setToken(offlineToken);
    await LocalStorage.setUser(ProfileData(id: 'local-user-1', firstname: 'Ray'));
  }

  group('ProfileNotifier.logOut', () {
    test('awaits the revoke before it returns', () async {
      await signIn();
      final repository = _SlowUserRepository();
      final notifier = ProfileNotifier(repository, null, null);

      await notifier.logOut();

      expect(repository.calls, 1);
      // Unawaited, this was false: the button navigated away while the
      // revoke and the session-end hooks were still running.
      expect(repository.completed, isTrue);
    });

    test('clears the local session', () async {
      await signIn();
      final notifier = ProfileNotifier(_SlowUserRepository(), null, null);

      await notifier.logOut();

      expect(LocalStorage.getToken(), isEmpty);
      expect(LocalStorage.getUser(), isNull);
    });

    test(
      'clears the local session when the revoke was REJECTED -- the offline / '
      'temp-local case',
      () async {
        await signIn();
        final notifier =
            ProfileNotifier(_SlowUserRepository(throws: true), null, null);

        await notifier.logOut();

        expect(LocalStorage.getToken(), isEmpty);
        expect(LocalStorage.getUser(), isNull);
      },
    );

    test('signs the user out in a compose with no users_sdk', () async {
      await signIn();
      // No UserRepositoryFacade registered: every account call is a no-op,
      // but forgetting the session on the device still has to happen.
      final notifier = ProfileNotifier(null, null, null);

      await notifier.logOut();

      expect(LocalStorage.getToken(), isEmpty);
      expect(LocalStorage.getUser(), isNull);
    });
  });
}
