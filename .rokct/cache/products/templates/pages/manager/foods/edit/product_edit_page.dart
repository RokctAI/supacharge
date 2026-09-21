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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stocks/edit_food_stocks_body.dart';
import 'details/edit_food_details_body.dart';
import '../create/stocks/create_food_stocks_body.dart';
import '../create/details/create_food_details_body.dart';
import 'package:base_sdk/src/presentation/components/keyboard_dismisser.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:products_sdk/src/common/infrastructure/models/data/seller_product_data.dart';
import 'package:products_sdk/src/manager/application/foods/create/details/create_food_details_provider.dart';
import 'package:products_sdk/src/manager/application/foods/edit/details/category/edit_food_categories_provider.dart';
import 'package:products_sdk/src/manager/application/foods/edit/details/edit_food_details_provider.dart';
import 'package:products_sdk/src/manager/application/foods/edit/details/units/edit_food_units_provider.dart';
import 'package:products_sdk/src/manager/application/foods/foods_provider.dart';
import 'package:products_sdk/src/manager/presentation/catalog/catalog_edit_rail.dart';
import 'package:products_sdk/src/manager/presentation/catalog/edit_plane_flow.dart';

/// The APPROVED edit flow (frames 35b/35d, Ray 2026-08-29 15:41Z): the
/// shipped EditProductModal's two tabs, pushed as a REAL route instead of a
/// sheet — the push is the 12:36Z nav-fold moment (this route covers the
/// home shell's centered nav; the corner back pill is the one affordance
/// left, kitchen_detail_page's precedent).
///
///  * WIDE (35b): the form declares 2 — Details | Stocks side-by-side
///    panes on the plane grid; the origin catalog keeps plane 1 as the
///    compressed [CatalogEditRail] (12:26Z origin rule).
///  * PHONE (35d): the panes fold back into the shipped Details/Stocks
///    segmented tabs.
///
/// The form field logic, validation and save paths are the SHIPPED bodies
/// unchanged in behaviour (EditFoodDetailsBody / EditFoodStocksBody — same
/// notifiers, same satellite picker sheets); only their presentation moved
/// into the approved dark language.
///
/// THE ADD MOMENT (35a's "+ New product", chip 618; section 35 decision
/// transfer item 2 — every 2+ tab form modal unfolds into panes at plane
/// widths): with [product] null this same page hosts the shipped
/// CreateProductModal's two tabs — CreateFoodDetailsBody | CreateFoodStocksBody
/// — in the 35b panes, the catalog rail keeping plane 1 with nothing
/// highlighted (the product does not exist yet). The shipped modal's ORDER
/// is kept: its Stocks tab sat behind an IgnorePointer until the details
/// save created the product, so here the stocks pane is locked until
/// `createdProduct` lands, and the stocks save pops the page exactly as it
/// closed the sheet. Phones never reach this branch — "add" stays the
/// shipped bottom sheet there (12:02Z sheet fork; see FoodsPage).
class ProductEditPage extends ConsumerStatefulWidget {
  /// The product being edited, or null for the ADD moment.
  final SellerProductData? product;

  const ProductEditPage({super.key, required this.product});

  bool get isCreate => product == null;

  /// Seeds the edit providers (exactly the shipped list-tap seeding) and
  /// pushes the page over the whole shell (root navigator = the nav fold).
  static Future<void> open(
    BuildContext context,
    WidgetRef ref,
    SellerProductData product,
  ) {
    ref.read(editFoodDetailsProvider.notifier).setFoodDetails(product);
    ref.read(editFoodUnitsProvider.notifier).setFoodUnit(product.unit);
    ref.read(editFoodCategoriesProvider.notifier).setFoodCategory(
          product.category,
        );
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => ProductEditPage(product: product)),
    );
  }

  /// The ADD moment at plane widths: pushes this page with the CREATE bodies
  /// in the panes (the same route type, the same nav fold). The create
  /// providers are reset from the page itself, exactly where the shipped
  /// modal reset them.
  static Future<void> openCreate(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const ProductEditPage(product: null)),
    );
  }

  @override
  ConsumerState<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends ConsumerState<ProductEditPage> {
  final ScrollController _detailsScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.isCreate) {
      // The shipped CreateProductModal's initState reset, unchanged.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) =>
            ref.read(createFoodDetailsProvider.notifier).updateAddFoodInfo(),
      );
    }
  }

  @override
  void dispose() {
    _detailsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(foodsProvider).foods;
    final product = widget.product;
    // The create moment's lock: stocks wait for the product to exist.
    final bool stocksLocked = product == null &&
        ref.watch(createFoodDetailsProvider).createdProduct == null;
    return KeyboardDismisser(
      child: Scaffold(
        backgroundColor: AppStyle.surfaceDark,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
            child: ProductEditPlaneFlow(
              railBuilder: (context) => CatalogEditRail(
                products: products,
                editedId: product?.id,
              ),
              formBuilder: (context) => ProductFormSplit(
                header: _header(),
                detailsTitle: AppHelpers.getTranslation('details'),
                stocksTitle: AppHelpers.getTranslation('stocks'),
                stocksHeaderTrailing: _variantsCount(),
                stocksLocked: stocksLocked,
                stocksLockedHint:
                    AppHelpers.getTranslation('save_details_first'),
                detailsBuilder: (context) => Padding(
                  // Clear of the corner back pill (the kitchen detail
                  // page's reserve).
                  padding: const EdgeInsets.only(bottom: 64),
                  child: product == null
                      ? const CreateFoodDetailsBody(
                          // The shipped modal hopped to its stocks tab
                          // after the details save; the lock lifting is
                          // that hop here (ProductFormSplit).
                          onSave: _noHop,
                          dark: true,
                        )
                      : EditFoodDetailsBody(
                          controller: _detailsScroll,
                          // The shipped modal hopped to its stocks tab
                          // after a details save; panes show both at once
                          // and the phone page keeps the user where they
                          // saved.
                          onSave: _noHop,
                        ),
                ),
                stocksBuilder: (context) => Padding(
                  padding: const EdgeInsets.only(bottom: 64),
                  child: product == null
                      ? const CreateFoodStocksBody()
                      : EditFoodStocksBody(product: product),
                ),
              ),
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
    );
  }

  static void _noHop() {}

  Widget _header() {
    final product = widget.product;
    final String title = product == null
        ? AppHelpers.getTranslation('new_product')
        : '${AppHelpers.getTranslation(TrKeys.editProduct)} — '
            '${product.translation?.title ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyle.interBold(size: 20, color: AppStyle.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _variantsCount() {
    final int count = widget.product?.stocks?.length ?? 0;
    if (count == 0) return null;
    return Text(
      '$count ${AppHelpers.getTranslation('variants')}',
      style: AppStyle.interNormal(
        size: 12,
        color: AppStyle.textDarkSecondary,
      ),
    );
  }
}
