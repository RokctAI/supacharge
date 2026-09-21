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
import 'package:flutter/rendering.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'foods/foods_body.dart';
import 'extras/extras_body.dart';
import 'addons/addons_body.dart';
import 'create/create_product_modal.dart';
import 'addons/create/create_addon_modal.dart';
import 'extras/create/create_extras_group_modal.dart';
import 'edit/product_edit_page.dart';
import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/presentation/components/keyboard_dismisser.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:merchants_sdk/src/manager/application/main/main_provider.dart';
import 'package:products_sdk/src/manager/application/addons/addons_provider.dart';
import 'package:products_sdk/src/manager/application/catalog/catalog_provider.dart';
import 'package:products_sdk/src/manager/application/extras/extras_provider.dart';
import 'package:products_sdk/src/manager/application/foods/food_categories_provider.dart';
import 'package:products_sdk/src/manager/application/foods/food_tabs_provider.dart';
import 'package:products_sdk/src/manager/application/foods/foods_provider.dart';
import 'package:products_sdk/src/common/infrastructure/models/data/seller_product_data.dart';
import 'package:products_sdk/src/manager/presentation/catalog/catalog_header.dart';
import 'package:products_sdk/src/manager/presentation/catalog/catalog_plane_flow.dart';
import 'package:products_sdk/src/manager/presentation/catalog/product_detail_pane.dart';
import 'package:products_sdk/src/manager/presentation/catalog/quick_stock_view.dart';
import 'package:products_sdk/src/manager/presentation/catalog/stock_grammar.dart';

/// The foods tab of the manager home shell (merchants_sdk's main_page.dart
/// hosts it — this install path is that shell's import contract), rebuilt as
/// the APPROVED product-management workspace (Ray 2026-08-29 15:41Z
/// "approved: … 35a,35b,35c,35d,35e."):
///
///  * the CATALOG DECLARES ALL (35a): on wide windows the grid takes planes
///    1–2 and the selected product's read-only detail — with the
///    Price/Cost/Margin profitability strip — holds the last plane;
///  * phones keep the one-plane list with the shipped tap-straight-to-edit
///    (35c — the tablet-only read stop is a deliberate approved asymmetry);
///  * Edit pushes a REAL route (35b/35d, `ProductEditPage`);
///  * the amber Stock button opens the approved 35e counts-only
///    quick-adjust — a sheet on phones, a pushed plane pane on wide widths
///    (the 12:02Z sheet fork), with the header count as its doorway;
///  * "+ New product" lives in the header now (the shipped shell FAB's
///    create dispatch, landed here — the floating-nav language has no FAB).
///
/// The header carries the shipped page's whole toolkit in the approved
/// language: the three inner tabs with counts, the search field (the 11m
/// search-plus-chips language), and the category chips (in FoodsBody).
/// The header row itself is products_sdk's [CatalogHeader], which lays out
/// by the planes the catalog holds: the 35a single row at two planes or
/// more, and the same elements on two rows when the catalog holds ONE
/// plane of a multi-plane screen (the two-plane fold with the detail open)
/// — the row cannot fit a ~390 px plane, which is what the tablet store
/// stills showed as "OVERFLOWED BY 234 PIXELS".
/// Tab-hosted, so no route. The legacy filter icon kept its no-op tap: the
/// app's FoodsFilterModal and foodsFilterProvider were dead code (never
/// opened, repository calls commented out) and were not ported.
class FoodsPage extends ConsumerStatefulWidget {
  const FoodsPage({super.key});

  @override
  ConsumerState<FoodsPage> createState() => _FoodsPageState();
}

class _FoodsPageState extends ConsumerState<FoodsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  late RefreshController _categoryController;
  late RefreshController _productController;
  late RefreshController _addonsController;
  late RefreshController _extrasController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref
            .read(foodTabsProvider.notifier)
            .setSelectedIndex(_tabController.index);
      }
      // The header segments and the create button label track the index.
      setState(() {});
    });
    _scrollController = ScrollController();
    _categoryController = RefreshController();
    _productController = RefreshController();
    _addonsController = RefreshController();
    _extrasController = RefreshController();
    _scrollController.addListener(() {
      final direction = _scrollController.position.userScrollDirection;
      ref
          .read(mainProvider.notifier)
          .changeScrolling(direction == ScrollDirection.reverse);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(foodCategoriesProvider.notifier).initialFetchCategories();
      ref.read(foodsProvider.notifier).initialFetchFoods();
      ref.read(addonsProvider.notifier).initialFetchAddons();
      ref.read(extrasProvider.notifier).fetchGroups();
    });
  }

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    _categoryController.dispose();
    _productController.dispose();
    _addonsController.dispose();
    _extrasController.dispose();
  }

  SellerProductData? _resolveSelected(
    List<SellerProductData> products,
    String? id,
  ) {
    if (id == null) return null;
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  void _refreshFoods() {
    final categoriesState = ref.read(foodCategoriesProvider);
    ref.read(foodsProvider.notifier).fetchProducts(
          isRefresh: true,
          categoryId: categoriesState.activeIndex == 1
              ? null
              : (categoriesState.activeIndex >= 2 &&
                      categoriesState.activeIndex - 2 <
                          categoriesState.categories.length)
                  ? categoriesState
                      .categories[categoriesState.activeIndex - 2].id
                  : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardDismisser(
      child: Scaffold(
        backgroundColor: AppStyle.surfaceDark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // On a ONE-plane (phone) width a selection pushes a real
                // route instead of holding a plane (the kitchen workspace
                // idiom) — the flow hosts the catalog alone there.
                final bool onePlane =
                    PlaneHost.planeCountFor(constraints.maxWidth) == 1;
                final products = ref.watch(foodsProvider).foods;
                final catalogState = ref.watch(catalogProvider);
                return CatalogPlaneFlow(
                  selectedProduct: onePlane
                      ? null
                      : _resolveSelected(products, catalogState.selectedId),
                  quickAdjustOpen: !onePlane && catalogState.quickAdjustOpen,
                  catalogBuilder: (context) => _catalog(context),
                  detailBuilder: (context, product) => ProductDetailPane(
                    product: product,
                    onEdit: () => ProductEditPage.open(context, ref, product),
                    onQuickStock: () =>
                        ref.read(catalogProvider.notifier).openQuickAdjust(),
                  ),
                  quickAdjustBuilder: (context) => QuickStockView(
                    products: products,
                    asSheet: false,
                    onSaved: (_) => _refreshFoods(),
                    onClose: () =>
                        ref.read(catalogProvider.notifier).closeQuickAdjust(),
                  ),
                  onPop: () =>
                      ref.read(catalogProvider.notifier).closeQuickAdjust(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _catalog(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context),
        const SizedBox(height: 12),
        _searchField(),
        const SizedBox(height: 10),
        Expanded(
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            controller: _tabController,
            children: [
              FoodsBody(
                categoryController: _categoryController,
                productController: _productController,
                scrollController: _scrollController,
              ),
              AddonsBody(addonsController: _addonsController),
              ExtrasBody(refreshController: _extrasController),
            ],
          ),
        ),
      ],
    );
  }

  /// The workspace header — [CatalogHeader] decides its own row/fold
  /// layout from the planes the catalog holds; this page only feeds it the
  /// live counts and the actions.
  Widget _header(BuildContext context) {
    final foods = ref.watch(foodsProvider).foods;
    final int attention = foods
        .where((p) => StockGrammar.productLevel(p) != StockLevel.healthy)
        .length;
    final int addonsCount = ref.watch(addonsProvider).addons.length;
    final int extrasCount = ref.watch(extrasProvider).groups.length;
    // "+ New product" opens the create modal of the ACTIVE inner tab
    // (product / add-on / extras group), exactly the shipped FAB's rule;
    // the label tracks the tab.
    final String newLabel = switch (_tabController.index) {
      1 => AppHelpers.getTranslation('addons'),
      2 => AppHelpers.getTranslation('extras'),
      _ => AppHelpers.getTranslation('new_product'),
    };
    return CatalogHeader(
      title: AppHelpers.getTranslation('products'),
      tabs: [
        CatalogTab(
          label: AppHelpers.getTranslation(TrKeys.foods),
          count: foods.length,
        ),
        CatalogTab(
          label: AppHelpers.getTranslation('addons'),
          count: addonsCount,
        ),
        CatalogTab(
          label: AppHelpers.getTranslation('extras'),
          count: extrasCount,
        ),
      ],
      activeTab: _tabController.index,
      onSelectTab: _tabController.animateTo,
      attention: attention,
      stockLabel: AppHelpers.getTranslation('stock'),
      onStock: () => _openQuickStock(context),
      newLabel: newLabel,
      onNew: () => _showCreateModal(context),
    );
  }

  /// The amber Stock button's tap — the doorway to the approved 35e
  /// quick-adjust: a sheet on a one-plane screen, a pushed plane pane on
  /// wide widths (the 12:02Z sheet fork).
  void _openQuickStock(BuildContext context) {
    final bool onePlane = (Planes.maybeOf(context)?.count ?? 1) == 1;
    if (onePlane) {
      _openQuickStockSheet(context);
    } else {
      ref.read(catalogProvider.notifier).openQuickAdjust();
    }
  }

  Widget _searchField() {
    return Container(
      height: 44,
      padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
      decoration: BoxDecoration(
        color: AppStyle.cardDark,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppStyle.strokeDarkSubtle),
      ),
      child: Consumer(
        builder: (context, ref, child) {
          final foodsEvent = ref.read(foodsProvider.notifier);
          final categoriesState = ref.watch(foodCategoriesProvider);
          return Row(
            children: [
              Icon(Remix.search_line,
                  size: 16, color: AppStyle.textDarkFaint),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  onChanged: (value) => foodsEvent.setQuery(
                    query: value,
                    categoryId: categoriesState.activeIndex == 1
                        ? null
                        : (categoriesState.activeIndex >= 2 &&
                                categoriesState.activeIndex - 2 <
                                    categoriesState.categories.length)
                            ? categoriesState
                                .categories[categoriesState.activeIndex - 2]
                                .id
                            : null,
                  ),
                  style: AppStyle.interNormal(
                    size: 14,
                    color: AppStyle.textPrimary,
                  ),
                  cursorColor: AppStyle.primary,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText:
                        '${AppHelpers.getTranslation(TrKeys.search)}...',
                    hintStyle: AppStyle.interNormal(
                      size: 14,
                      color: AppStyle.textDarkFaint,
                    ),
                  ),
                ),
              ),
              // The legacy filter icon kept its no-op tap (dead filter
              // slice, not ported).
              GestureDetector(
                onTap: () {},
                child: Icon(
                  Remix.equalizer_line,
                  size: 16,
                  color: AppStyle.textDarkFaint,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The phone presentation of the approved 35e surface: a bottom sheet
  /// (sheets overlay, never take planes — and the sheet fork keeps the
  /// sheet as the PHONE behaviour).
  void _openQuickStockSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppStyle.transparent,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.85,
        child: QuickStockView(
          products: ref.read(foodsProvider).foods,
          asSheet: true,
          onSaved: (_) => _refreshFoods(),
          onClose: () => Navigator.of(sheetContext).maybePop(),
        ),
      ),
    );
  }

  void _showCreateModal(BuildContext context) {
    final foodTabIndex = _tabController.index;
    // THE ADD MOMENT at plane widths (35a chip 618 + section 35 transfer
    // item 2, tabs-become-panes): the two-tab product form takes the
    // 35b panes in the LAST planes with the catalog rail on plane 1 —
    // the same pushed route as Edit, create bodies inside. Phones keep
    // the shipped bottom sheet (sheet = phone behaviour, 12:02Z); the
    // add-on and extras-group creates are single-tab CRUD satellites and
    // stay sheets at every width (transfer item 3).
    final bool onPlanes = (Planes.maybeOf(context)?.count ?? 1) > 1;
    if (foodTabIndex == 0 && onPlanes) {
      ProductEditPage.openCreate(context);
      return;
    }
    Widget modal;
    if (foodTabIndex == 0) {
      modal = const CreateProductModal();
    } else if (foodTabIndex == 1) {
      modal = const CreateAddonModal();
    } else {
      modal = const CreateExtrasGroupModal();
    }
    AppHelpers.showCustomModalBottomSheet(
      paddingTop: MediaQuery.paddingOf(context).top + 64,
      context: context,
      modal: modal,
      isDarkMode: false,
    );
  }
}
