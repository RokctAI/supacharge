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


// The shared SELECTION rows, the tab bar and the common app bar, restyling
// themselves the moment the theme mode changes. Each read its fill or its ink
// from AppStyle's app-wide isDark static, which is not an inherited widget, so
// the flip scheduled no rebuild of them.
//
// Two of these show that reading SOMETHING from the BuildContext is no
// defence: the selection rows read MediaQuery.sizeOf for their own text width
// and the app bar reads MediaQuery.paddingOf for the status-bar inset -
// neither of which changes when the theme mode does.
//
// Every subject is mounted as the host's `const` child, so a parent rebuild
// provably cannot deliver the flip, and nothing is remounted: the host flips
// AppStyle.setBrightness plus themeMode exactly as AppNotifier.changeTheme
// does and the test only pumps.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/models/data/address_new_data.dart';
import 'package:base_sdk/src/presentation/components/app_bars/common_app_bar.dart';
import 'package:base_sdk/src/presentation/components/custom_tab_bar.dart';
import 'package:base_sdk/src/presentation/components/select_address_item.dart';
import 'package:base_sdk/src/presentation/components/select_item.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';

import 'theme_flip_host.dart';

void _onVoid() {}

/// [SelectAddressItem] takes a model, so it cannot itself be the host's
/// `const` child - this region can, and its own build reads nothing from the
/// theme, so it is exactly the boundary a flip cannot cross.
class _AddressRowRegion extends StatelessWidget {
  const _AddressRowRegion();

  @override
  Widget build(BuildContext context) => SelectAddressItem(
        onTap: _onVoid,
        update: _onVoid,
        isActive: false,
        address: AddressNewModel(title: 'Home'),
      );
}

/// [CustomTabBar] needs a live [TabController], which needs a ticker: the
/// region owns it and still constructs `const`.
class _TabBarRegion extends StatefulWidget {
  const _TabBarRegion();

  @override
  State<_TabBarRegion> createState() => _TabBarRegionState();
}

class _TabBarRegionState extends State<_TabBarRegion>
    with SingleTickerProviderStateMixin {
  late final TabController controller = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomTabBar(
        tabController: controller,
        tabs: const <Tab>[Tab(text: 'All'), Tab(text: 'Done')],
      );
}

void main() {
  final bool wasDark = AppStyle.isDark;

  tearDown(() => AppStyle.isDark = wasDark);

  testWidgets('a select row restyles its card fill and title on a flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const SelectItem(
        onTap: _onVoid,
        isActive: false,
        title: 'Cash',
        desc: 'Pay on delivery',
      ),
      // `.first` is the row's own Container: the active dot below it is an
      // AnimatedContainer, which builds a decorated Container of its own.
      read: (WidgetTester t) =>
          containerFill(t, decoratedIn(SelectItem).first),
      expected: AppStyle.cardFor,
    );

    expect(textInk(tester, 'Cash'), AppStyle.inkFor(Brightness.light));
  });

  testWidgets('a select-address row restyles its card fill on a flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _AddressRowRegion(),
      read: (WidgetTester t) =>
          containerFill(t, decoratedIn(SelectAddressItem).first),
      expected: AppStyle.cardFor,
    );

    expect(textInk(tester, 'Home'), AppStyle.inkFor(Brightness.light));
  });

  testWidgets('the tab bar restyles its unselected label ink on a flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _TabBarRegion(),
      read: (WidgetTester t) =>
          t.widget<TabBar>(find.byType(TabBar)).unselectedLabelColor,
      expected: AppStyle.inkFor,
    );

    // The selected label stays the polarity-pinned white it always was.
    expect(tester.widget<TabBar>(find.byType(TabBar)).labelColor,
        AppStyle.white);
  });

  testWidgets('the common app bar restyles its fill on a flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const CommonAppBar(child: Text('Orders')),
      read: (WidgetTester t) => containerFill(t, decoratedIn(CommonAppBar)),
      expected: AppStyle.cardFor,
    );
  });
}
