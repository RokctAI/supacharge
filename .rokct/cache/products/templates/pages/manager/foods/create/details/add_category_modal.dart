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
import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import 'food_categories_modal.dart';
import 'package:base_sdk/src/presentation/components/buttons/custom_button.dart';
import 'package:base_sdk/src/presentation/components/title_icon.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:products_sdk/src/manager/application/foods/create/details/category/add/add_category_provider.dart';
import 'package:products_sdk/src/manager/application/foods/create/details/category/add_food_categories_provider.dart';
import 'package:products_sdk/src/manager/utils/seller_form_helpers.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_drag.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_wrap.dart';
import 'package:base_sdk/src/presentation/components/text_fields/underlined_text_field.dart';

class AddCategoryModal extends StatefulWidget {
  const AddCategoryModal({super.key});

  @override
  State<AddCategoryModal> createState() => _AddCategoryModalState();
}

class _AddCategoryModalState extends State<AddCategoryModal> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return ModalWrap(
      body: Padding(
        padding: REdgeInsets.symmetric(horizontal: 16),
        child: Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(addCategoryProvider);
            final event = ref.read(addCategoryProvider.notifier);
            return Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ModalDrag(),
                  TitleAndIcon(
                    title: AppHelpers.getTranslation(TrKeys.addNewCategory),
                  ),
                  24.verticalSpace,
                  Consumer(
                    builder: (context, ref, child) {
                      return UnderlinedTextField(
                        textController: ref
                            .watch(addFoodCategoriesProvider)
                            .categorySubController,
                        label:
                            '${AppHelpers.getTranslation(TrKeys.subShopCategory)}*',
                        suffixIcon: Icon(
                          Remix.arrow_down_s_line,
                          color: AppStyle.blackColor,
                          size: 18.r,
                        ),
                        readOnly: true,
                        validator: SellerFormValidators.emptyCheck,
                        onTap: () => AppHelpers.showCustomModalBottomSheet(
                          paddingTop: MediaQuery.paddingOf(context).top + 100.h,
                          context: context,
                          modal: const FoodCategoriesModal(isSubCategory: true),
                          isDarkMode: false,
                        ),
                      );
                    },
                  ),
                  24.verticalSpace,
                  UnderlinedTextField(
                    label: AppHelpers.getTranslation(TrKeys.categoryName),
                    inputType: TextInputType.text,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    onChanged: event.setTitle,
                    validator: SellerFormValidators.emptyCheck,
                  ),
                  24.verticalSpace,
                  UnderlinedTextField(
                    label: AppHelpers.getTranslation(TrKeys.input),
                    inputType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onChanged: event.setInput,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  36.verticalSpace,
                  CustomButton(
                    title: AppHelpers.getTranslation(TrKeys.save),
                    isLoading: state.isLoading,
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        event.createCategory(
                          success: () {
                            ref
                                .read(addFoodCategoriesProvider.notifier)
                                .updateCategories();
                            Navigator.pop(context);
                            AppHelpers.showAlertDialog(
                              context: context,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    AppHelpers.getTranslation(
                                      TrKeys.thanksForCategory,
                                    ),
                                    style: AppStyle.interNormal(),
                                    textAlign: TextAlign.center,
                                  ),
                                  16.verticalSpace,
                                  if (AppHelpers.getAppPhone() != null)
                                    CustomButton(
                                      title: AppHelpers.getAppPhone() ?? "",
                                      onPressed: () {
                                        final Uri launchUri = Uri(
                                          scheme: 'tel',
                                          path: AppHelpers.getAppPhone(),
                                        );
                                        launchUrl(launchUri);
                                      },
                                    ),
                                ],
                              ),
                            );
                          },
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
