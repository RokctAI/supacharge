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

import 'edit_food_units_modal.dart';
import 'edit_food_categories_modal.dart';
import '../../widgets/food_kitchens_modal.dart';
import 'package:base_sdk/src/presentation/components/buttons/custom_button.dart';
import 'package:base_sdk/src/presentation/components/keyboard_dismisser.dart';
import 'package:base_sdk/src/presentation/components/loading.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:base_sdk/src/models/data/translation.dart';
import 'package:kitchen_sdk/src/common/infrastructure/models/data/kitchen_data.dart';
import 'package:kitchen_sdk/src/manager/application/kitchens/kitchen_picker_provider.dart';
import 'package:products_sdk/src/manager/application/foods/edit/details/category/edit_food_categories_provider.dart';
import 'package:products_sdk/src/manager/application/foods/edit/details/edit_food_details_provider.dart';
import 'package:products_sdk/src/manager/application/foods/edit/details/units/edit_food_units_provider.dart';
import 'package:products_sdk/src/manager/application/foods/foods_provider.dart';
import 'package:products_sdk/src/manager/utils/seller_form_helpers.dart';
import 'package:base_sdk/src/presentation/components/custom_toggle3.dart';
import 'package:base_sdk/src/presentation/components/text_fields/underlined_text_field.dart';
import 'package:${package}/presentation/components/foods/multi_image_picker.dart';

/// The DETAILS section of the approved edit form (frames 35b/35d): the
/// shipped form FIELD FOR FIELD — images, title*, description*, the three
/// pickers, interval/min/max sharing a row, tax beside COST PRICE (with its
/// "feeds profit" helper — the 14:51Z profitability groundwork), the two
/// toggles, its own save — presentation regrouped per the approved frames,
/// logic and validation untouched (same notifier, same validators, same
/// satellite picker sheets).
///
/// Seeds kitchen_sdk's autoDispose picker here (not at the tap that opened
/// this form): this body's `watch` keeps the provider alive for the whole
/// edit session, and the seed converts products_sdk's minimal
/// `SellerProductKitchen` into kitchen_sdk's `KitchenModel` at this
/// host-template boundary — exactly the conversion ADR-005 assigns to the
/// host.
class EditFoodDetailsBody extends ConsumerStatefulWidget {
  final Function() onSave;
  final ScrollController controller;

  const EditFoodDetailsBody({
    super.key,
    required this.onSave,
    required this.controller,
  });

  @override
  ConsumerState<EditFoodDetailsBody> createState() =>
      _EditFoodDetailsBodyState();
}

class _EditFoodDetailsBodyState extends ConsumerState<EditFoodDetailsBody> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final kitchen = ref.read(editFoodDetailsProvider).product?.kitchen;
      if (kitchen != null) {
        ref
            .read(kitchenPickerProvider.notifier)
            .initialise(
              selected: KitchenModel(
                id: kitchen.id,
                translation: Translation(title: kitchen.title),
              ),
            );
      }
    });
  }

  Icon get _chevron => Icon(
        Remix.arrow_down_s_line,
        color: AppStyle.textPrimary,
        size: 18.r,
      );

  @override
  Widget build(BuildContext context) {
    return KeyboardDismisser(
      child: SingleChildScrollView(
        controller: widget.controller,
        physics: const BouncingScrollPhysics(),
        child: Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(editFoodDetailsProvider);
            final categoryState = ref.watch(editFoodCategoriesProvider);
            final unitState = ref.watch(editFoodUnitsProvider);
            final kitchenState = ref.watch(kitchenPickerProvider);
            final event = ref.read(editFoodDetailsProvider.notifier);
            final foodsEvent = ref.read(foodsProvider.notifier);
            return state.product == null
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3.r,
                      color: AppStyle.primary,
                    ),
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        16.verticalSpace,
                        state.isLoading
                            ? const Loading()
                            : MultiImagePicker(
                                imageUrls: state.listOfUrls,
                                listOfImages: state.images,
                                onImageChange: event.setImageFile,
                                onDelete: event.deleteImage,
                              ),
                        20.verticalSpace,
                        UnderlinedTextField(
                          label:
                              '${AppHelpers.getTranslation(TrKeys.productTitle)}*',
                          inputType: TextInputType.text,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          onChanged: event.setTitle,
                          initialText: state.product?.translation?.title,
                          validator: SellerFormValidators.emptyCheck,
                        ),
                        20.verticalSpace,
                        UnderlinedTextField(
                          label:
                              '${AppHelpers.getTranslation(TrKeys.description)}*',
                          inputType: TextInputType.text,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          onChanged: event.setDescription,
                          initialText:
                              state.product?.translation?.description,
                          validator: SellerFormValidators.emptyCheck,
                        ),
                        20.verticalSpace,
                        UnderlinedTextField(
                          textController: categoryState.categoriesController,
                          label:
                              '${AppHelpers.getTranslation(TrKeys.productCategory)}*',
                          suffixIcon: _chevron,
                          readOnly: true,
                          onTap: () => AppHelpers.showCustomModalBottomSheet(
                            paddingTop:
                                MediaQuery.paddingOf(context).top + 100.h,
                            context: context,
                            modal: const EditFoodCategoriesModal(),
                            isDarkMode: false,
                          ),
                          validator: SellerFormValidators.emptyCheck,
                        ),
                        20.verticalSpace,
                        // Units | Kitchen share a row (approved 35b/35d).
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: UnderlinedTextField(
                                textController: unitState.unitController,
                                label:
                                    '${AppHelpers.getTranslation(TrKeys.units)}*',
                                suffixIcon: _chevron,
                                readOnly: true,
                                onTap: () =>
                                    AppHelpers.showCustomModalBottomSheet(
                                  paddingTop:
                                      MediaQuery.paddingOf(context).top +
                                          250.h,
                                  context: context,
                                  modal: const EditFoodUnitsModal(),
                                  isDarkMode: false,
                                ),
                                validator: SellerFormValidators.emptyCheck,
                              ),
                            ),
                            10.horizontalSpace,
                            Expanded(
                              child: UnderlinedTextField(
                                textController:
                                    kitchenState.kitchenController,
                                label:
                                    AppHelpers.getTranslation(TrKeys.kitchen),
                                suffixIcon: _chevron,
                                readOnly: true,
                                onTap: () =>
                                    AppHelpers.showCustomModalBottomSheet(
                                  paddingTop:
                                      MediaQuery.paddingOf(context).top +
                                          250.h,
                                  context: context,
                                  modal: const FoodKitchensModal(),
                                  isDarkMode: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                        20.verticalSpace,
                        // Interval | Min | Max on one line (approved 35b).
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: UnderlinedTextField(
                                label:
                                    '${AppHelpers.getTranslation(TrKeys.interval)}*',
                                inputType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                onChanged: event.setInterval,
                                initialText: (state.product?.interval ?? 1)
                                    .toString(),
                                validator: SellerFormValidators.emptyCheck,
                              ),
                            ),
                            10.horizontalSpace,
                            Expanded(
                              child: UnderlinedTextField(
                                label:
                                    '${AppHelpers.getTranslation(TrKeys.minQuantity)}*',
                                inputType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                initialText:
                                    state.product?.minQty.toString() ?? '',
                                onChanged: event.setMinQty,
                                validator: SellerFormValidators.emptyCheck,
                              ),
                            ),
                            10.horizontalSpace,
                            Expanded(
                              child: UnderlinedTextField(
                                label:
                                    '${AppHelpers.getTranslation(TrKeys.maxQuantity)}*',
                                inputType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                initialText:
                                    state.product?.maxQty.toString() ?? '',
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
                        20.verticalSpace,
                        // Tax beside COST PRICE with its helper line —
                        // manager-only: cost never renders on customer
                        // surfaces (this template installs only under
                        // app_type=manager).
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: UnderlinedTextField(
                                label:
                                    '${AppHelpers.getTranslation(TrKeys.tax)}*',
                                inputType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                initialText: state.tax,
                                onChanged: event.setTax,
                                validator: SellerFormValidators.emptyCheck,
                              ),
                            ),
                            10.horizontalSpace,
                            Expanded(
                              child: UnderlinedTextField(
                                label: AppHelpers.getTranslation(
                                  TrKeys.costPrice,
                                ),
                                inputType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                initialText: state.costPrice,
                                onChanged: event.setCostPrice,
                                descriptionText: AppHelpers.getTranslation(
                                  'feeds_profit_on_every_sale_set_it_to_see_margins',
                                ),
                              ),
                            ),
                          ],
                        ),
                        20.verticalSpace,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppHelpers.getTranslation(TrKeys.showProduct),
                              style: AppStyle.interNormal(
                                size: 14.sp,
                                letterSpacing: -0.3,
                                color: AppStyle.textPrimary,
                              ),
                            ),
                            CustomToggle(
                              controller: ValueNotifier<bool>(state.active),
                              onChange: event.setActive,
                            ),
                          ],
                        ),
                        16.verticalSpace,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppHelpers.getTranslation(TrKeys.adultsOnly),
                              style: AppStyle.interNormal(
                                size: 14.sp,
                                letterSpacing: -0.3,
                                color: AppStyle.textPrimary,
                              ),
                            ),
                            CustomToggle(
                              controller: ValueNotifier<bool>(state.isAdult),
                              onChange: event.setIsAdult,
                            ),
                          ],
                        ),
                        32.verticalSpace,
                        CustomButton(
                          title: AppHelpers.getTranslation('save_details'),
                          isLoading: state.isLoading,
                          onPressed: () {
                            if (_formKey.currentState?.validate() ?? false) {
                              event.updateProduct(
                                unit: unitState.foodUnit,
                                kitchenId: kitchenState.selected?.id,
                                category: categoryState.foodCategory,
                                updated: (product) {
                                  widget.onSave();
                                  AppHelpers.showCheckTopSnackBarDone(
                                    context,
                                    AppHelpers.getTranslation(
                                      TrKeys.successfullyUpdated,
                                    ),
                                  );
                                  foodsEvent.updateSingleProduct(product);
                                },
                                failed: () => AppHelpers.showCheckTopSnackBar(
                                  context,
                                  AppHelpers.getTranslation(
                                    TrKeys.updateFailed,
                                  ),
                                ),
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
    );
  }
}
