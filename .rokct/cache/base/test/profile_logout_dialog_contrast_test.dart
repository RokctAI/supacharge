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

// GenericProfilePage's sign-out confirmation, in a DARK host.
//
// _confirmLogout raises a plain Material AlertDialog — no explicit
// backgroundColor — so in a dark app it renders on the theme's dark dialog
// surface (#2B2930 under ThemeData(brightness: Brightness.dark)). Its Cancel
// button was painted with the polarity-pinned AppStyle.black (#232B2F) for
// BOTH its label and its outline: 1.00:1 against that surface. Not "hard to
// read" — the entire button was absent from the dialog on every dark host
// (the manager hub, the driver app), leaving a sign-out confirmation whose
// only visible control was the one that signs you out.
//
// This suite measures the ACTUAL rendered dialog surface rather than
// assuming it, then holds the Cancel button's ink to the WCAG 1.4.3 body
// floor against it, in both polarities.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/gallery.dart';
import 'package:base_sdk/src/domain/interface/shops.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/presentation/components/buttons/custom_button.dart';
import 'package:base_sdk/src/presentation/pages/profile/generic_profile_page.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/local_storage.dart';

// Same fakes as generic_profile_spread_test.dart: with no stored token the
// page returns before its first repository call, so these need only be
// constructible.
class _FakeUserRepository extends Fake implements UserRepositoryFacade {}

class _FakeShopsRepository extends Fake implements ShopsRepositoryFacade {}

class _FakeGalleryRepository extends Fake implements GalleryRepositoryFacade {}

const double _kTextContrastFloor = 4.5;

double _channel(int v) {
  final c = v / 255.0;
  return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;
}

double _luminance(Color c) =>
    0.2126 * _channel((c.r * 255).round()) +
    0.7152 * _channel((c.g * 255).round()) +
    0.0722 * _channel((c.b * 255).round());

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

String _hex(Color c) => '#'
    '${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}'
    '${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}'
    '${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}'
    .toUpperCase();

void main() {
  final bool wasDark = AppStyle.isDark;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    getIt.registerSingleton<UserRepositoryFacade>(_FakeUserRepository());
    getIt.registerSingleton<ShopsRepositoryFacade>(_FakeShopsRepository());
    getIt.registerSingleton<GalleryRepositoryFacade>(_FakeGalleryRepository());
  });

  setUp(() {
    ProfileSectionRegistry.I.reset();
    // The sign-out affordance only renders once a host owns logout.
    ProfileSectionRegistry.I.onLogout = (_) {};
  });

  tearDown(() => AppStyle.isDark = wasDark);

  /// Pumps the page in [brightness], opens the sign-out confirmation and
  /// returns (cancel button, measured dialog surface).
  Future<(CustomButton, Color)> openConfirm(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    // Drive the polarity the way a user does: the stored preference is what
    // AppNotifier reads on build, and IT calls AppStyle.setBrightness — so
    // setting the token flag alone would be overwritten during the pump.
    await LocalStorage.setAppThemeMode(brightness == Brightness.dark);
    AppStyle.setBrightness(brightness);
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(390, 1400),
          builder: (context, _) => MaterialApp(
            theme: ThemeData(brightness: Brightness.light),
            darkTheme: ThemeData(brightness: Brightness.dark),
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const GenericProfilePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Remix.logout_circle_r_line));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget,
        reason: 'the sign-out confirmation did not open');

    // The Cancel button is the transparent-background one; Yes is on
    // AppStyle.primary.
    final cancel = tester
        .widgetList<CustomButton>(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(CustomButton),
        ))
        .firstWhere((b) => b.background == AppStyle.transparent);

    // The surface actually painted behind it — read, not assumed.
    final surface = tester
        .widgetList<Material>(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Material),
        ))
        .map((m) => m.color)
        .firstWhere((c) => c != null && c.a > 0)!;

    // Dismiss before returning: pumpWidget reuses the Navigator element, so
    // a dialog left open would obscure the sign-out button on the next pump.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    return (cancel, surface);
  }

  void expectLegible(Color ink, Color surface, String what) {
    final ratio = _contrast(ink, surface);
    expect(
      ratio,
      greaterThanOrEqualTo(_kTextContrastFloor),
      reason: '$what paints ${_hex(ink)} on the dialog surface '
          '${_hex(surface)} — ${ratio.toStringAsFixed(2)}:1, below the '
          '$_kTextContrastFloor:1 floor. AlertDialog takes its background '
          "from the host's ThemeData, so this ink must be a mode-resolving "
          'AppStyle token (textPrimary), never the pinned AppStyle.black.',
    );
  }

  testWidgets('the Cancel button is visible on a DARK host', (tester) async {
    final (cancel, surface) = await openConfirm(tester, Brightness.dark);
    expectLegible(cancel.textColor, surface, 'Cancel label');
    expectLegible(cancel.borderColor, surface, 'Cancel outline');
  });

  testWidgets('the Cancel button is visible on a LIGHT host', (tester) async {
    final (cancel, surface) = await openConfirm(tester, Brightness.light);
    expectLegible(cancel.textColor, surface, 'Cancel label');
    expectLegible(cancel.borderColor, surface, 'Cancel outline');
  });

  testWidgets('the Cancel ink tracks the mode rather than being pinned',
      (tester) async {
    final (dark, _) = await openConfirm(tester, Brightness.dark);
    final (light, _) = await openConfirm(tester, Brightness.light);
    expect(dark.textColor, isNot(equals(light.textColor)),
        reason: 'Cancel paints ${_hex(dark.textColor)} in both polarities — '
            'that is a pinned constant, not a resolving token.');
  });
}
