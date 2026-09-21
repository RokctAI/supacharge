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

// BaseWalletCard's balance rule: a zero or absent wallet balance hides
// the amount entirely (the card keeps its title, arrow and actions); a
// positive balance renders in AppStyle.green; a negative one in
// AppStyle.red. Exercised through the `wallet` snapshot seam so the
// live profileProvider (and its DI-backed repositories) is never built.

import 'package:base_sdk/base_sdk.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  // ProviderScope because the card is a ConsumerWidget (the provider
  // itself is never watched when `wallet` is supplied); ScreenUtilInit
  // mirrors the real app root, same as app_usage_badge_test.
  return ProviderScope(
    child: ScreenUtilInit(
      designSize: const Size(800, 600),
      builder: (context, _) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  final walletLabel = AppHelpers.getTranslation(TrKeys.wallet);

  // Same formatting call the widget makes (symbol passthrough with
  // isOrder: true), so the expectation tracks AppHelpers.numberFormat
  // instead of hardcoding a currency rendering.
  String fmt(num n) =>
      AppHelpers.numberFormat(number: n, symbol: 'R', isOrder: true);

  group('BaseWalletCard balance rule', () {
    testWidgets('zero balance hides the amount but keeps the card',
        (tester) async {
      var historyTapped = false;
      await tester.pumpWidget(_host(BaseWalletCard(
        wallet: Wallet(price: 0),
        symbol: 'R',
        onHistory: () => historyTapped = true,
        actions: const [Text('TOP UP')],
      )));
      await tester.pumpAndSettle();

      // No amount, no "label: " prefix — just the bare label.
      expect(find.text(fmt(0)), findsNothing);
      expect(find.text('$walletLabel: '), findsNothing);
      expect(find.text(walletLabel), findsOneWidget);

      // Card chrome stays useful: actions render, arrow still works.
      expect(find.text('TOP UP'), findsOneWidget);
      await tester.tap(find.byType(GestureDetector).first);
      expect(historyTapped, isTrue);
    });

    testWidgets('absent balance (null price / null wallet) also hides',
        (tester) async {
      await tester.pumpWidget(_host(BaseWalletCard(
        wallet: Wallet(price: null),
        symbol: 'R',
      )));
      await tester.pumpAndSettle();

      expect(find.text('$walletLabel: '), findsNothing);
      expect(find.text(walletLabel), findsOneWidget);
    });

    testWidgets('positive balance renders the amount in AppStyle.green',
        (tester) async {
      await tester.pumpWidget(_host(BaseWalletCard(
        wallet: Wallet(price: 1250.5),
        symbol: 'R',
      )));
      await tester.pumpAndSettle();

      expect(find.text('$walletLabel: '), findsOneWidget);
      final amount = tester.widget<Text>(find.text(fmt(1250.5)));
      expect(amount.style?.color, AppStyle.green);
    });

    testWidgets('negative balance renders the amount in AppStyle.red',
        (tester) async {
      await tester.pumpWidget(_host(BaseWalletCard(
        wallet: Wallet(price: -75),
        symbol: 'R',
      )));
      await tester.pumpAndSettle();

      final amount = tester.widget<Text>(find.text(fmt(-75)));
      expect(amount.style?.color, AppStyle.red);
    });
  });
}
