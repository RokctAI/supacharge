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


import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/handlers/platform_gateway.dart';
import 'package:base_sdk/src/handlers/token_refresh_service.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/secure_storage.dart';

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

/// Builds a Dio whose requests never hit the network: every POST is
/// counted and answered by [respond] (or failed via [fail]).
Dio stubbedDio({
  required FutureOr<Response<dynamic>> Function(RequestOptions options)
      respond,
  void Function(RequestOptions options)? onRequest,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://unit.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        onRequest?.call(options);
        try {
          handler.resolve(await respond(options));
        } on DioException catch (e) {
          handler.reject(e);
        }
      },
    ),
  );
  return dio;
}

Response<dynamic> frappeWrapped(RequestOptions options, Map body) =>
    Response<dynamic>(
      requestOptions: options,
      statusCode: 200,
      // Frappe wraps whitelisted-method dicts under `message`.
      data: {'message': body},
    );

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemorySecureStore secureStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    secureStore = MemorySecureStore();
    SecureStorage.store = secureStore;
    TokenRefreshService.resetForTesting();
  });

  tearDown(TokenRefreshService.resetForTesting);

  Future<void> seedSession({
    String token = 'oldkey:oldsecret',
    // compliance-ignore: flutter-hardcoded-secret (synthetic test fixture: patterned dummy refresh token seeded into the mock secure store; not a real credential)
    String refreshToken = 'refresh-token-32-chars-aaaaaaaaa',
    String? expiresAt,
  }) async {
    await LocalStorage.setToken(token);
    await SecureStorage.setRefreshToken(refreshToken);
    await LocalStorage.setTokenExpiry(expiresAt);
  }

  group('TokenRefreshService.refresh', () {
    test('success persists rotated token, refresh token and expiry',
        () async {
      await seedSession();
      TokenRefreshService.dioFactoryOverride = () => stubbedDio(
            respond: (options) => frappeWrapped(options, {
              'status': true,
              'message': 'Token rotated successfully',
              'data': {
                'access_token': 'newkey:newsecret',
                'refresh_token': 'rotated-refresh-token',
                'expires_at': '2026-08-15 10:00:00',
              },
            }),
          );

      expect(await TokenRefreshService.refresh(), isTrue);
      expect(LocalStorage.getToken(), 'newkey:newsecret');
      expect(await SecureStorage.getRefreshToken(), 'rotated-refresh-token');
      expect(LocalStorage.getTokenExpiry(), '2026-08-15 10:00:00');
    });

    test('sends the stored refresh token to the refresh endpoint', () async {
      await seedSession(refreshToken: 'the-stored-refresh-token');
      late RequestOptions seen;
      TokenRefreshService.dioFactoryOverride = () => stubbedDio(
            onRequest: (options) => seen = options,
            respond: (options) => frappeWrapped(options, {
              'status': true,
              'data': {
                'access_token': 'k:s',
                'refresh_token': 'next',
                'expires_at': '2026-08-15 10:00:00',
              },
            }),
          );

      await TokenRefreshService.refresh();
      expect(seen.path, kPlatformGatewayPath);
      expect(seen.data, {
        'cmd': TokenRefreshService.refreshCmd,
        'payload': {'refresh_token': 'the-stored-refresh-token'},
      });
    });

    test(
        'N concurrent callers -> exactly one backend call (single-flight)',
        () async {
      await seedSession();
      var calls = 0;
      TokenRefreshService.dioFactoryOverride = () => stubbedDio(
            respond: (options) async {
              calls++;
              // Simulate latency so all callers overlap the exchange.
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return frappeWrapped(options, {
                'status': true,
                'data': {
                  'access_token': 'k:s',
                  'refresh_token': 'next',
                  'expires_at': '2026-08-15 10:00:00',
                },
              });
            },
          );

      final results = await Future.wait(
        List.generate(8, (_) => TokenRefreshService.refresh()),
      );
      expect(calls, 1);
      expect(results, everyElement(isTrue));

      // A LATER refresh (after completion) is a new exchange.
      await TokenRefreshService.refresh();
      expect(calls, 2);
    });

    test(
        'HTTP 200 + status:false clears the session and fires '
        'onSessionExpired', () async {
      await seedSession(expiresAt: '2026-08-15 10:00:00');
      var expired = 0;
      TokenRefreshService.onSessionExpired = () => expired++;
      TokenRefreshService.dioFactoryOverride = () => stubbedDio(
            respond: (options) => frappeWrapped(options, {
              'status': false,
              'message': 'Invalid refresh token',
            }),
          );

      expect(await TokenRefreshService.refresh(), isFalse);
      expect(LocalStorage.getToken(), isEmpty);
      expect(await SecureStorage.getRefreshToken(), isEmpty);
      expect(LocalStorage.getTokenExpiry(), isEmpty);
      expect(expired, 1);
    });

    test('missing stored refresh token clears the session, no HTTP call',
        () async {
      await LocalStorage.setToken('orphan:token');
      var calls = 0;
      var expired = 0;
      TokenRefreshService.onSessionExpired = () => expired++;
      TokenRefreshService.dioFactoryOverride = () => stubbedDio(
            respond: (options) {
              calls++;
              return frappeWrapped(options, {'status': true});
            },
          );

      expect(await TokenRefreshService.refresh(), isFalse);
      expect(calls, 0);
      expect(LocalStorage.getToken(), isEmpty);
      expect(expired, 1);
    });

    test('auth-level HTTP error (401) clears the session', () async {
      await seedSession();
      var expired = 0;
      TokenRefreshService.onSessionExpired = () => expired++;
      TokenRefreshService.dioFactoryOverride = () => stubbedDio(
            respond: (options) => throw DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 401),
              type: DioExceptionType.badResponse,
            ),
          );

      expect(await TokenRefreshService.refresh(), isFalse);
      expect(LocalStorage.getToken(), isEmpty);
      expect(await SecureStorage.getRefreshToken(), isEmpty);
      expect(expired, 1);
    });

    test('transient transport error keeps the stored session', () async {
      await seedSession(expiresAt: '2026-08-15 10:00:00');
      var expired = 0;
      TokenRefreshService.onSessionExpired = () => expired++;
      TokenRefreshService.dioFactoryOverride = () => stubbedDio(
            respond: (options) => throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
            ),
          );

      expect(await TokenRefreshService.refresh(), isFalse);
      expect(LocalStorage.getToken(), 'oldkey:oldsecret');
      expect(
        await SecureStorage.getRefreshToken(),
        'refresh-token-32-chars-aaaaaaaaa',
      );
      expect(expired, 0);
    });
  });

  group('TokenRefreshService.isAccessTokenExpired', () {
    test('false when no expiry recorded', () async {
      await seedSession();
      expect(TokenRefreshService.isAccessTokenExpired(), isFalse);
    });

    test('true for a past expiry, false for a far-future one', () async {
      await seedSession(expiresAt: '2000-01-01 00:00:00');
      expect(TokenRefreshService.isAccessTokenExpired(), isTrue);

      await LocalStorage.setTokenExpiry('2999-01-01 00:00:00');
      expect(TokenRefreshService.isAccessTokenExpired(), isFalse);
    });

    test('true inside the skew window', () async {
      final soon = DateTime.now().add(const Duration(seconds: 10));
      await LocalStorage.setTokenExpiry(soon.toIso8601String());
      expect(TokenRefreshService.isAccessTokenExpired(), isTrue);
    });
  });

  group('LocalStorage.setToken', () {
    test('clears any stored refresh contract', () async {
      await seedSession(expiresAt: '2026-08-15 10:00:00');
      await LocalStorage.setToken('minted-by-otp-verify');
      expect(LocalStorage.getTokenExpiry(), isEmpty);
      expect(await SecureStorage.getRefreshToken(), isEmpty);
    });
  });

  group('TokenRefreshInterceptor', () {
    Dio clientWith(TokenRefreshInterceptor interceptor,
        {required FutureOr<Response<dynamic>> Function(RequestOptions) respond,
        required bool authed}) {
      final dio = Dio(BaseOptions(baseUrl: 'https://unit.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (authed) options.headers['Authorization'] = 'Bearer old';
            try {
              handler.resolve(await respond(options));
            } on DioException catch (e) {
              // `true`: hand the error to the FOLLOWING interceptors
              // (TokenRefreshInterceptor), like a real transport 401 would.
              handler.reject(e, true);
            }
          },
        ),
      );
      dio.interceptors.add(interceptor);
      return dio;
    }

    DioException unauthorized(RequestOptions options) => DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401),
          type: DioExceptionType.badResponse,
        );

    setUp(() {
      TokenRefreshInterceptor.retrySenderOverride = null;
    });

    tearDown(() {
      TokenRefreshInterceptor.retrySenderOverride = null;
    });

    test('401 -> refresh -> single retry with rotated token', () async {
      await seedSession();
      TokenRefreshService.dioFactoryOverride = () => stubbedDio(
            respond: (options) => frappeWrapped(options, {
              'status': true,
              'data': {
                'access_token': 'newkey:newsecret',
                'refresh_token': 'next',
                'expires_at': '2026-08-15 10:00:00',
              },
            }),
          );
      var retries = 0;
      TokenRefreshInterceptor.retrySenderOverride = (options) async {
        retries++;
        expect(options.extra[TokenRefreshInterceptor.retriedFlag], isTrue);
        // Stale header dropped so the retry client re-stamps the token.
        expect(options.headers.containsKey('Authorization'), isFalse);
        return Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: {'ok': true},
        );
      };

      final dio = clientWith(
        const TokenRefreshInterceptor(),
        authed: true,
        respond: (options) => throw unauthorized(options),
      );
      final response = await dio
          .post(kPlatformGatewayPath, data: {'cmd': 'api.anything'});
      expect(response.statusCode, 200);
      expect(response.data, {'ok': true});
      expect(retries, 1);
      expect(LocalStorage.getToken(), 'newkey:newsecret');
    });

    test('does not retry when refresh fails; original 401 propagates',
        () async {
      await seedSession();
      TokenRefreshService.dioFactoryOverride = () => stubbedDio(
            respond: (options) =>
                frappeWrapped(options, {'status': false, 'message': 'nope'}),
          );
      var retries = 0;
      TokenRefreshInterceptor.retrySenderOverride = (options) async {
        retries++;
        return Response<dynamic>(requestOptions: options, statusCode: 200);
      };

      final dio = clientWith(
        const TokenRefreshInterceptor(),
        authed: true,
        respond: (options) => throw unauthorized(options),
      );
      await expectLater(
        dio.post(kPlatformGatewayPath, data: {'cmd': 'api.anything'}),
        throwsA(isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          401,
        )),
      );
      expect(retries, 0);
      // Auth-level refresh failure cleared the session (forced re-login
      // path: the propagating 401 hits the existing notifier handling).
      expect(LocalStorage.getToken(), isEmpty);
    });

    test('a request that already retried is not refreshed again', () async {
      await seedSession();
      var refreshCalls = 0;
      TokenRefreshService.dioFactoryOverride = () => stubbedDio(
            respond: (options) {
              refreshCalls++;
              return frappeWrapped(options, {
                'status': true,
                'data': {
                  'access_token': 'k:s',
                  'refresh_token': 'next',
                  'expires_at': '2026-08-15 10:00:00',
                },
              });
            },
          );
      TokenRefreshInterceptor.retrySenderOverride = (options) async =>
          throw unauthorized(options);

      final dio = clientWith(
        const TokenRefreshInterceptor(),
        authed: true,
        respond: (options) => throw unauthorized(options),
      );
      await expectLater(
        dio.post(kPlatformGatewayPath, data: {'cmd': 'api.anything'}),
        throwsA(isA<DioException>()),
      );
      // One refresh for the first 401; the retried request's second 401
      // must NOT trigger another.
      expect(refreshCalls, 1);
    });

    test('unauthenticated requests are left alone', () async {
      await seedSession();
      var refreshCalls = 0;
      TokenRefreshService.dioFactoryOverride = () => stubbedDio(
            respond: (options) {
              refreshCalls++;
              return frappeWrapped(options, {'status': true});
            },
          );

      final dio = clientWith(
        const TokenRefreshInterceptor(),
        authed: false,
        respond: (options) => throw unauthorized(options),
      );
      await expectLater(
        dio.post(kPlatformGatewayPath, data: {'cmd': 'api.user.login'}),
        throwsA(isA<DioException>()),
      );
      expect(refreshCalls, 0);
    });

    test('the refresh endpoint itself is never refresh-retried', () async {
      await seedSession();
      var refreshCalls = 0;
      TokenRefreshService.dioFactoryOverride = () => stubbedDio(
            respond: (options) {
              refreshCalls++;
              return frappeWrapped(options, {'status': true});
            },
          );

      final dio = clientWith(
        const TokenRefreshInterceptor(),
        authed: true,
        respond: (options) => throw unauthorized(options),
      );
      await expectLater(
        dio.post(
          kPlatformGatewayPath,
          data: {
            'cmd': TokenRefreshService.refreshCmd,
            'payload': {'refresh_token': 'stale'},
          },
        ),
        throwsA(isA<DioException>()),
      );
      expect(refreshCalls, 0);
    });
  });
}
