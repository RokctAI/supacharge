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

// The two modal sheets this SDK opens, on a theme-mode change made while
// they are still open (Ray, 2026-09-19: "glance doesnt change test
// immediately untill you come back if you switched theme mode" — the same
// defect, audited here).
//
// THE TWO SHEETS ARE NOT THE SAME CASE, and the difference is exactly the
// `const` rule. Flutter's own `_ModalBottomSheet` reads the inherited theme
// for its bottom-sheet defaults, so the flip marks IT dirty and it invokes
// the route's builder closure again:
//
//   * [showSnoozeSheet] builds `_SnoozeSheet(...)` NON-const, so that
//     re-invocation hands the sheet a fresh widget and its State's build
//     runs again. The flip reaches it. Its first test below pins that, and
//     it is why the snooze sheet was REJECTED by the audit rather than
//     changed: it is not theme-blind.
//   * [showNewItemSheet] builds `const _NewItemSheet()`, and a const
//     instantiation is a boundary the flip cannot cross: the identical
//     widget is handed back, the element is not rebuilt, and AppStyle's
//     mode-resolving statics are not an inherited widget either — so with
//     nothing else asked for the mode the open sheet kept the previous
//     mode's ink, fill and stroke.
//
// The host below is that exact shape: the sheet is opened, the mode flips
// app-wide exactly as AppNotifier.changeTheme does it, and the tree is
// pumped WITHOUT remounting anything.

import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/presentation/notes/notes_list_controls.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/new_item_sheet.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/task_reminder_controls.dart';
import 'package:productivity_sdk/src/common/presentation/tasks/task_view_model.dart';

/// The app around a sheet: the mode flips here, the sheet is a route above.
class _ThemedHost extends StatefulWidget {
  const _ThemedHost({super.key, required this.onReady});

  /// Called once with a context under the MaterialApp, so the test can open
  /// the sheet the way a page does.
  final void Function(BuildContext context) onReady;

  @override
  State<_ThemedHost> createState() => _ThemedHostState();
}

class _ThemedHostState extends State<_ThemedHost> {
  bool dark = true;

  /// Mirrors AppNotifier.changeTheme: AppStyle's statics are synced and the
  /// Material themeMode flips, in that order.
  void flip() {
    AppStyle.setBrightness(dark ? Brightness.light : Brightness.dark);
    setState(() => dark = !dark);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(430, 930),
      builder: (BuildContext context, Widget? _) => MaterialApp(
        theme: ThemeData(useMaterial3: false, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: false, brightness: Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext inner) => TextButton(
              onPressed: () => widget.onReady(inner),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  final bool wasDark = AppStyle.isDark;
  tearDown(() => AppStyle.isDark = wasDark);

  /// Every colour named by a [Text] under [of], in tree order.
  List<Color?> inksUnder(WidgetTester tester, Finder of) => tester
      .widgetList<Text>(find.descendant(of: of, matching: find.byType(Text)))
      .map((Text text) => text.style?.color)
      .toList();

  /// The decoration of the first decorated [Container] under [of].
  BoxDecoration decorationUnder(WidgetTester tester, Finder of) {
    final Iterable<Container> boxes = tester
        .widgetList<Container>(
          find.descendant(of: of, matching: find.byType(Container)),
        )
        .where((Container box) => box.decoration is BoxDecoration);
    return boxes.first.decoration! as BoxDecoration;
  }

  Future<GlobalKey<_ThemedHostState>> pumpHost(
    WidgetTester tester,
    void Function(BuildContext context) open,
  ) async {
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    AppStyle.setBrightness(Brightness.dark);
    final GlobalKey<_ThemedHostState> host = GlobalKey<_ThemedHostState>();
    await tester.pumpWidget(_ThemedHost(key: host, onReady: open));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return host;
  }

  testWidgets(
      'a theme-mode change restyles the open new-item sheet, never remounted',
      (WidgetTester tester) async {
    final GlobalKey<_ThemedHostState> host = await pumpHost(
      tester,
      (BuildContext context) => showNewItemSheet(context),
    );

    final Finder row = find.byKey(newItemSheetKeyFor(WorkspaceList.tasks));
    expect(row, findsOneWidget);

    final Color darkInk = AppStyle.inkFor(Brightness.dark);
    final Color lightInk = AppStyle.inkFor(Brightness.light);
    final Color darkFaint = AppStyle.faintFor(Brightness.dark);
    final Color lightFaint = AppStyle.faintFor(Brightness.light);
    expect(darkInk, isNot(lightInk));
    expect(darkFaint, isNot(lightFaint));

    expect(inksUnder(tester, row), <Color?>[darkInk, darkFaint]);
    expect(
      decorationUnder(tester, row).color,
      AppStyle.cardAltFor(Brightness.dark),
    );

    // The flip, with the sheet's element never remounted: no second tap, no
    // second pumpWidget — the same tree, pumped again.
    host.currentState!.flip();
    await tester.pumpAndSettle();

    expect(
      inksUnder(tester, row),
      <Color?>[lightInk, lightFaint],
      reason: "the new-item sheet kept the previous mode's ink",
    );
    expect(
      decorationUnder(tester, row).color,
      AppStyle.cardAltFor(Brightness.light),
      reason: "the new-item sheet kept the previous mode's row fill",
    );
    expect(
      (decorationUnder(tester, row).border! as Border).top.color,
      AppStyle.subtleStrokeFor(Brightness.light),
      reason: "the new-item sheet kept the previous mode's row stroke",
    );
    // The heading above the rows rides the same rebuild.
    expect(
      tester.widget<Text>(find.text('Add to this page')).style?.color,
      lightInk,
      reason: "the new-item sheet kept the previous mode's heading ink",
    );
  });

  // The rejection, pinned: the snooze sheet's route builder is NOT const,
  // so the flip already reaches it through Flutter's own theme-reading
  // bottom-sheet scaffolding and its statics resolve afresh. Nothing in
  // this SDK had to change for this to hold, and this test is here so a
  // later `const` on that builder cannot quietly make it untrue.
  testWidgets(
      'a theme-mode change already reaches the open snooze sheet, never '
      'remounted', (WidgetTester tester) async {
    final TaskViewModel task = TaskViewModel(
      id: 'T-1',
      title: 'Month-end stock count',
      deadline: DateTime(2026, 9, 25, 17),
    );
    final GlobalKey<_ThemedHostState> host = await pumpHost(
      tester,
      (BuildContext context) => showSnoozeSheet(
        context,
        task: task,
        now: DateTime(2026, 9, 19, 9),
      ),
    );

    expect(find.text('Snooze the reminder'), findsOneWidget);
    final Finder sheet = find.ancestor(
      of: find.text('Snooze the reminder'),
      matching: find.byType(SafeArea),
    );

    final Color darkInk = AppStyle.inkFor(Brightness.dark);
    final Color lightInk = AppStyle.inkFor(Brightness.light);
    final Color darkFaint = AppStyle.faintFor(Brightness.dark);
    final Color lightFaint = AppStyle.faintFor(Brightness.light);

    expect(
      tester.widget<Text>(find.text('Snooze the reminder')).style?.color,
      darkInk,
    );
    expect(
      tester.widget<Text>(find.text('Month-end stock count')).style?.color,
      darkFaint,
    );
    expect(
      decorationUnder(tester, sheet.first).color,
      AppStyle.cardAltFor(Brightness.dark),
    );

    // The flip, with the sheet's element never remounted.
    host.currentState!.flip();
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('Snooze the reminder')).style?.color,
      lightInk,
      reason: "the snooze sheet kept the previous mode's heading ink",
    );
    expect(
      tester.widget<Text>(find.text('Month-end stock count')).style?.color,
      lightFaint,
      reason: "the snooze sheet kept the previous mode's subtitle ink",
    );
    expect(
      decorationUnder(tester, sheet.first).color,
      AppStyle.cardAltFor(Brightness.light),
      reason: "the snooze sheet kept the previous mode's note fill",
    );
    // An unselected option row: its label ink and its circle both resolve
    // from the mode the theme reports.
    final Text option = tester.widget<Text>(find.text('In an hour'));
    expect(
      option.style?.color,
      lightInk,
      reason: "a snooze option kept the previous mode's ink",
    );
  });
}
