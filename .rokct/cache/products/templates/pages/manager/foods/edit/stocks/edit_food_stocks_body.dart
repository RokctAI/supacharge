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
import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'edit_food_addons_modal.dart';
import 'edit_group_extras_modal.dart';
import 'package:base_sdk/src/presentation/components/buttons/custom_button.dart';
import 'package:base_sdk/src/presentation/components/keyboard_dismisser.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:products_sdk/src/common/infrastructure/models/data/seller_product_data.dart';
import 'package:products_sdk/src/manager/application/foods/edit/stocks/edit_food_stocks_provider.dart';
import 'package:products_sdk/src/manager/application/foods/food_categories_provider.dart';
import 'package:products_sdk/src/manager/application/foods/foods_provider.dart';
import 'package:${package}/presentation/components/foods/editable_food_stock_item.dart';
import 'package:${package}/presentation/components/foods/extras_item.dart';

/// The STOCKS section of the approved edit form (frame 35b's right pane /
/// 35d's second tab): the shipped stocks tab — extras-group chips (each
/// checked group's value combinations make one stock row), one variant card
/// per stock with price*/quantity*/SKU and its add-ons, delete on every row
/// but the first, its own save — presentation in the approved dark
/// language plus the "+ Add variant" affordance over the notifier's
/// existing `addEmptyStock`; logic, validation and the satellite sheets
/// untouched.
class EditFoodStocksBody extends ConsumerStatefulWidget {
  final SellerProductData product;

  const EditFoodStocksBody({super.key, required this.product});

  @override
  ConsumerState<EditFoodStocksBody> createState() => _EditFoodStocksBodyState();
}

class _EditFoodStocksBodyState extends ConsumerState<EditFoodStocksBody> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref
          .read(editFoodStocksProvider.notifier)
          .setInitialStocks(widget.product),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardDismisser(
      child: Consumer(
        builder: (context, ref, child) {
          final state = ref.watch(editFoodStocksProvider);
          final event = ref.read(editFoodStocksProvider.notifier);
          final foodsEvent = ref.read(foodsProvider.notifier);
          final categoriesState = ref.watch(foodCategoriesProvider);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              8.verticalSpace,
              Text(
                AppHelpers.getTranslation('extras_groups_make_one_stock_row_per_combination'),
                style: AppStyle.interNormal(
                  size: 12.sp,
                  color: AppStyle.textDarkSecondary,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52.r,
                      child: ListView.builder(
                        itemCount: state.groups.length,
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) => ExtrasItem(
                          extras: state.groups[index],
                          onTap: () {
                            event.toggleCheckedGroup(index);
                            AppHelpers.showCustomModalBottomSheet(
                              paddingTop:
                                  MediaQuery.paddingOf(context).top + 150,
                              context: context,
                              radius: 12,
                              modal: EditGroupExtrasModal(groupIndex: index),
                              isDarkMode: false,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  // "+ Add variant" — the notifier's existing
                  // addEmptyStock, surfaced (approved 35b affordance).
                  if (state.stocks.isNotEmpty)
                    TextButton(
                      onPressed: () => event.addEmptyStock(),
                      child: Text(
                        '+ ${AppHelpers.getTranslation('add_variant')}',
                        style: AppStyle.interSemi(
                          size: 13.sp,
                          color: AppStyle.primary,
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView.builder(
                    itemCount: state.stocks.length,
                    shrinkWrap: true,
                    padding: REdgeInsets.symmetric(vertical: 10),
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      return EditableFoodStockItem(
                        key: UniqueKey(),
                        isDeletable: index != 0,
                        stock: state.stocks[index],
                        onDeleteStock: () => event.deleteStock(index),
                        onPriceChange: (value) =>
                            event.setPrice(value: value, index: index),
                        onQuantityChange: (value) =>
                            event.setQuantity(value: value, index: index),
                        onAddonTap: (context) =>
                            AppHelpers.showCustomModalBottomSheet(
                          paddingTop: MediaQuery.paddingOf(context).top + 150,
                          context: context,
                          radius: 12,
                          modal: EditFoodAddonsModal(
                            stock: state.stocks[index],
                            onSave: (addons) =>
                                event.setStockAddons(addons, index),
                          ),
                          isDarkMode: true,
                        ),
                        onSkuChange: (value) =>
                            event.setSku(value: value, index: index),
                      );
                    },
                  ),
                ),
              ),
              CustomButton(
                title: AppHelpers.getTranslation('save_stocks'),
                isLoading: state.isSaving,
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    event.updateStocks(
                      uuid: widget.product.uuid,
                      updated: () {
                        foodsEvent.fetchProducts(
                          isRefresh: true,
                          categoryId: categoriesState.activeIndex == 1
                              ? null
                              : categoriesState
                                  .categories[categoriesState.activeIndex - 2]
                                  .id,
                        );
                        AppHelpers.showCheckTopSnackBarDone(
                          context,
                          AppHelpers.getTranslation(
                              TrKeys.successfullyUpdated),
                        );
                        context.maybePop();
                      },
                      failed: () => AppHelpers.showCheckTopSnackBar(
                        context,
                        AppHelpers.getTranslation(TrKeys.updateFailed),
                      ),
                    );
                  }
                },
              ),
              12.verticalSpace,
            ],
          );
        },
      ),
    );
  }
}
