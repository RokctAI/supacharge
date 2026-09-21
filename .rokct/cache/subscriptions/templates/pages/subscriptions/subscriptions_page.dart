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
import 'package:remixicon/remixicon.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:subscriptions_sdk/src/common/application/subscriptions/subscriptions_provider.dart';
import 'package:base_sdk/base_sdk.dart';
import 'package:subscriptions_sdk/subscriptions_sdk.dart';
import 'package:base_sdk/src/presentation/components/loading/loading_grid.dart';
import 'widgets/have_subscription.dart';
import 'package:${package}/presentation/theme/theme.dart';
import 'widgets/payment_dialog.dart';
import 'widgets/subscriptions_item.dart';

/// The manager /subscriptions screen in the settled plane language
/// (approved section 40, frames 40a/40b/40c, Ray 2026-08-30 13:08Z):
/// shops subscribing to THEIR TENANT's plan catalog
/// (`api.subscription.list_subscriptions` over the tenant `Subscription`
/// doctype — platform/control-tier plans are a different hub entirely and
/// never appear here; the catalog may legitimately be empty).
///
///  * Header: "Subscriptions" + count pill (chip 700, the sec-38 list
///    header slot), the CURRENT-PLAN card (chip 760) and the catalog rows
///    as PLAN CARDS (chip 761) — one card per plane column at spread
///    widths, stacked full-width on one plane.
///  * PAYMENT-CLASS CAP (the money rule): the page declares
///    [PlaneSpan.two] and stays at 2 even at the 3-plane width — the
///    leftover plane trails bare at the END, and that stage is exactly
///    where the PAYMENT PANE (chip 765) lands when Purchase is tapped. At
///    the 2-plane fold the origin yields to one plane (frame 40b) with
///    only the SELECTED card (chip 769) beside the pane.
///  * Pushed page ⇒ corner back pill (chip 347, the 12:36Z two-state
///    nav)... EXCEPT while the payment pane is up: payment = pushed page
///    WITHOUT the corner pill (Ray 15:06Z, the 11u exception extended) —
///    the escape is the pane's own Cancel (hardware back also just closes
///    the pane).
///  * On phones the purchase keeps the shipped dialog behaviour (the
///    sheet fork's phone half) — the plane mechanism disappears by
///    construction.
@RoutePage(name: 'ManagerSubscriptionsRoute')
class ManagerSubscriptionsPage extends ConsumerStatefulWidget {
  /// Optional category slice of the tenant catalog (Ray 13:26Z/13:33Z:
  /// "each home sdk might need to ask for category it needs"), matched
  /// against the tenant `Subscription` doctype's `type` select with the
  /// same exact-equality semantics as the Next.js frontend's existing
  /// `category` plan filtering. Null shows the full catalog. Applied
  /// client-side — `list_subscriptions` takes no category kwarg today.
  final String? category;

  const ManagerSubscriptionsPage({super.key, this.category});

  @override
  ConsumerState<ManagerSubscriptionsPage> createState() =>
      _SubscriptionsPageState();
}

class _SubscriptionsPageState extends ConsumerState<ManagerSubscriptionsPage> {
  late RefreshController refreshController;

  /// True while the payment pane holds the last plane (frame 40b). Phone
  /// purchases use the shipped dialog instead and never set this.
  bool _paymentOpen = false;

  @override
  void initState() {
    super.initState();
    refreshController = RefreshController();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref
          .read(subscriptionProvider.notifier)
          .fetchSubscriptions(isRefresh: true),
    );
  }

  @override
  void dispose() {
    refreshController.dispose();
    super.dispose();
  }

  void _closePayment() {
    if (_paymentOpen) setState(() => _paymentOpen = false);
  }

  void _onPaid() {
    _closePayment();
    ref.read(subscriptionProvider.notifier).fetchSubscriptions(isRefresh: true);
  }

  /// Opens the purchase flow for [plan] — the payment pane at plane widths,
  /// the shipped dialog on phones. Only reachable from a Purchase CTA: the
  /// held plan's card renders the disabled CURRENT-PLAN GUARD (chip 768)
  /// instead, so no accidental tap can start a charge.
  void _purchase(SubscriptionData plan, {required bool onePlane}) {
    final state = ref.read(subscriptionProvider);
    final notifier = ref.read(subscriptionProvider.notifier);
    final index = state.list.indexOf(plan);
    if (index < 0) return;
    notifier.fetchPayments(context: context);
    notifier.selectSubscribe(index: index);
    if (onePlane) {
      AppHelpers.showAlertDialog(
        context: context,
        child: PaymentDialog(
          onPaid: () => notifier.fetchSubscriptions(isRefresh: true),
        ),
      );
    } else {
      setState(() => _paymentOpen = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLrt = LocalStorage.getLangLtr();
    return Directionality(
      textDirection: isLrt ? TextDirection.ltr : TextDirection.rtl,
      child: PopScope(
        // While the pane is up, back is Cancel — it closes the payment,
        // never the page (the 11u payment-escape rule).
        canPop: !_paymentOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _closePayment();
        },
        child: Scaffold(
          backgroundColor: AppStyle.surfaceDark,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool onePlane =
                    PlaneHost.planeCountFor(constraints.maxWidth) == 1;
                final bool paneOpen = !onePlane && _paymentOpen;
                return Stack(
                  children: [
                    PlaneHost(
                      stack: [
                        PlanePage(
                          name: 'subscriptions-overview',
                          // The payment-class cap: declare 2, never all —
                          // on three planes the leftover trails bare at
                          // the END until the payment pane claims it.
                          span: PlaneSpan.two,
                          builder: (context) =>
                              _Overview(paymentOpen: paneOpen, page: this),
                        ),
                        if (paneOpen)
                          PlanePage(
                            name: 'subscription-payment',
                            builder: (context) => Container(
                              margin: REdgeInsets.only(
                                top: 16,
                                bottom: 16,
                              ),
                              padding: REdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppStyle.cardDark,
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: SubscriptionPaymentBody(
                                onCancel: _closePayment,
                                onPaid: _onPaid,
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Chip 347: pushed page ⇒ back-only corner pill at the
                    // bottom-END — deliberately ABSENT while the payment
                    // pane is up (the approved 11u payment exception).
                    if (!paneOpen)
                      PositionedDirectional(
                        end: 16,
                        bottom: 16,
                        child: FloatingBackPill(
                          back: FloatingNavBack(
                            icon: Remix.arrow_left_s_line,
                            label: AppHelpers.getTranslation(TrKeys.back),
                            onTap: () => context.maybePop(),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The overview column(s): header + count pill, current-plan card, plan
/// cards — laid out on the plane grid this subtree was granted
/// ([Planes.of]): two card columns when spread, a single stack when
/// compressed (frames 40b/40c). While the payment pane is up and only one
/// plane remains, the origin shows just the current-plan card and the
/// SELECTED card (the yielded-origin rule, frame 40b).
class _Overview extends ConsumerWidget {
  final bool paymentOpen;
  final _SubscriptionsPageState page;

  const _Overview({required this.paymentOpen, required this.page});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planes = Planes.of(context);
    final int span = planes.span;
    final bool onePlane = planes.count == 1;
    final state = ref.watch(subscriptionProvider);
    final notifier = ref.read(subscriptionProvider.notifier);
    final held = ShopSubscriptionStore.shopSubscription();
    final plans = PlanCardLogic.filterByCategory(
      state.list,
      page.widget.category,
    );
    final SubscriptionData? selectedPlan = paymentOpen &&
            state.selectSubscribe >= 0 &&
            state.selectSubscribe < state.list.length
        ? state.list[state.selectSubscribe]
        : null;
    // The yielded origin keeps the purchase in context: on its single
    // remaining plane only the chosen card stays beside the pane.
    final visible = paymentOpen && span == 1 && selectedPlan != null
        ? plans.where((p) => identical(p, selectedPlan)).toList()
        : plans;

    Widget card(SubscriptionData plan) => SubscriptionsItem(
          subscription: plan,
          isCurrent: PlanCardLogic.isCurrentPlan(plan, held),
          isSelected: paymentOpen && identical(plan, selectedPlan),
          purchase: () => page._purchase(plan, onePlane: onePlane),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: REdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Text(
                AppHelpers.getTranslation(TrKeys.subscriptions),
                style: AppStyle.interBold(size: 28),
              ),
              14.horizontalSpace,
              // Chip 700 — the sec-38 list-header count pill.
              Container(
                padding: REdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100.r),
                  border: Border.all(color: AppStyle.strokeDark),
                ),
                child: Text(
                  '${plans.length} '
                  '${AppHelpers.getTranslation('plans').toLowerCase()}',
                  style: AppStyle.interRegular(
                    size: 13,
                    color: AppStyle.textDarkSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SmartRefresher(
            controller: page.refreshController,
            onRefresh: () => notifier.fetchSubscriptions(
              context: context,
              controller: page.refreshController,
              isRefresh: true,
            ),
            child: state.isLoading
                ? LoadingGrid(
                    verticalPadding: 12,
                    itemBorderRadius: 16,
                    horizontalPadding: 16,
                    itemHeight: 260,
                  )
                : SingleChildScrollView(
                    // Content stops short of the bottom-END corner so the
                    // back pill owns it (12:36Z).
                    padding: REdgeInsets.fromLTRB(16, 4, 16, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (held != null) ...[
                          HaveSubscription(compact: span == 1),
                          16.verticalSpace,
                        ],
                        if (visible.isEmpty)
                          const _EmptyCatalog()
                        else if (span >= 2)
                          for (int i = 0; i < visible.length; i += 2)
                            Padding(
                              padding: REdgeInsets.only(bottom: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: card(visible[i])),
                                  SizedBox(width: planes.gap),
                                  Expanded(
                                    child: i + 1 < visible.length
                                        ? card(visible[i + 1])
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            )
                        else
                          for (final plan in visible)
                            Padding(
                              padding: REdgeInsets.only(bottom: 14),
                              child: card(plan),
                            ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// The honest empty state: a tenant that has published no plans is a
/// legitimate catalog, not an error — say so plainly, promise nothing.
class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: REdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AppStyle.cardDark,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Icon(
            Remix.price_tag_3_line,
            size: 36.r,
            color: AppStyle.textDarkSecondary,
          ),
          12.verticalSpace,
          Text(
            AppHelpers.getTranslation('no.plans.available'),
            textAlign: TextAlign.center,
            style: AppStyle.interNoSemi(size: 16),
          ),
          6.verticalSpace,
          Text(
            AppHelpers.getTranslation('plans.published.will.appear.here'),
            textAlign: TextAlign.center,
            style: AppStyle.interRegular(
              size: 13.5,
              color: AppStyle.textDarkSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
