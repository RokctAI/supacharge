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


// Ported from paas_manager lib/presentation/pages/restaurant/
// notification_list_page.dart (comms_sdk manager consume, fork plan S-3 /
// migration bucket b, D4 minimal parameterization: same page, imports and
// theming swapped for SDK conventions). Installed to the comms-owned
// lib/presentation/pages/notification/ path; the class keeps the
// NotificationListPage name so auto_route regenerates the exact
// NotificationListRoute the composed restaurant tab already pushes.
// The order-details modal is orders_sdk's installed host-composition file
// (${package} path), typed on orders_sdk's manager OrderData — only the id
// crosses the model seam (cross-SDK composition in host lib/ per ADR-005).
//
// NOTIFICATIONS IN THE STANDARD LIST LANGUAGE — approved design strip
// frame 38b, Ray 2026-08-30 12:23Z ("33 list language = STANDARD for all
// lists ... the All/Unread tabs are IN"):
//
//   700  header COUNT PILL — "N unread"
//   706  READ ALL, re-homed from its bottom overlay (it used to ride
//        ABOVE the floating nav, colliding with the two-state nav's
//        corner pill) to a header action
//   707  the All / Unread read-state tabs in the canonical 362/363
//        treatment
//   704/705  the shipped row and its unread dot, verbatim
//   347  the corner back pill at the bottom-END (the shipped pill sat
//        bottom-CENTER; the corner is the 12:36Z rule)
//
// The list DECLARES 2 planes; alone at a three-plane width the leftover
// plane TRAILS BARE at the end (Ray 10:47Z) — which is exactly where a
// tapped notification's order pane lands (the same 12:02Z sheet fork as
// frame 38a). The row + read-state halves live in the SDK
// (comms_sdk/src/common/presentation/notifications/) so they are testable.

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:base_sdk/src/constants/app_constants.dart';
import 'package:base_sdk/src/models/response/notification_response.dart';
import 'package:base_sdk/src/presentation/adaptive/adaptive_shell.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:base_sdk/src/presentation/components/lists/list_language.dart';
import 'package:base_sdk/src/presentation/components/lists/list_plane_flow.dart';
import 'package:base_sdk/src/presentation/components/loading.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:comms_sdk/src/common/presentation/notifications/notification_list_language.dart';
import 'package:${package}/application/notification/notification_provider.dart';
import 'package:${package}/presentation/pages/orders/details/order_details_modal.dart';
import 'package:orders_sdk/src/manager/infrastructure/models/data/order_data.dart'
    as sdk;

@RoutePage()
class NotificationListPage extends ConsumerStatefulWidget {
  const NotificationListPage({super.key});

  @override
  ConsumerState<NotificationListPage> createState() =>
      _NotificationListPageState();
}

class _NotificationListPageState extends ConsumerState<NotificationListPage> {
  final bool isLtr = LocalStorage.getLangLtr();
  NotificationReadFilter _filter = NotificationReadFilter.all;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).fetchAllNotifications(context);
    });
    super.initState();
  }

  /// The shipped tap, unchanged for everything that is NOT an order: read
  /// the row, then launch the blog / reservation web view or raise the
  /// body dialog. Orders return true so the caller opens the pane (planes)
  /// or the shipped sheet (phone).
  Future<bool> _handleTap(NotificationModel notification) async {
    final event = ref.read(notificationProvider.notifier);
    if (notification.readAt == null) {
      // readOne indexes into the notifier's own list, so resolve the row's
      // position there rather than in the filtered view.
      final index = ref
          .read(notificationProvider)
          .notifications
          .indexWhere((n) => identical(n, notification));
      if (index >= 0) {
        event.readOne(context, id: notification.id, index: index);
      }
    }
    if (notification.orderData != null) return true;
    if (notification.blogData != null) {
      await launchUrl(
        Uri.parse(
          '${AppConstants.webUrl}/blog/${notification.blogData?.uuid}',
        ),
        mode: LaunchMode.inAppWebView,
      );
      return false;
    }
    if (notification.type == 'reservation') {
      await launchUrl(
        Uri.parse('${AppConstants.webUrl}/reservations'),
        mode: LaunchMode.inAppWebView,
      );
      return false;
    }
    if (!mounted) return false;
    AppHelpers.showAlertDialog(
      context: context,
      child: Text('${notification.body ?? notification.title}'),
    );
    return false;
  }

  /// The shipped sheet — phone behaviour.
  void _openOrderSheet(NotificationModel notification) {
    AppHelpers.showCustomModalBottomSheet(
      context: context,
      modal: OrderDetailsModal(
        // The installed modal is typed on orders_sdk's manager OrderData
        // and refetches details by id; both models carry the Order docname
        // as String, so the id passes straight through.
        order: sdk.OrderData(id: notification.orderData?.id),
      ),
      isDarkMode: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: AdaptiveShell(
        compact: _buildCompact,
        // The fold is already a two-plane screen, so it takes the plane
        // layout too; only a one-plane window falls back to the sheet.
        medium: _buildPlanes,
        expanded: _buildPlanes,
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.surfaceDark,
      body: SafeArea(
        child: Stack(
          children: [
            _list(
              compact: true,
              onTap: (notification) async {
                if (await _handleTap(notification)) {
                  _openOrderSheet(notification);
                }
              },
            ),
            PositionedDirectional(
              end: 16,
              bottom: 16,
              child: FloatingBackPill(
                back: FloatingNavBack(
                  icon: Remix.arrow_left_wide_fill,
                  label: AppHelpers.getTranslation(TrKeys.back),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanes(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.surfaceDark,
      body: SafeArea(
        child: ListDetailFlow<NotificationModel>(
          backIcon: Remix.arrow_left_wide_fill,
          detailNameOf: (open) => open.id ?? '',
          listBuilder: (context, flow) => _list(
            selected: flow.open,
            onTap: (notification) async {
              if (await _handleTap(notification)) {
                flow.openDetail(notification);
              }
            },
          ),
          detailBuilder: (context, open, flow) => _OrderPane(
            orderId: open.orderData?.id,
            onClosed: flow.closeDetail,
          ),
        ),
      ),
    );
  }

  Widget _list({
    bool compact = false,
    NotificationModel? selected,
    required Future<void> Function(NotificationModel) onTap,
  }) {
    final state = ref.watch(notificationProvider);
    final event = ref.read(notificationProvider.notifier);
    final List<NotificationModel> all = state.notifications;
    final List<NotificationModel> rows = _filter.apply(all);
    final int unread = NotificationReadFilter.unread.countIn(all);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListScreenHeader(
          compact: compact,
          title: AppHelpers.getTranslation(TrKeys.notifications),
          // 700: the standard slot.
          countPill: ListCountPill(
            label:
                '$unread ${AppHelpers.getTranslation(TrKeys.unread).toLowerCase()}',
            color: unread > 0 ? AppStyle.primary : null,
          ),
          actions: [
            // 706: re-homed here so the bottom belongs to the nav alone.
            NotificationReadAllAction(
              enabled: unread > 0,
              onTap: () => event.readAll(context),
            ),
          ],
        ),
        // 707: the read-state filter tabs (PROPOSAL on the frame, ruled IN).
        ListFilterTabBar(
          activeIndex: _filter.index,
          onSelect: (index) => setState(
            () => _filter = NotificationReadFilter.values[index],
          ),
          tabs: [
            for (final filter in NotificationReadFilter.values)
              ListFilterTab(
                label: AppHelpers.getTranslation(filter.wire),
                color: filter.color,
                count: filter.countIn(all),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: state.isAllNotificationsLoading
              ? const Loading()
              : rows.isEmpty
              ? Center(
                  child: Text(
                    AppHelpers.getTranslation(TrKeys.noData),
                    style: AppStyle.interNormal(
                      size: 12,
                      color: AppStyle.textDarkSecondary,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async =>
                      event.fetchAllNotifications(context),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      ListPlaneColumns(
                        children: [
                          for (final notification in rows)
                            NotificationRow(
                              notification: notification,
                              selected:
                                  selected != null &&
                                  identical(selected, notification),
                              onTap: () => onTap(notification),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// The tapped notification's ORDER PANE, landing in the LAST plane (the
/// 12:02Z sheet fork, same as frame 38a): the installed
/// [OrderDetailsModal] hosted in a pane-local navigator so any
/// `Navigator.pop` inside it closes the PLANE, never the notification
/// route beneath it.
class _OrderPane extends StatelessWidget {
  final String? orderId;
  final VoidCallback onClosed;

  const _OrderPane({required this.orderId, required this.onClosed});

  static const String _sentinelName = '_notification-order-pane-sentinel';

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppStyle.surfaceDark,
      child: ClipRect(
        child: Navigator(
          observers: [_PopToSentinelObserver(onClosed)],
          onGenerateInitialRoutes: (navigator, initialRoute) => [
            MaterialPageRoute(
              settings: const RouteSettings(name: _sentinelName),
              builder: (_) => ColoredBox(color: AppStyle.surfaceDark),
            ),
            MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: AppStyle.surfaceDark,
                body: SafeArea(
                  child: OrderDetailsModal(order: sdk.OrderData(id: orderId)),
                ),
              ),
            ),
          ],
          onGenerateRoute: (settings) => MaterialPageRoute(
            settings: settings,
            builder: (_) => ColoredBox(color: AppStyle.surfaceDark),
          ),
        ),
      ),
    );
  }
}

/// Watches the pane-local navigator: when the pane pops back onto the
/// sentinel root, the plane has nothing left to show — fold it.
class _PopToSentinelObserver extends NavigatorObserver {
  final VoidCallback onPoppedToSentinel;

  _PopToSentinelObserver(this.onPoppedToSentinel);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute?.settings.name == _OrderPane._sentinelName) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onPoppedToSentinel());
    }
  }
}
