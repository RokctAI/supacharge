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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'stocks/create_food_stocks_body.dart';
import 'details/create_food_details_body.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:products_sdk/src/manager/application/foods/create/details/create_food_details_provider.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_drag.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_wrap.dart';

/// Opened by the merchants_sdk home shell's FAB when the foods tab is on
/// "foods" — `CreateProductModal` at this install path is main_page.dart's
/// import contract.
class CreateProductModal extends ConsumerStatefulWidget {
  const CreateProductModal({super.key});

  @override
  ConsumerState<CreateProductModal> createState() => _CreateProductModalState();
}

class _CreateProductModalState extends ConsumerState<CreateProductModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(createFoodDetailsProvider.notifier).updateAddFoodInfo(),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModalWrap(
      body: Column(
        children: [
          const ModalDrag(),
          IgnorePointer(
            child: Container(
              padding: REdgeInsets.all(6),
              height: 48.h,
              decoration: BoxDecoration(
                color: AppStyle.transparent,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppStyle.tabBarBorderColor),
              ),
              margin: REdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                onTap: (index) {},
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.r),
                  color: AppStyle.blackColor,
                ),
                labelColor: AppStyle.white,
                unselectedLabelColor: AppStyle.textGrey,
                unselectedLabelStyle: AppStyle.interRegular(size: 14.sp),
                labelStyle: AppStyle.interSemi(size: 14.sp),
                tabs: [
                  Tab(
                    child: Text(AppHelpers.getTranslation(TrKeys.addProduct)),
                  ),
                  Tab(
                    child: Text(AppHelpers.getTranslation(TrKeys.stocks)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                CreateFoodDetailsBody(
                  onSave: () => _tabController.animateTo(
                    1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeIn,
                  ),
                ),
                const CreateFoodStocksBody(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
