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
//
// The approved catalog plane behaviour (35a: the catalog declares ALL —
// grid over planes 1–2 with the read detail in the LAST plane, full nav
// (no corner pill) because the detail is a permanent pane; the pushed
// 35e quick-adjust pane DOES fold the nav to the pill per 12:36Z).

import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:products_sdk/src/common/infrastructure/models/data/seller_product_data.dart';
import 'package:products_sdk/src/manager/presentation/catalog/catalog_plane_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  final product = SellerProductData(id: 'prod-77');

  Widget host({
    required Size size,
    SellerProductData? selected,
    bool quickAdjustOpen = false,
    required void Function() onPop,
    void Function(Planes)? onCatalogPlanes,
    void Function(Planes)? onDetailPlanes,
  }) => ScreenUtilInit(
    designSize: size,
    builder: (_, __) => MaterialApp(
      home: Scaffold(
        body: CatalogPlaneFlow(
          selectedProduct: selected,
          quickAdjustOpen: quickAdjustOpen,
          catalogBuilder: (context) {
            onCatalogPlanes?.call(Planes.of(context));
            return const Text('CATALOG');
          },
          detailBuilder: (context, product) {
            onDetailPlanes?.call(Planes.of(context));
            return Text('DETAIL-${product.id}');
          },
          quickAdjustBuilder: (context) => const Text('QUICK-ADJUST'),
          onPop: onPop,
        ),
      ),
    ),
  );

  testWidgets('35a: at three planes the catalog alone still claims ALL',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Planes? catalogPlanes;
    await tester.pumpWidget(
      host(
        size: const Size(1280, 800),
        selected: null,
        onPop: () {},
        onCatalogPlanes: (p) => catalogPlanes = p,
      ),
    );
    expect(find.text('CATALOG'), findsOneWidget);
    expect(catalogPlanes!.count, 3);
    expect(catalogPlanes!.span, 3);
    expect(find.byType(FloatingBackPill), findsNothing);
  });

  testWidgets(
      '35a: a selected product takes the LAST plane, the catalog '
      'compresses onto TWO — and no corner pill (the read detail is a '
      'permanent pane, the full shell nav stays)', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Planes? catalogPlanes;
    Planes? detailPlanes;
    await tester.pumpWidget(
      host(
        size: const Size(1280, 800),
        selected: product,
        onPop: () {},
        onCatalogPlanes: (p) => catalogPlanes = p,
        onDetailPlanes: (p) => detailPlanes = p,
      ),
    );
    expect(find.text('CATALOG'), findsOneWidget);
    expect(find.text('DETAIL-prod-77'), findsOneWidget);
    expect(catalogPlanes!.count, 3);
    expect(catalogPlanes!.span, 2);
    expect(catalogPlanes!.index, 0);
    expect(detailPlanes!.span, 1);
    expect(detailPlanes!.index, 2);
    expect(detailPlanes!.isLast, isTrue);
    expect(find.byType(FloatingBackPill), findsNothing);
  });

  testWidgets('two-plane width: catalog | detail, one plane each',
      (tester) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Planes? catalogPlanes;
    Planes? detailPlanes;
    await tester.pumpWidget(
      host(
        size: const Size(700, 800),
        selected: product,
        onPop: () {},
        onCatalogPlanes: (p) => catalogPlanes = p,
        onDetailPlanes: (p) => detailPlanes = p,
      ),
    );
    expect(catalogPlanes!.count, 2);
    expect(catalogPlanes!.span, 1);
    expect(detailPlanes!.span, 1);
    expect(detailPlanes!.isLast, isTrue);
    expect(find.byType(FloatingBackPill), findsNothing);
  });

  testWidgets(
      '35e on wide: the quick-adjust pane REPLACES the detail as the '
      'pushed step and folds the nav to the corner pill; the pill pops it',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    bool popped = false;
    await tester.pumpWidget(
      host(
        size: const Size(1280, 800),
        selected: product,
        quickAdjustOpen: true,
        onPop: () => popped = true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('QUICK-ADJUST'), findsOneWidget);
    expect(find.text('DETAIL-prod-77'), findsNothing);
    expect(find.text('CATALOG'), findsOneWidget);
    expect(find.byType(FloatingBackPill), findsOneWidget);

    await tester.tap(find.byType(FloatingBackPill));
    expect(popped, isTrue);
  });

  testWidgets(
      '35c: phone — the flow hosts the catalog alone (selection pushes a '
      'REAL route outside the flow, the shipped tap-straight-to-edit)',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Planes? catalogPlanes;
    await tester.pumpWidget(
      host(
        size: const Size(393, 852),
        selected: null,
        onPop: () {},
        onCatalogPlanes: (p) => catalogPlanes = p,
      ),
    );
    expect(find.text('CATALOG'), findsOneWidget);
    expect(catalogPlanes!.count, 1);
    expect(catalogPlanes!.span, 1);
    expect(find.byType(FloatingBackPill), findsNothing);
  });
}
