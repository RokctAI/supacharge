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

import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../edit/product_edit_page.dart';
import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:products_sdk/src/manager/application/catalog/catalog_provider.dart';
import 'package:products_sdk/src/manager/application/foods/food_categories_provider.dart';
import 'package:products_sdk/src/manager/application/foods/foods_provider.dart';
import 'package:products_sdk/src/manager/presentation/catalog/product_catalog_card.dart';

/// The Foods inner tab of the approved catalog workspace: the category
/// chips row (the approved 11m search-plus-chips language) over the product
/// grid — sized by planes on wide windows (grid cards, approved 35a; a tap
/// selects into the detail plane) — or the one-plane list (the shipped
/// food_item shape with the stock states riding along, approved 35c; a tap
/// keeps the shipped behaviour and goes straight to the pushed edit form).
///
/// Kitchen-picker seeding note (kept from the modal era): kitchen_sdk's
/// `kitchenPickerProvider` is autoDispose, so EditFoodDetailsBody seeds it
/// in its own initState from the product it already has.
class FoodsBody extends ConsumerWidget {
  final RefreshController categoryController;
  final RefreshController productController;
  final ScrollController? scrollController;

  const FoodsBody({
    super.key,
    required this.categoryController,
    required this.productController,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _categoryChips(ref),
        const SizedBox(height: 10),
        Expanded(child: _products(context, ref)),
      ],
    );
  }

  /// The category chips — All first, then the seller's categories, the
  /// same 1-based active-index convention the shipped CategoriesTabBar used
  /// (index 1 = All, categories offset by 2).
  Widget _categoryChips(WidgetRef ref) {
    final categoriesState = ref.watch(foodCategoriesProvider);
    final categoriesEvent = ref.read(foodCategoriesProvider.notifier);
    final productsEvent = ref.read(foodsProvider.notifier);
    if (categoriesState.isLoading) return const SizedBox(height: 34);
    Widget chip({required int index, required String label}) {
      final bool active = categoriesState.activeIndex == index;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: InkWell(
          onTap: () {
            categoriesEvent.setActiveIndex(index);
            if (index != categoriesState.activeIndex) {
              productsEvent.fetchCategoryProducts(
                categoryId: index == 1
                    ? null
                    : categoriesState.categories[index - 2].id,
                refreshController: productController,
              );
            }
          },
          borderRadius: BorderRadius.circular(100),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: active ? AppStyle.primary : AppStyle.cardDark,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: active ? AppStyle.primary : AppStyle.strokeDark,
              ),
            ),
            child: Text(
              label,
              style: active
                  ? AppStyle.interSemi(size: 13, color: AppStyle.textPrimary)
                  : AppStyle.interNormal(
                      size: 13,
                      color: AppStyle.textDarkSecondary,
                    ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip(index: 1, label: AppHelpers.getTranslation(TrKeys.all)),
          for (var i = 0; i < categoriesState.categories.length; i++)
            chip(
              index: i + 2,
              label:
                  categoriesState.categories[i].translation?.title ?? '',
            ),
        ],
      ),
    );
  }

  Widget _products(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(foodsProvider);
    final productsEvent = ref.read(foodsProvider.notifier);
    final planes = Planes.maybeOf(context);
    final bool wide = (planes?.count ?? 1) > 1;

    if (productsState.isLoading && productsState.foods.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (productsState.foods.isEmpty) {
      return Center(
        child: Text(
          AppHelpers.getTranslation('no_products'),
          style: AppStyle.interNormal(
            size: 12,
            color: AppStyle.textDarkFaint,
          ),
        ),
      );
    }

    // Wide-screen auto-select (the kitchen queue idiom): the detail plane
    // stays filled, so the approved 35a never shows a bare last plane.
    final selectedId = ref.watch(catalogProvider).selectedId;
    if (wide && selectedId == null) {
      final String? firstId = productsState.foods.first.id;
      if (firstId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(catalogProvider.notifier).autoSelect(firstId);
        });
      }
    }

    // The grid grows with the planes the catalog holds: span + 1 columns
    // (three cards a row over two planes — approved 35a; the kitchen's
    // denser 2×span suits its smaller cards). One plane keeps the list.
    final int columns = wide ? (planes!.span + 1) : 1;

    return SmartRefresher(
      controller: productController,
      enablePullDown: true,
      enablePullUp: true,
      onRefresh: () =>
          productsEvent.refreshProducts(refreshController: productController),
      onLoading: () =>
          productsEvent.fetchMoreProducts(refreshController: productController),
      child: columns == 1
          ? ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.only(top: 4, bottom: 96),
              itemCount: productsState.foods.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final product = productsState.foods[index];
                return ProductCatalogTile(
                  product: product,
                  // The shipped tap-straight-to-edit, kept on phones
                  // (approved 35c/35d — the deliberate asymmetry).
                  onTap: () => ProductEditPage.open(context, ref, product),
                );
              },
            )
          : GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.only(top: 4, bottom: 96),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 196,
              ),
              itemCount: productsState.foods.length,
              itemBuilder: (context, index) {
                final product = productsState.foods[index];
                return ProductCatalogCard(
                  product: product,
                  selected: product.id != null && product.id == selectedId,
                  // On wide the tap is the read stop: selection drives the
                  // detail plane (approved 35a).
                  onTap: () =>
                      ref.read(catalogProvider.notifier).select(product.id),
                );
              },
            ),
    );
  }
}
