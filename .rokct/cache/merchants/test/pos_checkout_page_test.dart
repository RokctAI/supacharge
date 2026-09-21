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


// CheckoutPage (the POS checkout template) pumped DIRECTLY from
// templates/ (no ${package} imports by design — these tests are the
// template's compile gate; run with --dart-define=IS_DEMO=true).
//
// Covers the approved flows (strip frames 11c–11f): the Cash | QR method
// toggle with the QR card and online phase gate; the OFFLINE INVERSION
// (banner + straight-to-code entry, gate absent, QR still up) with the
// 6-digit code verified locally; and the dual finish — atomic
// print-then-record vs finish-without-receipt. PosConnectivity's
// debugConnectivityOverride seam pins each flow.

import 'package:base_sdk/src/models/data/currency_data.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:merchants_sdk/src/manager/application/pos_cart/pos_cart_provider.dart';
import 'package:merchants_sdk/src/manager/di/manager_merchants_di.dart';
import 'package:merchants_sdk/src/manager/presentation/pos/receipt_preview_page.dart';
import 'package:merchants_sdk/src/manager/presentation/pos/receipt_slip.dart';
import 'package:merchants_sdk/src/manager/utils/pos_connectivity.dart';
import 'package:merchants_sdk/src/manager/utils/pos_pay_verification.dart';
import 'package:merchants_sdk/src/manager/utils/pos_receipt_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../templates/pages/manager/billing/checkout_page.dart';

Widget _host(Widget child) => ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(home: child),
      ),
    );

Future<ProviderContainer> _pumpWithCart(WidgetTester tester) async {
  // The render harness's geometry: 390 logical at 3x dpr, on the tall
  // canvas the approved checkout frames used (11e/11f are 390x1420), so
  // the whole flow - QR, code entry, both finish buttons - is laid out
  // without scrolling.
  tester.view.physicalSize = const Size(1170, 4260);
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

  tearDown(() {
    PosConnectivity.debugConnectivityOverride = null;
    PosReceiptPrinter.handler = null;
  });

  testWidgets(
      'online: the Cash | QR toggle drives the QR card and the '
      '"I\'ve Scanned" phase gate', (tester) async {
    PosConnectivity.debugConnectivityOverride = true;
    await _pumpWithCart(tester);

    // QR is the default method: pay-link QR card + phase gate up, no
    // offline banner, no code entry yet.
    expect(find.byKey(const Key('posPayQrCard')), findsOneWidget);
    expect(find.textContaining("I've Scanned"), findsOneWidget);
    expect(find.textContaining('Till offline'), findsNothing);
    expect(find.textContaining('Confirm by Code'), findsNothing);

    // The summary carries the formatted total.
    expect(find.text('R150.00'), findsWidgets);

    // Cash hides the whole QR flow.
    await tester.tap(find.text('Cash'));
    await tester.pump();
    expect(find.byKey(const Key('posPayQrCard')), findsNothing);
    expect(find.textContaining("I've Scanned"), findsNothing);

    // Back to QR: the gate returns; passing it reveals the code entry
    // (the customer's payment screen now shows the code).
    await tester.tap(find.textContaining('QR / Pay link'));
    await tester.pump();
    await tester.tap(find.textContaining("I've Scanned"));
    await tester.pump();
    expect(find.textContaining('Confirm by Code'), findsOneWidget);
  });

  testWidgets(
      'OFFLINE INVERSION: banner + straight-to-code entry (no phase '
      'gate), the QR stays, and the 6-digit code verifies locally',
      (tester) async {
    PosConnectivity.debugConnectivityOverride = false;
    final container = await _pumpWithCart(tester);

    // Banner up, code entry immediate, gate gone — and the QR card STAYS
    // (the customer's phone is online even when the till is not).
    expect(find.textContaining('Till offline'), findsOneWidget);
    expect(find.textContaining('Confirm by Code'), findsOneWidget);
    expect(find.textContaining("I've Scanned"), findsNothing);
    expect(find.byKey(const Key('posPayQrCard')), findsOneWidget);

    // The right code — derived from the SAME stable order id and total
    // the page shows — verifies with zero server contact.
    final state = container.read(posCartProvider);
    final shopId = (LocalStorage.getShopJson()?['id'])?.toString() ?? '';
    final secret =
        (LocalStorage.getShopJson()?['uuid'])?.toString() ?? shopId;
    final good = PosPayVerification.code(
      orderId: state.orderId,
      amount: state.total,
      shopId: shopId,
      sharedSecret: secret,
    );

    final codeField = find.byType(TextField);
    await tester.enterText(codeField, '000001' == good ? '000002' : '000001');
    await tester.pump();
    expect(find.textContaining("doesn't match"), findsOneWidget);
    expect(find.text('Payment confirmed'), findsNothing);

    await tester.enterText(codeField, good);
    await tester.pump();
    expect(find.text('Payment confirmed'), findsOneWidget);
    expect(find.textContaining("doesn't match"), findsNothing);
  });

  testWidgets(
      'dual finish (11k): "Print Receipt & Finish" lands on the receipt '
      'preview first — printing from there is atomic, a dead printer '
      'leaves the sale open on the preview; "Finish without Receipt" on '
      'the checkout completes it straight away', (tester) async {
    PosConnectivity.debugConnectivityOverride = true;
    final container = await _pumpWithCart(tester);
    expect(container.read(posCartProvider).lines, hasLength(1));
    // The phone column carries no live slip — 11k is the phone's receipt.
    expect(find.byType(ReceiptSlip), findsNothing);

    // 293 on the checkout prints NOTHING yet: it lands on the preview —
    // the paper slip with the same lines and total, the "Receipt" title,
    // and the dual finish beneath the paper.
    var printCalls = 0;
    PosReceiptPrinter.handler = (orderId, lines, total) async {
      printCalls++;
    };
    await tester.tap(find.text('Print Receipt & Finish'));
    await tester.pumpAndSettle();
    expect(printCalls, 0, reason: '11k: printing never fires blind');
    expect(find.byType(ReceiptPreviewPage), findsOneWidget);
    expect(find.byType(ReceiptSlip), findsOneWidget);
    expect(find.text('Receipt'), findsOneWidget);
    expect(find.text('Flame-grilled beef burger'), findsOneWidget);
    expect(find.text('QTY 1'), findsOneWidget);
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('R150.00'), findsWidgets);
    expect(container.read(posCartProvider).lines, hasLength(1));

    // A throwing printer: the sale must NOT be recorded (the retired
    // Spazafy checkout recorded first and silently ate the receipt) —
    // and the preview stays up for another try.
    PosReceiptPrinter.handler = (orderId, lines, total) async {
      throw StateError('printer offline');
    };
    await tester.tap(find.byKey(const Key('posReceiptPrintFinish')));
    await tester.pumpAndSettle();
    expect(container.read(posCartProvider).lines, hasLength(1),
        reason: 'atomic print+finish: failed print leaves the sale open');
    expect(find.byType(ReceiptPreviewPage), findsOneWidget);

    // A working printer receives the order and THEN the sale records;
    // the preview pops and the checkout leaves with it.
    String? printedOrder;
    double? printedTotal;
    int? printedLineCount;
    PosReceiptPrinter.handler = (orderId, lines, total) async {
      printedOrder = orderId;
      printedTotal = total;
      printedLineCount = lines.length;
    };
    final orderId = container.read(posCartProvider).orderId;
    await tester.tap(find.byKey(const Key('posReceiptPrintFinish')));
    await tester.pumpAndSettle();
    expect(printedOrder, orderId);
    expect(printedTotal, 150);
    expect(printedLineCount, 1);
    expect(container.read(posCartProvider).lines, isEmpty);
    expect(container.read(posCartProvider).total, 0);
    expect(find.byType(ReceiptPreviewPage), findsNothing);

    // Finish without Receipt on the checkout: no printing, no preview,
    // straight to done — the shipped behaviour stays reachable.
    printCalls = 0;
    PosReceiptPrinter.handler = (orderId, lines, total) async {
      printCalls++;
    };
    await container.read(posCartProvider.notifier).addByBarcode('600777');
    await tester.pump();
    await tester.tap(find.text('Finish without Receipt'));
    await tester.pumpAndSettle();
    expect(printCalls, 0);
    expect(find.byType(ReceiptPreviewPage), findsNothing);
    expect(container.read(posCartProvider).lines, isEmpty);
  });

  testWidgets(
      'the preview\'s "Finish without Receipt" (294) records without '
      'printing and pops back', (tester) async {
    PosConnectivity.debugConnectivityOverride = true;
    final container = await _pumpWithCart(tester);
    var printCalls = 0;
    PosReceiptPrinter.handler = (orderId, lines, total) async {
      printCalls++;
    };
    await tester.tap(find.text('Print Receipt & Finish'));
    await tester.pumpAndSettle();
    expect(find.byType(ReceiptPreviewPage), findsOneWidget);
    await tester.tap(find.byKey(const Key('posReceiptFinishWithout')));
    await tester.pumpAndSettle();
    expect(printCalls, 0);
    expect(container.read(posCartProvider).lines, isEmpty);
    expect(find.byType(ReceiptPreviewPage), findsNothing);
  });
}
