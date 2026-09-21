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
import 'package:intl/intl.dart' show toBeginningOfSentenceCase;

import 'package:base_sdk/src/models/data/shop_data.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';

// Ported from paas_manager lib/presentation/component/list_items/
// small_weekday_item.dart. Only the restaurant vertical reads it, so it
// installs as a merchants component (lib/presentation/components/
// restaurant/) rather than surviving in the host's shared component pool.
// The day model is base_sdk's [ShopWorkingDay]; `intl` is a host dependency
// (templates compile in the host package).
class SmallWeekdayItem extends StatelessWidget {
  final bool isSelected;
  final ShopWorkingDay day;
  final int size;
  final int fontSize;
  final int borderRadius;

  const SmallWeekdayItem({
    super.key,
    required this.isSelected,
    required this.day,
    this.size = 40,
    this.fontSize = 14,
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size.r,
      width: size.r,
      decoration: BoxDecoration(
        color: isSelected ? AppStyle.primary : AppStyle.white,
        borderRadius: BorderRadius.circular(borderRadius.r),
      ),
      alignment: Alignment.center,
      child: Text(
        '${toBeginningOfSentenceCase(day.day?.substring(0, 2))}',
        style: AppStyle.interNormal(
          size: fontSize.sp,
          color: AppStyle.blackColor,
        ),
      ),
    );
  }
}
