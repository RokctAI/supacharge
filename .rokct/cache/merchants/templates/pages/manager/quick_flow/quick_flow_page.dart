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
import 'package:get_it/get_it.dart';
import 'package:remixicon/remixicon.dart';

import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/models/data/product_data.dart';
import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/custom_toggle3.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_nav_mode.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:merchants_sdk/src/manager/application/quick_flow/quick_flow_provider.dart';
import 'package:merchants_sdk/src/manager/domain/interface/pos_catalog.dart';
import 'package:merchants_sdk/src/manager/domain/interface/quick_flow.dart';

// QUICK FLOW — the merchant's order-automation surface (approved design
// strip section 42, frames 42a tablet / 42b phone).
//
// One place where a shop tells the till to run itself between customers.
// Three switches, and they are NOT peers — the surface says which is which
// rather than flattening them:
//
//   * AUTO-ACCEPT INCOMING ORDERS (chip 797) is `Shop.auto_approve_orders`,
//     a field that already existed and was already honoured by
//     `create_order` before this page was drawn. The row exposes that exact
//     field and NOTHING else changed server-side for it; the badge says
//     LIVE · SERVER for exactly that reason, and the gate line under it
//     (798) is the doctype's own description — the platform's "Auto Approve
//     All Orders" has to be on too, or nothing moves.
//   * AUTO-COMPLETE AT READY (chip 799) is new on both sides: a new Shop
//     field and a new Order-controller rule. It is drawn and defaulted OFF
//     and carries the hand-over warning (800) in as many words, because
//     what it buys — no tap after Ready — is bought by nobody confirming
//     the customer took the goods.
//   * KEYPAD AUTODIAL (chip 802) plus the DIGIT PRESETS grid (803/804/805)
//     is the new per-shop digit→product map. base_sdk's shared MoneyKeypad
//     (design chip 390) is NOT touched by any of it — autodial is the
//     TILL's interpretation of a digit press while its ticket is empty, so
//     the shared pad keeps its pure-input-surface contract fleet-wide.
//
// PLANES (42a): a PlaneHost whose root is the merchant Sections rail (795,
// Quick flow lit) and whose active step is this detail claiming TWO planes
// at tablet width — more space buys MORE DETAIL, not zoom, so the preset
// grid lays out 3-up and the flow strip runs three steps across. On a phone
// the host grants one plane, the rail drops away, the grid folds 3-up → 1-up
// and the wide-read extras (the platform-gate line and the flow strip) go
// with it (42b). Nothing scales down; the same components run at fewer
// columns. The corner back pill at the bottom-END is PlaneHost's own
// (canonical 347) — this is a pushed surface, so it is the only nav
// affordance on screen.
//
// No local draft and no Save button: every switch writes THROUGH to the
// shop (optimistically, reverting if the server refuses), because two of
// the three change what the till does the moment they move and a
// half-saved automation setting is worse than none.
//
// State lives in the SDK at lib/src/manager/application/quick_flow/
// (quickFlowProvider); this installed page is only the presentation shell,
// per the restaurant-tab convention. Carries no `${package}` import, so the
// standalone test harness compiles and pumps it directly — the analyzer
// excludes templates/, so those tests ARE this file's compile gate.
//
// Installed by the manifest to lib/presentation/pages/quick_flow/ with the
// /quick-flow route; @RoutePage(name: 'ManagerQuickFlowRoute') so the host's
// generated router owns the route class.

@RoutePage(name: 'ManagerQuickFlowRoute')
class QuickFlowPage extends ConsumerStatefulWidget {
  const QuickFlowPage({super.key});

  @override
  ConsumerState<QuickFlowPage> createState() => _QuickFlowPageState();
}

class _QuickFlowPageState extends ConsumerState<QuickFlowPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(quickFlowProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.surfaceDark,
      body: SafeArea(
        child: PlaneHost(
          back: FloatingNavBack(
            icon: Remix.arrow_left_s_line,
            label: AppHelpers.getTranslation(TrKeys.back),
            onTap: () => Navigator.of(context).maybePop(),
          ),
          stack: [
            PlanePage(name: 'merchant-sections', builder: _sectionsRail),
            PlanePage(
              name: 'quick-flow',
              // 42a: the detail takes the room the rail does not need —
              // three-up presets and a three-step flow strip, not a
              // stretched phone layout. On one plane the rail is simply
              // not granted and this is the whole screen (42b).
              span: PlaneSpan.two,
              builder: _detail,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // PLANE 1 — the merchant Sections rail (chip 795)
  // -------------------------------------------------------------------

  /// The origin echo the plane model prescribes: the restaurant tab's own
  /// Sections list, with ONE new row — Quick flow — inserted second and
  /// lit (2px primary left rule over a 10% primary wash). The other rows
  /// are drawn exactly as they read on the tab and are not re-implemented
  /// here: tapping one pops back to the real list, where it opens. The
  /// rail is never granted on a phone, so this never shows there.
  Widget _sectionsRail(BuildContext context) {
    final shopName = ref.watch(quickFlowProvider).settings.shopName;
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 120.h),
      children: [
        Text(
          AppHelpers.getTranslation(TrKeys.sections),
          style: AppStyle.interSemi(size: 22),
        ),
        if (shopName.isNotEmpty) ...[
          4.verticalSpace,
          Text(
            shopName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyle.interRegular(
              size: 14,
              color: AppStyle.textDarkSecondary,
            ),
          ),
        ],
        16.verticalSpace,
        _railRow(TrKeys.restaurantSettings, Remix.restaurant_line),
        _railRow(TrKeys.quickFlow, Remix.flashlight_line, active: true),
        _railRow(TrKeys.income, Remix.line_chart_line),
        _railRow(TrKeys.myOrderHistory, Remix.history_line),
        _railRow(TrKeys.notifications, Remix.notification_2_line),
        _railRow(TrKeys.syncIssues, Remix.refresh_line),
      ],
    );
  }

  Widget _railRow(String trKey, IconData icon, {bool active = false}) {
    return GestureDetector(
      onTap: active ? null : () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.only(bottom: 4.h),
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
        decoration: BoxDecoration(
          color: active
              ? AppStyle.primary.withValues(alpha: .10)
              : AppStyle.transparent,
          border: Border(
            left: BorderSide(
              color: active ? AppStyle.primary : AppStyle.transparent,
              width: 2.w,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22.r,
              color: active ? AppStyle.primary : AppStyle.textPrimary,
            ),
            14.horizontalSpace,
            Expanded(
              child: Text(
                AppHelpers.getTranslation(trKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyle.interSemi(size: 16),
              ),
            ),
            Icon(
              Remix.arrow_right_s_line,
              size: 20.r,
              color: AppStyle.textDarkSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // THE DETAIL
  // -------------------------------------------------------------------

  Widget _detail(BuildContext context) {
    final state = ref.watch(quickFlowProvider);
    final settings = state.settings;
    // The wide read: at two-plus planes the surface has room for the
    // things that explain rather than switch — the platform-gate line
    // (798) and the flow strip. On one plane they are the first to go.
    final wide = Planes.of(context).span > 1;
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 120.h),
      children: [
        _header(settings),
        if (state.error != null) ...[
          14.verticalSpace,
          _errorLine(state.error!),
        ],
        20.verticalSpace,
        _autoAcceptCard(settings, wide: wide),
        14.verticalSpace,
        _autoCompleteCard(settings),
        14.verticalSpace,
        _autodialCard(settings, wide: wide),
        if (wide) ...[
          24.verticalSpace,
          _flowStrip(),
        ],
      ],
    );
  }

  /// Chip 796: the header — title, shop-name pill, and the one line that
  /// says what the whole surface is for.
  Widget _header(QuickFlowSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                AppHelpers.getTranslation(TrKeys.quickFlow),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyle.interSemi(size: 24),
              ),
            ),
            if (settings.shopName.isNotEmpty) ...[
              12.horizontalSpace,
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 7.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppStyle.cardDark,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: AppStyle.strokeDarkSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Remix.store_2_line,
                        size: 14.r,
                        color: AppStyle.textDarkSecondary,
                      ),
                      6.horizontalSpace,
                      Flexible(
                        child: Text(
                          settings.shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppStyle.interRegular(size: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        8.verticalSpace,
        Text(
          AppHelpers.getTranslation(TrKeys.quickFlowExplainer),
          style: AppStyle.interRegular(
            size: 14,
            color: AppStyle.textDarkSecondary,
          ),
        ),
      ],
    );
  }

  Widget _errorLine(String message) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppStyle.red.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppStyle.red.withValues(alpha: .22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Remix.error_warning_line, size: 16.r, color: AppStyle.red),
          10.horizontalSpace,
          Expanded(
            child: Text(
              message,
              style: AppStyle.interRegular(size: 13),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // (a) AUTO-ACCEPT — the one control here bound to a field that already
  //     existed (chips 797/798)
  // -------------------------------------------------------------------

  Widget _autoAcceptCard(QuickFlowSettings settings, {required bool wide}) {
    return _card(
      child: Column(
        children: [
          _switchRow(
            icon: Remix.check_double_line,
            tint: AppStyle.green,
            title: AppHelpers.getTranslation(TrKeys.autoAcceptOrders),
            subtitle:
                AppHelpers.getTranslation(TrKeys.autoAcceptOrdersExplainer),
            badge: _badge(
              AppHelpers.getTranslation(TrKeys.liveServer),
              AppStyle.green,
            ),
            value: settings.autoAcceptOrders,
            onChanged: (value) => ref
                .read(quickFlowProvider.notifier)
                .setAutoAcceptOrders(value),
          ),
          // Chip 798: the platform half of the gate, in the doctype's own
          // words. A wide-read detail — dropped on the phone (42b).
          if (wide) ...[
            14.verticalSpace,
            Divider(height: 1.h, color: AppStyle.strokeDarkSubtle),
            14.verticalSpace,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  settings.platformAutoApprove
                      ? Remix.lock_unlock_line
                      : Remix.lock_line,
                  size: 16.r,
                  color: AppStyle.textDarkSecondary,
                ),
                10.horizontalSpace,
                Expanded(
                  child: Text(
                    AppHelpers.getTranslation(
                      TrKeys.autoAcceptPlatformGate,
                    ),
                    style: AppStyle.interRegular(
                      size: 13,
                      color: AppStyle.textDarkSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // (b) AUTO-COMPLETE AT READY (chips 799/800/801)
  // -------------------------------------------------------------------

  Widget _autoCompleteCard(QuickFlowSettings settings) {
    return _card(
      child: Column(
        children: [
          _switchRow(
            icon: Remix.flag_line,
            tint: AppStyle.rate,
            title: AppHelpers.getTranslation(TrKeys.autoCompleteAtReady),
            subtitle: AppHelpers.getTranslation(
              TrKeys.autoCompleteAtReadyExplainer,
            ),
            badge: _badge(
              AppHelpers.getTranslation(TrKeys.newFlag),
              AppStyle.rate,
            ),
            value: settings.autoCompleteAtReady,
            onChanged: (value) => ref
                .read(quickFlowProvider.notifier)
                .setAutoCompleteAtReady(value),
          ),
          14.verticalSpace,
          // Chip 800: the hand-over warning. Short, and the least
          // comfortable sentence on the page on purpose — this switch
          // trades a confirmation nobody makes for a tap nobody makes.
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: AppStyle.rate.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppStyle.rate.withValues(alpha: .22)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 5.h),
                  child: Container(
                    width: 6.r,
                    height: 6.r,
                    decoration: BoxDecoration(
                      color: AppStyle.rate,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                10.horizontalSpace,
                Expanded(
                  child: Text(
                    AppHelpers.getTranslation(
                      TrKeys.autoCompleteAtReadyWarning,
                    ),
                    style: AppStyle.interRegular(size: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // (c) KEYPAD AUTODIAL + the digit-preset grid (chips 802–805)
  // -------------------------------------------------------------------

  Widget _autodialCard(QuickFlowSettings settings, {required bool wide}) {
    return _card(
      child: Column(
        children: [
          _switchRow(
            icon: Remix.grid_line,
            tint: AppStyle.primary,
            title: AppHelpers.getTranslation(TrKeys.keypadAutodial),
            subtitle:
                AppHelpers.getTranslation(TrKeys.keypadAutodialExplainer),
            badge: _badge(
              AppHelpers.getTranslation(TrKeys.newFlag),
              AppStyle.rate,
            ),
            value: settings.keypadAutodial,
            onChanged: (value) =>
                ref.read(quickFlowProvider.notifier).setKeypadAutodial(value),
          ),
          14.verticalSpace,
          Divider(height: 1.h, color: AppStyle.strokeDarkSubtle),
          14.verticalSpace,
          // Chip 803: the grid's header rail. The counter is the whole
          // point of showing it — a half-configured pad should be visible,
          // not a surprise at the till.
          Row(
            children: [
              Text(
                AppHelpers.getTranslation(TrKeys.digitPresets).toUpperCase(),
                style: AppStyle.interSemi(
                  size: 12,
                  color: AppStyle.textDarkSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${settings.presetCount} '
                '${_decap(AppHelpers.getTranslation(TrKeys.ofNineSet))}',
                style: AppStyle.interRegular(
                  size: 12,
                  color: AppStyle.textDarkSecondary,
                ),
              ),
            ],
          ),
          14.verticalSpace,
          // 3-up at plane width, 1-up on the phone. THE COLUMN COUNT IS
          // THE ONLY THING THAT CHANGES: cell height and type sizes are
          // identical at both widths (42b).
          _presetGrid(settings, columns: wide ? 3 : 1),
        ],
      ),
    );
  }

  Widget _presetGrid(QuickFlowSettings settings, {required int columns}) {
    final cells = <Widget>[
      for (var digit = 1; digit <= QuickFlowSettings.presetSlots; digit++)
        _presetSlot(digit, settings.presetFor(digit)),
    ];
    if (columns == 1) {
      return Column(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) 10.verticalSpace,
            cells[i],
          ],
        ],
      );
    }
    final rows = <Widget>[];
    for (var start = 0; start < cells.length; start += columns) {
      final slice = cells.sublist(
        start,
        (start + columns).clamp(0, cells.length),
      );
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < columns; i++) ...[
              if (i > 0) 10.horizontalSpace,
              Expanded(
                child: i < slice.length ? slice[i] : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) 10.verticalSpace,
          IntrinsicHeight(child: rows[i]),
        ],
      ],
    );
  }

  /// Chip 804 (filled) / chip 805 (empty). An unset digit is drawn
  /// deliberately quiet — dashed, faint, "Add item" — because an unset
  /// digit is INERT on the till, not an error.
  Widget _presetSlot(int digit, QuickFlowPreset? preset) {
    final filled = preset != null;
    return GestureDetector(
      key: Key('quickFlowPreset$digit'),
      behavior: HitTestBehavior.opaque,
      onTap: filled ? null : () => _pickPresetProduct(digit),
      child: Container(
        padding: EdgeInsets.all(10.r),
        decoration: BoxDecoration(
          color: filled ? AppStyle.cardDarkAlt : AppStyle.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: filled
                ? AppStyle.strokeDarkSubtle
                : AppStyle.strokeDarkSubtle,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30.r,
              height: 30.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filled
                    ? AppStyle.primary.withValues(alpha: .15)
                    : AppStyle.transparent,
                borderRadius: BorderRadius.circular(8.r),
                border: filled
                    ? null
                    : Border.all(color: AppStyle.strokeDarkSubtle),
              ),
              child: Text(
                '$digit',
                style: AppStyle.interSemi(
                  size: 14,
                  color: filled ? AppStyle.primary : AppStyle.textDarkFaint,
                ),
              ),
            ),
            12.horizontalSpace,
            Expanded(
              child: filled
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          preset.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppStyle.interSemi(size: 12),
                        ),
                        2.verticalSpace,
                        Text(
                          AppHelpers.numberFormat(number: preset.price),
                          style: AppStyle.interRegular(
                            size: 11,
                            color: AppStyle.textDarkSecondary,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      AppHelpers.getTranslation(TrKeys.addItem),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyle.interRegular(
                        size: 13,
                        color: AppStyle.textDarkSecondary,
                      ),
                    ),
            ),
            8.horizontalSpace,
            filled
                ? GestureDetector(
                    key: Key('quickFlowPresetClear$digit'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        ref.read(quickFlowProvider.notifier).clearPreset(digit),
                    child: Icon(
                      Remix.close_line,
                      size: 16.r,
                      color: AppStyle.textDarkSecondary,
                    ),
                  )
                : Icon(
                    Remix.add_line,
                    size: 16.r,
                    color: AppStyle.textDarkSecondary,
                  ),
          ],
        ),
      ),
    );
  }

  /// The picker behind an empty slot's `+`. Searches through the till's own
  /// catalog seam ([PosCatalogRepositoryFacade] — the same lookup the
  /// scanner and the Add Items lane use), so this page never imports
  /// products_sdk (ADR-005). With no facade registered the sheet says so
  /// rather than pretending to search.
  Future<void> _pickPresetProduct(int digit) async {
    final product = await showModalBottomSheet<ProductData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppStyle.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) => _PresetPickerSheet(digit: digit),
    );
    if (product == null || !mounted) return;
    await ref
        .read(quickFlowProvider.notifier)
        .setPreset(QuickFlowPreset(digit: digit, product: product));
  }

  // -------------------------------------------------------------------
  // The flow strip — what the attendant actually does, three steps across.
  // Wide read only (42b drops it with the rest of the wide extras).
  // -------------------------------------------------------------------

  Widget _flowStrip() {
    final steps = <(String, String)>[
      (
        AppHelpers.getTranslation(TrKeys.quickFlowStep1Title),
        AppHelpers.getTranslation(TrKeys.quickFlowStep1Body),
      ),
      (
        AppHelpers.getTranslation(TrKeys.quickFlowStep2Title),
        AppHelpers.getTranslation(TrKeys.quickFlowStep2Body),
      ),
      (
        AppHelpers.getTranslation(TrKeys.quickFlowStep3Title),
        AppHelpers.getTranslation(TrKeys.quickFlowStep3Body),
      ),
    ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Remix.flashlight_line, size: 16.r, color: AppStyle.primary),
              8.horizontalSpace,
              Expanded(
                child: Text(
                  AppHelpers.getTranslation(TrKeys.quickFlowAllThreeOn),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyle.interSemi(size: 14),
                ),
              ),
              8.horizontalSpace,
              Text(
                AppHelpers.getTranslation(TrKeys.whatTheAttendantDoes),
                style: AppStyle.interRegular(
                  size: 12,
                  color: AppStyle.textDarkSecondary,
                ),
              ),
            ],
          ),
          18.verticalSpace,
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      child: Icon(
                        Remix.arrow_right_s_line,
                        size: 18.r,
                        color: AppStyle.textDarkFaint,
                      ),
                    ),
                  Expanded(child: _flowStep(i + 1, steps[i].$1, steps[i].$2)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowStep(int index, String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24.r,
          height: 24.r,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppStyle.primary.withValues(alpha: .15),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: AppStyle.interSemi(size: 12, color: AppStyle.primary),
          ),
        ),
        10.verticalSpace,
        Text(title, style: AppStyle.interSemi(size: 14)),
        6.verticalSpace,
        Text(
          body,
          style: AppStyle.interRegular(
            size: 13,
            color: AppStyle.textDarkSecondary,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Shared pieces
  // -------------------------------------------------------------------

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppStyle.cardDark,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: child,
    );
  }

  /// Chip 227's settings-row idiom, dark: leading tinted glyph, semi label
  /// with its flag badge, a sub-line that says what the switch actually
  /// does, and the toggle trailing.
  Widget _switchRow({
    required IconData icon,
    required Color tint,
    required String title,
    required String subtitle,
    required Widget badge,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40.r,
          height: 40.r,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20.r, color: tint),
        ),
        14.horizontalSpace,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The badge wraps to its OWN LINE rather than compressing
              // the label (42b) — a Wrap, not a Row.
              Wrap(
                spacing: 10.w,
                runSpacing: 6.h,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(title, style: AppStyle.interSemi(size: 16)),
                  badge,
                ],
              ),
              6.verticalSpace,
              Text(
                subtitle,
                style: AppStyle.interRegular(
                  size: 13,
                  color: AppStyle.textDarkSecondary,
                ),
              ),
            ],
          ),
        ),
        14.horizontalSpace,
        // base_sdk's manager toggle, driven from state: a fresh controller
        // per build carries the CURRENT value, so an optimistic write that
        // the server refuses snaps the switch back with the state.
        CustomToggle(
          key: Key('quickFlowToggle$title'),
          controller: ValueNotifier<bool>(value),
          onChange: (checked) => onChanged(checked ?? false),
        ),
      ],
    );
  }

  /// The humanized tr-key fallback upper-cases its first letter, which is
  /// wrong mid-sentence — the checkout's own `_decap` rule.
  static String _decap(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  /// Chip 801: the reusable flag badge — a 20px pill, tinted text on a 15%
  /// wash of the same colour.
  Widget _badge(String label, Color color) {
    return Container(
      height: 20.h,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Text(
        label,
        style: AppStyle.interSemi(
          size: 10,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// The preset picker: search the shop's catalog, tap a product, it becomes
/// that digit's preset. Modelled on the checkout's customer picker sheet —
/// same debounce, same honest empty states.
class _PresetPickerSheet extends StatefulWidget {
  const _PresetPickerSheet({required this.digit});

  final int digit;

  @override
  State<_PresetPickerSheet> createState() => _PresetPickerSheetState();
}

class _PresetPickerSheetState extends State<_PresetPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  List<ProductData> _results = const [];
  bool _searching = false;
  bool _searched = false;

  PosCatalogRepositoryFacade? get _catalog =>
      GetIt.I.isRegistered<PosCatalogRepositoryFacade>()
          ? GetIt.I<PosCatalogRepositoryFacade>()
          : null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String text) async {
    final catalog = _catalog;
    if (catalog == null || text.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searched = text.trim().isNotEmpty;
      });
      return;
    }
    setState(() => _searching = true);
    final result = await catalog.searchProducts(text: text.trim());
    if (!mounted) return;
    result.when(
      success: (data) => setState(() {
        _results = data.data ?? const [];
        _searching = false;
        _searched = true;
      }),
      failure: (error, statusCode) => setState(() {
        _results = const [];
        _searching = false;
        _searched = true;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 16.h,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${AppHelpers.getTranslation(TrKeys.chooseItemForKey)} '
            '${widget.digit}',
            style: AppStyle.interSemi(size: 16),
          ),
          14.verticalSpace,
          TextField(
            key: const Key('quickFlowPresetSearch'),
            controller: _controller,
            onSubmitted: _search,
            onChanged: _search,
            style: AppStyle.interRegular(size: 14),
            decoration: InputDecoration(
              hintText: AppHelpers.getTranslation(TrKeys.searchProducts),
              hintStyle: AppStyle.interRegular(
                size: 14,
                color: AppStyle.textDarkSecondary,
              ),
              filled: true,
              fillColor: AppStyle.cardDarkAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          14.verticalSpace,
          if (_catalog == null)
            _note(AppHelpers.getTranslation(TrKeys.noData))
          else if (_searching)
            const Center(child: CircularProgressIndicator.adaptive())
          else if (_results.isEmpty && _searched)
            _note(AppHelpers.getTranslation(TrKeys.noData))
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 320.h),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (context, index) => 8.verticalSpace,
                itemBuilder: (context, index) {
                  final product = _results[index];
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(product),
                    child: Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: AppStyle.cardDarkAlt,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.translation?.title ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppStyle.interSemi(size: 14),
                            ),
                          ),
                          8.horizontalSpace,
                          Text(
                            AppHelpers.numberFormat(
                              number: (product.stocks?.isNotEmpty ?? false)
                                  ? product.stocks!.first.price
                                  : product.stock?.price,
                            ),
                            style: AppStyle.interRegular(
                              size: 13,
                              color: AppStyle.textDarkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          16.verticalSpace,
        ],
      ),
    );
  }

  Widget _note(String message) => Padding(
        padding: EdgeInsets.symmetric(vertical: 18.h),
        child: Text(
          message,
          style: AppStyle.interRegular(
            size: 13,
            color: AppStyle.textDarkSecondary,
          ),
        ),
      );
}
