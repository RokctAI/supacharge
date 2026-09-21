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
import 'package:remixicon/remixicon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'add_category_modal.dart';
import 'package:base_sdk/src/presentation/components/title_icon.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:products_sdk/src/manager/application/foods/create/details/category/add_food_categories_provider.dart';
import 'package:products_sdk/src/manager/application/foods/food_categories_provider.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_drag.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_wrap.dart';
import 'package:${package}/presentation/components/foods/food_category_item.dart';

class FoodCategoriesModal extends ConsumerStatefulWidget {
  final bool isSubCategory;

  const FoodCategoriesModal({super.key, this.isSubCategory = false});

  @override
  ConsumerState<FoodCategoriesModal> createState() =>
      _FoodCategoriesModalState();
}

class _FoodCategoriesModalState extends ConsumerState<FoodCategoriesModal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isSubCategory) {
        ref.read(addFoodCategoriesProvider.notifier).updateCategoriesSub();
      }
      ref
          .read(addFoodCategoriesProvider.notifier)
          .setCategories(ref.watch(foodCategoriesProvider).categories);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ModalWrap(
      body: Column(
        children: [
          const ModalDrag(),
          if (!widget.isSubCategory)
            GestureDetector(
              onTap: () => AppHelpers.showCustomModalBottomSheet(
                context: context,
                paddingTop: 100,
                modal: const AddCategoryModal(),
                isDarkMode: false,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Remix.play_list_add_line,
                    color: AppStyle.blue,
                    size: 18.r,
                  ),
                  10.horizontalSpace,
                  Text(
                    AppHelpers.getTranslation(TrKeys.addNewCategory),
                    style: AppStyle.interSemi(
                      size: 14,
                      color: AppStyle.blue,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          16.verticalSpace,
          Divider(
            color: AppStyle.orderStatusProgressBack,
            height: 1.r,
            thickness: 1.r,
          ),
          24.verticalSpace,
          Expanded(
            child: Padding(
              padding: REdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    TitleAndIcon(
                      title: AppHelpers.getTranslation(TrKeys.categories),
                      titleSize: 16,
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final state = ref.watch(addFoodCategoriesProvider);
                        return ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: widget.isSubCategory
                              ? state.categoriesSub.length
                              : state.categories.length,
                          itemBuilder: (context, index) {
                            return FoodCategoryItem(
                              category: widget.isSubCategory
                                  ? state.categoriesSub[index]
                                  : state.categories[index],
                              onTap: () {
                                widget.isSubCategory
                                    ? ref
                                          .read(
                                            addFoodCategoriesProvider.notifier,
                                          )
                                          .setActiveIndexSub(index)
                                    : ref
                                          .read(
                                            addFoodCategoriesProvider.notifier,
                                          )
                                          .setActiveIndex(index);
                                Navigator.pop(context);
                              },
                              isSelected:
                                  (widget.isSubCategory
                                      ? state.activeSubIndex
                                      : state.activeIndex) ==
                                  index,
                              onDelete:
                                  (widget.isSubCategory
                                          ? state.categoriesSub[index].shopId
                                          : state.categories[index].shopId) ==
                                      // Shop ids are shop_name docname
                                      // strings, never ints.
                                      LocalStorage.getShopJson()?['id']
                                          ?.toString()
                                  ? () {
                                      ref
                                          .read(
                                            addFoodCategoriesProvider.notifier,
                                          )
                                          .deleteCategories(
                                            state.categories[index],
                                          );
                                    }
                                  : null,
                            );
                          },
                        );
                      },
                    ),
                    20.verticalSpace,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
