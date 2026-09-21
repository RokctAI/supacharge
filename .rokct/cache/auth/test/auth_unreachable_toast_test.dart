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


// The toast the launcher's entry screen puts up by itself.
//
// Ray, 2026-09-20: "something went wrong with server is stll showing in
// splash/ login screen". On a phone the login page draws the splash artwork
// full-bleed, so the two read as one screen; the toast belongs to the login
// page, which calls `LoginNotifier.checkLanguage` from its first post-frame
// callback with no user action at all.
//
// The chain on Ray's phone: the device has a network, so the radio guard
// passes; the tenant backend does not answer, so the language fetch fails;
// `AppHelpers.errorHandler` turns that into the honest "we couldn't reach
// the server" line and sends the verbatim cause to telemetry; and
// `AuthErrorPresenter.showTechnical` - what every failure branch in
// login_notifier.dart calls - then replaced that line with the generic
// `something_went_wrong_with_the_server` fallback, which humanizes to
// "Something went wrong with the server": Ray's sentence, word for word.
//
// This file guards the auth side of that chain: the exact presenter call
// the login screen makes, over a failure string built the way
// `SettingsRepository.getLanguages` builds it, on a device with no language
// stored yet - which is every first-run entry, and the only state the
// login screen can be in while the backend it would fetch languages from
// is unreachable.
//
// `LoginNotifier` itself cannot be constructed in a standalone auth_sdk
// test: it reaches OfflineAuthService, whose drift accessors only exist
// once a host app has run build_runner over its composed AppDatabase. That
// is pre-existing and unrelated to this test.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/handlers/network_exceptions.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';

import 'package:auth_sdk/src/common/services/auth_error_presenter.dart';

/// The failure string and status a repository produces for a backend that
/// never answered — the fleet-standard catch block, not a hand-written
/// string.
({String failure, int status}) unreachableFailure(DioExceptionType type) {
  final e = DioException(
    requestOptions: RequestOptions(
      path: '/api/v1/method/rokct.platform.api',
      data: {'cmd': 'api.language.get_languages'},
    ),
    type: type,
  );
  return (
    failure: AppHelpers.errorHandler(e),
    status: NetworkExceptions.getDioStatus(e),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.init();
  });

  /// The generic line Ray was shown: no backend row and no bundled English
  /// row exists for this key, so `getTranslation` humanizes it.
  String genericLine() =>
      AppHelpers.getTranslation(TrKeys.somethingWentWrongWithTheServer);

  Future<void> pumpPresenter(
    WidgetTester tester,
    DioExceptionType type,
  ) async {
    final f = unreachableFailure(type);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Verbatim the call login_notifier.dart makes when the
                // language catalogue fetch fails.
                AuthErrorPresenter.showTechnical(
                  context,
                  type: 'auth_languages_load_failed',
                  detail: f.failure,
                  statusCode: f.status,
                );
              });
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  group('the entry screen when the guard passes and the backend does not '
      'answer', () {
    test('no language is stored, so this is a first-run entry', () {
      expect(LocalStorage.getLanguage(), isNull);
    });

    test('the sentence Ray reported is exactly the generic fallback', () {
      expect(genericLine(), 'Something went wrong with the server');
    });

    testWidgets('an unreachable backend names the server, not a vague '
        'something', (tester) async {
      await pumpPresenter(tester, DioExceptionType.connectionError);

      expect(
        find.text("We couldn't reach the server. Please try again."),
        findsOneWidget,
        reason: 'the honest line the failure already carried must survive',
      );
      expect(
        find.text(genericLine()),
        findsNothing,
        reason: 'the generic fallback must not overwrite the honest line',
      );
      // Not the offline toast either: that one belongs to the radio guard,
      // which did not fire here.
      expect(find.text('No internet connection'), findsNothing);
      expect(
        find.text(AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection)),
        findsNothing,
        reason: 'the guard already found a network; do not blame the reader',
      );
    });

    testWidgets('a timeout says the server was too slow', (tester) async {
      await pumpPresenter(tester, DioExceptionType.receiveTimeout);

      expect(
        find.text('The server took too long to respond. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.text("We couldn't reach the server. Please try again."),
        findsNothing,
      );
      expect(find.text(genericLine()), findsNothing);
    });

    testWidgets('a definitive rejection still shows the server its own words',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  AuthErrorPresenter.show(
                    context,
                    type: 'auth_login_failed',
                    failure: 'Your password is incorrect.',
                    statusCode: 401,
                  );
                });
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Your password is incorrect.'), findsOneWidget);
      expect(find.text(genericLine()), findsNothing);
    });
  });
}
