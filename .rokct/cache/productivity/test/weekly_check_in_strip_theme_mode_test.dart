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

// The weekly check-in strip restyles itself on the theme-mode change
// itself, with its page still mounted (Ray, 2026-09-19: "glance doesnt
// change test immediately untill you come back if you switched theme
// mode" — the same defect, found here by the audit that followed).
//
// The strip used to resolve nothing from its BuildContext: every colour
// came from AppStyle's app-wide statics. A static is not an inherited
// widget, so a mode flip scheduled no rebuild of this element — and
// personal_mastery_page.dart mounts it `const`, so the flip provably
// cannot reach it through a parent rebuild either. It kept the previous
// mode's ink and card until the page was built again from scratch.
//
// The host below is that exact shape: the mode flips app-wide and the
// strip sits behind a `const` child boundary. Only a dependency of the
// strip's own on the inherited theme can restyle it here.

import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/presentation/vision/mastery_goal_card.dart';

/// The `const` mount boundary personal_mastery_page.dart's `_listPlane`
/// gives the strip: handed back identical, so its element is not rebuilt.
class _StripRegion extends StatelessWidget {
  const _StripRegion();

  @override
  Widget build(BuildContext context) => const WeeklyCheckInStrip();
}

/// The same `const` boundary, with the strip under a subtree [Theme] of the
/// OPPOSITE brightness to the app-wide flag: a panel that forces its own
/// mode. AppStyle's statics still answer for the app, so this is the one
/// arrangement in which "the flag" and "the theme this widget is under"
/// disagree — and it is the arrangement that tells which of the two the
/// strip's card and stroke are actually reading.
class _OppositeThemeHost extends StatelessWidget {
  const _OppositeThemeHost({required this.subtree});

  final Brightness subtree;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1280, 900),
      builder: (BuildContext context, Widget? _) => MaterialApp(
        theme: ThemeData(useMaterial3: false, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: false, brightness: Brightness.dark),
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: Theme(
            data: ThemeData(useMaterial3: false, brightness: subtree),
            child: const _StripRegion(),
          ),
        ),
      ),
    );
  }
}

class _ThemedHost extends StatefulWidget {
  const _ThemedHost({super.key});

  @override
  State<_ThemedHost> createState() => _ThemedHostState();
}

class _ThemedHostState extends State<_ThemedHost> {
  bool dark = true;

  /// Mirrors AppNotifier.changeTheme: AppStyle's statics are synced and
  /// the Material themeMode flips, in that order.
  void flip() {
    AppStyle.setBrightness(dark ? Brightness.light : Brightness.dark);
    setState(() => dark = !dark);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1280, 900),
      builder: (BuildContext context, Widget? _) => MaterialApp(
        theme: ThemeData(useMaterial3: false, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: false, brightness: Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const Scaffold(body: _StripRegion()),
      ),
    );
  }
}

void main() {
  final bool wasDark = AppStyle.isDark;
  tearDown(() => AppStyle.isDark = wasDark);

  /// Every colour the strip's own spans name, in order: label ink then
  /// fact ink, for each of the two facts.
  List<Color?> spanInks(WidgetTester tester) {
    final List<Color?> out = <Color?>[];
    final Finder texts = find.descendant(
      of: find.byType(WeeklyCheckInStrip),
      matching: find.byType(Text),
    );
    for (final Text text in tester.widgetList<Text>(texts)) {
      final InlineSpan? span = text.textSpan;
      if (span is! TextSpan) continue;
      for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
        out.add(child.style?.color);
      }
    }
    return out;
  }

  /// The card the strip paints itself on.
  BoxDecoration cardOf(WidgetTester tester) {
    final Finder container = find.descendant(
      of: find.byType(WeeklyCheckInStrip),
      matching: find.byType(Container),
    );
    return tester.widget<Container>(container.first).decoration!
        as BoxDecoration;
  }

  testWidgets(
      'a theme-mode change restyles the check-in strip with its page still '
      'mounted', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    AppStyle.setBrightness(Brightness.dark);

    final GlobalKey<_ThemedHostState> host = GlobalKey<_ThemedHostState>();
    await tester.pumpWidget(_ThemedHost(key: host));
    await tester.pumpAndSettle();

    final Color darkInk = AppStyle.inkFor(Brightness.dark);
    final Color lightInk = AppStyle.inkFor(Brightness.light);
    final Color darkSecondary = AppStyle.secondaryInkFor(Brightness.dark);
    final Color lightSecondary = AppStyle.secondaryInkFor(Brightness.light);
    expect(darkInk, isNot(lightInk));
    expect(darkSecondary, isNot(lightSecondary));

    expect(spanInks(tester), <Color?>[
      darkInk,
      darkSecondary,
      darkInk,
      darkSecondary,
    ]);
    final Color darkCard = cardOf(tester).color!;

    // The flip, with the strip's element never remounted.
    host.currentState!.flip();
    await tester.pumpAndSettle();

    expect(
      spanInks(tester),
      <Color?>[lightInk, lightSecondary, lightInk, lightSecondary],
      reason: "the check-in strip kept the previous mode's ink",
    );
    // The card and its stroke ride the same rebuild: the strip now
    // depends on the inherited theme, so the mode change reschedules its
    // build and every colour in it is resolved afresh.
    expect(
      cardOf(tester).color,
      isNot(darkCard),
      reason: "the check-in strip kept the previous mode's card",
    );
  });

  testWidgets(
      'the check-in strip takes its card and stroke from the theme it is '
      'under, not the app-wide flag', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The app is dark and AppStyle agrees; only the strip's subtree is
    // light. A flip of the app-wide flag alone cannot tell the two reads
    // apart — after `AppNotifier.changeTheme` the flag and the theme agree
    // again, so the statics happen to answer correctly — which is why the
    // card fill and the hairline were left on statics when the ink was
    // fixed. Here they cannot both be right.
    AppStyle.setBrightness(Brightness.dark);
    await tester.pumpWidget(
      const _OppositeThemeHost(subtree: Brightness.light),
    );
    await tester.pumpAndSettle();

    final BoxDecoration card = cardOf(tester);
    expect(
      AppStyle.cardAltFor(Brightness.light),
      isNot(AppStyle.cardAltFor(Brightness.dark)),
    );
    expect(
      AppStyle.subtleStrokeFor(Brightness.light),
      isNot(AppStyle.subtleStrokeFor(Brightness.dark)),
    );
    expect(
      card.color,
      AppStyle.cardAltFor(Brightness.light),
      reason: 'the card fill came from the app-wide flag, not the theme',
    );
    expect(
      (card.border! as Border).top.color,
      AppStyle.subtleStrokeFor(Brightness.light),
      reason: 'the hairline came from the app-wide flag, not the theme',
    );
    // The ink, fixed first, already reads the theme: all four colours in
    // the strip now name the same mode.
    expect(spanInks(tester), <Color?>[
      AppStyle.inkFor(Brightness.light),
      AppStyle.secondaryInkFor(Brightness.light),
      AppStyle.inkFor(Brightness.light),
      AppStyle.secondaryInkFor(Brightness.light),
    ]);
  });
}
