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


// The shared CHROME - app bars, dialogs, buttons and the loading
// placeholder - restyling itself the moment the theme mode changes, with
// the screen it is on still mounted (Ray, 2026-09-19: "glance doesnt change
// test immediately untill you come back if you switched theme mode").
//
// Each of these named its ground and ink from AppStyle's app-wide isDark
// static and resolved nothing from its BuildContext, so the flip scheduled
// no rebuild of it. The loading grid is the sharpest case: its fill was
// read inside an itemBuilder, which runs only when the GridView decides to
// build a tile, so a placeholder screen could sit in the wrong mode's grey
// indefinitely.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/presentation/components/app_bars/app_bar_bottom_sheet.dart';
import 'package:base_sdk/src/presentation/components/app_bars/custom_app_bar.dart';
import 'package:base_sdk/src/presentation/components/badges/alert_dialog.dart';
import 'package:base_sdk/src/presentation/components/buttons/button_item.dart';
import 'package:base_sdk/src/presentation/components/buttons/social_button.dart';
import 'package:base_sdk/src/presentation/components/loading/loading_grid.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';

import 'theme_flip_host.dart';

class _CustomAppBarRegion extends StatelessWidget {
  const _CustomAppBarRegion();

  @override
  Widget build(BuildContext context) => const CustomAppBar(
        bottomPadding: 12,
        child: Text('Orders'),
      );
}

class _BottomSheetBarRegion extends StatelessWidget {
  const _BottomSheetBarRegion();

  @override
  Widget build(BuildContext context) =>
      const AppBarBottomSheet(title: 'Pick a size');
}

class _ComingSoonRegion extends StatelessWidget {
  const _ComingSoonRegion();

  @override
  Widget build(BuildContext context) => const ComingSoonDialog();
}

class _LoadingGridRegion extends StatelessWidget {
  const _LoadingGridRegion();

  @override
  Widget build(BuildContext context) => const LoadingGrid(itemCount: 2);
}

class _ButtonItemRegion extends StatelessWidget {
  const _ButtonItemRegion();

  @override
  Widget build(BuildContext context) => ButtonItem(
        icon: Remix.global_line,
        title: 'Language',
        selectValue: 'English',
        isLtr: true,
        onTap: () {},
      );
}

class _SocialButtonRegion extends StatelessWidget {
  const _SocialButtonRegion();

  @override
  Widget build(BuildContext context) => SocialButton(
        iconData: Remix.google_fill,
        title: 'Google',
        onPressed: () {},
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bool wasDark = AppStyle.isDark;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  tearDown(() => AppStyle.isDark = wasDark);

  testWidgets('the custom app bar restyles its ground on a mode flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _CustomAppBarRegion(),
      read: (t) => containerFill(t, decoratedIn(CustomAppBar).first),
      expected: AppStyle.cardFor,
      reason: "the app bar kept the previous mode's ground, so its "
          'default-ink title sat on the wrong polarity',
    );
  });

  testWidgets("the bottom-sheet app bar restyles its title and back glyph",
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _BottomSheetBarRegion(),
      read: (t) => textInk(t, 'Pick a size'),
      expected: AppStyle.inkFor,
      reason: "the sheet bar's title kept the previous mode's ink",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _BottomSheetBarRegion(),
      read: (t) => iconInk(t, Icons.arrow_back),
      expected: AppStyle.inkFor,
      reason: "the sheet bar's back glyph kept the previous mode's ink",
    );
  });

  testWidgets('the coming-soon dialog restyles its surface and body on a flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _ComingSoonRegion(),
      read: (t) => tester.widget<AlertDialog>(find.byType(AlertDialog)).backgroundColor,
      expected: AppStyle.cardFor,
      reason: "the dialog kept the previous mode's surface",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _ComingSoonRegion(),
      read: (t) =>
          textInk(t, AppHelpers.getTranslation(TrKeys.featureNotAvailable)),
      expected: AppStyle.inkFor,
      reason: "the dialog's body kept the previous mode's ink",
    );
  });

  testWidgets('the loading grid restyles its placeholder tiles on a flip',
      (WidgetTester tester) async {
    // The fill is read in build now, not inside the itemBuilder, so the
    // flip rebuilds the grid and every tile is handed the new mode's grey.
    await expectRestylesOnFlip(
      tester,
      child: const _LoadingGridRegion(),
      read: (t) => containerFill(t, decoratedIn(LoadingGrid).first),
      expected: AppStyle.cardFor,
      reason: "the loading tiles kept the previous mode's grey",
    );
  });

  testWidgets('a settings button item restyles its card, label and glyphs',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _ButtonItemRegion(),
      read: (t) => containerFill(t, decoratedIn(ButtonItem).first),
      expected: AppStyle.cardFor,
      reason: "the button item kept the previous mode's card fill",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _ButtonItemRegion(),
      read: (t) => textInk(t, 'Language'),
      expected: AppStyle.inkFor,
      reason: "the button item's label kept the previous mode's ink",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _ButtonItemRegion(),
      read: (t) => iconInk(t, Remix.global_line),
      expected: AppStyle.inkFor,
      reason: "the button item's glyph kept the previous mode's ink",
    );
  });

  testWidgets('a social button restyles its alt fill, stroke and label',
      (WidgetTester tester) async {
    // The one subject in this sweep that wanted the SECOND card fill and so
    // drove AppStyle.cardAltFor.
    await expectRestylesOnFlip(
      tester,
      child: const _SocialButtonRegion(),
      read: (t) => tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .style
          ?.backgroundColor
          ?.resolve(const <WidgetState>{}),
      expected: AppStyle.cardAltFor,
      reason: "the social button kept the previous mode's alt fill",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _SocialButtonRegion(),
      read: (t) => tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .style
          ?.side
          ?.resolve(const <WidgetState>{})
          ?.color,
      expected: AppStyle.strokeFor,
      reason: "the social button kept the previous mode's stroke",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _SocialButtonRegion(),
      read: (t) => textInk(t, 'Google'),
      expected: AppStyle.inkFor,
      reason: "the social button's label kept the previous mode's ink",
    );
  });
}
