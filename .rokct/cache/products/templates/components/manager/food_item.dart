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
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:products_sdk/src/common/infrastructure/models/data/seller_product_data.dart';
import 'package:base_sdk/src/presentation/components/helper/common_image.dart';
import 'package:${package}/presentation/pages/main/widgets/buttons_bouncing_effect.dart';

/// The manager foods-tab product card, typed on products_sdk's
/// `SellerProductData`. orders_sdk installs a same-named sibling at
/// `components/orders/food_item.dart` typed on its own POS `ProductData` —
/// the two are the same legacy widget split by the per-SDK model split, and
/// they never meet in one import graph. Reconciling them onto one shared model
/// is a dedup-workstream item, not a compose blocker.
class FoodItem extends StatelessWidget {
  final SellerProductData product;
  final Function() onTap;
  final int spacing;

  const FoodItem({
    super.key,
    required this.product,
    required this.onTap,
    this.spacing = 1,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOutOfStock = product.stocks == null || product.stocks!.isEmpty;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: product.status == 'pending' ? AppStyle.pending : AppStyle.white,
        margin: EdgeInsets.only(bottom: spacing.r),
        padding: REdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                16.horizontalSpace,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${product.translation?.title}',
                        style: AppStyle.interNormal(
                          size: 14.sp,
                          color: AppStyle.blackColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      8.verticalSpace,
                      Text(
                        '${product.translation?.description}',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyle.interNormal(
                          size: 12.sp,
                          color: AppStyle.textGrey,
                          letterSpacing: -0.3,
                        ),
                      ),
                      8.verticalSpace,
                      Text(
                        isOutOfStock
                            ? AppHelpers.getTranslation(TrKeys.outOfStock)
                            : AppHelpers.numberFormat(
                                number: product.stocks?.first.price ?? 0,
                              ),
                        style: AppStyle.interSemi(
                          size: 14.sp,
                          color: isOutOfStock
                              ? AppStyle.red
                              : AppStyle.blackColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                8.horizontalSpace,
                CommonImage(
                  width: 110,
                  height: 106,
                  url: product.img,
                  radius: 0,
                  errorRadius: 0,
                  fit: BoxFit.fitWidth,
                ),
                16.horizontalSpace,
              ],
            ),
            20.verticalSpace,
            Padding(
              padding: REdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                thickness: 1.r,
                height: 1.r,
                color: AppStyle.tabBarBorderColor,
              ),
            ),
            14.verticalSpace,
            Padding(
              padding: REdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ButtonsBouncingEffect(
                    child: Row(
                      children: [
                        Text(
                          AppHelpers.getTranslation(TrKeys.parameters),
                          style: AppStyle.interNormal(size: 13.sp),
                        ),
                        6.horizontalSpace,
                        Icon(
                          Remix.arrow_down_s_line,
                          size: 18.r,
                          color: AppStyle.blackColor,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 30.r,
                    alignment: Alignment.center,
                    padding: REdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.r),
                      color: product.status == 'pending'
                          ? AppStyle.pendingDark
                          : AppStyle.primary,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          product.status == 'pending'
                              ? Remix.time_fill
                              : Remix.check_double_line,
                          size: 20.r,
                          color: AppStyle.white,
                        ),
                        6.horizontalSpace,
                        Text(
                          product.status == 'pending'
                              ? AppHelpers.getTranslation(TrKeys.pending)
                              : AppHelpers.getTranslation(TrKeys.published),
                          style: AppStyle.interNormal(
                            size: 14.sp,
                            color: AppStyle.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            8.verticalSpace,
          ],
        ),
      ),
    );
  }
}
