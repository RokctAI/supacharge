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

// THE STANDARD LIST LANGUAGE (approved design strip section 38, Ray
// 2026-08-30 12:23Z: "33 list language = STANDARD for all lists"):
//
//   * the filter tab bar renders every tab with its count pill, marks
//     exactly one active in its own colour (chips 362/363), and reports
//     taps by index;
//   * View more · +N appears only while there is more to page (chip 356);
//   * a section-38 list DECLARES TWO planes, so at a three-plane width
//     the leftover plane TRAILS BARE rather than the list stretching
//     (frame 38b, Ray 10:47Z);
//   * a tapped row's detail takes the DEFAULT one-plane claim in the LAST
//     plane, the corner back pill folds it away, and back RESTORES the
//     list's full spread (frames 38a/38b, the 12:02Z sheet fork + the
//     12:36Z two-state nav rule);
//   * on a one-plane (phone) screen the columns collapse to one — the
//     mechanism disappears by construction (frame 38d).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:base_sdk/src/presentation/components/lists/list_language.dart';
import 'package:base_sdk/src/presentation/components/lists/list_plane_flow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, Widget child, {Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: size ?? const Size(390, 844),
        builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pump();
  }

  group('362/363 — the filter tab bar', () {
    testWidgets('renders every tab with its count pill and reports taps by '
        'index', (tester) async {
      int? tapped;
      await pump(
        tester,
        ListFilterTabBar(
          activeIndex: 0,
          onSelect: (index) => tapped = index,
          tabs: const [
            ListFilterTab(label: 'Delivered', color: Colors.orange, count: 226),
            ListFilterTab(label: 'Cancelled', color: Colors.red, count: 21),
          ],
        ),
      );

      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('226'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      expect(find.byType(ListTabCountPill), findsNWidgets(2));

      await tester.tap(find.text('Cancelled'));
      expect(tapped, 1);
    });

    testWidgets('the ACTIVE tab alone wears its colour (363)', (tester) async {
      const active = Color(0xFFFF6600);
      await pump(
        tester,
        ListFilterTabBar(
          activeIndex: 1,
          onSelect: (_) {},
          tabs: const [
            ListFilterTab(label: 'All', color: Colors.blue, count: 12),
            ListFilterTab(label: 'Unread', color: active, count: 3),
          ],
        ),
      );

      Border borderOf(String label) {
        final container = tester.widget<Container>(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(Container),
              )
              .last,
        );
        return (container.decoration! as BoxDecoration).border! as Border;
      }

      expect(borderOf('Unread').top.color, active);
      expect(borderOf('All').top.color, isNot(Colors.blue));
    });

    testWidgets('a tab with no count draws no pill', (tester) async {
      await pump(
        tester,
        ListFilterTabBar(
          activeIndex: 0,
          onSelect: (_) {},
          tabs: const [ListFilterTab(label: 'All', color: Colors.blue)],
        ),
      );
      expect(find.byType(ListTabCountPill), findsNothing);
    });
  });

  group('356 — View more · +N', () {
    testWidgets('shows the remainder and pages on tap', (tester) async {
      var pages = 0;
      await pump(
        tester,
        ListViewMore(
          moreCount: 241,
          label: 'View more',
          onTap: () => pages++,
        ),
      );
      expect(find.textContaining('241'), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      expect(pages, 1);
    });

    testWidgets('vanishes once nothing is left to page', (tester) async {
      await pump(
        tester,
        ListViewMore(moreCount: 0, label: 'View more', onTap: () {}),
      );
      expect(find.textContaining('View more'), findsNothing);
    });
  });

  group('700 — the header count pill', () {
    testWidgets('is the standard slot beside the title', (tester) async {
      await pump(
        tester,
        const ListScreenHeader(
          title: 'Order history',
          countPill: ListCountPill(label: '247 orders'),
        ),
      );
      expect(find.text('Order history'), findsOneWidget);
      expect(find.text('247 orders'), findsOneWidget);
    });
  });

  group('the section-38 plane shape', () {
    testWidgets('the list declares TWO planes; at three the leftover plane '
        'trails BARE (38b)', (tester) async {
      Planes? listPlanes;
      await pump(
        tester,
        ListDetailFlow<String>(
          backIcon: Icons.arrow_back,
          detailNameOf: (open) => open,
          listBuilder: (context, flow) {
            listPlanes = Planes.of(context);
            return const Text('LIST');
          },
          detailBuilder: (context, open, flow) => Text('DETAIL-$open'),
        ),
        size: const Size(1280, 800),
      );

      expect(find.text('LIST'), findsOneWidget);
      expect(listPlanes!.count, 3);
      expect(listPlanes!.span, 2);
      expect(listPlanes!.index, 0);
      // Nothing pushed yet, so no back pill: the flow is at its root.
      expect(find.byType(FloatingBackPill), findsNothing);
    });

    testWidgets('a tapped row pushes the detail into the LAST plane with the '
        'DEFAULT one-plane claim; the corner pill pops it and back '
        'restores (38a)', (tester) async {
      Planes? listPlanes;
      Planes? detailPlanes;
      ListDetailFlowState<String>? flowState;

      await pump(
        tester,
        ListDetailFlow<String>(
          backIcon: Icons.arrow_back,
          detailNameOf: (open) => open,
          listBuilder: (context, flow) {
            flowState = flow;
            listPlanes = Planes.of(context);
            return const Text('LIST');
          },
          detailBuilder: (context, open, flow) {
            detailPlanes = Planes.of(context);
            return Text('DETAIL-$open');
          },
        ),
        size: const Size(1280, 800),
      );

      flowState!.openDetail('order-1041');
      await tester.pump();

      expect(find.text('DETAIL-order-1041'), findsOneWidget);
      // Default claim: exactly one plane, and it is the LAST one.
      expect(detailPlanes!.span, 1);
      expect(detailPlanes!.index, 2);
      expect(detailPlanes!.isLast, isTrue);
      // The list keeps its two planes; the bare plane is now the detail's.
      expect(listPlanes!.span, 2);
      expect(listPlanes!.index, 0);
      // A pushed page holds a plane, so the nav folds to the corner pill.
      expect(find.byType(FloatingBackPill), findsOneWidget);

      await tester.tap(find.byType(FloatingBackPill));
      await tester.pumpAndSettle();

      expect(find.text('DETAIL-order-1041'), findsNothing);
      expect(find.byType(FloatingBackPill), findsNothing);
      expect(listPlanes!.span, 2);
    });

    testWidgets('one plane: the phone fold — no pill, list is the screen '
        '(38d)', (tester) async {
      Planes? listPlanes;
      await pump(
        tester,
        ListDetailFlow<String>(
          backIcon: Icons.arrow_back,
          detailNameOf: (open) => open,
          listBuilder: (context, flow) {
            listPlanes = Planes.of(context);
            return const Text('LIST');
          },
          detailBuilder: (context, open, flow) => Text('DETAIL-$open'),
        ),
        size: const Size(390, 844),
      );
      expect(listPlanes!.count, 1);
      expect(listPlanes!.span, 1);
    });
  });

  group('ListPlaneColumns — plane-aligned columns', () {
    testWidgets('deals rows across the granted planes, footer spanning them '
        'all', (tester) async {
      await pump(
        tester,
        ListDetailFlow<String>(
          backIcon: Icons.arrow_back,
          detailNameOf: (open) => open,
          listBuilder: (context, flow) => ListPlaneColumns(
            footer: const Text('FOOTER'),
            children: const [Text('A'), Text('B'), Text('C')],
          ),
          detailBuilder: (context, open, flow) => const SizedBox.shrink(),
        ),
        size: const Size(1280, 800),
      );

      expect(ListPlaneColumns.columnsOf, isNotNull);
      final columns = tester
          .widget<ListPlaneColumns>(find.byType(ListPlaneColumns));
      expect(columns.children.length, 3);
      // Two columns at a two-plane claim: A and C lead, B trails.
      final rowFinder = find.descendant(
        of: find.byType(ListPlaneColumns),
        matching: find.byType(Row),
      );
      expect(rowFinder, findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('FOOTER'), findsOneWidget);
      // Round-robin across two columns: A and B sit side by side on the
      // plane grid, C falls under A.
      expect(
        tester.getTopLeft(find.text('B')).dx,
        greaterThan(tester.getTopLeft(find.text('A')).dx),
      );
      expect(
        tester.getTopLeft(find.text('B')).dy,
        tester.getTopLeft(find.text('A')).dy,
      );
      expect(
        tester.getTopLeft(find.text('C')).dy,
        greaterThan(tester.getTopLeft(find.text('A')).dy),
      );
      expect(
        tester.getTopLeft(find.text('C')).dx,
        tester.getTopLeft(find.text('A')).dx,
      );
      // The footer spans them: it starts at the columns' own left edge and
      // sits below both.
      expect(
        tester.getTopLeft(find.text('FOOTER')).dy,
        greaterThan(tester.getTopLeft(find.text('C')).dy),
      );
    });

    testWidgets('one plane collapses to a single column (38d)',
        (tester) async {
      await pump(
        tester,
        ListDetailFlow<String>(
          backIcon: Icons.arrow_back,
          detailNameOf: (open) => open,
          listBuilder: (context, flow) => ListPlaneColumns(
            children: const [Text('A'), Text('B')],
          ),
          detailBuilder: (context, open, flow) => const SizedBox.shrink(),
        ),
        size: const Size(390, 844),
      );
      expect(
        find.descendant(
          of: find.byType(ListPlaneColumns),
          matching: find.byType(Row),
        ),
        findsNothing,
      );
      expect(
        tester.getTopLeft(find.text('B')).dy,
        greaterThan(tester.getTopLeft(find.text('A')).dy),
      );
    });
  });
}
