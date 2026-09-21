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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'widgets/edit_extras_item_modal.dart';
import 'widgets/delete_extras_item_modal.dart';
import 'widgets/group_detail_extras_item.dart';
import 'widgets/create_new_group_item_modal.dart';
import '../delete/delete_extras_group_modal.dart';
import '../update/update_extras_group_modal.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:products_sdk/src/common/infrastructure/models/data/seller_extras_group.dart';
import 'package:products_sdk/src/manager/application/extras/details/extras_group_details_provider.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_drag.dart';
import 'package:base_sdk/src/presentation/components/helper/modal_wrap.dart';
import 'package:base_sdk/src/presentation/components/text_fields/underlined_text_field.dart';
import 'package:${package}/presentation/pages/main/widgets/buttons_bouncing_effect.dart';

class ExtrasGroupDetailsModal extends ConsumerStatefulWidget {
  final SellerExtrasGroup group;

  const ExtrasGroupDetailsModal({super.key, required this.group});

  @override
  ConsumerState<ExtrasGroupDetailsModal> createState() =>
      _ExtrasGroupDetailsModalState();
}

class _ExtrasGroupDetailsModalState
    extends ConsumerState<ExtrasGroupDetailsModal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref
          .read(extrasGroupDetailsProvider.notifier)
          .fetchGroupExtras(groupId: widget.group.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModalWrap(
      body: Padding(
        padding: REdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const ModalDrag(),
            ButtonsBouncingEffect(
              child: GestureDetector(
                onTap: () => AppHelpers.showCustomModalBottomSheet(
                  context: context,
                  modal: CreateNewGroupItemModal(group: widget.group),
                  isDarkMode: false,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Remix.play_list_add_line,
                      color: AppStyle.blue,
                      size: 18.r,
                    ),
                    10.horizontalSpace,
                    Text(
                      AppHelpers.getTranslation(TrKeys.addNewExtras),
                      style: AppStyle.interSemi(
                        size: 14,
                        color: AppStyle.blue,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            UnderlinedTextField(
              label: '',
              readOnly: true,
              initialText: widget.group.translation?.title,
              onTap: () => AppHelpers.showCustomModalBottomSheet(
                context: context,
                modal: UpdateExtrasGroupModal(group: widget.group),
                isDarkMode: true,
              ),
              suffixIcon:
                  // Shop ids are shop_name docname strings, never ints.
                  widget.group.shopId ==
                      LocalStorage.getShopJson()?['id']?.toString()
                  ? GestureDetector(
                      onTap: () => AppHelpers.showCustomModalBottomSheet(
                        context: context,
                        isDarkMode: true,
                        modal: DeleteExtrasGroupModal(group: widget.group),
                      ),
                      child: Icon(
                        Remix.delete_bin_fill,
                        size: 24.r,
                        color: AppStyle.red,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(extrasGroupDetailsProvider);
                  return state.isLoading
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
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: REdgeInsets.only(top: 16, bottom: 24),
                          shrinkWrap: true,
                          itemCount: state.extras.length,
                          itemBuilder: (context, index) =>
                              GroupDetailExtrasItem(
                                extras: state.extras[index],
                                onEditTap: () =>
                                    AppHelpers.showCustomModalBottomSheet(
                                      context: context,
                                      modal: EditExtrasItemModal(
                                        group: widget.group,
                                        extras: state.extras[index],
                                      ),
                                      isDarkMode: false,
                                    ),
                                onDeleteTap: () =>
                                    AppHelpers.showCustomModalBottomSheet(
                                      context: context,
                                      modal: DeleteExtrasItemModal(
                                        extras: state.extras[index],
                                      ),
                                      isDarkMode: false,
                                    ),
                              ),
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
