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


// The profile page's shared rows and cards, restyling themselves the moment
// the theme mode changes - which on this page is not a nicety: the theme
// TOGGLE lives here, so the profile is by definition still on screen when
// the mode flips (Ray, 2026-09-19: "glance doesnt change test immediately
// untill you come back if you switched theme mode").
//
// Each of these named its ink, fill and stroke from AppStyle's app-wide
// isDark static and resolved nothing from its BuildContext. A static is not
// an inherited widget, so the flip scheduled no rebuild of them at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';

import 'package:base_sdk/src/presentation/pages/profile/profile_action_item.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/presentation/pages/profile/widgets/profile_actions_section.dart';
import 'package:base_sdk/src/presentation/pages/profile/widgets/profile_nav_tile.dart';
import 'package:base_sdk/src/presentation/pages/profile/widgets/profile_section_card.dart';
import 'package:base_sdk/src/presentation/pages/profile/widgets/profile_switch_tile.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';

import 'theme_flip_host.dart';

const String _group = 'theme.sweep';

class _SwitchTileRegion extends StatelessWidget {
  const _SwitchTileRegion();

  @override
  Widget build(BuildContext context) => ProfileSwitchTile(
        icon: Icons.dark_mode_outlined,
        title: 'Dark mode',
        subtitle: 'Follows the system',
        value: true,
        onChanged: (_) {},
      );
}

class _NavTileRegion extends StatelessWidget {
  const _NavTileRegion();

  @override
  Widget build(BuildContext context) => ProfileNavTile(
        icon: Icons.language_outlined,
        title: 'Language',
        subtitle: 'English',
        onTap: () {},
      );
}

class _SectionCardRegion extends StatelessWidget {
  const _SectionCardRegion();

  @override
  Widget build(BuildContext context) => const ProfileSectionCard(
        title: 'Settings',
        child: SizedBox(height: 20),
      );
}

class _ActionGridRegion extends StatelessWidget {
  const _ActionGridRegion();

  @override
  Widget build(BuildContext context) => const ProfileActionsSection(
        group: _group,
        layout: ProfileActionLayout.grid,
      );
}

class _ActionRowsRegion extends StatelessWidget {
  const _ActionRowsRegion();

  @override
  Widget build(BuildContext context) => const ProfileActionsSection(
        group: _group,
        layout: ProfileActionLayout.rows,
      );
}

void main() {
  final bool wasDark = AppStyle.isDark;

  setUp(() {
    ProfileSectionRegistry.I.reset();
    ProfileSectionRegistry.I.registerAction(
      group: _group,
      item: ProfileActionItem(
        id: 'orders',
        icon: Icons.receipt_long_outlined,
        label: () => 'Orders',
        onTap: (_) {},
      ),
    );
  });

  tearDown(() {
    ProfileSectionRegistry.I.reset();
    AppStyle.isDark = wasDark;
  });

  /// The one Container the subject itself draws.
  testWidgets('a profile switch tile restyles its title and subtitle on a flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _SwitchTileRegion(),
      read: (t) => textInk(t, 'Dark mode'),
      expected: AppStyle.inkFor,
      reason: "the switch tile's title kept the previous mode's ink",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _SwitchTileRegion(),
      read: (t) => textInk(t, 'Follows the system'),
      expected: AppStyle.secondaryInkFor,
      reason: "the switch tile's subtitle kept the previous mode's ink",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _SwitchTileRegion(),
      read: (t) => iconInk(t, Icons.dark_mode_outlined),
      expected: AppStyle.inkFor,
      reason: "the switch tile's glyph kept the previous mode's ink",
    );
  });

  testWidgets('a profile nav tile restyles its title, subtitle and chevron',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _NavTileRegion(),
      read: (t) => textInk(t, 'Language'),
      expected: AppStyle.inkFor,
      reason: "the nav tile's title kept the previous mode's ink",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _NavTileRegion(),
      read: (t) => textInk(t, 'English'),
      expected: AppStyle.secondaryInkFor,
      reason: "the nav tile's subtitle kept the previous mode's ink",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _NavTileRegion(),
      read: (t) => iconInk(t, Remix.arrow_right_s_line),
      expected: AppStyle.secondaryInkFor,
      reason: "the nav tile's chevron kept the previous mode's ink",
    );
  });

  testWidgets('a profile section card restyles its surface and group label',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _SectionCardRegion(),
      read: (t) => containerFill(t, decoratedIn(ProfileSectionCard).first),
      expected: AppStyle.cardFor,
      reason: "the section card kept the previous mode's surface",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _SectionCardRegion(),
      read: (t) => textInk(t, 'SETTINGS'),
      expected: AppStyle.secondaryInkFor,
      reason: "the section card's group label kept the previous mode's ink",
    );
  });

  testWidgets('a square action tile restyles its surface and label on a flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _ActionGridRegion(),
      read: (t) => containerFill(t, decoratedIn(ProfileActionsSection).first),
      expected: AppStyle.cardFor,
      reason: "the action tile kept the previous mode's surface",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _ActionGridRegion(),
      read: (t) => textInk(t, 'Orders'),
      expected: AppStyle.inkFor,
      reason: "the action tile's label kept the previous mode's ink",
    );
  });

  testWidgets('a settings action row restyles its surface, stroke and chevron',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _ActionRowsRegion(),
      read: (t) => containerFill(t, decoratedIn(ProfileActionsSection).first),
      expected: AppStyle.cardFor,
      reason: "the action row kept the previous mode's surface",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _ActionRowsRegion(),
      read: (t) => containerStroke(t, decoratedIn(ProfileActionsSection).first),
      expected: AppStyle.strokeFor,
      reason: "the action row kept the previous mode's stroke",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _ActionRowsRegion(),
      read: (t) => iconInk(t, Remix.arrow_right_s_line),
      expected: AppStyle.secondaryInkFor,
      reason: "the action row's chevron kept the previous mode's ink",
    );
  });

  testWidgets("an action item's own accent survives a mode flip",
      (WidgetTester tester) async {
    // A contributor that names a colour for its glyph keeps it: the sweep
    // replaced the widget's DEFAULT ink, not a caller's choice.
    ProfileSectionRegistry.I.reset();
    const Color accent = Color(0xFF00A3FF);
    ProfileSectionRegistry.I.registerAction(
      group: _group,
      item: ProfileActionItem(
        id: 'accented',
        icon: Icons.bolt_outlined,
        label: () => 'Accented',
        onTap: (_) {},
        accent: accent,
      ),
    );

    AppStyle.setBrightness(Brightness.dark);
    final GlobalKey<ThemeFlipHostState> host = GlobalKey<ThemeFlipHostState>();
    await tester.pumpWidget(
      ThemeFlipHost(key: host, child: const _ActionRowsRegion()),
    );
    await tester.pumpAndSettle();

    expect(iconInk(tester, Icons.bolt_outlined), accent);
    host.currentState!.flip();
    await tester.pumpAndSettle();
    expect(iconInk(tester, Icons.bolt_outlined), accent);
  });
}
