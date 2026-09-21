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
// THE ADD MOMENT on the approved edit plane flow (35a chip 618 "+ New
// product" + section 35 decision-transfer item 2, tabs-become-panes; Ray
// 2026-08-29 15:41Z "approved: … 35a,35b,35c,35d,35e."): "add" rides
// ProductEditPlaneFlow with the CREATE bodies in the 35b panes — rail |
// details | stocks at three planes, details | stocks at two, the shipped
// segmented tabs at one — and the shipped create order survives the fold:
// stocks stay locked until the details save creates the product.

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

  const String hint = 'Save details first';

  /// The page's wiring for the add moment: no product on the rail, the
  /// stocks pane locked while `createdProduct` is null. [locked] is the
  /// live value the page reads off createFoodDetailsProvider.
  Widget host({
    required Size size,
    required ValueNotifier<bool> locked,
    void Function() onBack = _noop,
    void Function(Planes)? onRailPlanes,
    void Function(Planes)? onFormPlanes,
  }) => ScreenUtilInit(
    designSize: size,
    builder: (_, __) => MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: locked,
          builder: (context, isLocked, _) => ProductEditPlaneFlow(
            railBuilder: (context) {
              onRailPlanes?.call(Planes.of(context));
              return const Text('RAIL');
            },
            formBuilder: (context) {
              onFormPlanes?.call(Planes.of(context));
              return ProductFormSplit(
                header: const Text('New product'),
                detailsTitle: 'Details',
                stocksTitle: 'Stocks',
                stocksLocked: isLocked,
                stocksLockedHint: hint,
                detailsBuilder: (context) => const Text('CREATE-DETAILS'),
                stocksBuilder: (context) => const Text('CREATE-STOCKS'),
              );
            },
            onBack: onBack,
          ),
        ),
      ),
    ),
  );

  /// The IgnorePointer that fences the stocks body while locked.
  Finder stocksFence() => find.ancestor(
    of: find.text('CREATE-STOCKS'),
    matching: find.byWidgetPredicate(
      (w) => w is IgnorePointer && w.ignoring,
    ),
  );

  testWidgets(
      '1280 (three planes): add = rail | details | stocks — the rail keeps '
      'plane 1 with nothing to highlight, the form claims TWO, stocks locked '
      'under the hint until the product exists, then live', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final locked = ValueNotifier<bool>(true);
    Planes? railPlanes;
    Planes? formPlanes;
    await tester.pumpWidget(
      host(
        size: const Size(1280, 800),
        locked: locked,
        onRailPlanes: (p) => railPlanes = p,
        onFormPlanes: (p) => formPlanes = p,
      ),
    );
    expect(find.text('RAIL'), findsOneWidget);
    expect(railPlanes!.count, 3);
    expect(railPlanes!.index, 0);
    expect(railPlanes!.span, 1);
    expect(formPlanes!.index, 1);
    expect(formPlanes!.span, 2);
    expect(formPlanes!.isLast, isTrue);
    // Both panes at once, the create bodies inside.
    expect(find.text('New product'), findsOneWidget);
    expect(find.text('CREATE-DETAILS'), findsOneWidget);
    expect(find.text('CREATE-STOCKS'), findsOneWidget);
    // The shipped order: stocks wait for the details save.
    expect(find.text(hint), findsOneWidget);
    expect(stocksFence(), findsOneWidget);
    // A pushed page holds planes: the corner pill.
    expect(find.byType(FloatingBackPill), findsOneWidget);

    // The details save created the product — the lock lifts in place.
    locked.value = false;
    await tester.pump();
    expect(find.text(hint), findsNothing);
    expect(stocksFence(), findsNothing);
    expect(find.text('CREATE-STOCKS'), findsOneWidget);
    expect(find.text('CREATE-DETAILS'), findsOneWidget);
  });

  testWidgets(
      '800 (two planes): the rail yields entirely — details | stocks fill '
      'the fold, stocks locked under the hint, pill present', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final locked = ValueNotifier<bool>(true);
    Planes? formPlanes;
    await tester.pumpWidget(
      host(
        size: const Size(800, 1280),
        locked: locked,
        onFormPlanes: (p) => formPlanes = p,
      ),
    );
    expect(find.text('RAIL'), findsNothing);
    expect(formPlanes!.count, 2);
    expect(formPlanes!.index, 0);
    expect(formPlanes!.span, 2);
    expect(find.text('CREATE-DETAILS'), findsOneWidget);
    expect(find.text('CREATE-STOCKS'), findsOneWidget);
    expect(find.text(hint), findsOneWidget);
    expect(stocksFence(), findsOneWidget);
    expect(find.byType(FloatingBackPill), findsOneWidget);

    locked.value = false;
    await tester.pump();
    expect(find.text(hint), findsNothing);
    expect(stocksFence(), findsNothing);
  });

  testWidgets(
      '393 (one plane): the panes fold to the shipped segmented tabs; the '
      'Stocks tab cannot be selected while locked, and the form hops to '
      'Stocks when the lock lifts (the shipped onSave hop)', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final locked = ValueNotifier<bool>(true);
    bool popped = false;
    await tester.pumpWidget(
      host(
        size: const Size(393, 852),
        locked: locked,
        onBack: () => popped = true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('RAIL'), findsNothing);
    expect(find.text('CREATE-DETAILS'), findsOneWidget);
    expect(find.text('CREATE-STOCKS'), findsNothing);

    // The shipped modal's IgnorePointer tab bar: Stocks is inert.
    await tester.tap(find.text('Stocks'));
    await tester.pumpAndSettle();
    expect(find.text('CREATE-DETAILS'), findsOneWidget);
    expect(find.text('CREATE-STOCKS'), findsNothing);

    // Details saved: the shipped hop to the Stocks tab.
    locked.value = false;
    await tester.pumpAndSettle();
    expect(find.text('CREATE-DETAILS'), findsNothing);
    expect(find.text('CREATE-STOCKS'), findsOneWidget);
    expect(find.text(hint), findsNothing);

    // And Details is still a tap away.
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('CREATE-DETAILS'), findsOneWidget);

    expect(find.byType(FloatingBackPill), findsOneWidget);
    await tester.tap(find.byType(FloatingBackPill));
    expect(popped, isTrue);
  });

  testWidgets('the edit moment is untouched: unlocked by default, no hint',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1280, 800),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: ProductEditPlaneFlow(
              railBuilder: (context) => const Text('RAIL'),
              formBuilder: (context) => ProductFormSplit(
                detailsTitle: 'Details',
                stocksTitle: 'Stocks',
                detailsBuilder: (context) => const Text('EDIT-DETAILS'),
                stocksBuilder: (context) => const Text('EDIT-STOCKS'),
              ),
              onBack: _noop,
            ),
          ),
        ),
      ),
    );
    expect(find.text('EDIT-STOCKS'), findsOneWidget);
    expect(stocksFence(), findsNothing);
    expect(find.byIcon(Icons.lock), findsNothing);
  });
}

void _noop() {}
