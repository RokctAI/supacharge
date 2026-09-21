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
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:base_sdk/src/presentation/theme/app_style.dart';

// Ported from paas_manager lib/presentation/pages/restaurant/widgets/
// sections_item.dart (styles repointed to base_sdk's AppStyle).
//
// Row ink rides the host's mode-resolving [AppStyle.textPrimary], NOT the
// polarity-pinned [AppStyle.blackColor] the paas_manager original used: the
// rows render inside GenericProfilePage, whose scaffold is
// [AppStyle.surfaceDark] (#101010 in dark mode), so pure black left every
// row title effectively invisible (1.10:1). textPrimary resolves to white on
// the dark surface and near-black on the light one.
//
// [subtitle] (optional) renders a small grey glance line under the title —
// added for the approved PRODUCTIVITY gate row (frame 7e, chip 391, Ray
// 2026-08-29 15:41Z), whose Tasks row carries open/due counts. Rows
// without a subtitle are byte-identical to the original single-line
// layout.
class SectionsItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const SectionsItem({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 20.h),
        color: AppStyle.transparent,
        child: Row(
          children: [
            Icon(icon),
            16.horizontalSpace,
            subtitle == null
                ? Text(
                    title,
                    style: AppStyle.interRegular(
                      size: 16.sp,
                      color: AppStyle.textPrimary,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppStyle.interRegular(
                          size: 16.sp,
                          color: AppStyle.textPrimary,
                        ),
                      ),
                      2.verticalSpace,
                      Text(
                        subtitle!,
                        style: AppStyle.interRegular(
                          size: 12.sp,
                          color: AppStyle.textGrey,
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
