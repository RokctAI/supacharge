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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:remixicon/remixicon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

import 'working_time_modal.dart';
import 'package:${package}/presentation/routes/app_router.dart';
import 'package:${package}/presentation/component/helper/horizontal_image_picker.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_drag.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_wrap.dart';
import 'package:base_sdk/src/presentation/components/helper/shop_bordered_avatar.dart';
import 'package:base_sdk/src/presentation/components/text_fields/underlined_text_field.dart';
import 'package:${package}/presentation/components/restaurant/small_weekday_item.dart';
import 'package:${package}/presentation/pages/main/widgets/buttons_bouncing_effect.dart';
import 'package:base_sdk/src/constants/app_constants.dart';
import 'package:base_sdk/src/models/data/shop_data.dart';
import 'package:base_sdk/src/presentation/components/blur_wrap.dart';
import 'package:base_sdk/src/presentation/components/buttons/custom_button.dart';
import 'package:base_sdk/src/presentation/components/keyboard_dismisser.dart';
import 'package:base_sdk/src/presentation/components/title_icon.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/app_validators.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:merchants_sdk/src/manager/application/restaurant/restaurant_provider.dart';
import 'package:merchants_sdk/src/manager/application/restaurant/working_days/working_days_provider.dart';

// Ported from paas_manager lib/presentation/pages/restaurant/widgets/
// edit_restaurant_modal.dart. Deltas: KeyboardDisable -> base_sdk's
// KeyboardDismisser; AppValidators.emptyCheck -> isNotEmptyValidator (the
// base name); the delivery-zone row routes to zones_sdk's installed
// ManagerDeliveryZoneRoute (zones_sdk owns the zone page — S-1/S-1b); the
// phone-field UI gate reads AppConstants.isSpecificNumberEnabled (base_sdk
// 1.8.0, remote-config-overridable per paas_manager#28).
class EditRestaurantModal extends ConsumerStatefulWidget {
  const EditRestaurantModal({super.key});

  @override
  ConsumerState<EditRestaurantModal> createState() =>
      _EditRestaurantModalState();
}

class _EditRestaurantModalState extends ConsumerState<EditRestaurantModal> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return KeyboardDismisser(
      child: ModalWrap(
        body: Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(restaurantProvider);
            final event = ref.read(restaurantProvider.notifier);
            final workingDayEvent = ref.read(workingDaysProvider.notifier);
            PhoneNumber? shopNumber;
            try {
              shopNumber = PhoneNumber.fromCompleteNumber(
                completeNumber: "+${state.shop?.phone?.replaceAll('+', "")}",
              );
            } catch (e) {
              debugPrint(e.toString());
            }
            return state.shop == null
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3.r,
                      color: AppStyle.primary,
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Padding(
                            padding: REdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                const ModalDrag(),
                                TitleAndIcon(
                                  title: AppHelpers.getTranslation(
                                    TrKeys.restaurantSettings,
                                  ),
                                ),
                                24.verticalSpace,
                                HorizontalImagePicker(
                                  onImageChange: event.setBackgroundImageFile,
                                  onDelete: () =>
                                      event.setBackgroundImageFile(null),
                                  imageFilePath: state.backgroundImageFile,
                                  imageUrl: state.shop?.backgroundImg,
                                ),
                                24.verticalSpace,
                                Row(
                                  children: [
                                    ButtonsBouncingEffect(
                                      child: GestureDetector(
                                        onTap: () async {
                                          XFile? file;
                                          try {
                                            file = await ImagePicker()
                                                .pickImage(
                                                  source: ImageSource.gallery,
                                                );
                                          } catch (ex) {
                                            debugPrint(
                                              '===> trying to select image $ex',
                                            );
                                          }
                                          if (file != null) {
                                            event.setLogoImageFile(file.path);
                                          }
                                        },
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            state.logoImageFile != null
                                                ? BlurWrap(
                                                    radius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                    child: Container(
                                                      width: 50.r,
                                                      height: 50.r,
                                                      color: AppStyle.blackColor
                                                          .withOpacity(0.27),
                                                      alignment:
                                                          Alignment.center,
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20.r,
                                                            ),
                                                        child: Image.file(
                                                          File(
                                                            state
                                                                .logoImageFile!,
                                                          ),
                                                          width: 40.r,
                                                          height: 40.r,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : ShopBorderedAvatar(
                                                    size: 50,
                                                    imageSize: 40,
                                                    imageUrl:
                                                        state.shop?.logoImg,
                                                    borderRadius: 16,
                                                    bgColor: AppStyle.blackColor
                                                        .withOpacity(0.27),
                                                  ),
                                            Icon(
                                              Remix.camera_fill,
                                              color: AppStyle.white,
                                              size: 20.r,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    16.horizontalSpace,
                                    Expanded(
                                      child: UnderlinedTextField(
                                        initialText:
                                            state.shop?.translation?.title,
                                        label: AppHelpers.getTranslation(
                                          TrKeys.restaurantName,
                                        ),
                                        onChanged: event.setTitle,
                                        validator:
                                            AppValidators.isNotEmptyValidator,
                                      ),
                                    ),
                                  ],
                                ),
                                24.verticalSpace,
                                UnderlinedTextField(
                                  initialText:
                                      state.shop?.translation?.description,
                                  label: AppHelpers.getTranslation(
                                    TrKeys.description,
                                  ),
                                  onChanged: event.setDescription,
                                  validator: AppValidators.isNotEmptyValidator,
                                ),
                                24.verticalSpace,
                                if (AppConstants.isSpecificNumberEnabled)
                                  IntlPhoneField(
                                    disableLengthCheck:
                                        !AppConstants.isNumberLengthAlwaysSame,
                                    onChanged: (phoneNum) {
                                      event.setPhone(phoneNum.completeNumber);
                                    },
                                    validator: (s) {
                                      if (AppConstants
                                              .isNumberLengthAlwaysSame &&
                                          (s?.isValidNumber() ?? true)) {
                                        return AppHelpers.getTranslation(
                                          TrKeys.phoneNumberIsNotValid,
                                        );
                                      }
                                      return null;
                                    },
                                    keyboardType: TextInputType.phone,
                                    initialCountryCode: shopNumber == null
                                        ? (shopNumber?.isValidNumber() ?? false)
                                              ? shopNumber?.countryISOCode
                                              : AppConstants.countryCodeISO
                                        : AppConstants.countryCodeISO,
                                    initialValue: shopNumber == null
                                        ? (shopNumber?.isValidNumber() ?? false)
                                              ? shopNumber?.number
                                              : state.shop?.phone
                                        : "",
                                    invalidNumberMessage:
                                        AppHelpers.getTranslation(
                                          TrKeys.phoneNumberIsNotValid,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    showCountryFlag: AppConstants.showFlag,
                                    showDropdownIcon:
                                        AppConstants.showArrowIcon,
                                    autovalidateMode:
                                        AppConstants.isNumberLengthAlwaysSame
                                        ? AutovalidateMode.onUserInteraction
                                        : AutovalidateMode.disabled,
                                    textAlignVertical: TextAlignVertical.center,
                                    decoration: InputDecoration(
                                      counterText: '',
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide.merge(
                                          const BorderSide(
                                            color: AppStyle.differBorderColor,
                                          ),
                                          const BorderSide(
                                            color: AppStyle.differBorderColor,
                                          ),
                                        ),
                                      ),
                                      errorBorder: UnderlineInputBorder(
                                        borderSide: BorderSide.merge(
                                          const BorderSide(
                                            color: AppStyle.differBorderColor,
                                          ),
                                          const BorderSide(
                                            color: AppStyle.differBorderColor,
                                          ),
                                        ),
                                      ),
                                      border: const UnderlineInputBorder(),
                                      focusedErrorBorder:
                                          const UnderlineInputBorder(),
                                      disabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide.merge(
                                          const BorderSide(
                                            color: AppStyle.differBorderColor,
                                          ),
                                          const BorderSide(
                                            color: AppStyle.differBorderColor,
                                          ),
                                        ),
                                      ),
                                      focusedBorder:
                                          const UnderlineInputBorder(),
                                    ),
                                  ),
                                if (!AppConstants.isSpecificNumberEnabled)
                                  UnderlinedTextField(
                                    initialText: state.shop?.phone,
                                    label: AppHelpers.getTranslation(
                                      TrKeys.phoneNumber,
                                    ),
                                    onChanged: event.setPhone,
                                    validator:
                                        AppValidators.isNotEmptyValidator,
                                  ),
                                24.verticalSpace,
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              16.horizontalSpace,
                              Text(
                                AppHelpers.getTranslation(TrKeys.orderPayment),
                                style: AppStyle.interNormal(),
                              ),
                              18.horizontalSpace,
                              DropdownButton(
                                // The legacy state defaulted to the shop's
                                // order_payment; until the backend returns
                                // it (recorded gap) fall back to 'before' so
                                // the dropdown always has a valid value.
                                value: state.orderPayment ?? 'before',
                                borderRadius: BorderRadius.circular(10.r),
                                items: [
                                  DropdownMenuItem(
                                    value: "before",
                                    child: Text(
                                      AppHelpers.getTranslation(TrKeys.before),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: "after",
                                    child: Text(
                                      AppHelpers.getTranslation(TrKeys.after),
                                    ),
                                  ),
                                ],
                                onChanged: (s) {
                                  if (s == null) return;
                                  event.setPayment(s);
                                },
                              ),
                            ],
                          ),
                          const Divider(),
                          GestureDetector(
                            onTap: () {
                              workingDayEvent.changeIndex(null);
                              AppHelpers.showCustomModalBottomSheet(
                                paddingTop: MediaQuery.paddingOf(context).top,
                                context: context,
                                modal: const WorkingTimeModal(),
                                isDarkMode: false,
                              );
                            },
                            child: Container(
                              color: AppStyle.transparent,
                              child: Padding(
                                padding: REdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(
                                      Remix.time_fill,
                                      size: 18.r,
                                      color: AppStyle.blackColor,
                                    ),
                                    8.horizontalSpace,
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppHelpers.getTranslation(
                                            TrKeys.workingHours,
                                          ),
                                          style: AppStyle.interNormal(
                                            size: 12.sp,
                                            color: AppStyle.blackColor,
                                          ),
                                        ),
                                        4.verticalSpace,
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            ...(state.shop?.shopWorkingDays ??
                                                    [])
                                                .map(
                                                  (ShopWorkingDay day) =>
                                                      Padding(
                                                        padding:
                                                            REdgeInsets.only(
                                                              right: 4,
                                                            ),
                                                        child: SmallWeekdayItem(
                                                          isSelected:
                                                              !(day.disabled ??
                                                                  false),
                                                          day: day,
                                                          size: 30,
                                                          fontSize: 11,
                                                          borderRadius: 6,
                                                        ),
                                                      ),
                                                ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Remix.arrow_right_s_line,
                                      size: 24.r,
                                      color: AppStyle.blackColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Divider(),
                          GestureDetector(
                            onTap: () => context.pushRoute(
                              const ManagerDeliveryZoneRoute(),
                            ),
                            child: Container(
                              color: AppStyle.transparent,
                              child: Padding(
                                padding: REdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(Remix.navigation_fill, size: 20.r),
                                    8.horizontalSpace,
                                    Text(
                                      AppHelpers.getTranslation(
                                        TrKeys.deliveryZone,
                                      ),
                                      style: AppStyle.interNormal(
                                        size: 12.sp,
                                        color: AppStyle.blackColor,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Remix.arrow_right_s_line,
                                      size: 24.r,
                                      color: AppStyle.blackColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Divider(),
                          24.verticalSpace,
                          Padding(
                            padding: REdgeInsets.all(16),
                            child: CustomButton(
                              title: AppHelpers.getTranslation(TrKeys.save),
                              isLoading: state.isLoading,
                              onPressed: () {
                                if (_formKey.currentState?.validate() ??
                                    false) {
                                  event.updateShop(
                                    context,
                                    updateSuccess: context.maybePop,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
          },
        ),
      ),
    );
  }
}
