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

// The credit / partly-paid + send-for-delivery checkout (approved strip
// frames 11g–11i), pumped DIRECTLY from templates/ with the demo
// PosOrdersFacade (MockPosOrdersRepository). Run with
// --dart-define=IS_DEMO=true.
//
// Covers: the customer attach unlocking the split (305/306 — the "owes"
// chip), the Amount-paying-now edit driving the remainder banner and the
// summary split rows (307/309/292), the submitted draft carrying the
// split into the pipeline (paid_now + Credit + status 'delivered' /
// deliveryType 'pickup' for an in-store sale), and the send-for-delivery
// state (312–315): customer + address required, then a 'ready' /
// 'delivery' draft — Ray's ruling that scanned sales enter the NORMAL
// create-order pipeline with the status they are in.

import 'package:base_sdk/src/models/data/currency_data.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:merchants_sdk/src/manager/application/pos_cart/pos_cart_provider.dart';
import 'package:merchants_sdk/src/manager/di/manager_merchants_di.dart';
import 'package:merchants_sdk/src/manager/domain/interface/pos_orders.dart';
import 'package:merchants_sdk/src/manager/infrastructure/repositories/mock_pos_orders_repository.dart';
import 'package:merchants_sdk/src/manager/utils/pos_connectivity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../templates/pages/manager/billing/checkout_page.dart';

Widget _host(Widget child) => ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(home: child),
      ),
    );

Future<ProviderContainer> _pumpWithCart(WidgetTester tester) async {
  // Tall canvas (the 11g/11i frames are 390x3420+ logical, plus the
  // keypad card's five key rows) so the whole flow — toggles, cards,
  // keypad, banner, summary, buttons — lays out without scrolling.
  tester.view.physicalSize = const Size(1170, 12600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_host(const CheckoutPage()));
  final element = tester.element(find.byType(CheckoutPage));
  final container = ProviderScope.containerOf(element, listen: false);
  await container.read(posCartProvider.notifier).addByBarcode('600123');
  await tester.pump(); // connectivity probe microtask + cart rebuild
  return container;
}

MockPosOrdersRepository get _mock =>
    GetIt.I<PosOrdersFacade>() as MockPosOrdersRepository;

Future<void> _attachDemoCustomer(WidgetTester tester) async {
  await tester.tap(find.text('Add customer'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Thabo Mokoena'));
  await tester.pumpAndSettle();
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

  setUp(() async {
    // A fresh mock per test so submitted drafts don't leak across tests.
    if (GetIt.I.isRegistered<PosOrdersFacade>()) {
      await GetIt.I.unregister<PosOrdersFacade>();
    }
    GetIt.I.registerSingleton<PosOrdersFacade>(MockPosOrdersRepository());
    PosConnectivity.debugConnectivityOverride = true;
  });

  tearDown(() {
    PosConnectivity.debugConnectivityOverride = null;
  });

  testWidgets(
      'credit split (11g): attaching the customer unlocks the amount '
      'entry; editing below the total shows the owes chip, the remainder '
      'banner and the summary split; the submitted draft carries '
      'paid-now + Credit into the pipeline', (tester) async {
    final container = await _pumpWithCart(tester);

    // Before the attach: no amount card, no split (a full sale).
    expect(find.byKey(const Key('posPaidNowField')), findsNothing);
    expect(find.text('Billing to'.toUpperCase()), findsOneWidget);

    await _attachDemoCustomer(tester);

    // The attach: initials avatar + the outstanding "owes" chip (306).
    expect(find.text('TM'), findsOneWidget);
    expect(find.textContaining('owes'), findsOneWidget);
    expect(find.textContaining('R89.50'), findsOneWidget);

    // The amount card unlocked, prefilled with the total (150.00). Edit
    // to 100 ON THE KEY PAD (390 — the fresh prefill is replaced by the
    // first digit, calculator-entry style) — the split appears:
    // remainder banner (309) + summary rows.
    final amountField = find.byKey(const Key('posPaidNowField'));
    expect(amountField, findsOneWidget);
    for (final digit in ['1', '0', '0']) {
      await tester.tap(find.byKey(Key('moneyKey$digit')));
      await tester.pump();
    }
    expect(find.textContaining('remains'), findsOneWidget);
    expect(find.text('Paying now · Cash'), findsNothing); // QR selected
    expect(find.textContaining('Paying now'), findsOneWidget);
    expect(find.text('On credit'), findsOneWidget);
    expect(find.text('R50.00'), findsWidgets);

    // Finish without Receipt submits the draft, then clears the sale.
    await tester.tap(find.text('Finish without Receipt'));
    await tester.pumpAndSettle();
    expect(_mock.submitted, hasLength(1));
    final draft = _mock.submitted.single;
    expect(draft.paidNow, 100);
    expect(draft.onCredit, isTrue);
    expect(draft.status, 'delivered');
    expect(draft.deliveryType, 'pickup');
    expect(draft.customerId, MockPosOrdersRepository.demoCustomer.id);
    expect(draft.total, 150);
    expect(draft.lines, hasLength(1));
    expect(container.read(posCartProvider).lines, isEmpty);
  });

  testWidgets(
      'all-on-credit quick action (308) zeroes the paying-now amount',
      (tester) async {
    await _pumpWithCart(tester);
    await _attachDemoCustomer(tester);

    await tester.tap(find.textContaining('all on credit'));
    await tester.pump();
    expect(find.textContaining('remains'), findsOneWidget);

    await tester.tap(find.text('Finish without Receipt'));
    await tester.pumpAndSettle();
    final draft = _mock.submitted.single;
    expect(draft.paidNow, 0);
    expect(draft.onCredit, isTrue);
  });

  testWidgets(
      'send-for-delivery (11i): customer and address are required, then '
      'the draft enters the pipeline as ready/delivery — an offline till '
      'holds it locally until the sync drains it', (tester) async {
    final container = await _pumpWithCart(tester);

    await tester.tap(find.text('Send for delivery'));
    await tester.pump();

    // No customer yet: the finish refuses and the sale stays open.
    await tester.tap(find.text('Send for delivery & Finish'));
    await tester.pumpAndSettle();
    expect(_mock.submitted, isEmpty);
    expect(container.read(posCartProvider).lines, hasLength(1));

    await _attachDemoCustomer(tester);

    // Customer but no address: still refused.
    await tester.tap(find.text('Send for delivery & Finish'));
    await tester.pumpAndSettle();
    expect(_mock.submitted, isEmpty);

    // Enter the address via the Delivers-to card's editor (314). Two
    // "Change" links are on screen (billing-to + delivers-to); the
    // delivers-to card sits below.
    await tester.tap(find.text('Change').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '12 Marigold Ave, Rosebank',
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('12 Marigold Ave, Rosebank'), findsOneWidget);

    await tester.tap(find.text('Send for delivery & Finish'));
    await tester.pumpAndSettle();
    expect(_mock.submitted, hasLength(1));
    final draft = _mock.submitted.single;
    expect(draft.status, 'ready');
    expect(draft.deliveryType, 'delivery');
    expect(draft.address, '12 Marigold Ave, Rosebank');
    expect(draft.paidNow, 150); // untouched entry = full total
    expect(draft.onCredit, isFalse);
    expect(container.read(posCartProvider).lines, isEmpty);
  });
}
