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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:${package}/presentation/routes/app_router.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_drag.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_wrap.dart';
// Profile (delete account) is users_sdk's vertical (fork plan S-2). Until
// its facade lands, this stays the HOST's own application slice via
// ${package} — the same survive-until-consume convention as the host
// component imports above; the host consume swaps it for users_sdk's
// provider.
import 'package:${package}/application/profile/profile_provider.dart';
import 'package:base_sdk/src/presentation/components/buttons/custom_button.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';

// Ported from paas_manager lib/presentation/pages/restaurant/widgets/
// logout_modal.dart. LoginRoute stays a host route: auth_sdk composes with
// skip_install and the app keeps its own login page (driver precedent).
class LogoutModal extends StatelessWidget {
  final bool isDeleteAccount;

  const LogoutModal({super.key, this.isDeleteAccount = false});

  @override
  Widget build(BuildContext context) {
    return ModalWrap(
      body: Padding(
        padding: REdgeInsets.symmetric(horizontal: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ModalDrag(),
            12.verticalSpace,
            Text(
              AppHelpers.getTranslation(isDeleteAccount
                  ? TrKeys.areYouSure
                  : TrKeys.doYouReallyWantToLogout),
              style: AppStyle.interSemi(size: 16.sp),
              textAlign: TextAlign.center,
            ),
            40.verticalSpace,
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                      borderColor: AppStyle.black,
                      background: AppStyle.transparent,
                      title: AppHelpers.getTranslation(TrKeys.cancel),
                      onPressed: () {
                        Navigator.pop(context);
                      }),
                ),
                16.horizontalSpace,
                Expanded(
                  child: Consumer(builder: (context, ref, child) {
                    if (isDeleteAccount) {
                      return CustomButton(
                          background: AppStyle.red,
                          textColor: AppStyle.white,
                          title:
                              AppHelpers.getTranslation(TrKeys.deleteAccount),
                          onPressed: () {
                            ref
                                .read(profileProvider.notifier)
                                .deleteAccount(context);
                          });
                    } else {
                      return CustomButton(
                          title: AppHelpers.getTranslation(TrKeys.logout),
                          onPressed: () {
                            LocalStorage.logout();
                            context.router.popUntilRoot();
                            context.replaceRoute(const LoginRoute());
                          });
                    }
                  }),
                ),
              ],
            ),
            32.verticalSpace,
          ],
        ),
      ),
    );
  }
}
