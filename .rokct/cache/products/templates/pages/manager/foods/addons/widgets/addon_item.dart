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
import 'package:${package}/presentation/pages/main/widgets/buttons_bouncing_effect.dart';

class AddonItem extends StatelessWidget {
  final SellerProductData addon;
  final VoidCallback onTap;

  const AddonItem({super.key, required this.addon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isOutOfStock = addon.stock == null;
    return Container(
      color: addon.status == 'pending' ? AppStyle.pending : AppStyle.white,
      margin: REdgeInsets.only(bottom: 10),
      padding: REdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${addon.translation?.title}',
            style: AppStyle.interNormal(
              size: 14.sp,
              color: AppStyle.blackColor,
              letterSpacing: -0.3,
            ),
          ),
          8.verticalSpace,
          Text(
            '${addon.translation?.description}',
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
                : AppHelpers.numberFormat(number: addon.stock?.price ?? 0),
            style: AppStyle.interSemi(
              size: 14.sp,
              color: isOutOfStock ? AppStyle.red : AppStyle.blackColor,
              letterSpacing: -0.3,
            ),
          ),
          20.verticalSpace,
          Divider(
            thickness: 1.r,
            height: 1.r,
            color: AppStyle.tabBarBorderColor,
          ),
          14.verticalSpace,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onTap,
                child: ButtonsBouncingEffect(
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
              ),
              Container(
                height: 30.r,
                alignment: Alignment.center,
                padding: REdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.r),
                  color: addon.status == 'pending'
                      ? AppStyle.pendingDark
                      : AppStyle.primary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      addon.status == 'pending'
                          ? Remix.time_fill
                          : Remix.check_double_line,
                      size: 20.r,
                      color: AppStyle.white,
                    ),
                    6.horizontalSpace,
                    Text(
                      addon.status == 'pending'
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
        ],
      ),
    );
  }
}
