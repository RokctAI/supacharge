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

// The catalog header at the two-plane fold (tablet store review
// 2026-09-02, still 10-menu): the tour's tablet leg is 800 logical wide =
// two planes of 393, and the 35a header row painted "OVERFLOWED BY 234
// PIXELS" stripes inside plane 1. The header now lays out by the planes
// the catalog holds: the approved single row when it holds two or more,
// the same elements on two rows when it holds one plane of a multi-plane
// screen. Every element stays; nothing overflows.

import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:products_sdk/src/common/infrastructure/models/data/seller_product_data.dart';
import 'package:products_sdk/src/manager/presentation/catalog/catalog_header.dart';
import 'package:products_sdk/src/manager/presentation/catalog/catalog_plane_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  const tabs = [
    CatalogTab(label: 'Foods', count: 46),
    CatalogTab(label: 'Add-ons', count: 12),
    CatalogTab(label: 'Extras', count: 5),
  ];

  Widget header() => CatalogHeader(
        title: 'Products',
        tabs: tabs,
        activeTab: 0,
        onSelectTab: (_) {},
        attention: 3,
        onStock: () {},
        stockLabel: 'Stock',
        onNew: () {},
        newLabel: 'New product',
      );

  /// The catalog flow exactly as foods_page.dart hosts it: the header at
  /// the top of the catalog plane, a product selected so the detail holds
  /// the last plane. [width] is the window; the catalog plane is
  /// (width - 14) / 2 at two planes.
  Widget host({required double width, SellerProductData? selected}) =>
      ScreenUtilInit(
        designSize: Size(width, 1280),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: CatalogPlaneFlow(
              selectedProduct: selected,
              quickAdjustOpen: false,
              catalogBuilder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [header(), const Expanded(child: SizedBox())],
              ),
              detailBuilder: (context, product) => const Text('DETAIL'),
              quickAdjustBuilder: (context) => const Text('QUICK'),
              onPop: () {},
            ),
          ),
        ),
      );

  Future<void> pumpAt(WidgetTester tester, double width,
      {SellerProductData? selected}) async {
    tester.view.physicalSize = Size(width, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(width: width, selected: selected));
    await tester.pump();
  }

  void expectEveryElement() {
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Foods'), findsOneWidget);
    expect(find.text('Add-ons'), findsOneWidget);
    expect(find.text('Extras'), findsOneWidget);
    expect(find.text('46'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  }

  testWidgets(
      'two-plane fold: the header holds a 393 px plane with no overflow '
      'and every element present', (tester) async {
    // 800 logical = the tour tablet leg = two planes of (800 - 14) / 2 =
    // 393; the selected product takes plane 2, the catalog keeps plane 1.
    await pumpAt(tester, 800, selected: SellerProductData(id: 'p1'));

    // No RenderFlex overflow was reported while laying out the header.
    expect(tester.takeException(), isNull);
    expectEveryElement();
    expect(find.text('New product'), findsNothing,
        reason: 'the fold row carries the compact create action');

    // Plane 1 is exactly 393 wide and everything the header paints stays
    // inside it — to the left of the detail plane's seam.
    final planeRight = tester.getTopLeft(find.text('DETAIL')).dx - 14;
    expect(planeRight, closeTo(393, 0.5));
    for (final text in ['Products', 'Foods', 'Add-ons', 'Extras', '5']) {
      final rect = tester.getRect(find.text(text));
      expect(rect.right, lessThanOrEqualTo(planeRight),
          reason: '"$text" must stay inside the 393 px catalog plane');
      expect(rect.left, greaterThanOrEqualTo(0));
    }
    // The compact actions sit on the title row; the tab pill folded
    // beneath it.
    final title = tester.getRect(find.text('Products'));
    final foods = tester.getRect(find.text('Foods'));
    expect(foods.top, greaterThanOrEqualTo(title.bottom));
  });

  testWidgets(
      'three planes (35a): the catalog holds two planes and keeps the '
      'approved single row, labelled actions, no overflow', (tester) async {
    await pumpAt(tester, 1280, selected: SellerProductData(id: 'p1'));
    expect(tester.takeException(), isNull);
    expectEveryElement();
    expect(find.text('New product'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    // One row: the tabs share the title's baseline band.
    final title = tester.getRect(find.text('Products'));
    final foods = tester.getRect(find.text('Foods'));
    expect(foods.top, lessThan(title.bottom));
  });

  testWidgets(
      'two planes with no selection: the catalog spreads over both and '
      'keeps the single row', (tester) async {
    await pumpAt(tester, 800);
    expect(tester.takeException(), isNull);
    expectEveryElement();
    expect(find.text('New product'), findsOneWidget);
  });

  testWidgets('one plane (phone): the shipped compact header, no inner tabs',
      (tester) async {
    await pumpAt(tester, 390);
    expect(tester.takeException(), isNull);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Foods'), findsNothing);
    expect(find.text('New product'), findsNothing);
  });

  testWidgets('tab taps and actions fire through the header',
      (tester) async {
    int? selected;
    var stock = 0;
    var created = 0;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1280, 800),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: PlaneHost(
              stack: [
                PlanePage(
                  name: 'catalog',
                  span: PlaneSpan.all,
                  builder: (_) => CatalogHeader(
                    title: 'Products',
                    tabs: tabs,
                    activeTab: 0,
                    onSelectTab: (i) => selected = i,
                    attention: 0,
                    onStock: () => stock++,
                    stockLabel: 'Stock',
                    onNew: () => created++,
                    newLabel: 'New product',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Extras'));
    expect(selected, 2);
    await tester.tap(find.text('Stock'));
    expect(stock, 1);
    await tester.tap(find.text('New product'));
    expect(created, 1);
  });
}
