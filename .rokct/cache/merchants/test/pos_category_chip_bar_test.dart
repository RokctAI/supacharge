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

// The Add Items pane's category chip bar - approved design strip frame
// 11m, chip 349 ("a horizontal pill row (All / ...) in the dark till
// tokens"), pumped DIRECTLY from templates/ like the other POS tests
// (run with --dart-define=IS_DEMO=true; the demo catalog seeds Mains /
// Sides / Drinks with the burger in Mains):
//
//   * 1280 (three planes): the pane shows the bar under the search field
//     - All first, active, then the demo shop's categories; a tapped
//     chip with nothing typed lists its category (Mains -> the burger,
//     Sides -> no rows) and narrows a typed query the same way; All
//     clears the rows again with nothing typed;
//   * 393 (phone): no bar on the page, and none in the Add Items sheet
//     (11j stays 316-321);
//   * Clear All keeps the categories and the tapped chip (catalog
//     browsing state is not cart state).

import 'package:base_sdk/src/models/data/currency_data.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:merchants_sdk/src/manager/application/pos_cart/pos_cart_provider.dart';
import 'package:merchants_sdk/src/manager/di/manager_merchants_di.dart';
import 'package:merchants_sdk/src/manager/infrastructure/repositories/mock_products_repository.dart';
import 'package:merchants_sdk/src/manager/presentation/pos/pos_category_chip_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../templates/pages/manager/billing/billing_page.dart';

const _barKey = Key('posCategoryChipBar');
const _paneKey = Key('posAddItemsPane');
const _laneKey = Key('posAddItemsLane');
const _fieldKey = Key('posAddItemsSearchField');
const _burger = 'Flame-grilled beef burger';

Widget _host(Size size) => ProviderScope(
  child: ScreenUtilInit(
    designSize: size,
    builder: (context, _) => const MaterialApp(home: BillingPage()),
  ),
);

Future<ProviderContainer> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(size));
  // The pane's initState asks the demo catalog for the categories; the
  // answer lands on the next frame.
  await tester.pump();
  await tester.pump();
  final element = tester.element(find.byType(BillingPage));
  return ProviderScope.containerOf(element, listen: false);
}

/// A chip tap: the pane re-runs the query and the demo answer lands.
Future<void> _tapChip(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pump();
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

  testWidgets('1280 (three planes): the pane draws the bar - All first and '
      'active, then Mains / Sides / Drinks - and a chip filters the rows', (
    tester,
  ) async {
    final container = await _pump(tester, const Size(1280, 800));

    expect(find.byKey(_paneKey), findsOneWidget);
    expect(find.byKey(_barKey), findsOneWidget);
    expect(container.read(posCartProvider).categories.map((c) => c.id), [
      '1',
      '2',
      '3',
    ]);
    // All first, then the demo shop's categories, left to right.
    final chips = [
      PosCategoryChipBar.allChipKey,
      PosCategoryChipBar.chipKey('1'),
      PosCategoryChipBar.chipKey('2'),
      PosCategoryChipBar.chipKey('3'),
    ];
    for (final key in chips) {
      expect(find.byKey(key), findsOneWidget);
    }
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Mains'), findsOneWidget);
    expect(find.text('Sides'), findsOneWidget);
    expect(find.text('Drinks'), findsOneWidget);
    double left(Key key) => tester.getTopLeft(find.byKey(key)).dx;
    expect(left(chips[0]), lessThan(left(chips[1])));
    expect(left(chips[1]), lessThan(left(chips[2])));
    expect(left(chips[2]), lessThan(left(chips[3])));
    // All is the active chip: nothing tapped, nothing typed, no rows.
    expect(container.read(posCartProvider).categoryId, isNull);
    expect(find.text(_burger), findsNothing);

    // Mains with nothing typed lists the category: the burger.
    await _tapChip(tester, PosCategoryChipBar.chipKey('1'));
    expect(container.read(posCartProvider).categoryId, '1');
    expect(find.text(_burger), findsOneWidget);

    // Sides: the burger is not a side.
    await _tapChip(tester, PosCategoryChipBar.chipKey('2'));
    expect(container.read(posCartProvider).categoryId, '2');
    expect(find.text(_burger), findsNothing);

    // A typed query under Sides stays narrowed; under All it widens.
    await tester.enterText(find.byKey(_fieldKey), 'burger');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text(_burger), findsNothing);
    await _tapChip(tester, PosCategoryChipBar.allChipKey);
    expect(container.read(posCartProvider).categoryId, isNull);
    expect(container.read(posCartProvider).query, 'burger');
    expect(find.text(_burger), findsOneWidget);

    // Nothing typed + All = no rows, as an emptied field always was.
    await tester.enterText(find.byKey(_fieldKey), '');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text(_burger), findsNothing);
  });

  testWidgets(
    'Clear All keeps the categories and the tapped chip - the bar never '
    'blinks out between customers',
    (tester) async {
      final container = await _pump(tester, const Size(1280, 800));
      await _tapChip(tester, PosCategoryChipBar.chipKey('3'));
      await container.read(posCartProvider.notifier).addByBarcode('600123');
      await tester.pump();
      expect(find.text('Clear all'), findsOneWidget);

      await tester.tap(find.text('Clear all'));
      await tester.pump();

      final state = container.read(posCartProvider);
      expect(state.lines, isEmpty);
      expect(
        state.categories.length,
        MockProductsRepository.demoCategories.length,
      );
      expect(state.categoryId, '3');
      expect(find.byKey(_barKey), findsOneWidget);
      expect(find.text('Drinks'), findsOneWidget);
    },
  );

  testWidgets(
    '393 (phone): no bar on the page and none in the Add Items sheet',
    (tester) async {
      final container = await _pump(tester, const Size(393, 852));
      expect(find.byKey(_paneKey), findsNothing);
      expect(find.byKey(_barKey), findsNothing);
      // A phone never asks for the categories: the sheet has no bar.
      expect(container.read(posCartProvider).categories, isEmpty);

      await tester.tap(find.byKey(_laneKey));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(_fieldKey), findsOneWidget);
      expect(find.byKey(_barKey), findsNothing);
      expect(find.byType(PosCategoryChipBar), findsNothing);
    },
  );

  testWidgets('no categories: the bar draws nothing at all', (tester) async {
    tester.view.physicalSize = const Size(600, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(600, 400),
        builder: (context, _) => MaterialApp(
          home: Scaffold(
            body: PosCategoryChipBar(
              categories: const [],
              selectedId: null,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(PosCategoryChipBar.allChipKey), findsNothing);
    expect(find.text('All'), findsNothing);
  });
}
