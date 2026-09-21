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


// The profile page's wallet card and its edit-own-details sheet, restyling
// themselves the moment the theme mode changes. This page is where the theme
// TOGGLE lives, so it is by definition on screen when the mode flips.
//
// Both are Consumers, and both show that being one is no defence (the
// ProductCard lesson from #247): the wallet card watches nothing at all when
// a `wallet` snapshot is supplied, and the sheet watches the profile and
// edit-profile providers, neither of which fires when the theme mode changes.
// The sheet also reads MediaQuery.of for the keyboard inset, which a mode
// flip never moves.
//
// Each subject is mounted as the host's `const` child - a boundary the flip
// cannot cross - and nothing is remounted: the host flips
// AppStyle.setBrightness plus themeMode exactly as AppNotifier.changeTheme
// does and the test only pumps.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/gallery.dart';
import 'package:base_sdk/src/domain/interface/shops.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/models/data/profile_data.dart';
import 'package:base_sdk/src/presentation/pages/profile/edit_profile_sheet.dart';
import 'package:base_sdk/src/presentation/pages/profile/widgets/base_wallet_card.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';

import 'theme_flip_host.dart';

class _FakeUserRepository extends Fake implements UserRepositoryFacade {}

class _FakeShopsRepository extends Fake implements ShopsRepositoryFacade {}

class _FakeGalleryRepository extends Fake implements GalleryRepositoryFacade {}

/// The card takes a model, so it cannot itself be the host's `const` child.
/// This region can, and its own build reads nothing from the theme - exactly
/// the boundary the flip cannot cross. The inner [ProviderScope] is what a
/// [ConsumerWidget] needs; the `wallet` snapshot means no provider is watched.
class _WalletCardRegion extends StatelessWidget {
  const _WalletCardRegion();

  @override
  Widget build(BuildContext context) => ProviderScope(
        child: BaseWalletCard(wallet: Wallet(price: 25), symbol: 'R'),
      );
}

/// The sheet needs a live [ScrollController]; the region owns it and still
/// constructs `const`.
class _EditSheetRegion extends StatefulWidget {
  const _EditSheetRegion();

  @override
  State<_EditSheetRegion> createState() => _EditSheetRegionState();
}

class _EditSheetRegionState extends State<_EditSheetRegion> {
  final ScrollController controller = ScrollController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
        child: EditProfileScreen(controller: controller),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bool wasDark = AppStyle.isDark;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    getIt.registerSingleton<UserRepositoryFacade>(_FakeUserRepository());
    getIt.registerSingleton<ShopsRepositoryFacade>(_FakeShopsRepository());
    getIt.registerSingleton<GalleryRepositoryFacade>(_FakeGalleryRepository());
  });

  tearDown(() => AppStyle.isDark = wasDark);

  final String walletLabel = AppHelpers.getTranslation(TrKeys.wallet);

  testWidgets('the wallet card restyles its title ink on a flip',
      (WidgetTester tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _WalletCardRegion(),
      read: (WidgetTester t) => textInk(t, '$walletLabel: '),
      expected: AppStyle.inkFor,
    );
  });

  testWidgets('the wallet card keeps its balance colour across a flip',
      (WidgetTester tester) async {
    // A positive balance is AppStyle.green in both modes - a status colour,
    // not a mode role.
    await expectPinnedOnFlip(
      tester,
      child: const _WalletCardRegion(),
      read: (WidgetTester t) => textInk(
          t, AppHelpers.numberFormat(number: 25, symbol: 'R', isOrder: true)),
    );
    expect(
        textInk(tester,
            AppHelpers.numberFormat(number: 25, symbol: 'R', isOrder: true)),
        AppStyle.green);
  });

  testWidgets('the edit-details sheet restyles its chrome on a flip',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await expectRestylesOnFlip(
      tester,
      child: const _EditSheetRegion(),
      read: (WidgetTester t) =>
          containerFill(t, decoratedIn(EditProfileScreen).first),
      // The shipped light chrome is bgGrey@96%, the dark one the resolving
      // page surface at the same alpha - neither value changes here.
      expected: (Brightness brightness) => (brightness == Brightness.dark
              ? AppStyle.surfaceFor(brightness)
              : AppStyle.bgGrey)
          .withValues(alpha: 0.96),
    );
  });
}
