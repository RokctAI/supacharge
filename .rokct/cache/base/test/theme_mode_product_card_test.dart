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


// The shared product card, restyling itself the moment the theme mode
// changes with the grid it is in still on screen (Ray, 2026-09-19: "glance
// doesnt change test immediately untill you come back if you switched theme
// mode").
//
// Being a ConsumerWidget was no help: the brand and shop lookups are
// `ref.read`s, and nothing this card watches fires when the theme mode
// flips. Its fill and title ink came from AppStyle's app-wide isDark static
// and it resolved nothing from its BuildContext, so a grid of these kept
// the previous mode's colours until the page was built again from scratch.
//
// The card is pumped behind a `const` boundary the flip cannot cross, over
// Fake repositories: the notifiers it reads are constructed from the
// locator, and none of their methods ever runs.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/banners.dart';
import 'package:base_sdk/src/domain/interface/brands.dart';
import 'package:base_sdk/src/domain/interface/cart.dart';
import 'package:base_sdk/src/domain/interface/categories.dart';
import 'package:base_sdk/src/domain/interface/products.dart';
import 'package:base_sdk/src/domain/interface/shops.dart';
import 'package:base_sdk/src/models/data/product_data.dart';
import 'package:base_sdk/src/models/data/translation.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/utils/products/product_card.dart';

import 'theme_flip_host.dart';

class _FakeCartRepository extends Fake implements CartRepositoryFacade {}

class _FakeShopsRepository extends Fake implements ShopsRepositoryFacade {}

class _FakeProductsRepository extends Fake implements ProductsRepositoryFacade {}

class _FakeCategoriesRepository extends Fake
    implements CategoriesRepositoryFacade {}

class _FakeBannersRepository extends Fake implements BannersRepositoryFacade {}

class _FakeBrandsRepository extends Fake implements BrandsRepositoryFacade {}

final ProductData _product = ProductData(
  id: 'p-1',
  img: '',
  translation: Translation(title: 'Oat milk', description: 'One litre'),
);

class _ProductCardRegion extends StatelessWidget {
  const _ProductCardRegion();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        height: 260,
        child: ProductCard(
          product: _product,
          hasTransparentBg: false,
          cartQuantity: 0,
          showShopName: false,
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bool wasDark = AppStyle.isDark;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<CartRepositoryFacade>(_FakeCartRepository());
    getIt.registerSingleton<ShopsRepositoryFacade>(_FakeShopsRepository());
    getIt
        .registerSingleton<ProductsRepositoryFacade>(_FakeProductsRepository());
    getIt.registerSingleton<CategoriesRepositoryFacade>(
        _FakeCategoriesRepository());
    getIt.registerSingleton<BannersRepositoryFacade>(_FakeBannersRepository());
    getIt.registerSingleton<BrandsRepositoryFacade>(_FakeBrandsRepository());
  });

  tearDown(() async {
    await getIt.reset();
    AppStyle.isDark = wasDark;
  });

  Future<void> pumpAndFlip(
    WidgetTester tester, {
    required Object? Function(WidgetTester tester) read,
    required Color Function(Brightness) expected,
    required String reason,
  }) async {
    AppStyle.setBrightness(Brightness.dark);
    final GlobalKey<ThemeFlipHostState> host = GlobalKey<ThemeFlipHostState>();
    await tester.pumpWidget(ProviderScope(
      child: ThemeFlipHost(key: host, child: const _ProductCardRegion()),
    ));
    await tester.pumpAndSettle();

    expect(expected(Brightness.dark), isNot(expected(Brightness.light)));
    expect(read(tester), expected(Brightness.dark),
        reason: 'dark mode, before the flip');

    host.currentState!.flip();
    await tester.pumpAndSettle();

    expect(read(tester), expected(Brightness.light), reason: reason);
  }

  testWidgets('a product card restyles its surface on a mode flip',
      (WidgetTester tester) async {
    await pumpAndFlip(
      tester,
      read: (t) => containerFill(t, decoratedIn(ProductCard).first),
      expected: AppStyle.cardFor,
      reason: "the product card kept the previous mode's surface",
    );
  });

  testWidgets("a product card restyles its title ink on a mode flip",
      (WidgetTester tester) async {
    await pumpAndFlip(
      tester,
      read: (t) => textInk(t, 'Oat milk'),
      expected: AppStyle.inkFor,
      reason: "the product card's title kept the previous mode's ink",
    );
  });
}
