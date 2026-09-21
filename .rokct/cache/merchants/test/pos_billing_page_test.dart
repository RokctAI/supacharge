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


// BillingPage (the POS till template) pumped DIRECTLY from templates/ —
// the billing templates carry no ${package} imports precisely so this
// harness can compile them standalone (analyzer excludes templates/, so
// these tests ARE the templates' compile gate). RUN WITH
// `flutter test --dart-define=IS_DEMO=true`: demo mode keeps the camera
// unmounted (the stage renders its stand-in) and routes scans to
// MockProductsRepository.

import 'package:base_sdk/src/models/data/currency_data.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:merchants_sdk/src/manager/application/pos_cart/pos_cart_provider.dart';
import 'package:merchants_sdk/src/manager/di/manager_merchants_di.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../templates/pages/manager/billing/billing_page.dart';

Widget _host(Widget child) => ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(home: child),
      ),
    );

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
      'a demo scan lands Flame-grilled beef burger as a line card with '
      'formatted money everywhere — and the Continue button carries the '
      'total',
      (tester) async {
    // The render harness's geometry: 390 logical at 3x dpr (the approved
    // frames') so the page lays out exactly as shipped, not in the test
    // binding's 800x600 default.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(const BillingPage()));
    await tester.pump();

    // Empty cart: the empty state shows, no Clear All yet.
    expect(find.textContaining('R150.00'), findsNothing);

    // Scan through the page's own provider scope — the same demo lookup
    // path the camera's onDetect takes.
    final element = tester.element(find.byType(BillingPage));
    final container = ProviderScope.containerOf(element, listen: false);
    await container.read(posCartProvider.notifier).addByBarcode('600123');
    await tester.pump();

    // The line card: title, formatted unit-price line ("R150.00 × 1" —
    // never the Spazafy raw "150.0 x 1"), formatted line total.
    expect(find.text('Flame-grilled beef burger'), findsOneWidget);
    expect(find.text('R150.00 × 1'), findsOneWidget);

    // Step up: the quantity, the price line and both totals track.
    container.read(posCartProvider.notifier).increment(0);
    await tester.pump();
    expect(find.text('R150.00 × 2'), findsOneWidget);
    expect(find.text('R300.00'), findsWidgets); // line total + summary total

    // Continue carries the total (chip 287).
    expect(find.textContaining('R300.00'), findsWidgets);

    // No exponential rendering anywhere on the page (the section-8 bug).
    for (final w in tester.widgetList<Text>(find.byType(Text))) {
      expect(w.data ?? '', isNot(contains('e+')));
    }

    // Clear All empties the page — list AND totals (derived, never stale).
    await tester.tap(find.text('Clear all'));
    await tester.pump();
    expect(find.text('Flame-grilled beef burger'), findsNothing);
    expect(find.textContaining('R300.00'), findsNothing);
    expect(container.read(posCartProvider).total, 0);
  });
}
