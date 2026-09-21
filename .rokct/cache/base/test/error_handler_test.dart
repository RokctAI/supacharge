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


import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/handlers/network_exceptions.dart';
import 'package:base_sdk/src/handlers/platform_gateway.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/bundled_translations.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';

/// AppHelpers.errorHandler is the single funnel every repository's catch
/// block feeds into student-facing snackbars. Contract under test:
///
///   * a request that never reached a responding server says the SERVER
///     could not be reached — it does not tell the reader to check a
///     connection that the pre-request guard already found working;
///   * a timeout says the server was too slow, which is a different
///     instruction from a server that is not there;
///   * real server responses keep the pre-existing message extraction;
///   * no input whatsoever can make it return "null" or an empty string.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  RequestOptions options() => RequestOptions(
        path: kPlatformGatewayPath,
        data: {'cmd': 'api.user.register_user'},
      );

  test(
      'a server that never answered says the SERVER could not be reached, '
      'never "null" and never "check your network connection"', () {
    const unreachableTypes = [
      DioExceptionType.connectionError,
      DioExceptionType.badCertificate,
      DioExceptionType.unknown,
      DioExceptionType.cancel,
    ];
    for (final type in unreachableTypes) {
      final message = AppHelpers.errorHandler(
        DioException(requestOptions: options(), type: type),
      );
      expect(message.trim(), isNotEmpty, reason: '\$type');
      expect(message, isNot('null'), reason: '\$type');
      expect(
        message,
        AppHelpers.getTranslation(TrKeys.couldNotReachServer),
        reason: '\$type',
      );
      // The regression itself: the reader's connection is not the subject.
      expect(
        message,
        isNot(AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection)),
        reason: '\$type',
      );
      expect(message.toLowerCase(), isNot(contains('your')), reason: '\$type');
    }
  });

  test('a timeout says the server was too slow, not that it is absent', () {
    const timeoutTypes = [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ];
    for (final type in timeoutTypes) {
      final message = AppHelpers.errorHandler(
        DioException(requestOptions: options(), type: type),
      );
      expect(message.trim(), isNotEmpty, reason: '\$type');
      expect(message, isNot('null'), reason: '\$type');
      expect(
        message,
        AppHelpers.getTranslation(TrKeys.serverTookTooLong),
        reason: '\$type',
      );
      expect(
        message,
        isNot(AppHelpers.getTranslation(TrKeys.couldNotReachServer)),
        reason: '\$type',
      );
    }
  });

  test('the two connection lines are the bundled English copy', () {
    // The keys NAME a string rather than spelling it, so the humanized
    // fallback is not copy; bundled_en_translations.dart supplies both,
    // and TranslationSeeder offers the backend these same values.
    expect(
      BundledTranslations.lookup('en', TrKeys.couldNotReachServer),
      "We couldn't reach the server. Please try again.",
    );
    expect(
      BundledTranslations.lookup('en', TrKeys.serverTookTooLong),
      'The server took too long to respond. Please try again.',
    );
    // And a device with no language chosen yet now gets that bundled copy
    // rather than the clipped humanized fragment.
    //
    // This assertion previously pinned 'Could not reach server', with the
    // note that getTranslation consults the bundled map by the ACTIVE
    // locale and no language has been chosen here. That was the real
    // behaviour and it is exactly the gap Ray then reported on the
    // launcher: splash and login BOTH run before a language exists (the
    // login screen's own checkLanguage cannot store one while the backend
    // is unreachable), so the two screens this copy was written for were
    // the only two that could never show it. getTranslation now falls back
    // to BundledTranslations.baseLocale while no language is stored, so
    // the copy asserted above is the copy that reaches the screen. A
    // chosen language is unaffected.
    expect(
      AppHelpers.getTranslation(TrKeys.couldNotReachServer),
      "We couldn't reach the server. Please try again.",
    );
    expect(
      AppHelpers.getTranslation(TrKeys.serverTookTooLong),
      'The server took too long to respond. Please try again.',
    );
  });

  test('a response-bearing failure is classified by its status, not as '
      '"no internet"', () {
    // getDioException used to fall through every arm to
    // noInternetConnection(); each arm now returns the variant it names.
    NetworkExceptions classify(int status) => NetworkExceptions.getDioException(
          DioException(
            requestOptions: options(),
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: options(), statusCode: status),
          ),
        );
    expect(classify(400), isA<BadRequest>());
    expect(classify(401), isA<UnauthorisedRequest>());
    expect(classify(404), isA<NotFound>());
    expect(classify(409), isA<Conflict>());
    expect(classify(500), isA<InternalServerError>());
    expect(classify(503), isA<ServiceUnavailable>());
    for (final status in [400, 401, 404, 409, 500, 503]) {
      expect(
        classify(status),
        isNot(isA<NoInternetConnection>()),
        reason: '\$status',
      );
    }
    expect(
      NetworkExceptions.getDioException(
        DioException(
          requestOptions: options(),
          type: DioExceptionType.receiveTimeout,
        ),
      ),
      isA<RequestTimeout>(),
    );
  });

  test('a real server response keeps the existing message extraction', () {
    final e = DioException(
      requestOptions: options(),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options(),
        statusCode: 409,
        data: {'message': 'Email already exists'},
      ),
    );
    expect(AppHelpers.errorHandler(e), 'Email already exists');
  });

  test('non-Dio errors keep their toString message', () {
    expect(AppHelpers.errorHandler(Exception('boom')), 'Exception: boom');
  });

  test('hardened fallback: no input yields "null" or an empty string', () {
    // null.toString() is the exact null-shorted chain that used to reach
    // the register screen as a red "null" toast.
    for (final input in [null, '', 'null', '   ']) {
      final message = AppHelpers.errorHandler(input);
      expect(message.trim(), isNotEmpty, reason: '"$input"');
      expect(message.trim(), isNot('null'), reason: '"$input"');
    }
  });
}
