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


// The presenter half of the unreachable-backend wording.
//
// `profile_server_unreachable_toast_test.dart` covers a surface that hands
// `ApiResult.failure`'s `error` string straight to the snackbar, so the
// honest "we couldn't reach the server" line reaches the screen. Every auth
// surface - login included - goes through ErrorPresenter instead, and its
// technical branch used to overwrite that line with the generic
// `something_went_wrong_with_the_server` fallback. Same failure, two
// different sentences depending on which screen you were standing on.
//
// Ray, 2026-09-20, about the launcher: "something went wrong with server is
// stll showing in splash/ login screen". That sentence is the humanized
// form of `something_went_wrong_with_the_server`, and the login screen -
// which draws the splash artwork full-bleed on a phone - is where the
// presenter was substituting it.
//
// The detail strings below are produced by the real funnel
// (`AppHelpers.errorHandler` over a response-less DioException, status from
// `NetworkExceptions.getDioStatus`), not hand-written, so the test cannot
// pass by agreeing with itself.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/handlers/network_exceptions.dart';
import 'package:base_sdk/src/handlers/platform_gateway.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/error_presenter.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';

/// A response-less DioException of [type], shaped like a gateway call to a
/// backend that is simply not there.
DioException _unreachable(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(
        path: kPlatformGatewayPath,
        data: {'cmd': 'api.language.get_languages'},
      ),
      type: type,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.init();
  });

  /// The generic line Ray was shown: no `en` row and no bundled `en` value
  /// exists for this key, so `getTranslation` humanizes it.
  String genericLine() =>
      AppHelpers.getTranslation(TrKeys.somethingWentWrongWithTheServer);

  group('ErrorPresenter keeps the authored unreachable-backend line', () {
    test('the generic fallback really is the sentence Ray reported', () {
      expect(genericLine(), 'Something went wrong with the server');
    });

    test('resolve() returns the server-unreachable line, not the generic one',
        () {
      final e = _unreachable(DioExceptionType.connectionError);

      final line = ErrorPresenter.resolve(
        type: 'auth_languages_load_failed',
        detail: AppHelpers.errorHandler(e),
        statusCode: NetworkExceptions.getDioStatus(e),
      );

      expect(
        line,
        AppHelpers.getTranslation(TrKeys.couldNotReachServer),
        reason: 'the failure string already named the server honestly',
      );
      expect(line, isNot(genericLine()));
    });

    test('resolve() keeps the too-slow line for a timeout', () {
      final e = _unreachable(DioExceptionType.receiveTimeout);

      expect(
        ErrorPresenter.resolve(
          type: 'auth_languages_load_failed',
          detail: AppHelpers.errorHandler(e),
          statusCode: NetworkExceptions.getDioStatus(e),
        ),
        AppHelpers.getTranslation(TrKeys.serverTookTooLong),
      );
    });

    test('an explicit friendly line still wins', () {
      final e = _unreachable(DioExceptionType.connectionError);

      expect(
        ErrorPresenter.resolve(
          type: 'auth_confirm_code_failed',
          detail: AppHelpers.errorHandler(e),
          statusCode: NetworkExceptions.getDioStatus(e),
          friendly: 'We could not verify that code, please try again.',
        ),
        'We could not verify that code, please try again.',
      );
    });

    test('raw technical detail is still never shown', () {
      final line = ErrorPresenter.resolve(
        type: 'auth_languages_load_failed',
        detail: 'DioException [unknown]: SocketException: Failed host lookup',
        statusCode: 500,
      );

      expect(line, genericLine());
    });

    test('a definitive 4xx server message is still shown verbatim', () {
      expect(
        ErrorPresenter.resolve(
          type: 'auth_login_failed',
          detail: 'Your password is incorrect.',
          statusCode: 401,
        ),
        'Your password is incorrect.',
      );
    });
  });

  // The recognition is exercised through its only consumer, so this file
  // compiles against the pre-fix sources and fails on the assertion rather
  // than on a missing symbol.
  group('only the two authored lines are let through', () {
    String lineFor(String detail) => ErrorPresenter.resolve(
          type: 'auth_languages_load_failed',
          detail: detail,
          statusCode: 500,
        );

    test('both authored lines survive verbatim', () {
      for (final key in <String>[
        TrKeys.couldNotReachServer,
        TrKeys.serverTookTooLong,
      ]) {
        final authored = AppHelpers.getTranslation(key);
        expect(lineFor(authored), authored, reason: 'for $key');
      }
    });

    test('anything else falls back to the generic line', () {
      for (final other in <String>[
        'null',
        'Something went wrong with the server',
        'DioException [connection error]',
        "We couldn't reach the server",
        'Server is down, sorry!',
      ]) {
        expect(
          lineFor(other),
          genericLine(),
          reason: 'must not let "$other" through as student copy',
        );
      }
    });

    test('an empty detail still falls back to the generic line', () {
      expect(lineFor('   '), genericLine());
    });
  });

  group('before any language has been chosen', () {
    test('no language is stored at all', () {
      expect(LocalStorage.getLanguage(), isNull);
    });

    test('a key with bundled English copy resolves to that copy, not a '
        'humanized fragment', () {
      // The whole point of kBaseEnTranslations: these two keys NAME a
      // string, so humanizing them clips them to "Could not reach server"
      // / "Server took too long". Splash and login run before a language
      // exists, which is precisely where that clipping showed.
      expect(
        AppHelpers.getTranslation(TrKeys.couldNotReachServer),
        "We couldn't reach the server. Please try again.",
      );
      expect(
        AppHelpers.getTranslation(TrKeys.serverTookTooLong),
        'The server took too long to respond. Please try again.',
      );
      expect(
        AppHelpers.getTranslation(TrKeys.couldNotReachServer),
        isNot(AppHelpers.humanizeTrKey(TrKeys.couldNotReachServer)),
      );
    });

    test('a key with no bundled row still humanizes', () {
      expect(
        AppHelpers.getTranslation(TrKeys.somethingWentWrongWithTheServer),
        AppHelpers.humanizeTrKey(TrKeys.somethingWentWrongWithTheServer),
      );
    });

    test('the end-to-end line a login screen would paint is the authored '
        'sentence', () {
      final e = _unreachable(DioExceptionType.connectionError);

      expect(
        ErrorPresenter.resolve(
          type: 'auth_languages_load_failed',
          detail: AppHelpers.errorHandler(e),
          statusCode: NetworkExceptions.getDioStatus(e),
        ),
        "We couldn't reach the server. Please try again.",
      );
    });
  });

  group('the snackbar branch', () {
    testWidgets('showTechnical paints the server line, not the generic one',
        (tester) async {
      final e = _unreachable(DioExceptionType.connectionError);
      late BuildContext hostContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                hostContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      ErrorPresenter.showTechnical(
        hostContext,
        type: 'auth_languages_load_failed',
        detail: AppHelpers.errorHandler(e),
        statusCode: NetworkExceptions.getDioStatus(e),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(
        find.text(AppHelpers.getTranslation(TrKeys.couldNotReachServer)),
        findsOneWidget,
      );
      expect(find.text(genericLine()), findsNothing);
    });
  });
}
