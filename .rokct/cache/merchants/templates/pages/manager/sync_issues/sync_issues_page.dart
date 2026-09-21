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

// Sync-issues screen (park-and-surface, offline-first Phase 2): lists the
// parked `needs_attention` records across the three manager local-first
// boxes with the server's rejection message, and resolves each with Try
// again (requeue the queued push as-is) or Discard (delete record + outbox
// op). State lives in the SDK at lib/src/manager/application/sync_issues/
// (syncIssuesProvider over SyncIssuesService); this installed page is only
// the presentation shell, per the restaurant-tab convention.
//
// SYNC ISSUES IN THE STANDARD LIST LANGUAGE — approved design strip frame
// 38c, Ray 2026-08-30 12:23Z ("33 list language = STANDARD for all lists
// ... the box tabs are IN"). This is the list whose cards carry ACTIONS,
// so if the treatment holds here it holds anywhere:
//
//   700  header COUNT PILL — "N parked"
//   711  the needs-attention header hint
//   710  the record's BOX as 362/363 filter tabs — All / Shop / Product /
//        Order, colour-coded per the 33a set (the shipped page showed the
//        box only as a per-card label)
//   708  the SYNC-ISSUE CARD in the 33 dress
//   709  the shipped ACTION PAIR — Try again / Discard (behind the shipped
//        are-you-sure dialog)
//   347  the corner back pill at the bottom-END
//
// The list DECLARES 2 planes and fills the fold exactly. The shipped empty
// state (check circle + No data) is kept.

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/buttons/custom_button.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:base_sdk/src/presentation/components/lists/list_language.dart';
import 'package:base_sdk/src/presentation/components/lists/list_plane_flow.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:merchants_sdk/src/manager/application/sync_issues/sync_issues_provider.dart';
import 'package:merchants_sdk/src/manager/infrastructure/services/sync_issues_service.dart';
import 'package:merchants_sdk/src/manager/presentation/sync_issues/sync_issue_boxes.dart';
import 'package:merchants_sdk/src/manager/presentation/sync_issues/sync_issue_card.dart';

@RoutePage(name: 'ManagerSyncIssuesRoute')
class SyncIssuesPage extends ConsumerStatefulWidget {
  const SyncIssuesPage({super.key});

  @override
  ConsumerState<SyncIssuesPage> createState() => _SyncIssuesPageState();
}

class _SyncIssuesPageState extends ConsumerState<SyncIssuesPage> {
  SyncIssueBox _box = SyncIssueBox.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(syncIssuesProvider.notifier).fetch(),
    );
  }

  /// Box name -> what the record is, via base TrKeys (`shop` / `product` /
  /// `order`); the box name itself is the tolerant fallback.
  String _boxLabel(String box) {
    switch (box) {
      case 'manager_shops':
        return AppHelpers.getTranslation(TrKeys.shop);
      case 'manager_products':
        return AppHelpers.getTranslation(TrKeys.product);
      case 'manager_orders':
        return AppHelpers.getTranslation(TrKeys.order);
    }
    return box;
  }

  String _tabLabel(SyncIssueBox tab) {
    switch (tab) {
      case SyncIssueBox.all:
        return AppHelpers.getTranslation(TrKeys.all);
      case SyncIssueBox.shop:
        return AppHelpers.getTranslation(TrKeys.shop);
      case SyncIssueBox.product:
        return AppHelpers.getTranslation(TrKeys.product);
      case SyncIssueBox.order:
        return AppHelpers.getTranslation(TrKeys.order);
    }
  }

  Future<void> _retry(SyncIssue issue) async {
    final retried = await ref.read(syncIssuesProvider.notifier).retry(issue);
    if (!mounted) return;
    // On success the row leaves the list (record back to pending_sync) —
    // that refresh is the feedback. Failure means no queued op was left to
    // requeue; the record stays parked and only discard resolves it.
    if (!retried) {
      AppHelpers.showCheckTopSnackBar(
        context,
        AppHelpers.getTranslation(TrKeys.somethingWentWrongWithTheServer),
      );
    }
  }

  void _confirmDiscard(SyncIssue issue) {
    AppHelpers.showAlertDialog(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppHelpers.getTranslation(TrKeys.areYouSure),
            style: AppStyle.interNormal(
              size: 14.sp,
              color: AppStyle.blackColor,
            ),
            textAlign: TextAlign.center,
          ),
          24.verticalSpace,
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  title: AppHelpers.getTranslation(TrKeys.cancel),
                  background: AppStyle.transparent,
                  borderColor: AppStyle.borderColor,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              16.horizontalSpace,
              Expanded(
                child: CustomButton(
                  title: AppHelpers.getTranslation(TrKeys.discard),
                  background: AppStyle.red,
                  textColor: AppStyle.white,
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(syncIssuesProvider.notifier).discard(issue);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The list declares TWO planes and has no pushed detail of its own —
    // the actions resolve in place (Try again) or behind a dialog
    // (Discard), so the flow never leaves this page.
    return Scaffold(
      backgroundColor: AppStyle.surfaceDark,
      body: SafeArea(
        child: Stack(
          children: [
            ListPlaneFlow(
              backIcon: Remix.arrow_left_wide_fill,
              listSpan: PlaneSpan.two,
              onCloseDetail: () {},
              listBuilder: _buildList,
            ),
            // 347: the corner back pill. ListPlaneFlow draws its own only
            // while a detail pane holds a plane; this list never pushes
            // one, so the page owns the corner itself.
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

  Widget _buildList(BuildContext context) {
    final state = ref.watch(syncIssuesProvider);
    final List<SyncIssue> issues = state.issues;
    final List<SyncIssue> rows = _box.apply(issues);
    final bool compact = (Planes.maybeOf(context)?.count ?? 1) <= 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListScreenHeader(
          compact: compact,
          title: AppHelpers.getTranslation(TrKeys.syncIssues),
          // 700: the standard slot.
          countPill: ListCountPill(
            label:
                '${issues.length} ${AppHelpers.getTranslation(TrKeys.parked).toLowerCase()}',
            color: issues.isEmpty ? null : AppStyle.red,
          ),
          // 711: the needs-attention hint.
          hint: issues.isEmpty
              ? null
              : syncIssueNeedsAttentionHint(issues.length),
        ),
        // 710: the box filter tabs.
        ListFilterTabBar(
          activeIndex: _box.index,
          onSelect: (index) =>
              setState(() => _box = SyncIssueBox.values[index]),
          tabs: [
            for (final tab in SyncIssueBox.values)
              ListFilterTab(
                label: _tabLabel(tab),
                color: tab.color,
                count: tab.countIn(issues),
                darkPillText: tab.darkPillText,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: state.isLoading && issues.isEmpty
              ? const Center(child: CircularProgressIndicator.adaptive())
              : rows.isEmpty
              ? _empty()
              : RefreshIndicator.adaptive(
                  onRefresh: () => ref.read(syncIssuesProvider.notifier).fetch(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: REdgeInsets.only(
                      left: 10,
                      right: 10,
                      top: 4,
                      bottom: 90,
                    ),
                    children: [
                      ListPlaneColumns(
                        children: [
                          for (final issue in rows)
                            SyncIssueCard(
                              issue: issue,
                              boxLabel: _boxLabel(issue.box),
                              retryLabel: AppHelpers.getTranslation(
                                TrKeys.tryAgain,
                              ),
                              discardLabel: AppHelpers.getTranslation(
                                TrKeys.discard,
                              ),
                              onRetry: () => _retry(issue),
                              onDiscard: () => _confirmDiscard(issue),
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

  /// The shipped empty state, kept.
  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Remix.checkbox_circle_line,
            size: 48.r,
            color: AppStyle.textDarkSecondary,
          ),
          12.verticalSpace,
          Text(
            AppHelpers.getTranslation(TrKeys.noData),
            style: AppStyle.interNormal(
              size: 14.sp,
              color: AppStyle.textDarkSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
