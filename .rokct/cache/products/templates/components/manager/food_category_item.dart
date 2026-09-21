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
import 'package:products_sdk/src/common/infrastructure/models/data/seller_category_data.dart';
import 'package:${package}/presentation/pages/main/widgets/buttons_bouncing_effect.dart';

class FoodCategoryItem extends StatelessWidget {
  final SellerCategoryData category;
  final Function() onTap;
  final VoidCallback? onDelete;
  final bool isSelected;

  const FoodCategoryItem({
    super.key,
    required this.category,
    required this.onTap,
    required this.isSelected,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return category.status != "unpublished"
        ? Padding(
            padding: REdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppStyle.white,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                padding: REdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: 18.w,
                          height: 18.h,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppStyle.primary
                                : AppStyle.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppStyle.blackColor
                                  : AppStyle.textGrey,
                              width: isSelected ? 4 : 2,
                            ),
                          ),
                        ),
                        16.horizontalSpace,
                        Expanded(
                          child: Text(
                            category.translation?.title ?? "---",
                            style: AppStyle.interRegular(
                              size: 15.sp,
                              color: AppStyle.blackColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (onDelete != null)
                          ButtonsBouncingEffect(
                            child: GestureDetector(
                              onTap: onDelete,
                              child: Icon(Remix.delete_bin_line, size: 21.r),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
  }
}
