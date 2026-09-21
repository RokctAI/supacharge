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

// The Languages sheet follows the app theme (guided tour run 34112448075,
// 16-comms_language.png: a light sheet over a dark page).
//
// AppHelpers.showCustomModalBottomSheet paints the sheet route transparent
// and the modal brings its own surface, so the isDarkMode flag a caller
// passes never reaches the paint - the sheet has to resolve the surface
// against AppStyle's mode flag itself.

import 'package:base_sdk/src/application/language/language_notifier.dart';
import 'package:base_sdk/src/application/language/language_provider.dart';
import 'package:base_sdk/src/application/language/language_state.dart';
import 'package:base_sdk/src/models/response/languages_response.dart';
import 'package:base_sdk/src/presentation/components/buttons/custom_button.dart';
import 'package:base_sdk/src/presentation/components/title_icon.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:comms_sdk/src/common/infrastructure/repositories/mock_settings_repository.dart';
import 'package:comms_sdk/src/common/presentation/pages/setting/language_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves the picker its list without the connectivity probe and the
/// repository round-trip the real notifier makes.
class _StubLanguageNotifier extends LanguageNotifier {
  _StubLanguageNotifier() : super(MockSettingsRepository());

  @override
  Future<void> getLanguages(
    BuildContext context, {
    bool autoSelectIfSingle = false,
  }) async {
    state = LanguageState(
      isLoading: false,
      list: [
        LanguageData(id: '1', title: 'English', locale: 'en', backward: false),
        LanguageData(id: '2', title: 'isiZulu', locale: 'zu', backward: false),
      ],
    );
  }
}

Widget _harness(Widget child) => ProviderScope(
      overrides: [
        languageProvider.overrideWith((ref) => _StubLanguageNotifier()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(home: child),
      ),
    );

Color _surfaceOf(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(LanguageScreen),
          matching: find.byType(Container),
        )
        .first,
  );
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  tearDown(() => AppStyle.setBrightness(Brightness.dark));

  group('the sheet surface follows the theme', () {
    testWidgets('dark: the theme dark surface, title in primary ink',
        (tester) async {
      AppStyle.setBrightness(Brightness.dark);
      await tester.pumpWidget(
        _harness(Scaffold(body: LanguageScreen(onSave: () {}))),
      );
      await tester.pump();

      expect(
        _surfaceOf(tester),
        AppStyle.surfaceDark.withValues(alpha: 0.96),
      );
      expect(_surfaceOf(tester), isNot(AppStyle.bgGrey.withValues(alpha: 0.96)));
      final title = tester.widget<TitleAndIcon>(find.byType(TitleAndIcon));
      expect(title.titleColor, AppStyle.textPrimary);
      expect(title.titleColor, isNot(AppStyle.black));
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('light: the soft page grey', (tester) async {
      AppStyle.setBrightness(Brightness.light);
      await tester.pumpWidget(
        _harness(Scaffold(body: LanguageScreen(onSave: () {}))),
      );
      await tester.pump();

      expect(_surfaceOf(tester), AppStyle.bgGrey.withValues(alpha: 0.96));
    });
  });

  group('opened through the helper on a wide window', () {
    testWidgets('the Save button sits inside the END-anchored panel',
        (tester) async {
      // The tablet leg: 1600x2560 physical at 240 dpi (~1066 x 1706 dp).
      tester.view.physicalSize = const Size(1600, 2560);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      AppStyle.setBrightness(Brightness.dark);

      await tester.pumpWidget(
        _harness(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppHelpers.showCustomModalBottomSheet(
                  context: context,
                  modal: LanguageScreen(onSave: () {}),
                  isDarkMode: true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final sheet = tester.getRect(find.byType(LanguageScreen));
      final save = tester.getRect(find.byType(CustomButton));
      final window = tester.getRect(find.byType(MaterialApp));

      expect(save.bottom, lessThanOrEqualTo(sheet.bottom));
      expect(save.top, greaterThanOrEqualTo(sheet.top));
      expect(sheet.bottom, lessThanOrEqualTo(window.bottom));
      expect(sheet.left, greaterThanOrEqualTo(0));
      expect(sheet.right, lessThanOrEqualTo(window.right));
      expect(_surfaceOf(tester), AppStyle.surfaceDark.withValues(alpha: 0.96));
    });
  });
}
