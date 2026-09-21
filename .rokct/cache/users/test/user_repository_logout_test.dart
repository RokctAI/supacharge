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

// SIGN-OUT IS LOCAL, AND IT IS UNCONDITIONAL.
//
// Ray, 2026-09-19: "if on temp local user you logout all your tasks still
// show". A temp-local (offline) account's token is `offline:<local user id>`
// -- auth_sdk's OfflineAuthService mints it, no backend ever issued it -- so
// `api.user.logout` cannot succeed for one of those users. With the local
// clear sitting on the success path only, sign-out was a guaranteed no-op
// for exactly the users who have nothing BUT local data: the token stayed,
// the profile stayed, and every SDK's session-end tidy-up (SessionEndHooks)
// was reported as failed work.
//
// The gateway is exercised end-to-end here rather than mocked (the
// user_repository_payload_test pattern): the registered HttpService is
// swapped for one whose Dio talks to a recording adapter, so the failing
// revoke fails the way a real one does -- a DioException out of
// PlatformGateway -- and the assertion covers the real call path.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/handlers/http_service.dart';
import 'package:base_sdk/src/models/data/profile_data.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/secure_storage.dart';

import 'package:users_sdk/src/common/infrastructure/repositories/user_repository.dart';
import 'package:users_sdk/src/common/services/session_end_hooks.dart';

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

/// Answers every request with [status], so the gateway call either succeeds
/// or throws exactly as a real one does.
class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'message': 'ok'}),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _StubHttpService extends HttpService {
  _StubHttpService(this.adapter);

  final _StatusAdapter adapter;

  @override
  Dio client({bool requireAuth = false, bool routing = false}) =>
      Dio()..httpClientAdapter = adapter;
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
    await LocalStorage.setUser(
      ProfileData(id: 'local-user-1', firstname: 'Ray'),
    );
  }

  Future<void> useGateway(int status) async {
    if (getIt.isRegistered<HttpService>()) {
      await getIt.unregister<HttpService>();
    }
    getIt.registerSingleton<HttpService>(_StubHttpService(_StatusAdapter(status)));
  }

  setUp(SessionEndHooks.clearAll);

  tearDown(() async {
    SessionEndHooks.clearAll();
    if (getIt.isRegistered<HttpService>()) {
      await getIt.unregister<HttpService>();
    }
  });

  group('UserRepository.logoutAccount', () {
    test('clears the local session when the revoke SUCCEEDS', () async {
      await signIn();
      await useGateway(200);

      final result = await UserRepository().logoutAccount(fcm: '');

      expect(result, isA<Success<dynamic>>());
      expect(LocalStorage.getToken(), isEmpty);
      expect(LocalStorage.getUser(), isNull);
    });

    test(
      'clears the local session even when the revoke FAILS -- the offline / '
      'temp-local case, where it can never succeed',
      () async {
        await signIn();
        // 401 is what a backend answers for `offline:<id>`: a token it never
        // issued. Before the fix this returned failure and left the token,
        // the profile and every SDK\'s local data exactly where they were.
        await useGateway(401);

        final result = await UserRepository().logoutAccount(fcm: '');

        // The revoke result is still reported ...
        expect(result, isA<Failure<dynamic>>());
        // ... but the device has forgotten the session regardless.
        expect(LocalStorage.getToken(), isEmpty);
        expect(LocalStorage.getUser(), isNull);
      },
    );

    test('runs the session-end hooks on the failing path too', () async {
      await signIn();
      await useGateway(500);

      var ran = 0;
      SessionEndHooks.register('productivity_local_data', () async => ran++);

      final result = await UserRepository().logoutAccount(fcm: '');

      expect(result, isA<Failure<dynamic>>());
      // The hook is what each SDK hangs its own on-device user data off, so
      // a sign-out that reports failure must still have fired it.
      expect(ran, 1);
      expect(LocalStorage.getToken(), isEmpty);
    });
  });

  group('UserRepository.deleteAccount', () {
    test('clears the local session even when the delete FAILS', () async {
      await signIn();
      await useGateway(500);

      final result = await UserRepository().deleteAccount();

      expect(result, isA<Failure<dynamic>>());
      // SessionEndHooks has already torn down the session-scoped state by
      // this point, so leaving a live local session behind would be worse
      // than being signed out and asked to try again.
      expect(LocalStorage.getToken(), isEmpty);
      expect(LocalStorage.getUser(), isNull);
    });
  });
}
