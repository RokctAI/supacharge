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
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'widgets/addon_item.dart';
import 'edit/edit_addon_modal.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:products_sdk/src/manager/application/addons/addons_provider.dart';
import 'package:products_sdk/src/manager/application/addons/edit/edit_addon_provider.dart';
import 'package:products_sdk/src/manager/application/addons/edit/units/edit_addon_units_provider.dart';
import 'package:base_sdk/src/presentation/components/loading/loading_list.dart';

class AddonsBody extends StatelessWidget {
  final RefreshController addonsController;

  const AddonsBody({super.key, required this.addonsController});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(addonsProvider);
        final event = ref.read(addonsProvider.notifier);
        return state.isLoading
            ? const LoadingList(
                verticalPadding: 16,
                itemBorderRadius: 0,
                itemPadding: 10,
              )
            : SmartRefresher(
                controller: addonsController,
                physics: const NeverScrollableScrollPhysics(),
                enablePullDown: true,
                enablePullUp: true,
                onLoading: () =>
                    event.fetchMoreAddons(refreshController: addonsController),
                onRefresh: () =>
                    event.refreshAddons(refreshController: addonsController),
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: REdgeInsets.only(top: 16),
                  shrinkWrap: true,
                  itemCount: state.addons.length,
                  itemBuilder: (context, index) => AddonItem(
                    addon: state.addons[index],
                    onTap: () {
                      ref
                          .read(editAddonProvider.notifier)
                          .setAddonDetails(state.addons[index]);
                      ref
                          .read(editAddonUnitsProvider.notifier)
                          .setAddonUnit(state.addons[index].unit);
                      AppHelpers.showCustomModalBottomSheet(
                        paddingTop: 60,
                        context: context,
                        modal: EditAddonModal(addon: state.addons[index]),
                        isDarkMode: false,
                      );
                    },
                  ),
                ),
              );
      },
    );
  }
}
