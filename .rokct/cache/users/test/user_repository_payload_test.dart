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

// Regression guard for the two profile calls whose payload keys did not
// match the server signature (Dart SDK audit 2026-09-02, U1/U2):
//
//   * update_profile_image(image)                 sent {'image_url': ...}
//   * update_password(password, password_confirmation) sent {'password'} only
//
// Frappe binds JSON payload keys to kwargs by name, so an unknown key is
// dropped silently and the missing positional raises a TypeError on every
// call. The gateway is exercised end-to-end here: the registered
// HttpService is swapped for one whose Dio talks to a recording adapter,
// so the assertion covers the real PlatformGateway envelope
// ({cmd, payload} POSTed to kPlatformGatewayPath), not a hand-rolled mock.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/handlers/http_service.dart';
import 'package:base_sdk/src/handlers/platform_gateway.dart';
import 'package:base_sdk/src/models/response/profile_response.dart';

import 'package:users_sdk/src/common/infrastructure/repositories/user_repository.dart';

/// Records every request and answers each with the same canned JSON body.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.reply);

  final Map<String, dynamic> reply;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(reply),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// [HttpService] whose Dio has no interceptors and no network: the
/// gateway resolves `dioHttp` lazily per call, so registering this in
/// GetIt is all the swap PlatformGateway needs.
class _RecordingHttpService extends HttpService {
  _RecordingHttpService(this.adapter);

  final _RecordingAdapter adapter;
  final List<bool> requireAuthCalls = [];

  @override
  Dio client({bool requireAuth = false, bool routing = false}) {
    requireAuthCalls.add(requireAuth);
    return Dio()..httpClientAdapter = adapter;
  }
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingAdapter adapter;
  late _RecordingHttpService http;

  setUp(() async {
    // ProfileResponse.fromJson reads only `data`; a body without it is a
    // valid (empty-profile) success, which is all these tests need.
    adapter = _RecordingAdapter({'message': 'ok'});
    http = _RecordingHttpService(adapter);
    if (getIt.isRegistered<HttpService>()) {
      await getIt.unregister<HttpService>();
    }
    getIt.registerSingleton<HttpService>(http);
  });

  tearDown(() async {
    if (getIt.isRegistered<HttpService>()) {
      await getIt.unregister<HttpService>();
    }
  });

  Map<String, dynamic> body(RequestOptions options) =>
      (options.data as Map).cast<String, dynamic>();

  Map<String, dynamic> payload(RequestOptions options) =>
      (body(options)['payload'] as Map).cast<String, dynamic>();

  group('UserRepository gateway payloads', () {
    test(
        'updateProfileImage sends the server\'s `image` kwarg, '
        'not `image_url`', () async {
      final result = await UserRepository().updateProfileImage(
        firstName: 'Ada',
        imageUrl: '/files/avatar.png',
      );

      expect(result, isA<Success<ProfileResponse>>());
      expect(adapter.requests, hasLength(1));

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, kPlatformGatewayPath);
      expect(body(request)['cmd'], 'api.user.update_profile_image');
      expect(payload(request), {'image': '/files/avatar.png'});
      expect(payload(request), isNot(contains('image_url')));
      // Profile writes are session-scoped: the authenticated client.
      expect(http.requireAuthCalls, [true]);
    });

    test('updatePassword sends both password and password_confirmation',
        () async {
      final result = await UserRepository().updatePassword(
        password: 'correct horse',
        passwordConfirmation: 'correct horse',
      );

      expect(result, isA<Success<ProfileResponse>>());
      expect(adapter.requests, hasLength(1));

      final request = adapter.requests.single;
      expect(request.path, kPlatformGatewayPath);
      expect(body(request)['cmd'], 'api.user.update_password');
      expect(payload(request), {
        'password': 'correct horse',
        'password_confirmation': 'correct horse',
      });
      expect(http.requireAuthCalls, [true]);
    });

    test('updatePassword forwards the confirmation verbatim (server decides)',
        () async {
      // The server is the authority on the equality check ("Password
      // confirmation does not match."); the repository must not silently
      // copy `password` into the confirmation slot.
      await UserRepository().updatePassword(
        password: 'one',
        passwordConfirmation: 'two',
      );

      expect(payload(adapter.requests.single)['password_confirmation'], 'two');
    });
  });
}
