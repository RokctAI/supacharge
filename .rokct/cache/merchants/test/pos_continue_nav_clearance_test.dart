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


// The POS till's Continue button against the manager shell's floating
// bottom pill (paas_manager guided tour 33952102598, phone still 05: the
// pill sat on top of the orange Continue and hid it).
//
// The shell (the installed main_page.dart template, which carries a
// `${package}` import and so cannot be pumped here) parks its pill in the
// Scaffold's `floatingActionButton` slot at centerFloat, `managerNavPillHeight`
// tall; this harness mounts BillingPage in exactly that slot geometry and
// asserts the button's bottom edge clears the pill's top edge on a
// 390x844 phone — and that plane widths, where the shell docks the nav as
// a rail beside the pages, keep the cart plane's original 12 gap.

import 'package:base_sdk/src/models/data/currency_data.dart';
import 'package:base_sdk/src/presentation/components/blur_wrap.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:merchants_sdk/src/manager/di/manager_merchants_di.dart';
import 'package:merchants_sdk/src/manager/presentation/main/manager_nav_clearance.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../templates/pages/manager/billing/billing_page.dart';

const Key _navKey = Key('navPill');
const Key _continueKey = Key('posContinue');

/// The shell's pill slot: a centerFloat floatingActionButton holding the
/// BlurWrap housing at the shell's height.
Widget _shell({required bool pill}) => Scaffold(
      resizeToAvoidBottomInset: false,
      body: const BillingPage(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: !pill
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BlurWrap(
                  radius: BorderRadius.circular(100.r),
                  child: Container(
                    key: _navKey,
                    height: managerNavPillHeight(),
                    width: 260.r,
                    decoration: BoxDecoration(
                      color: AppStyle.bottomNavigationBarColor.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                  ),
                ),
              ],
            ),
    );

Future<void> _pumpAt(
  WidgetTester tester, {
  required Size logical,
  required double dpr,
  required bool pill,
}) async {
  tester.view.physicalSize = logical * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: ScreenUtilInit(
        designSize: logical.width < 600 ? const Size(375, 812) : logical,
        builder: (context, _) => MaterialApp(home: _shell(pill: pill)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await LocalStorage.setSelectedCurrency(
      CurrencyData(id: 'ZAR', symbol: 'R', position: 'before', rate: 1),
    );
    ManagerMerchantsDependencies.register(GetIt.instance);
  });

  testWidgets(
      '390x844 phone: Continue sits above the pill, with the frames\' gap '
      'between them, and the pill itself is where the shell put it',
      (tester) async {
    await _pumpAt(
      tester,
      logical: const Size(390, 844),
      dpr: 3,
      pill: true,
    );
    final button = tester.getRect(find.byKey(_continueKey));
    final pill = tester.getRect(find.byKey(_navKey));
    expect(button.bottom, lessThan(pill.top));
    expect(button.overlaps(pill), isFalse);
    expect(pill.top - button.bottom, greaterThanOrEqualTo(12.h - 0.5));
    // Not moved, not hidden: the Scaffold still floats the pill
    // kFloatingActionButtonMargin above the bottom edge.
    expect(pill.bottom, closeTo(844 - kFloatingActionButtonMargin, 0.5));
    expect(pill.height, closeTo(managerNavPillHeight(), 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      '800x1280 tablet (two planes): the cart plane keeps its 12 gap — '
      'the shell docks the nav as a rail there, nothing floats over the '
      'foot', (tester) async {
    await _pumpAt(
      tester,
      logical: const Size(800, 1280),
      dpr: 2,
      pill: false,
    );
    final button = tester.getRect(find.byKey(_continueKey));
    expect(button.bottom, closeTo(1280 - 12.h, 0.5));
    expect(tester.takeException(), isNull);
  });
}
