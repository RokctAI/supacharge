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
// The approved edit plane behaviour (35b: the form declares TWO — rail |
// details | stocks at three planes, the origin catalog keeping plane 1;
// 35d: one plane folds the panes back into the shipped segmented tabs)
// and the corner back pill at every width (the pushed route IS the
// 12:36Z nav fold).

import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:products_sdk/src/manager/presentation/catalog/edit_plane_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  Widget host({
    required Size size,
    required void Function() onBack,
    void Function(Planes)? onRailPlanes,
    void Function(Planes)? onFormPlanes,
  }) => ScreenUtilInit(
    designSize: size,
    builder: (_, __) => MaterialApp(
      home: Scaffold(
        body: ProductEditPlaneFlow(
          railBuilder: (context) {
            onRailPlanes?.call(Planes.of(context));
            return const Text('RAIL');
          },
          formBuilder: (context) {
            onFormPlanes?.call(Planes.of(context));
            return ProductFormSplit(
              detailsTitle: 'Details',
              stocksTitle: 'Stocks',
              detailsBuilder: (context) => const Text('DETAILS-FORM'),
              stocksBuilder: (context) => const Text('STOCKS-FORM'),
            );
          },
          onBack: onBack,
        ),
      ),
    ),
  );

  testWidgets(
      '35b: three planes — the form claims TWO (details | stocks side by '
      'side), the origin rail keeps plane 1, and the corner pill shows',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Planes? railPlanes;
    Planes? formPlanes;
    await tester.pumpWidget(
      host(
        size: const Size(1280, 800),
        onBack: () {},
        onRailPlanes: (p) => railPlanes = p,
        onFormPlanes: (p) => formPlanes = p,
      ),
    );
    expect(find.text('RAIL'), findsOneWidget);
    expect(railPlanes!.count, 3);
    expect(railPlanes!.span, 1);
    expect(railPlanes!.index, 0);
    expect(formPlanes!.span, 2);
    expect(formPlanes!.isLast, isTrue);
    // Both sections visible at once — the tabs-become-panes fold.
    expect(find.text('DETAILS-FORM'), findsOneWidget);
    expect(find.text('STOCKS-FORM'), findsOneWidget);
    // A pushed page holds planes: the nav is folded to the corner pill.
    expect(find.byType(FloatingBackPill), findsOneWidget);
  });

  testWidgets(
      '35b at two planes: the rail yields entirely — details | stocks',
      (tester) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Planes? formPlanes;
    await tester.pumpWidget(
      host(
        size: const Size(700, 800),
        onBack: () {},
        onFormPlanes: (p) => formPlanes = p,
      ),
    );
    expect(find.text('RAIL'), findsNothing);
    expect(formPlanes!.count, 2);
    expect(formPlanes!.span, 2);
    expect(find.text('DETAILS-FORM'), findsOneWidget);
    expect(find.text('STOCKS-FORM'), findsOneWidget);
    expect(find.byType(FloatingBackPill), findsOneWidget);
  });

  testWidgets(
      '35d: one plane — the panes fold back into the shipped segmented '
      'tabs (Details first, Stocks on tap) and the pill pops the route',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    bool popped = false;
    await tester.pumpWidget(
      host(size: const Size(393, 852), onBack: () => popped = true),
    );
    await tester.pumpAndSettle();
    expect(find.text('RAIL'), findsNothing);
    // Tabs, not panes: only the active section renders.
    expect(find.text('DETAILS-FORM'), findsOneWidget);
    expect(find.text('STOCKS-FORM'), findsNothing);

    await tester.tap(find.text('Stocks'));
    await tester.pumpAndSettle();
    expect(find.text('DETAILS-FORM'), findsNothing);
    expect(find.text('STOCKS-FORM'), findsOneWidget);

    expect(find.byType(FloatingBackPill), findsOneWidget);
    await tester.tap(find.byType(FloatingBackPill));
    expect(popped, isTrue);
  });
}
