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

// KEYPAD AUTODIAL on the till (approved design strip section 42, frame
// 42c): while there is NOTHING on the ticket, a digit key is the item the
// shop mapped to it; the moment an item is on, the keys are money again.
//
// The point of these cases is the SEAM: base_sdk's MoneyKeypad (chip 390)
// is the same pure input surface it always was — it emits 'moneyKey3' and
// the TILL decides what that press means. So every case here drives the
// real shared keypad and asserts on the cart, never on a keypad variant.
//
// Pumped directly from templates/ (the analyzer excludes templates/, so
// this test is part of checkout_page.dart's compile gate). RUN WITH
// `flutter test --dart-define=IS_DEMO=true`: the demo Quick flow
// repository serves the section-42 seed shop (autodial on, keys 1-5 set).

import 'package:base_sdk/src/models/data/currency_data.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:merchants_sdk/src/manager/application/pos_cart/pos_cart_provider.dart';
import 'package:merchants_sdk/src/manager/application/quick_flow/quick_flow_provider.dart';
import 'package:merchants_sdk/src/manager/di/manager_merchants_di.dart';
import 'package:merchants_sdk/src/manager/utils/pos_connectivity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../templates/pages/manager/billing/checkout_page.dart';

Widget _host(Widget child) => ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(home: child),
      ),
    );

late ProviderContainer _container;

Future<void> _pumpEmptyTill(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 12600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_host(const CheckoutPage()));
  final element = tester.element(find.byType(CheckoutPage));
  _container = ProviderScope.containerOf(element, listen: false);
  // The till reads the shop's arming state once, on its first frame.
  await _container.read(quickFlowProvider.notifier).load();
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String keyId) async {
  await tester.tap(find.byKey(Key(keyId)), warnIfMissed: false);
  await tester.pump();
}

Future<void> _attachDemoCustomer(WidgetTester tester) async {
  await tester.tap(find.text('Add customer'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Thabo Mokoena'));
  await tester.pumpAndSettle();
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
    PosConnectivity.debugConnectivityOverride = true;
  });

  tearDownAll(() {
    PosConnectivity.debugConnectivityOverride = null;
  });

  testWidgets('an empty ticket arms the pad and says the rule once',
      (tester) async {
    await _pumpEmptyTill(tester);
    _container.read(posCartProvider.notifier).clearAll();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('tap a digit to drop its preset'),
      findsOneWidget,
    );
    // Chip 806: the armed keys print their preset UNDER the numeral;
    // unset keys carry nothing, and `00` / `0` / backspace never do.
    expect(find.text('5 L refill'), findsOneWidget);
    expect(find.text('20 L refill'), findsOneWidget);
    expect(find.text('Ice · 2 kg'), findsOneWidget);
    // The pad itself is the shared component, unchanged.
    expect(find.byKey(const Key('moneyKey3')), findsOneWidget);
    expect(find.byKey(const Key('moneyKeyBackspace')), findsOneWidget);
  });

  testWidgets('a digit key drops its preset straight on the ticket',
      (tester) async {
    await _pumpEmptyTill(tester);
    _container.read(posCartProvider.notifier).clearAll();
    await tester.pumpAndSettle();
    expect(_container.read(posCartProvider).isEmpty, isTrue);

    await _tapKey(tester, 'moneyKey3');
    await tester.pumpAndSettle();

    final cart = _container.read(posCartProvider);
    expect(cart.lines.length, 1);
    expect(cart.lines.single.title, '20 L refill');
    expect(cart.lines.single.quantity, 1);
    expect(cart.total, 35);
  });

  testWidgets('once an item is on, the arming strip goes with the rule',
      (tester) async {
    await _pumpEmptyTill(tester);
    _container.read(posCartProvider.notifier).clearAll();
    await tester.pumpAndSettle();

    await _tapKey(tester, 'moneyKey3');
    await tester.pumpAndSettle();
    // The hint strip is the VISIBLE FORM of the arming condition, so it
    // leaves exactly when the condition does.
    expect(find.textContaining('tap a digit to drop its preset'), findsNothing);
    // Chip 808: the strip says what landed, and that the pad has changed
    // meaning.
    expect(find.text('20 L refill'), findsOneWidget);
    expect(find.textContaining('the keys are money again'), findsOneWidget);
  });

  testWidgets('with a customer attached the keys really are money again',
      (tester) async {
    await _pumpEmptyTill(tester);
    _container.read(posCartProvider.notifier).clearAll();
    await tester.pumpAndSettle();
    await _attachDemoCustomer(tester);

    // Armed: the money card yields, so there is never a second keypad on
    // the page — the armed pad IS the pad.
    expect(find.byKey(const Key('posPaidNowField')), findsNothing);
    expect(find.byKey(const Key('moneyKey3')), findsOneWidget);

    await _tapKey(tester, 'moneyKey3');
    await tester.pumpAndSettle();
    expect(_container.read(posCartProvider).lines.single.title, '20 L refill');

    // Now the same shared component types MONEY: key 5 must not put
    // "Ice · 2 kg" on the ticket.
    expect(find.byKey(const Key('posPaidNowField')), findsOneWidget);
    await _tapKey(tester, 'moneyKey5');
    await tester.pumpAndSettle();
    expect(_container.read(posCartProvider).lines.length, 1);
    expect(_displayed(tester), '5');
  });

  testWidgets('an unset digit is inert, not an error', (tester) async {
    await _pumpEmptyTill(tester);
    _container.read(posCartProvider.notifier).clearAll();
    await tester.pumpAndSettle();
    // Keys 6-9 hold nothing in the seed shop.
    await _tapKey(tester, 'moneyKey7');
    await tester.pumpAndSettle();
    expect(_container.read(posCartProvider).isEmpty, isTrue);
    // Still armed, still saying so.
    expect(
      find.textContaining('tap a digit to drop its preset'),
      findsOneWidget,
    );
  });


  testWidgets('a shop with autodial off never sees the pad', (tester) async {
    await _pumpEmptyTill(tester);
    _container.read(posCartProvider.notifier).clearAll();
    await _container.read(quickFlowProvider.notifier).setKeypadAutodial(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('tap a digit to drop its preset'), findsNothing);
    expect(find.text('20 L refill'), findsNothing);
    // Restore for any later case in this file.
    await _container.read(quickFlowProvider.notifier).setKeypadAutodial(true);
  });
}
