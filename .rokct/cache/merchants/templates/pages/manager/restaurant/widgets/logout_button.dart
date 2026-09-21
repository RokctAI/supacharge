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

import 'logout_modal.dart';
import 'package:base_sdk/src/presentation/components/custom_toggle3.dart';
import 'package:${package}/presentation/pages/main/widgets/buttons_bouncing_effect.dart';
import 'package:base_sdk/src/presentation/components/blur_wrap.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';

// Ported from paas_manager lib/presentation/pages/restaurant/widgets/
// logout_button.dart; BlurWrap now comes from base_sdk, the toggle stays
// the host's isText variant (base_sdk's CustomToggles differ in signature).
class LogoutButton extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onChange;

  const LogoutButton({super.key, required this.isOpen, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 6.r,
      right: 16.r,
      child: Row(
        children: [
          BlurWrap(
            radius: BorderRadius.circular(10.r),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                color: AppStyle.blackColor.withOpacity(0.29),
              ),
              padding: EdgeInsets.all(4.r),
              child: CustomToggle(
                isText: true,
                key: UniqueKey(),
                controller: ValueNotifier<bool>(isOpen),
                onChange: (value) {
                  onChange();
                },
              ),
            ),
          ),
          16.horizontalSpace,
          ButtonsBouncingEffect(
            child: GestureDetector(
              onTap: () => AppHelpers.showCustomModalBottomSheet(
                context: context,
                modal: const LogoutModal(),
                isDarkMode: LocalStorage.getAppThemeMode(),
              ),
              child: BlurWrap(
                radius: BorderRadius.circular(10.r),
                child: Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.r),
                    color: AppStyle.blackColor.withOpacity(0.29),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Remix.logout_circle_r_line,
                    color: AppStyle.white,
                    size: 22.r,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
