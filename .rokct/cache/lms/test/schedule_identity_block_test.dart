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


// The Schedule header's logged-out state must render the app name through
// base_sdk's AppHelpers.getAppName seam (the server "title" setting, then
// the compose-time AppConstants.appTitle fallback) — never a hard-coded
// brand literal — and must show the FULL name: "Welcome to <name>" is a
// sentence, so a dotted name is not folded here (the splash wordmark fold
// lives in base_sdk).

import 'package:base_sdk/src/constants/app_constants.dart';
import 'package:base_sdk/src/models/response/global_settings_response.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';
// Transitive via base_sdk; test-only use to back LocalStorage.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Row(children: [Expanded(child: child)]),
      ),
    );

Future<void> _seedTitle(String? value) => LocalStorage.setSettingsList(
      [SettingsData(id: 1, key: 'title', value: value)],
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const {});
    await LocalStorage.init();
    // The first line goes through AppHelpers.getTranslation; seed the one
    // key the finders rely on exactly as the host app would serve it.
    await LocalStorage.setTranslations({'welcome_to': 'Welcome to'});
  });

  setUp(LocalStorage.deleteSettingsList);

  testWidgets('logged out: renders the server "title" setting in full, '
      'dot and all', (tester) async {
    await _seedTitle('acme.school');
    await tester.pumpWidget(
        _host(const ScheduleIdentityBlock(firstName: '', lastName: '')));

    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text('acme.school'), findsOneWidget);
    // No wordmark fold in a sentence: the stem alone must not appear.
    expect(find.text('acme'), findsNothing);
  });

  testWidgets('logged out: no "title" setting falls back to the composed '
      'AppConstants.appTitle, not a literal', (tester) async {
    await tester.pumpWidget(
        _host(const ScheduleIdentityBlock(firstName: '', lastName: '')));

    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text(AppConstants.appTitle), findsOneWidget);
  });

  testWidgets('logged out: a blank "title" value also falls back',
      (tester) async {
    await _seedTitle('   ');
    await tester.pumpWidget(
        _host(const ScheduleIdentityBlock(firstName: '', lastName: '')));

    expect(find.text(AppConstants.appTitle), findsOneWidget);
  });

  testWidgets('logged in: shows the student, never the app name',
      (tester) async {
    await _seedTitle('acme.school');
    await tester.pumpWidget(_host(
        const ScheduleIdentityBlock(firstName: 'Thandi', lastName: 'Nkosi')));

    expect(find.text('Thandi'), findsOneWidget);
    expect(find.text('Nkosi'), findsOneWidget);
    expect(find.text('Welcome to'), findsNothing);
    expect(find.text('acme.school'), findsNothing);
  });

  test('appName(): trims the setting and falls back when null or blank',
      () async {
    await _seedTitle('  acme.school ');
    expect(ScheduleIdentityBlock.appName(), 'acme.school');

    await _seedTitle(null);
    expect(ScheduleIdentityBlock.appName(), AppConstants.appTitle);

    LocalStorage.deleteSettingsList();
    expect(ScheduleIdentityBlock.appName(), AppConstants.appTitle);
  });
}
