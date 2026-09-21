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

// The manager shell's tablet-mode rail reserves its footprint (tablet
// store review 2026-09-02, stills 08 / 10 / 12 / 14: list and card text
// sat under the rail on every tab because main_page.dart floated the rail
// over the pages with no inset). At the tour's 800 logical width a
// scrolling list beside the rail never has an item under it — first or
// last — and the plane host inside the page counts its planes on the
// width it really has.

import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_nav_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchants_sdk/src/manager/presentation/main/nav_rail_layout.dart';

void main() {
  const railKey = ValueKey('rail');
  const itemCount = 30;

  Widget rail() => Container(key: railKey, width: 60, height: 320);

  Widget list() => ListView.builder(
        itemCount: itemCount,
        itemBuilder: (context, i) => SizedBox(
          key: ValueKey('item$i'),
          height: 96,
          child: Text('Row $i'),
        ),
      );

  Future<void> pumpAt(
    WidgetTester tester, {
    double width = 800,
    FloatingNavPlacement placement = FloatingNavPlacement.railStart,
    TextDirection direction = TextDirection.ltr,
    Widget? pages,
  }) async {
    tester.view.physicalSize = Size(width, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: Size(width, 1280),
        builder: (_, __) => MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: NavRailLayout(
                placement: placement,
                rail: rail(),
                pages: pages ?? list(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('800 logical, start rail: no list item sits under the rail — '
      'first row clear, and the last row fully visible once scrolled to',
      (tester) async {
    await pumpAt(tester);
    final railRect = tester.getRect(find.byKey(railKey));
    // The rail hugs the start edge inside its 16 px margin, vertically
    // centred.
    expect(railRect.left, closeTo(16, 0.5));
    expect(railRect.center.dy, closeTo(640, 1));

    // Every visible row starts right of the rail's footprint (16 + 60 +
    // 16 = 92) — no overlap at the leading edge.
    final first = tester.getRect(find.byKey(const ValueKey('item0')));
    expect(first.left, greaterThanOrEqualTo(railRect.right + 16 - 0.5));
    expect(first.left, closeTo(92, 0.5));
    expect(first.overlaps(railRect), isFalse);
    expect(first.right, closeTo(800, 0.5));

    // Scroll to the end: the last row is entirely on screen and entirely
    // clear of the rail.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('item${itemCount - 1}')),
      400,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    final last = tester.getRect(find.byKey(const ValueKey('item${itemCount - 1}')));
    expect(last.top, greaterThanOrEqualTo(0));
    expect(last.bottom, lessThanOrEqualTo(1280));
    expect(last.left, closeTo(92, 0.5));
    expect(last.overlaps(railRect), isFalse);
  });

  testWidgets('the page beside the rail counts its planes on its own '
      'width: 800 - 92 = 708 is still two planes', (tester) async {
    Planes? planes;
    double? hostWidth;
    await pumpAt(
      tester,
      pages: LayoutBuilder(
        builder: (context, constraints) {
          hostWidth = constraints.maxWidth;
          return PlaneHost(
            stack: [
              PlanePage(
                name: 'page',
                span: PlaneSpan.all,
                builder: (context) {
                  planes = Planes.of(context);
                  return const Text('PAGE');
                },
              ),
            ],
          );
        },
      ),
    );
    expect(hostWidth, closeTo(708, 0.5));
    expect(planes!.count, 2);
    expect(planes!.span, 2);
  });

  testWidgets('end rail: the rail takes the trailing column, pages keep '
      'the start edge', (tester) async {
    await pumpAt(tester, placement: FloatingNavPlacement.railEnd);
    final railRect = tester.getRect(find.byKey(railKey));
    expect(railRect.right, closeTo(800 - 16, 0.5));
    final first = tester.getRect(find.byKey(const ValueKey('item0')));
    expect(first.left, closeTo(0, 0.5));
    expect(first.right, closeTo(800 - 92, 0.5));
    expect(first.overlaps(railRect), isFalse);
  });

  testWidgets('RTL: railStart hugs the right edge and the pages sit to '
      'its left', (tester) async {
    await pumpAt(tester, direction: TextDirection.rtl);
    final railRect = tester.getRect(find.byKey(railKey));
    expect(railRect.right, closeTo(800 - 16, 0.5));
    final first = tester.getRect(find.byKey(const ValueKey('item0')));
    expect(first.right, closeTo(800 - 92, 0.5));
    expect(first.overlaps(railRect), isFalse);
  });
}
