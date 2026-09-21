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

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'create_addon_units_modal.dart';
import 'package:base_sdk/src/presentation/components/buttons/custom_button.dart';
import 'package:base_sdk/src/presentation/components/keyboard_dismisser.dart';
import 'package:base_sdk/src/presentation/components/title_icon.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:products_sdk/src/manager/application/addons/addons_provider.dart';
import 'package:products_sdk/src/manager/application/addons/create/create_addon_provider.dart';
import 'package:products_sdk/src/manager/application/addons/create/units/create_addon_units_provider.dart';
import 'package:products_sdk/src/manager/utils/seller_form_helpers.dart';
import 'package:base_sdk/src/presentation/components/custom_toggle3.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_drag.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_wrap.dart';
import 'package:base_sdk/src/presentation/components/text_fields/underlined_text_field.dart';

/// Opened by the merchants_sdk home shell's FAB when the foods tab is on
/// "addons" — `CreateAddonModal` at this install path is main_page.dart's
/// import contract.
class CreateAddonModal extends ConsumerStatefulWidget {
  const CreateAddonModal({super.key});

  @override
  ConsumerState<CreateAddonModal> createState() => _CreateAddonModalState();
}

class _CreateAddonModalState extends ConsumerState<CreateAddonModal> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(createAddonProvider.notifier).updateAddonInfo(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardDismisser(
      child: ModalWrap(
        body: Padding(
          padding: REdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const ModalDrag(),
              TitleAndIcon(title: AppHelpers.getTranslation(TrKeys.addons)),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final state = ref.watch(createAddonProvider);
                    final unitState = ref.watch(createAddonUnitsProvider);
                    final event = ref.read(createAddonProvider.notifier);
                    final addonsEvent = ref.read(addonsProvider.notifier);
                    return Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: [
                                  24.verticalSpace,
                                  UnderlinedTextField(
                                    label:
                                        '${AppHelpers.getTranslation(TrKeys.title)}*',
                                    inputType: TextInputType.text,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    textInputAction: TextInputAction.next,
                                    onChanged: event.setTitle,
                                    validator: SellerFormValidators.emptyCheck,
                                  ),
                                  24.verticalSpace,
                                  UnderlinedTextField(
                                    label:
                                        '${AppHelpers.getTranslation(TrKeys.description)}*',
                                    inputType: TextInputType.text,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    textInputAction: TextInputAction.next,
                                    onChanged: event.setDescription,
                                    validator: SellerFormValidators.emptyCheck,
                                  ),
                                  24.verticalSpace,
                                  Consumer(
                                    builder: (context, ref, child) {
                                      return UnderlinedTextField(
                                        textController:
                                            unitState.unitController,
                                        label:
                                            '${AppHelpers.getTranslation(TrKeys.units)}*',
                                        suffixIcon: Icon(
                                          Remix.arrow_down_s_line,
                                          color: AppStyle.blackColor,
                                          size: 18.r,
                                        ),
                                        readOnly: true,
                                        validator:
                                            SellerFormValidators.emptyCheck,
                                        onTap: () =>
                                            AppHelpers.showCustomModalBottomSheet(
                                              paddingTop:
                                                  MediaQuery.of(
                                                    context,
                                                  ).padding.top +
                                                  300.h,
                                              context: context,
                                              modal:
                                                  const CreateAddonUnitsModal(),
                                              isDarkMode: false,
                                            ),
                                      );
                                    },
                                  ),
                                  24.verticalSpace,
                                  UnderlinedTextField(
                                    label:
                                        '${AppHelpers.getTranslation(TrKeys.tax)}*',
                                    inputType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                    onChanged: event.setTax,
                                    validator: SellerFormValidators.minQtyCheck,
                                  ),
                                  24.verticalSpace,
                                  UnderlinedTextField(
                                    label: AppHelpers.getTranslation(
                                      TrKeys.sku,
                                    ),
                                    inputType: TextInputType.text,
                                    textInputAction: TextInputAction.done,
                                    onChanged: event.setBarcode,
                                  ),
                                  24.verticalSpace,
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: UnderlinedTextField(
                                          label:
                                              '${AppHelpers.getTranslation(TrKeys.price)}*',
                                          inputType: TextInputType.number,
                                          textInputAction: TextInputAction.next,
                                          onChanged: event.setPrice,
                                          validator:
                                              SellerFormValidators.minQtyCheck,
                                        ),
                                      ),
                                      10.horizontalSpace,
                                      Expanded(
                                        child: UnderlinedTextField(
                                          label:
                                              '${AppHelpers.getTranslation(TrKeys.quantity)}*',
                                          inputType: TextInputType.number,
                                          textInputAction: TextInputAction.next,
                                          onChanged: event.setQuantity,
                                          validator:
                                              SellerFormValidators.minQtyCheck,
                                        ),
                                      ),
                                    ],
                                  ),
                                  24.verticalSpace,
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        AppHelpers.getTranslation(
                                          TrKeys.active,
                                        ),
                                        style: AppStyle.interNormal(
                                          size: 14.sp,
                                          letterSpacing: -0.3,
                                          color: AppStyle.blackColor,
                                        ),
                                      ),
                                      CustomToggle(
                                        controller: ValueNotifier<bool>(true),
                                        onChange: event.setActive,
                                      ),
                                    ],
                                  ),
                                  24.verticalSpace,
                                ],
                              ),
                            ),
                          ),
                          CustomButton(
                            title: AppHelpers.getTranslation(TrKeys.save),
                            isLoading: state.isLoading,
                            onPressed: () {
                              if (_formKey.currentState?.validate() ?? false) {
                                event.createAddon(
                                  unitId:
                                      unitState.units[unitState.activeIndex].id,
                                  created: () {
                                    AppHelpers.showCheckTopSnackBarDone(
                                      context,
                                      AppHelpers.getTranslation(
                                        TrKeys.successfullyCreated,
                                      ),
                                    );
                                    addonsEvent.refreshAddons();
                                    context.router.popUntilRoot();
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
            ],
          ),
        ),
      ),
    );
  }
}
