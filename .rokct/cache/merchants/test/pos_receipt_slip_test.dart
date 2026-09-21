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

// ReceiptSlip (design strip chip 322, approved frame 11k): the receipt as
// paper. Renders a fixture cart's lines and totals — exactly the data
// PosReceiptPrinter takes, plus the tender the checkout computes — in
// both modes (AppStyle.isDark is the fleet's mode flag: the paper stays
// paper, the surround follows the mode).

import 'package:base_sdk/src/models/data/currency_data.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchants_sdk/src/manager/presentation/pos/receipt_slip.dart';
import 'package:merchants_sdk/src/manager/utils/pos_receipt_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

final PosReceiptData _fixture = PosReceiptData(
  shopName: 'Corner Kitchen',
  orderId: 'pos-fixture-1',
  issuedAt: DateTime(2026, 8, 29, 13, 53),
  lines: const [
    PosReceiptLine(
      title: 'Loose Tomatoes (kg)',
      quantity: 0.75,
      lineTotal: 112.5,
    ),
    PosReceiptLine(
      title: 'Flame-grilled beef burger',
      quantity: 2,
      lineTotal: 300,
    ),
  ],
  total: 412.5,
  tender: const [
    PosReceiptTender(label: 'Cash', amount: 300),
    PosReceiptTender(label: 'On credit', amount: 112.5),
  ],
  customerName: 'Naledi M',
);

Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
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
  });

  final bool wasDark = AppStyle.isDark;
  tearDown(() => AppStyle.isDark = wasDark);

  for (final dark in [true, false]) {
    testWidgets(
      '${dark ? 'dark' : 'light'}: the slip prints the masthead, every '
      'line with QTY and line total, the TOTAL, the tender and the '
      'customer — and the date stamp',
      (tester) async {
        AppStyle.isDark = dark;
        await tester.pumpWidget(_host(ReceiptSlip(receipt: _fixture)));
        await tester.pump();

        // 323: the printed masthead.
        expect(find.text('CORNER KITCHEN'), findsOneWidget);
        expect(find.text('SALE RECEIPT'), findsOneWidget);
        // 324: the line rows — title, QTY as sold, formatted line total.
        expect(find.text('Loose Tomatoes (kg)'), findsOneWidget);
        expect(find.text('QTY 0.75'), findsOneWidget);
        expect(find.text('R112.50'), findsWidgets);
        expect(find.text('Flame-grilled beef burger'), findsOneWidget);
        expect(find.text('QTY 2'), findsOneWidget);
        expect(find.text('R300.00'), findsWidgets);
        // Items row (sum of quantities) and 326 TOTAL.
        expect(find.text('2.75'), findsOneWidget);
        expect(find.text('TOTAL'), findsOneWidget);
        expect(find.text('R412.50'), findsOneWidget);
        // The tender the checkout computed, and the attached customer.
        expect(find.text('PAID'), findsOneWidget);
        expect(find.text('Cash'), findsOneWidget);
        expect(find.text('On credit'), findsOneWidget);
        expect(find.text('Naledi M'), findsOneWidget);
        // The stamp and the order id.
        expect(find.text('2026-08-29 13:53'), findsOneWidget);
        expect(find.text('pos-fixture-1'), findsOneWidget);
        expect(find.text('Thank you'), findsOneWidget);
        // No delivery line unless send-for-delivery is on.
        expect(find.text('Delivery'), findsNothing);

        // Intrinsic width: the paper never stretches past its strip.
        final paper = tester.getSize(
        find
            .descendant(
              of: find.byType(ReceiptSlip),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
        expect(paper.width, lessThanOrEqualTo(ReceiptSlip.paperWidth + 0.5));
      },
    );
  }

  testWidgets(
    'send-for-delivery prints the delivery line with the address; the '
    'compact slip is the same paper, shorter',
    (tester) async {
      final delivery = PosReceiptData(
        shopName: _fixture.shopName,
        orderId: _fixture.orderId,
        issuedAt: _fixture.issuedAt,
        lines: _fixture.lines,
        total: _fixture.total,
        tender: _fixture.tender,
        customerName: _fixture.customerName,
        delivery: true,
        deliveryAddress: '12 Market Lane',
      );
      await tester.pumpWidget(_host(ReceiptSlip(receipt: delivery)));
      await tester.pump();
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('12 Market Lane'), findsOneWidget);
      final full = tester.getSize(find.byType(ReceiptSlip));

      await tester.pumpWidget(
        _host(ReceiptSlip(receipt: delivery, compact: true)),
      );
      await tester.pump();
      expect(find.text('R412.50'), findsOneWidget);
      final compact = tester.getSize(find.byType(ReceiptSlip));
      expect(compact.height, lessThan(full.height));
    },
  );
}
