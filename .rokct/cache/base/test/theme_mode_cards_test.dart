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


// The shared CARDS and the maintenance page, restyling themselves the
// moment the theme mode changes with the screen still mounted (Ray,
// 2026-09-19: "glance doesnt change test immediately untill you come back
// if you switched theme mode").
//
// Each named its fill and ink from AppStyle's app-wide isDark static and
// resolved nothing from its BuildContext. MarketItem is the case that shows
// why MediaQuery does not count: its shop variant reads
// MediaQuery.sizeOf(context) for its width, which registers a real
// dependency - on the WINDOW SIZE, which does not change when the theme
// mode does. So the card still kept the previous mode's colours.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/models/data/shop_data.dart';
import 'package:base_sdk/src/models/data/translation.dart';
import 'package:base_sdk/src/presentation/components/market_item.dart';
import 'package:base_sdk/src/presentation/components/size_item.dart';
import 'package:base_sdk/src/presentation/components/tab_bar_item.dart';
import 'package:base_sdk/src/presentation/pages/initial/maintenance/maintenance_page.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';

import 'theme_flip_host.dart';

/// The shop variant's shape: no bonus (so no translation lookup in the
/// title line) and no background image to fetch.
final ShopData _shop = ShopData(
  id: 'shop-1',
  logoImg: '',
  verify: false,
  translation: Translation(title: 'Corner Store', description: 'Open now'),
);

class _MarketItemRegion extends StatelessWidget {
  const _MarketItemRegion();

  @override
  Widget build(BuildContext context) {
    // The shop variant declares a fixed 140pt height, which the default
    // test font's metrics overflow by 2pt (google_fonts cannot fetch Inter
    // in a test, so the label falls back to a wider face). A little text
    // scaling makes it fit. Nothing about the mode: MediaQuery does not
    // change when the theme mode flips, which is the whole reason this card
    // needed fixing in the first place - its `MediaQuery.sizeOf` width
    // lookup was a real dependency on the wrong thing.
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(0.8)),
      child: MarketItem(shop: _shop, isShop: true),
    );
  }
}

class _TabBarItemRegion extends StatelessWidget {
  const _TabBarItemRegion();

  @override
  Widget build(BuildContext context) => TabBarItem(
        title: 'All',
        index: 0,
        currentIndex: 1,
        onTap: () {},
      );
}

class _SizeItemRegion extends StatelessWidget {
  const _SizeItemRegion();

  @override
  Widget build(BuildContext context) =>
      SizeItem(title: 'Large', isActive: false, onTap: () {});
}

class _MaintenanceRegion extends StatelessWidget {
  const _MaintenanceRegion();

  @override
  Widget build(BuildContext context) => const MaintenancePage();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bool wasDark = AppStyle.isDark;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  tearDown(() => AppStyle.isDark = wasDark);

  testWidgets('a market item restyles its card and title on a mode flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _MarketItemRegion(),
      read: (t) => containerFill(t, decoratedIn(MarketItem).first),
      expected: AppStyle.cardFor,
      reason: "the market item kept the previous mode's card fill",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _MarketItemRegion(),
      read: (t) => textInk(t, 'Corner Store'),
      expected: AppStyle.inkFor,
      reason: "the market item's title kept the previous mode's ink",
    );
  });

  testWidgets('an IDLE tab bar item restyles its fill and label on a flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _TabBarItemRegion(),
      read: (t) => (tester
              .widget<AnimatedContainer>(find.byType(AnimatedContainer))
              .decoration as BoxDecoration?)
          ?.color,
      expected: AppStyle.cardFor,
      reason: "the tab bar item kept the previous mode's fill",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _TabBarItemRegion(),
      read: (t) => textInk(t, 'All'),
      expected: AppStyle.inkFor,
      reason: "the tab bar item's label kept the previous mode's ink",
    );
  });

  testWidgets('a size item restyles its card and label on a mode flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _SizeItemRegion(),
      read: (t) => containerFill(t, decoratedIn(SizeItem).first),
      expected: AppStyle.cardFor,
      reason: "the size item kept the previous mode's card fill",
    );
    await expectRestylesOnFlip(
      tester,
      child: const _SizeItemRegion(),
      read: (t) => textInk(t, 'Large'),
      expected: AppStyle.inkFor,
      reason: "the size item's label kept the previous mode's ink",
    );
  });

  testWidgets('the maintenance page restyles its ground and title on a flip',
      (WidgetTester tester) async {
    // This page brings its own Scaffold, so the host adds none; it is the
    // whole screen, and a mode flip while its retry probe is in flight used
    // to leave it on the previous mode's ground.
    await expectRestylesOnFlip(
      tester,
      wrapInScaffold: false,
      child: const _MaintenanceRegion(),
      read: (t) => tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      expected: AppStyle.surfaceFor,
      reason: "the maintenance page kept the previous mode's ground",
    );
    await expectRestylesOnFlip(
      tester,
      wrapInScaffold: false,
      child: const _MaintenanceRegion(),
      read: (t) => textInk(t, AppHelpers.getTranslation(TrKeys.maintenanceTitle)),
      expected: AppStyle.inkFor,
      reason: "the maintenance page's title kept the previous mode's ink, so "
          'it could sit white-on-light',
    );
  });
}
