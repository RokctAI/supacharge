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


// The standard list language, restyling itself the moment the theme mode
// changes with the list still on screen - the defect of #242 and the audit
// that followed it (Ray, 2026-09-19: "glance doesnt change test immediately
// untill you come back if you switched theme mode", and "might be worth
// checking in all sdks if this is there not just in glance").
//
// Every element of the language named its fills, strokes and ink from
// AppStyle's app-wide isDark static and resolved nothing from its
// BuildContext. A static is not an inherited widget, so a mode flip
// scheduled no rebuild of a chip, pill, header or foot, and a list already
// on screen kept the previous mode's colours until it was built again from
// scratch. None of these has a mount site inside base_sdk, so no host
// rebuild can be assumed - each is pumped behind the `const` boundary the
// flip cannot cross.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/presentation/components/lists/list_language.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';

import 'theme_flip_host.dart';

/// The tab row with one active and one idle tab. `const`, so the flip
/// reaches it only through its own theme dependency.
class _TabBarRegion extends StatelessWidget {
  const _TabBarRegion();

  @override
  Widget build(BuildContext context) {
    return ListFilterTabBar(
      activeIndex: 0,
      onSelect: (_) {},
      tabs: const <ListFilterTab>[
        ListFilterTab(label: 'Active', color: Color(0xFF00A3FF), count: 3),
        ListFilterTab(label: 'Idle', color: Color(0xFF8A8A8A), count: 1),
      ],
    );
  }
}

class _CountPillRegion extends StatelessWidget {
  const _CountPillRegion();

  @override
  Widget build(BuildContext context) => const ListCountPill(label: '247 orders');
}

class _RoundActionRegion extends StatelessWidget {
  const _RoundActionRegion();

  @override
  Widget build(BuildContext context) =>
      ListRoundAction(icon: Icons.notifications_none, onTap: () {});
}

class _HeaderRegion extends StatelessWidget {
  const _HeaderRegion();

  @override
  Widget build(BuildContext context) =>
      const ListScreenHeader(title: 'Orders', hint: '3 need attention');
}

class _ViewMoreRegion extends StatelessWidget {
  const _ViewMoreRegion();

  @override
  Widget build(BuildContext context) =>
      ListViewMore(moreCount: 12, onTap: () {}, label: 'View more');
}

void main() {
  final bool wasDark = AppStyle.isDark;
  tearDown(() => AppStyle.isDark = wasDark);

  testWidgets('an IDLE filter chip restyles its fill on a mode flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _TabBarRegion(),
      // The idle chip sits on the card surface; the active one carries its
      // own tab colour and must not move (asserted below).
      read: (t) => containerFill(
          t, find.ancestor(of: find.text('Idle'), matching: find.byType(Container)).first),
      expected: AppStyle.cardFor,
      reason: "the idle filter chip kept the previous mode's card fill",
    );
  });

  testWidgets('an IDLE filter chip restyles its stroke and label on a flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _TabBarRegion(),
      read: (t) => containerStroke(
          t, find.ancestor(of: find.text('Idle'), matching: find.byType(Container)).first),
      expected: AppStyle.strokeFor,
      reason: "the idle filter chip kept the previous mode's stroke",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _TabBarRegion(),
      read: (t) => textInk(t, 'Idle'),
      expected: AppStyle.secondaryInkFor,
      reason: "the idle filter chip's label kept the previous mode's ink",
    );
  });

  testWidgets("an ACTIVE chip keeps its own tab colour across a flip",
      (WidgetTester tester) async {
    // 363's active treatment is the TAB's colour, not a mode colour: the
    // sweep must not have turned a caller's choice into a theme lookup.
    AppStyle.setBrightness(Brightness.dark);
    final GlobalKey<ThemeFlipHostState> host = GlobalKey<ThemeFlipHostState>();
    await tester.pumpWidget(
      ThemeFlipHost(key: host, child: const _TabBarRegion()),
    );
    await tester.pumpAndSettle();

    Color? activeStroke() => containerStroke(
        tester,
        find
            .ancestor(of: find.text('Active'), matching: find.byType(Container))
            .first);

    const Color tabColour = Color(0xFF00A3FF);
    expect(activeStroke(), tabColour);
    // Its label is the mode's primary ink, which DOES flip.
    expect(textInk(tester, 'Active'), AppStyle.inkFor(Brightness.dark));

    host.currentState!.flip();
    await tester.pumpAndSettle();

    expect(activeStroke(), tabColour);
    expect(textInk(tester, 'Active'), AppStyle.inkFor(Brightness.light));
  });

  testWidgets('the list-header count pill restyles on a mode flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _CountPillRegion(),
      read: (t) => containerStroke(t, find.byType(Container)),
      expected: AppStyle.strokeFor,
      reason: "the count pill kept the previous mode's stroke",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _CountPillRegion(),
      read: (t) => textInk(t, '247 orders'),
      expected: AppStyle.secondaryInkFor,
      reason: "the count pill's label kept the previous mode's ink",
    );
  });

  testWidgets('a header round utility restyles on a mode flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _RoundActionRegion(),
      read: (t) => containerFill(t, find.byType(Container)),
      expected: AppStyle.cardFor,
      reason: "the round utility kept the previous mode's disc fill",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _RoundActionRegion(),
      read: (t) => iconInk(t, Icons.notifications_none),
      expected: AppStyle.secondaryInkFor,
      reason: "the round utility's glyph kept the previous mode's ink",
    );
  });

  testWidgets('the standard list header restyles its title and hint on a flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _HeaderRegion(),
      read: (t) => textInk(t, 'Orders'),
      expected: AppStyle.inkFor,
      reason: "the list header's title kept the previous mode's ink",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _HeaderRegion(),
      read: (t) => textInk(t, '3 need attention'),
      expected: AppStyle.faintFor,
      reason: "the list header's hint kept the previous mode's faint ink",
    );
  });

  testWidgets("the paging foot restyles on a mode flip",
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _ViewMoreRegion(),
      read: (t) => containerStroke(t, find.byType(Container)),
      expected: AppStyle.strokeFor,
      reason: "the View more foot kept the previous mode's stroke",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _ViewMoreRegion(),
      read: (t) => textInk(t, 'View more  ·  +12'),
      expected: AppStyle.secondaryInkFor,
      reason: "the View more label kept the previous mode's ink",
    );
  });
}
