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


// Ported from paas_driver lib/presentation/pages/profile/
// notification_list_page.dart (comms_sdk driver consume, driver migration
// S-D5, mirroring the manager block: same page, imports and theming swapped
// for SDK conventions — host Style becomes base AppStyle, host services and
// models become their base_sdk twins, CommonImage's imageUrl param becomes
// base's url). Installed to the EXACT tracked host path, so the installer's
// hash guard warn-skips it while paas_driver's own copy is still tracked
// (no duplicate NotificationListPage ever reaches auto_route codegen);
// when the driver repo deletes its host copy (migration stage M2), compose
// provides this one at the same path. The class keeps the
// NotificationListPage name so auto_route regenerates the exact
// NotificationListRoute that delivery_sdk's installed driver profile_page
// (zones#12) pushes.
//
// Divergence from the manager template: paas_driver ships no order-details
// modal (the host page carries it commented out), so the orderData branch
// is a deliberate no-op after readOne — wire delivery_sdk's modal here if
// the courier vertical grows one.

// ignore_for_file: deprecated_member_use

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jiffy/jiffy.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:base_sdk/src/constants/app_constants.dart';
import 'package:base_sdk/src/models/response/notification_response.dart';
import 'package:base_sdk/src/presentation/components/app_bars/common_app_bar.dart';
import 'package:base_sdk/src/presentation/components/buttons/custom_button.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:base_sdk/src/presentation/components/helper/common_image.dart';
import 'package:remixicon/remixicon.dart';
import 'package:base_sdk/src/presentation/components/loading.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:${package}/application/notification/notification_provider.dart';

@RoutePage()
class NotificationListPage extends ConsumerStatefulWidget {
  const NotificationListPage({super.key});

  @override
  ConsumerState<NotificationListPage> createState() =>
      _NotificationListPageState();
}

class _NotificationListPageState extends ConsumerState<NotificationListPage> {
  final bool isLtr = LocalStorage.getLangLtr();
  late RefreshController refreshController;

  @override
  void initState() {
    refreshController = RefreshController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).fetchAllNotifications(context);
    });
    super.initState();
  }

  @override
  void dispose() {
    refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    final event = ref.read(notificationProvider.notifier);
    return Directionality(
      textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppStyle.bgGrey,
        body: Stack(children: [
          state.isAllNotificationsLoading
            ? const Loading()
            : Column(
                children: [
                  CommonAppBar(
                    child: Text(
                      AppHelpers.getTranslation(TrKeys.notifications),
                      style: AppStyle.interSemi(
                        size: 18,
                        color: AppStyle.black,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SmartRefresher(
                      controller: refreshController,
                      enablePullDown: true,
                      enablePullUp: true,
                      onRefresh: () {
                        event.fetchNotificationsPaginate(
                            refreshController: refreshController,
                            isRefresh: true);
                      },
                      onLoading: () {
                        event.fetchNotificationsPaginate(
                          refreshController: refreshController,
                        );
                      },
                      child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.only(
                              top: 24.h,
                              right: 16.w,
                              left: 16.w,
                              bottom:
                                  MediaQuery.paddingOf(context).bottom + 72.h),
                          itemCount: state.notifications.length,
                          itemBuilder: (context, index) {
                            return InkWell(
                              onTap: () async {
                                if (state.notifications[index].readAt == null) {
                                  event.readOne(
                                      index: index,
                                      context,
                                      id: state.notifications[index].id);
                                }
                                if (state.notifications[index].orderData !=
                                    null) {
                                  // Deliberate no-op (parity with the host
                                  // page, which carries the order-details
                                  // modal commented out): the driver compose
                                  // has no installed order-details modal to
                                  // open yet. readOne above still marks the
                                  // notification read.
                                } else if (state
                                        .notifications[index].blogData !=
                                    null) {
                                  await launch(
                                    "${AppConstants.webUrl}/blog/${state.notifications[index].blogData?.uuid}",
                                    forceSafariVC: true,
                                    forceWebView: true,
                                    enableJavaScript: true,
                                  );
                                } else if (state.notifications[index].type ==
                                    "reservation") {
                                  await launch(
                                    "${AppConstants.webUrl}/reservations",
                                    forceSafariVC: true,
                                    forceWebView: true,
                                    enableJavaScript: true,
                                  );
                                } else {
                                  AppHelpers.showAlertDialog(
                                      context: context,
                                      child: Text(
                                          '${state.notifications[index].body ?? state.notifications[index].title}'));
                                }
                              },
                              child: Column(
                                children: [
                                  notificationItem(state.notifications[index]),
                                  const Divider()
                                ],
                              ),
                            );
                          }),
                    ),
                  ),
                ],
              ),
          // One bottom overlay (design strip section 12, core#125): the
          // page's read-all action riding above the floating nav's
          // back-only pill, whose back segment replaces the standalone
          // PopButton as this screen's ONE back affordance. Back-only
          // (empty tab list): the driver app composes no root tab set.
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: [
                        Expanded(
                            child: CustomButton(
                          background: AppStyle.black,
                          textColor: AppStyle.white,
                          title: AppHelpers.getTranslation(TrKeys.readAll),
                          onPressed: () async {
                            event.readAll(context);
                          },
                        ))
                      ],
                    ),
                  ),
                  FloatingBottomNav(
                    mode: FloatingNavTabsMode(
                      tabs: const [],
                      currentIndex: 0,
                      onSelect: (_) {},
                      back: FloatingNavBack(
                        icon: Remix.arrow_left_wide_fill,
                        label: AppHelpers.getTranslation(TrKeys.back),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget notificationItem(NotificationModel notification) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.r),
      child: Row(
        children: [
          CommonImage(
            radius: 22,
            url: notification.client?.img ?? notification.blogData?.img,
            height: 44,
            width: 44,
          ),
          12.horizontalSpace,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notification.client != null)
                Row(
                  children: [
                    Text(
                      '${notification.client?.firstname ?? ''} ${notification.client?.lastname?.substring(0, 1) ?? ''}.',
                      style: AppStyle.interSemi(size: 16, color: AppStyle.black),
                    ),
                    15.horizontalSpace,
                    Container(
                      height: 8.r,
                      width: 8.r,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: notification.readAt == null
                              ? AppStyle.primary
                              : AppStyle.transparent),
                    )
                  ],
                ),
              2.verticalSpace,
              Row(
                children: [
                  SizedBox(
                    width: notification.client != null
                        ? MediaQuery.sizeOf(context).width / 2
                        : null,
                    child: Text(
                      '${notification.body ?? notification.title}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                      style: AppStyle.interRegular(
                          size: 14, color: AppStyle.black),
                    ),
                  ),
                  if (notification.client == null)
                    Container(
                      margin: EdgeInsets.only(left: 8.r),
                      height: 8.r,
                      width: 8.r,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: notification.readAt == null
                              ? AppStyle.primary
                              : AppStyle.transparent),
                    )
                ],
              ),
              4.verticalSpace,
              Text(
                Jiffy.parseFromDateTime(
                        notification.createdAt ?? DateTime.now())
                    .fromNow(),
                style: AppStyle.interRegular(
                    size: 12, color: AppStyle.textGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
