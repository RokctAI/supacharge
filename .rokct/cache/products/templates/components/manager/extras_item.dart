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
import 'package:products_sdk/src/common/infrastructure/models/data/seller_extras_group.dart';
import 'package:${package}/presentation/pages/main/widgets/buttons_bouncing_effect.dart';

/// An extras-group chip of the approved stocks pane (frame 35b: Size /
/// Sauce / Cheese, checked = in use): each checked group's value
/// combinations make one stock row. Same tap behaviour as shipped — toggle
/// plus the group-extras sheet — in the approved chip dress.
class ExtrasItem extends StatelessWidget {
  final SellerExtrasGroup extras;
  final Function()? onTap;
  final bool isLast;

  const ExtrasItem({
    super.key,
    required this.extras,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool checked = extras.isChecked ?? false;
    return ButtonsBouncingEffect(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: REdgeInsets.only(right: 8, top: 8, bottom: 8),
          padding: REdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100.r),
            color: AppStyle.transparent,
            border: Border.all(
              color: checked ? AppStyle.primary : AppStyle.strokeDark,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                checked
                    ? Remix.checkbox_circle_fill
                    : Remix.checkbox_blank_circle_line,
                color: checked ? AppStyle.primary : AppStyle.textDarkFaint,
                size: 18.r,
              ),
              6.horizontalSpace,
              Text(
                '${extras.translation?.title}',
                style: AppStyle.interSemi(
                  size: 13.sp,
                  letterSpacing: -0.3,
                  color: checked ? AppStyle.primary : AppStyle.textDarkSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
