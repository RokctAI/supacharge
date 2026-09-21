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

// The PRODUCTIVITY gate's hub rows — Tasks (approved frame 7e, chip 391,
// Ray 2026-08-29 15:41Z) and Calculator (approved frame 45b, chip 842):
// SectionsItem pumped DIRECTLY from templates/ (the
// widget carries no ${package} imports, so this harness is its compile
// gate, same contract as the POS suites). Pins the row shapes the gate
// relies on: the two-line glance row (title + an optional glance line) and
// the untouched single-line shape every pre-7e hub row keeps - the shape
// the hub's rows have since merchants_sdk 1.26.0, when the seeded demo
// glances gave way to the composer markers test/hub_markers_test.dart
// pins.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/services/local_storage.dart';

import '../templates/pages/manager/restaurant/widgets/sections_item.dart';

Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  testWidgets(
      'the Tasks gate row renders title + subtitle glance and fires its tap',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(_host(SectionsItem(
      title: 'Tasks',
      subtitle: 'a glance line',
      icon: Remix.task_line,
      onTap: () => tapped++,
    )));

    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('a glance line'), findsOneWidget);
    expect(find.byIcon(Remix.task_line), findsOneWidget);

    await tester.tap(find.text('Tasks'));
    expect(tapped, 1);
  });

  testWidgets(
      'CHIP 842: the Calculator gate row renders its glance and fires its tap',
      (tester) async {
    // Design strip frame 45b, GATE 1 of section 45: the PRODUCTIVITY
    // group gains a second row, in the same idiom as the Tasks row —
    // calculator glyph, title, and the earn-your-glance sub-line. The
    // hub row itself carries no sub-line (calc_sdk's memory lives in an
    // in-memory autoDispose StateNotifier, nothing live for merchants_sdk
    // to read, and ADR-005 forbids reaching for it anyway); this pins the
    // shape the row takes once a glance is supplied.
    var tapped = 0;
    await tester.pumpWidget(_host(SectionsItem(
      title: 'Calculator',
      subtitle: 'a glance line',
      icon: Remix.calculator_line,
      onTap: () => tapped++,
    )));

    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('a glance line'), findsOneWidget);
    expect(find.byIcon(Remix.calculator_line), findsOneWidget);

    await tester.tap(find.text('Calculator'));
    expect(tapped, 1);
  });

  testWidgets('the two productivity rows are the same shape, not two shapes',
      (tester) async {
    // 45b's whole claim is that gate 1 costs nothing: the Calculator row
    // is the Tasks row with different content, so a change to one can
    // never silently diverge the other.
    await tester.pumpWidget(_host(Column(children: [
      SectionsItem(
        title: 'Tasks',
        subtitle: 'a glance line',
        icon: Remix.task_line,
        onTap: () {},
      ),
      SectionsItem(
        title: 'Calculator',
        subtitle: 'a glance line',
        icon: Remix.calculator_line,
        onTap: () {},
      ),
    ])));

    expect(find.byType(SectionsItem), findsNWidgets(2));
    final first = tester.getSize(find.byType(SectionsItem).first);
    final second = tester.getSize(find.byType(SectionsItem).last);
    expect(second, first);
  });

  testWidgets('a row without a subtitle keeps the single-line shape',
      (tester) async {
    await tester.pumpWidget(_host(SectionsItem(
      title: 'Income',
      icon: Remix.line_chart_line,
      onTap: () {},
    )));

    expect(find.text('Income'), findsOneWidget);
    // No second Text under the title: only the single title Text renders.
    expect(find.byType(Text), findsOneWidget);
  });
}
