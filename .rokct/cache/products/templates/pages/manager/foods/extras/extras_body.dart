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

import 'widgets/main_group_item.dart';
import 'details/extras_group_details_modal.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/presentation/components/helper/no_data_info.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:products_sdk/src/manager/application/extras/extras_provider.dart';

class ExtrasBody extends StatelessWidget {
  final RefreshController refreshController;

  const ExtrasBody({super.key, required this.refreshController});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(extrasProvider);
        final event = ref.read(extrasProvider.notifier);
        return SmartRefresher(
          physics: const NeverScrollableScrollPhysics(),
          controller: refreshController,
          onRefresh: () =>
              event.fetchGroups(refreshController: refreshController),
          child: state.isLoading
              ? Center(
                  child: SizedBox(
                    width: 30.r,
                    height: 30.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 4.r,
                      color: AppStyle.blackColor,
                    ),
                  ),
                )
              : state.groups.isEmpty
                  ? NoDataInfo(title: AppHelpers.getTranslation(TrKeys.noData))
                  : ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: state.groups.length,
                      padding: REdgeInsets.only(
                          right: 16, top: 20, left: 16, bottom: 100),
                      itemBuilder: (context, index) => MainGroupItem(
                        group: state.groups[index],
                        onTap: () => AppHelpers.showCustomModalBottomSheet(
                          context: context,
                          modal: ExtrasGroupDetailsModal(
                            group: state.groups[index],
                          ),
                          isDarkMode: true,
                        ),
                      ),
                    ),
        );
      },
    );
  }
}
