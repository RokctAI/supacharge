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

// THE KEY PAD at checkout (chip 390 — approved frames 11u tablet
// 2026-08-29 15:41Z / 11y phone 2026-08-30): the amount-paying-now entry
// is base_sdk's shared MoneyKeypad, and the amount display (336) is a
// plain read-out that CANNOT summon the OS keyboard — the 11y ruling.
// Covers the gate (no focusable entry in the amount card, keypad
// present), keypad editing end to end into the submitted draft
// (digits / 00 / decimal / ⌫ / OK-normalize, calculator-entry
// replacement of the fresh prefill), and the quick chips resetting
// freshness. Run with --dart-define=IS_DEMO=true.

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

Future<void> _pumpWithCart(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 12600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_host(const CheckoutPage()));
  final element = tester.element(find.byType(CheckoutPage));
  final container = ProviderScope.containerOf(element, listen: false);
  await container.read(posCartProvider.notifier).addByBarcode('600123');
  await tester.pump();
}

MockPosOrdersRepository get _mock =>
    GetIt.I<PosOrdersFacade>() as MockPosOrdersRepository;

Future<void> _attachDemoCustomer(WidgetTester tester) async {
  await tester.tap(find.text('Add customer'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Thabo Mokoena'));
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String keyId) async {
  await tester.tap(find.byKey(Key(keyId)));
  await tester.pump();
}

String _displayed(WidgetTester tester) {
  final display = find.descendant(
    of: find.byKey(const Key('posPaidNowField')),
    matching: find.byType(Text),
  );
  return (tester.widget<Text>(display).data)!;
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
      'the 11y gate: the amount display never summons the OS keyboard — '
      'no focusable entry in the amount card, OUR keypad does the entry',
      (tester) async {
    await _pumpWithCart(tester);
    await _attachDemoCustomer(tester);

    // The amount card is a read-out, not a field: no EditableText (and
    // so no OS-keyboard focus target) anywhere inside it.
    final card = find.byKey(const Key('posPaidNowField'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(EditableText)),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.byType(TextField)),
      findsNothing,
    );

    // The key pad (390) is on the page: digits grid with the 00 money
    // key and ⌫, plus the . | OK confirm row.
    for (final id in [
      'moneyKey1', 'moneyKey5', 'moneyKey9', 'moneyKey00', 'moneyKey0', //
      'moneyKeyBackspace', 'moneyKeyDecimal', 'moneyKeyOk',
    ]) {
      expect(find.byKey(Key(id)), findsOneWidget, reason: '$id missing');
    }
  });

  testWidgets(
      'keypad editing end to end: fresh prefill replaced by the first '
      'digit, 00 and decimal keys, ⌫ edits, OK normalizes, and the '
      'submitted draft carries the keypad amount', (tester) async {
    await _pumpWithCart(tester);
    await _attachDemoCustomer(tester);

    // Prefilled with the full total.
    expect(_displayed(tester), '150.00');

    // First digit REPLACES the fresh prefill (calculator entry).
    await _tapKey(tester, 'moneyKey7');
    expect(_displayed(tester), '7');
    await _tapKey(tester, 'moneyKey00');
    expect(_displayed(tester), '700');

    // ⌫ edits in place; entry above the total still clamps via OK.
    await _tapKey(tester, 'moneyKeyBackspace');
    await _tapKey(tester, 'moneyKeyBackspace');
    expect(_displayed(tester), '7');

    await _tapKey(tester, 'moneyKey5');
    await _tapKey(tester, 'moneyKeyDecimal');
    await _tapKey(tester, 'moneyKey5');
    expect(_displayed(tester), '75.5');

    // OK normalizes to what the sale takes (two decimals).
    await _tapKey(tester, 'moneyKeyOk');
    expect(_displayed(tester), '75.50');

    // The split is live off the keypad amount.
    expect(find.textContaining('remains'), findsOneWidget);
    expect(find.text('On credit'), findsOneWidget);

    await tester.tap(find.text('Finish without Receipt'));
    await tester.pumpAndSettle();
    final draft = _mock.submitted.single;
    expect(draft.paidNow, 75.50);
    expect(draft.onCredit, isTrue);
  });

  testWidgets(
      'quick chips re-arm freshness: Full then a digit starts a new '
      'entry instead of appending', (tester) async {
    await _pumpWithCart(tester);
    await _attachDemoCustomer(tester);

    await _tapKey(tester, 'moneyKey2');
    expect(_displayed(tester), '2');

    // Full quick chip restores the total AND freshness.
    await tester.tap(find.textContaining('Full'));
    await tester.pump();
    expect(_displayed(tester), '150.00');

    await _tapKey(tester, 'moneyKey9');
    expect(_displayed(tester), '9');
  });
}
