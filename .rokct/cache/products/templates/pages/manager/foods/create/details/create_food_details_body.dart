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

import 'food_categories_modal.dart';
import 'create_food_units_modal.dart';
import '../../widgets/food_kitchens_modal.dart';
import 'package:base_sdk/src/presentation/components/buttons/custom_button.dart';
import 'package:base_sdk/src/presentation/components/keyboard_dismisser.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:kitchen_sdk/src/manager/application/kitchens/kitchen_picker_provider.dart';
import 'package:products_sdk/src/manager/application/foods/create/details/category/add_food_categories_provider.dart';
import 'package:products_sdk/src/manager/application/foods/create/details/create_food_details_provider.dart';
import 'package:products_sdk/src/manager/application/foods/create/details/units/create_food_units_provider.dart';
import 'package:products_sdk/src/manager/application/foods/food_categories_provider.dart';
import 'package:products_sdk/src/manager/application/foods/foods_provider.dart';
import 'package:products_sdk/src/manager/utils/seller_form_helpers.dart';
import 'package:base_sdk/src/presentation/components/custom_toggle3.dart';
import 'package:base_sdk/src/presentation/components/text_fields/underlined_text_field.dart';
import 'package:${package}/presentation/components/foods/multi_image_picker.dart';

class CreateFoodDetailsBody extends StatefulWidget {
  final Function() onSave;

  /// True when this body sits on the dark pushed page (the 35b add moment,
  /// ProductEditPage): the picker chevrons and toggle labels take the
  /// mode-resolving ink. False (the default) keeps the shipped bottom-sheet
  /// look untouched.
  final bool dark;

  const CreateFoodDetailsBody({
    super.key,
    required this.onSave,
    this.dark = false,
  });

  @override
  State<CreateFoodDetailsBody> createState() => _CreateFoodDetailsBodyState();
}

class _CreateFoodDetailsBodyState extends State<CreateFoodDetailsBody> {
  final _formKey = GlobalKey<FormState>();

  Color get _ink => widget.dark ? AppStyle.textPrimary : AppStyle.blackColor;

  @override
  Widget build(BuildContext context) {
    return KeyboardDismisser(
      child: Padding(
        padding: REdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(createFoodDetailsProvider);
              final categoryState = ref.watch(addFoodCategoriesProvider);
              final unitState = ref.watch(createFoodUnitsProvider);
              final kitchenState = ref.watch(kitchenPickerProvider);
              final categoriesState = ref.watch(foodCategoriesProvider);
              final event = ref.read(createFoodDetailsProvider.notifier);
              final foodsEvent = ref.read(foodsProvider.notifier);
              return Form(
                key: _formKey,
                child: Column(
                  children: [
                    24.verticalSpace,
                    MultiImagePicker(
                      imageUrls: state.listOfUrls,
                      listOfImages: state.images,
                      onImageChange: event.setImageFile,
                      onDelete: event.deleteImage,
                    ),
                    24.verticalSpace,
                    UnderlinedTextField(
                      label:
                          '${AppHelpers.getTranslation(TrKeys.productTitle)}*',
                      inputType: TextInputType.text,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      onChanged: event.setTitle,
                      validator: SellerFormValidators.emptyCheck,
                    ),
                    24.verticalSpace,
                    UnderlinedTextField(
                      label:
                          '${AppHelpers.getTranslation(TrKeys.description)}*',
                      inputType: TextInputType.text,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      onChanged: event.setDescription,
                      validator: SellerFormValidators.emptyCheck,
                    ),
                    24.verticalSpace,
                    Consumer(
                      builder: (context, ref, child) {
                        return UnderlinedTextField(
                          textController: categoryState.categoryController,
                          label:
                              '${AppHelpers.getTranslation(TrKeys.productCategory)}*',
                          suffixIcon: Icon(
                            Remix.arrow_down_s_line,
                            color: _ink,
                            size: 18.r,
                          ),
                          readOnly: true,
                          validator: SellerFormValidators.emptyCheck,
                          onTap: () => AppHelpers.showCustomModalBottomSheet(
                            paddingTop:
                                MediaQuery.paddingOf(context).top + 100.h,
                            context: context,
                            modal: const FoodCategoriesModal(),
                            isDarkMode: false,
                          ),
                        );
                      },
                    ),
                    24.verticalSpace,
                    Consumer(
                      builder: (context, ref, child) {
                        return UnderlinedTextField(
                          textController: unitState.unitController,
                          label: '${AppHelpers.getTranslation(TrKeys.units)}*',
                          suffixIcon: Icon(
                            Remix.arrow_down_s_line,
                            color: _ink,
                            size: 18.r,
                          ),
                          readOnly: true,
                          validator: SellerFormValidators.emptyCheck,
                          onTap: () => AppHelpers.showCustomModalBottomSheet(
                            paddingTop:
                                MediaQuery.paddingOf(context).top + 300.h,
                            context: context,
                            modal: const CreateFoodUnitsModal(),
                            isDarkMode: false,
                          ),
                        );
                      },
                    ),
                    24.verticalSpace,
                    Consumer(
                      builder: (context, ref, child) {
                        return UnderlinedTextField(
                          textController: kitchenState.kitchenController,
                          label: AppHelpers.getTranslation(TrKeys.kitchen),
                          suffixIcon: Icon(
                            Remix.arrow_down_s_line,
                            color: _ink,
                            size: 18.r,
                          ),
                          readOnly: true,
                          onTap: () => AppHelpers.showCustomModalBottomSheet(
                            paddingTop:
                                MediaQuery.paddingOf(context).top + 300.h,
                            context: context,
                            modal: const FoodKitchensModal(),
                            isDarkMode: false,
                          ),
                        );
                      },
                    ),
                    24.verticalSpace,
                    UnderlinedTextField(
                      label: '${AppHelpers.getTranslation(TrKeys.interval)}*',
                      inputType: TextInputType.number,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      onChanged: event.setInterval,
                      validator: SellerFormValidators.minQtyCheck,
                    ),
                    24.verticalSpace,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: UnderlinedTextField(
                            label:
                                '${AppHelpers.getTranslation(TrKeys.minQuantity)}*',
                            inputType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            onChanged: event.setMinQty,
                            validator: (value) =>
                                SellerFormValidators.minQtyCheck(value),
                          ),
                        ),
                        10.horizontalSpace,
                        Expanded(
                          child: UnderlinedTextField(
                            label:
                                '${AppHelpers.getTranslation(TrKeys.maxQuantity)}*',
                            inputType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            onChanged: event.setMaxQty,
                            validator: (value) =>
                                SellerFormValidators.maxQtyCheck(
                                  value,
                                  state.minQty,
                                ),
                          ),
                        ),
                      ],
                    ),
                    24.verticalSpace,
                    UnderlinedTextField(
                      label: '${AppHelpers.getTranslation(TrKeys.tax)}*',
                      inputType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onChanged: event.setTax,
                      validator: SellerFormValidators.emptyCheck,
                    ),
                    24.verticalSpace,
                    // Manager-only: cost price (optional). Never rendered on
                    // customer-facing surfaces — this template only installs
                    // under app_type=manager.
                    UnderlinedTextField(
                      label: AppHelpers.getTranslation(TrKeys.costPrice),
                      inputType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onChanged: event.setCostPrice,
                    ),
                    24.verticalSpace,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppHelpers.getTranslation(TrKeys.showProduct),
                          style: AppStyle.interNormal(
                            size: 14.sp,
                            letterSpacing: -0.3,
                            color: _ink,
                          ),
                        ),
                        CustomToggle(
                          controller: ValueNotifier<bool>(state.active),
                          onChange: event.setActive,
                        ),
                      ],
                    ),
                    24.verticalSpace,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppHelpers.getTranslation(TrKeys.adultsOnly),
                          style: AppStyle.interNormal(
                            size: 14.sp,
                            letterSpacing: -0.3,
                            color: _ink,
                          ),
                        ),
                        CustomToggle(
                          controller: ValueNotifier<bool>(state.isAdult),
                          onChange: event.setIsAdult,
                        ),
                      ],
                    ),
                    40.verticalSpace,
                    CustomButton(
                      title: AppHelpers.getTranslation(TrKeys.save),
                      isLoading: state.isCreating,
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          event.createProduct(
                            categoryId: categoryState
                                .categories[categoryState.activeIndex]
                                .id,
                            unitId: unitState.units[unitState.activeIndex].id,
                            kitchenId: kitchenState.selected?.id,
                            created: () {
                              widget.onSave();
                              AppHelpers.showCheckTopSnackBarDone(
                                context,
                                AppHelpers.getTranslation(
                                  TrKeys.successfullyCreated,
                                ),
                              );
                              foodsEvent.fetchProducts(
                                isRefresh: true,
                                categoryId: categoriesState.activeIndex == 1
                                    ? null
                                    : categoriesState
                                          .categories[categoriesState
                                                  .activeIndex -
                                              2]
                                          .id,
                              );
                            },
                            onError: () {},
                          );
                        }
                      },
                    ),
                    20.verticalSpace,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
