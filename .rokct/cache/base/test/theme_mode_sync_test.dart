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


// Dark-mode wiring: the AppTheme.defaultDarkMode first-launch seam, and the
// AppNotifier startup/toggle sync that keeps AppStyle's mode-resolving
// tokens in lockstep with the Material themeMode (both read the same
// persisted preference — see templates/app_widget.dart's theme/darkTheme
// pair).

import 'package:base_sdk/base_sdk.dart';
import 'package:base_sdk/src/application/app_widget/app_provider.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> boot(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    await LocalStorage.init();
  }

  tearDown(() {
    // Reset the mutable statics each test may poke: the seam back to the
    // kernel's light default, AppStyle back to its dark-first default.
    AppTheme.defaultDarkMode = false;
    AppStyle.isDark = true;
  });

  group('AppTheme.defaultDarkMode seam', () {
    test('kernel default is light', () async {
      await boot({});
      expect(AppTheme.defaultDarkMode, isFalse);
      expect(LocalStorage.getAppThemeMode(), isFalse);
    });

    test('no stored preference: getAppThemeMode follows the seam', () async {
      await boot({});
      AppTheme.defaultDarkMode = true; // dark-first app glue (driver/manager)
      expect(LocalStorage.getAppThemeMode(), isTrue);
    });

    test('a stored preference always beats the seam', () async {
      await boot({StorageKeys.keyAppThemeMode: false});
      AppTheme.defaultDarkMode = true;
      expect(LocalStorage.getAppThemeMode(), isFalse);
    });
  });

  group('AppNotifier brightness sync', () {
    test('cold start with a stored light preference drives AppStyle light',
        () async {
      await boot({StorageKeys.keyAppThemeMode: false});
      AppStyle.isDark = true; // pre-sync dark-first default
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(appProvider);
      expect(state.isDarkMode, isFalse);
      // The notifier synced AppStyle before the first frame: surfaces agree.
      expect(AppStyle.isDark, isFalse);
    });

    test('cold start with no preference follows a dark-first seam', () async {
      await boot({});
      AppTheme.defaultDarkMode = true;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(appProvider);
      expect(state.isDarkMode, isTrue);
      expect(AppStyle.isDark, isTrue);
    });

    test('changeTheme keeps storage, state and AppStyle in lockstep',
        () async {
      await boot({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(appProvider); // build the notifier (syncs light)

      await container.read(appProvider.notifier).changeTheme(true);
      expect(container.read(appProvider).isDarkMode, isTrue);
      expect(AppStyle.isDark, isTrue);
      expect(LocalStorage.getAppThemeMode(), isTrue);

      await container.read(appProvider.notifier).changeTheme(false);
      expect(container.read(appProvider).isDarkMode, isFalse);
      expect(AppStyle.isDark, isFalse);
      expect(LocalStorage.getAppThemeMode(), isFalse);
    });
  });

  group('font helper default color', () {
    // The helpers use .sp, so they need a live ScreenUtil — same harness as
    // base_wallet_card_test.
    Future<void> pumpScreenUtil(
        WidgetTester tester, void Function() body) async {
      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (context, _) {
          body();
          return const MaterialApp(home: SizedBox.shrink());
        },
      ));
    }

    List<TextStyle> allHelperDefaults() => [
          AppStyle.interBold(),
          AppStyle.interSemi(),
          AppStyle.interNoSemi(),
          AppStyle.interNormal(),
          AppStyle.interRegular(),
          AppStyle.logoFontBold(),
          AppStyle.logoFontBoldItalic(),
          AppStyle.logoFontBlackItalic(),
          AppStyle.logoMottoRegular(),
          AppStyle.logoMottoRegularItalic(),
        ];

    testWidgets(
        'omitted color resolves to the mode-resolving textPrimary '
        '(white on dark, ink on light)', (tester) async {
      await pumpScreenUtil(tester, () {
        AppStyle.isDark = true;
        final darkPrimary = AppStyle.textPrimary;
        for (final style in allHelperDefaults()) {
          expect(style.color, darkPrimary);
          expect(style.color, AppStyle.white);
        }

        AppStyle.isDark = false;
        final lightPrimary = AppStyle.textPrimary;
        expect(lightPrimary, isNot(AppStyle.white));
        for (final style in allHelperDefaults()) {
          expect(style.color, lightPrimary);
        }
      });
    });

    testWidgets('an explicitly passed color is untouched', (tester) async {
      await pumpScreenUtil(tester, () {
        AppStyle.isDark = true;
        expect(AppStyle.interNormal(color: AppStyle.red).color, AppStyle.red);
        expect(AppStyle.interBold(color: AppStyle.black).color, AppStyle.black);
      });
    });
  });
}
