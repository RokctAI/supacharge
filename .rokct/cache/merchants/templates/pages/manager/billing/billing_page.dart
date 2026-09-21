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

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:remixicon/remixicon.dart';

import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:base_sdk/src/presentation/components/helper/common_image.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/demo_session.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:get_it/get_it.dart';
import 'package:merchants_sdk/src/manager/application/pos_cart/pos_cart_provider.dart';
import 'package:merchants_sdk/src/manager/application/pos_cart/pos_cart_state.dart';
import 'package:merchants_sdk/src/manager/application/pos_cart/pos_sale_finish.dart';
import 'package:merchants_sdk/src/manager/application/quick_flow/quick_flow_provider.dart';
import 'package:merchants_sdk/src/manager/domain/interface/pos_orders.dart';
import 'package:merchants_sdk/src/manager/presentation/main/manager_nav_clearance.dart';
import 'package:merchants_sdk/src/manager/presentation/pos/pos_category_chip_bar.dart';
import 'package:merchants_sdk/src/manager/presentation/pos/receipt_preview_page.dart';
import 'package:merchants_sdk/src/manager/presentation/pos/receipt_slip.dart';

// Same install directory (lib/presentation/pages/billing/), so the
// relative import resolves both here and in the composed host — the
// restaurant_page template imports its widgets the same way.
import 'checkout_page.dart';

// The manager POS tab (BillingPage) — the old Spazafy ManagerBillingPage
// rebuilt around the retired Quick Receipt app's working ideas, in the
// current AppStyle token language. Approved design 2026-08-28 (strip
// section 11, frames 11a/11b, with Ray's same-day deltas):
//   * scanner viewfinder stage (chip 273) with torch (274) and
//     pause/resume (275; a 45s idle timer auto-pauses — the old app's
//     battery-saving idiom carried over);
//   * the Scan entry lane (276) sits CENTERED INSIDE the viewfinder
//     stage per chip 227's settings-row idiom — leading scan glyph +
//     semi label + trailing chevron on a light card (light in BOTH
//     modes: it rides the fixed dark camera housing). Per Ray's icon
//     dedup the stand-in's ghost scan_2_line watermark is REMOVED (it
//     duplicated the lane's leading glyph directly below it) — the lane
//     keeps the icon, the stage stays a clean housing. Tap resumes the
//     camera. Add Items (277) keeps the lane row below the stage; its
//     sheet follows frame 11j (chips 316–321): the 171-pattern bare
//     title row and the section-12 back-only floating pill;
//   * cart: item-count chip (278), Clear All (279), line cards (280) with
//     −/+ steppers (281/283), a tappable quantity opening a decimal edit
//     for weighed kg/L units (282), currency-formatted line totals (284,
//     "R150.00 × 2" — never raw floats), per-line remove (285);
//   * the summary (286) restyled to match the checkout's summary card
//     (292) per Ray 2026-08-28: a free-standing rounded card on the page
//     surface (Items row, hairline, bold Total), with the Continue
//     button (287) OUTSIDE the card in 293's button treatment;
//   * a pending-sync indicator (offline-first: sales recorded on the
//     till that have not reached the backend yet, via
//     PosOrdersFacade.pendingSaleCount).
//
// The five Spazafy compile errors are gone by construction (real
// crossAxisAlignment; base_sdk's real ProductData/Stocks family via
// PosCartState; numberFormat(number:); AppStyle.bgGrey/mode-resolving
// tokens; no phantom widgets), and the held build's review findings are
// designed out here: the scanner controller is DISPOSED, scans dedupe in
// the notifier (2s window), money is cents-rounded at the state boundary,
// and the order id is minted in the notifier — never in build.
//
// Tab-hosted at index 0 of the manager shell (main_page.dart imports this
// page directly), so it carries no @RoutePage and the manifest declares no
// route for it — the RestaurantPage/OrdersHomePage contract. Checkout is a
// pushed route: the manifest's /pos-checkout (checkout_page.dart, same
// install directory), reached by path so this template compiles without
// the host's generated router.
//
// Demo (--dart-define=IS_DEMO=true): the camera never mounts — the stage
// renders its camera-less stand-in (the strip's render harness did the
// same; the stage, frame and controls are the real widgets) and barcode
// lookups route to MockProductsRepository via the DI demo gate, so
// headless tours and the standalone test harness exercise the real page.
//
// TABLET MODE — the approved plane layout (design strip section 11,
// frames 11m/11n, approved by Ray 2026-08-29 13:53Z / 13:06Z, built here
// on base_sdk's PlaneHost): the till is the flow's ROOT and declares ALL
// planes, spreading ITSELF by the span it is granted —
//   * 3 planes (>= 840): scan | Add Items | cart (11m) — the Add Items
//     experience is a PERMANENT PANE (11j's search, no sheet: Ray's
//     12:02Z sheet fork), so the Add Items lane (277) leaves the scan
//     plane there ("227 in 11m is redundent as they already show");
//   * 2 planes (600..839): scan | cart — the same declaration granted
//     two (11m: "the same declaration that yields scan | cart at 673");
//     the lane stays, since no pane shows ("the lane stays wherever the
//     pane is absent");
//   * 1 plane: exactly the phone page above.
// Continue on plane widths does NOT push the /pos-checkout route: the
// checkout is pushed INTO THE PLANES as the flow's next step, claiming
// TWO (11n, Ray 12:26Z: "what i came from should take first plane") —
// at three planes the till yields to its scan plane (273 + the 277 lane,
// "where the flow came from; Charge is one BACK away") and the checkout
// spreads order truth | tender over planes 2–3; at two planes the
// payment claim takes both and the till slides off (the plane model's
// grant rule, min(claim, count)). The host's back pill sits at the
// bottom-END corner (12d, the two-state nav) and pops the checkout; the
// till is top-level, so it carries no pill of its own — the shell's nav
// (the rail in the manager compose) is the full nav. Phones never enter
// any of this: PlaneHost is one plane there, Continue pushes the route.
// THE RECEIPT AS ONE PLANE (frame 11r, approved 13:06Z — "the best ui
// ever", the reference standard): "Print Receipt & Finish" on the hosted
// checkout POPS the checkout off this stack and pushes the receipt
// preview (ReceiptPreviewPage: 11k's paper slip, 322, plus the dual
// finish) claiming the DEFAULT — ONE plane, PlaneSpan.one — so it takes
// the LAST plane at its natural size and the till returns beneath on the
// leftover planes (scan | cart at three, the next sale's stage); the END
// pill pops it back to the till. On a phone the checkout pushes the
// preview as a route itself (11k).
//
// 11m's category chip bar (chip 349, "a horizontal pill row (All / ...)
// in the dark till tokens") rides the Add Items PANE since 1.30.0 —
// PosCategoryChipBar under the search field, fed by the catalog seam's
// categories; a tapped chip filters the rows (with nothing typed it lists
// the category). Pane only: the phone sheet (11j) stays 316–321.

class BillingPage extends ConsumerStatefulWidget {
  const BillingPage({super.key});

  @override
  ConsumerState<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends ConsumerState<BillingPage>
    with WidgetsBindingObserver {
  /// 45s with no accepted scan pauses the camera (resume re-arms it).
  static const Duration idleTimeout = Duration(seconds: 45);

  MobileScannerController? _controller;
  Timer? _idleTimer;
  bool _paused = false;
  bool _torchOn = false;

  /// The checkout holds planes 2–3 (11n) — plane widths only; on a phone
  /// the checkout is the pushed /pos-checkout route and this is ignored.
  bool _checkoutOpen = false;

  /// The receipt preview holds the LAST plane (11r) in place of the
  /// checkout — the sale as the checkout snapshotted it at 293. Plane
  /// widths only, like [_checkoutOpen].
  ({PosReceiptData receipt, PosSaleFinish sale})? _receipt;

  /// Sales recorded on this till that have not reached the backend yet
  /// (offline-first pending-sync indicator). Null hides the chip.
  int? _pendingSyncCount;

  PosOrdersFacade? get _posOrders =>
      GetIt.I.isRegistered<PosOrdersFacade>() ? GetIt.I<PosOrdersFacade>() : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The camera stays unmounted in a demo build or a demo session
    // (base_sdk's runtime switch; the stage renders its stand-in). A plain
    // read: the till is pushed after the login flow has settled the switch,
    // and a sign-out tears it down, so it is never on screen at the flip.
    if (!DemoSession.demoActive) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
      );
      _armIdleTimer();
    }
    unawaited(_refreshPendingSync());
    // Autodial's arming condition is shop state; read it once here so the
    // till knows whether an empty ticket has anywhere to go before the
    // attendant taps.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(quickFlowProvider).loaded) {
        unawaited(ref.read(quickFlowProvider.notifier).load());
      }
    });
  }

  Future<void> _refreshPendingSync() async {
    final facade = _posOrders;
    if (facade == null) return;
    final count = await facade.pendingSaleCount();
    if (mounted) setState(() => _pendingSyncCount = count);
  }

  @override
  void dispose() {
    // Held-build finding: the Spazafy page leaked its controller — the
    // camera stayed lit after leaving the tab. Cancel + dispose here.
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _armIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, () {
      if (!mounted || _paused) return;
      _setPaused(true);
    });
  }

  void _setPaused(bool paused) {
    setState(() => _paused = paused);
    if (paused) {
      _idleTimer?.cancel();
      unawaited(_controller?.stop());
    } else {
      unawaited(_controller?.start());
      _armIdleTimer();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final raw = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (raw == null || raw.isEmpty) return;
    // The notifier owns the 2s dedupe window — a held frame-stream can
    // never re-add the same physical scan.
    final added =
        await ref.read(posCartProvider.notifier).addByBarcode(raw);
    if (added) {
      unawaited(HapticFeedback.mediumImpact());
      _armIdleTimer();
    }
  }

  /// The shop mapped at least one digit and turned autodial on. Read
  /// here only to keep Continue reachable on an empty ticket — the till's
  /// actual interpretation of a key press lives on the checkout surface,
  /// where the keypad is.
  bool get _autodialArmed =>
      ref.watch(quickFlowProvider).settings.autodialArmed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.surfaceDark,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // A phone-width window never hosts the checkout in a plane —
          // Continue pushed the route there, so a stale flag is ignored.
          final bool onePlane =
              PlaneHost.planeCountFor(constraints.maxWidth) == 1;
          final receipt = onePlane ? null : _receipt;
          final bool checkoutOpen =
              !onePlane && _checkoutOpen && receipt == null;
          return PlaneHost(
            // The ONE back affordance while a step holds a plane: the
            // host parks it at the bottom-END corner (12d) and it pops
            // the NEWEST step — the receipt, else the checkout — never
            // the till.
            back: FloatingNavBack(
              icon: Remix.arrow_left_wide_fill,
              label: AppHelpers.getTranslation(TrKeys.back),
              onTap: _popStep,
            ),
            stack: [
              PlanePage(
                name: 'pos-till',
                // 11m: "the page declares 3 and spreads ITSELF".
                span: PlaneSpan.all,
                builder: _till,
              ),
              if (checkoutOpen)
                PlanePage(
                  name: 'pos-checkout',
                  // 11n: the payment cap — checkout claims TWO; the till
                  // keeps the first plane where a third exists.
                  span: PlaneSpan.two,
                  builder: (context) => CheckoutPage(
                    onClose: _closeCheckout,
                    onReceipt: _openReceipt,
                  ),
                ),
              if (receipt != null)
                PlanePage(
                  name: 'pos-receipt',
                  // 11r: the DEFAULT claim — one plane, never stretched;
                  // the till fills the rest beneath, no forcing.
                  span: PlaneSpan.one,
                  builder: (context) => ReceiptPreviewPage(
                    receipt: receipt.receipt,
                    sale: receipt.sale,
                    onFinished: _closeReceipt,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// The till, spread by the span the host granted it.
  Widget _till(BuildContext context) {
    final state = ref.watch(posCartProvider);
    final planes = Planes.of(context);
    // One-plane screen: the shipped phone page, untouched.
    if (planes.count == 1) return _phoneColumn(context, state);
    // Yielded to one plane beside the checkout (11n plane 1): the scan
    // stage and the Add Items lane — the cart lives in the checkout's
    // summary now.
    if (planes.span == 1) return _scanColumn(context, lane: true);
    final SizedBox seam = SizedBox(width: planes.gap);
    final bool addItemsPane = planes.span >= 3;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 11m plane 1: at three planes the lane (277) is REMOVED — the
        // pane beside it IS Add Items; at the two-plane fold no pane
        // shows, so the lane stays the door.
        Expanded(child: _scanColumn(context, lane: !addItemsPane)),
        if (addItemsPane) ...[
          seam,
          // 11m plane 2: the Add Items experience as a permanent pane
          // (317 title, 318 search, 319/320 rows) — no sheet, no pill.
          Expanded(
            child: SafeArea(
              bottom: false,
              child: const _AddItemsSearch(
                key: Key('posAddItemsPane'),
                asPane: true,
              ),
            ),
          ),
        ],
        seam,
        // 11m plane 3: the cart — 278–280, 286/287.
        Expanded(
          child: SafeArea(
            bottom: false,
            child: _cartColumn(context, state),
          ),
        ),
      ],
    );
  }

  /// The shipped phone page (frames 11a/11b), exactly as before.
  Widget _phoneColumn(BuildContext context, PosCartState state) {
    return Column(
      children: [
        _scannerStage(context),
        16.verticalSpace,
        _lanes(context),
        18.verticalSpace,
        Expanded(child: _cartColumn(context, state)),
      ],
    );
  }

  /// The scan plane: the viewfinder stage (273–276) and, where no Add
  /// Items pane is on screen, the Add Items lane (277).
  Widget _scanColumn(BuildContext context, {required bool lane}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _scannerStage(context),
        if (lane) ...[
          16.verticalSpace,
          _lanes(context),
        ],
      ],
    );
  }

  /// The cart: header (278/279), line cards (280–285), summary + Continue
  /// (286/287). The whole phone page below the lanes; a plane of its own
  /// at plane widths.
  Widget _cartColumn(BuildContext context, PosCartState state) {
    return Column(
      children: [
        _cartHeader(context, state),
        10.verticalSpace,
        Expanded(
          child: state.lines.isEmpty
              ? Center(
                  child: Text(
                    AppHelpers.getTranslation(TrKeys.cartIsEmpty),
                    style: AppStyle.interRegular(
                      size: 14,
                      color: AppStyle.textDarkSecondary,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: state.lines.length,
                  separatorBuilder: (context, index) => 12.verticalSpace,
                  itemBuilder: (context, index) =>
                      _lineCard(context, state, index),
                ),
        ),
        _summary(context, state),
      ],
    );
  }

  /// Continue (287): on a phone the checkout is the pushed /pos-checkout
  /// route, as shipped; on plane widths it is the flow's next step and
  /// takes its planes here (11n).
  void _openCheckout(BuildContext context) {
    if ((Planes.maybeOf(context)?.count ?? 1) > 1) {
      setState(() => _checkoutOpen = true);
      return;
    }
    unawaited(
      context.router
          .pushNamed('/pos-checkout')
          .whenComplete(_refreshPendingSync),
    );
  }

  /// Back pops the checkout (the host's END-corner pill), and so does a
  /// finished sale; the pending-sync chip re-reads either way, exactly as
  /// the route's whenComplete did.
  void _closeCheckout() {
    if (!_checkoutOpen) return;
    setState(() => _checkoutOpen = false);
    unawaited(_refreshPendingSync());
  }

  /// 293 on the hosted checkout (11r): the checkout pops, the receipt
  /// takes the last plane.
  void _openReceipt(PosReceiptData receipt, PosSaleFinish sale) {
    setState(() {
      _checkoutOpen = false;
      _receipt = (receipt: receipt, sale: sale);
    });
  }

  /// Back pops the receipt (the END pill) and lands on the till — the
  /// sale is still open, Continue re-enters the checkout; a finished sale
  /// leaves the same way with the cart already cleared.
  void _closeReceipt() {
    if (_receipt == null) return;
    setState(() => _receipt = null);
    unawaited(_refreshPendingSync());
  }

  /// The END pill pops the NEWEST step of the flow.
  void _popStep() {
    if (_receipt != null) {
      _closeReceipt();
      return;
    }
    _closeCheckout();
  }

  /// Chip 273: the viewfinder stage — a fixed dark camera housing (same in
  /// both modes, like a real viewfinder) with torch (274) and pause (275)
  /// riding its top-right, and the Scan control (276) CENTERED inside the
  /// stage per Ray 2026-08-28 (chip 227's settings-row idiom). Demo builds
  /// render the camera-less stand-in.
  Widget _scannerStage(BuildContext context) {
    final controller = _controller;
    final bool cameraLive = controller != null && !_paused;
    return Container(
      key: const Key('posScanStage'),
      height: 340.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppStyle.black,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28.r),
          bottomRight: Radius.circular(28.r),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (cameraLive)
            Positioned.fill(
              child: MobileScanner(
                controller: controller,
                onDetect: _onDetect,
              ),
            ),
          // Icon dedup per Ray 2026-08-28: the stand-in's ghost
          // scan_2_line watermark is REMOVED (it duplicated the Scan
          // control's leading glyph directly below it) — the stage stays
          // a clean housing; the control keeps the icon.
          Center(child: _scanControl(context)),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(top: 8.h, right: 16.w),
                child: Row(
                  children: [
                    _stageButton(
                      icon: _torchOn
                          ? Remix.flashlight_fill
                          : Remix.flashlight_line,
                      onTap: () {
                        setState(() => _torchOn = !_torchOn);
                        unawaited(_controller?.toggleTorch());
                      },
                    ),
                    10.horizontalSpace,
                    _stageButton(
                      icon: _paused ? Remix.play_line : Remix.pause_line,
                      onTap: () => _setPaused(!_paused),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Chip 276: the Scan control, centered in the viewfinder (273) per
  /// chip 227's settings-row idiom — leading scan glyph + semi label +
  /// trailing chevron on a LIGHT card (white in both modes: it rides the
  /// fixed dark camera housing). The lane KEEPS its leading glyph
  /// (load-bearing in the settings-row idiom) — Ray's dedup removed the
  /// stage's duplicate watermark instead. Tap resumes the camera.
  Widget _scanControl(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_paused) _setPaused(false);
      },
      child: Container(
        height: 56.r,
        padding: EdgeInsets.symmetric(horizontal: 28.w),
        decoration: BoxDecoration(
          color: AppStyle.white,
          borderRadius: BorderRadius.circular(100.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Remix.scan_2_line,
              size: 22.r,
              color: AppStyle.blackColor,
            ),
            10.horizontalSpace,
            Text(
              AppHelpers.getTranslation(TrKeys.scan),
              style: AppStyle.interSemi(
                size: 17,
                color: AppStyle.blackColor,
              ),
            ),
            10.horizontalSpace,
            Icon(
              Remix.arrow_right_s_line,
              size: 20.r,
              color: AppStyle.blackColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stageButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44.r,
        height: 44.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppStyle.white.withOpacity(0.14),
        ),
        child: Icon(icon, size: 22.r, color: AppStyle.white),
      ),
    );
  }

  /// Chip 277: the Add Items entry lane (manual search by name or
  /// barcode). The Scan lane (276) moved into the viewfinder stage per
  /// Ray 2026-08-28, so Add Items keeps the lane row alone.
  Widget _lanes(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          KeyedSubtree(
            key: const Key('posAddItemsLane'),
            child: _laneChip(
              icon: Remix.search_line,
              label: AppHelpers.getTranslation(TrKeys.addItems),
              onTap: () => _openAddItemsSheet(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _laneChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44.r,
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        decoration: BoxDecoration(
          color: AppStyle.cardDark,
          borderRadius: BorderRadius.circular(100.r),
          border: Border.all(color: AppStyle.strokeDark, width: 1.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18.r, color: AppStyle.textPrimary),
            8.horizontalSpace,
            Text(
              label,
              style: AppStyle.interSemi(size: 15),
            ),
          ],
        ),
      ),
    );
  }

  /// Chips 278/279: "Cart" + quantity-sum chip + Clear All.
  Widget _cartHeader(BuildContext context, PosCartState state) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Text(
            AppHelpers.getTranslation(TrKeys.cart),
            style: AppStyle.interSemi(size: 22),
          ),
          10.horizontalSpace,
          if (state.lines.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppStyle.blue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(100.r),
              ),
              child: Text(
                _trimQty(state.itemCount),
                style: AppStyle.interSemi(size: 13, color: AppStyle.blue),
              ),
            ),
          const Spacer(),
          if ((_pendingSyncCount ?? 0) > 0) ...[
            // Pending-sync indicator: offline-first sales recorded on the
            // till still queued for the backend (they drain through the
            // SyncEngine when the backend is reachable).
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppStyle.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(100.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Remix.refresh_line,
                    size: 14.r,
                    color: AppStyle.primary,
                  ),
                  4.horizontalSpace,
                  Text(
                    '$_pendingSyncCount ${AppHelpers.getTranslation(TrKeys.pendingSync)}',
                    style: AppStyle.interSemi(
                      size: 12,
                      color: AppStyle.primary,
                    ),
                  ),
                ],
              ),
            ),
            10.horizontalSpace,
          ],
          if (state.lines.isNotEmpty)
            GestureDetector(
              // Clear All resets the WHOLE cart state; the total is a
              // derived getter so it reads 0 immediately (the Spazafy
              // stale-total bug is impossible by construction).
              onTap: () => ref.read(posCartProvider.notifier).clearAll(),
              child: Text(
                AppHelpers.getTranslation(TrKeys.clearAll),
                style: AppStyle.interSemi(size: 15, color: AppStyle.red),
              ),
            ),
        ],
      ),
    );
  }

  /// Chip 280: one cart line card — image, title, formatted "unit × qty"
  /// price line, −/+ stepper with the tappable decimal quantity, line
  /// total, remove.
  Widget _lineCard(BuildContext context, PosCartState state, int index) {
    final line = state.lines[index];
    final notifier = ref.read(posCartProvider.notifier);
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppStyle.cardDark,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommonImage(
            url: line.product.img,
            width: 56.r,
            height: 56.r,
            radius: 12,
          ),
          12.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.title,
                  style: AppStyle.interSemi(size: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                4.verticalSpace,
                // Chip 284's sibling: the unit-price line is currency
                // formatted ("R150.00 × 2"), never the Spazafy raw
                // "18.99 x 2" float string.
                Text(
                  '${AppHelpers.numberFormat(number: line.unitPrice)} × ${_trimQty(line.quantity)}',
                  style: AppStyle.interRegular(
                    size: 13,
                    color: AppStyle.textDarkSecondary,
                  ),
                ),
                10.verticalSpace,
                Row(
                  children: [
                    _stepButton(
                      icon: Remix.subtract_line,
                      onTap: () => notifier.decrement(index),
                    ),
                    GestureDetector(
                      // Chip 282: tapping the quantity opens the decimal
                      // edit for weighed units (kg/L).
                      onTap: () => _editQuantity(context, index, line),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w),
                        child: Text(
                          _trimQty(line.quantity),
                          style: AppStyle.interSemi(size: 16),
                        ),
                      ),
                    ),
                    _stepButton(
                      icon: Remix.add_line,
                      onTap: () => notifier.increment(index),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppHelpers.numberFormat(number: line.lineTotal),
                style: AppStyle.interSemi(size: 16),
              ),
              10.verticalSpace,
              GestureDetector(
                onTap: () => notifier.removeLine(index),
                child: Icon(
                  Remix.delete_bin_line,
                  size: 20.r,
                  color: AppStyle.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36.r,
        height: 36.r,
        decoration: BoxDecoration(
          color: AppStyle.cardDarkAlt,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppStyle.strokeDarkSubtle, width: 1.r),
        ),
        child: Icon(icon, size: 18.r, color: AppStyle.textPrimary),
      ),
    );
  }

  /// Chips 286/287: the receipt-style summary — restyled per Ray
  /// 2026-08-28 to match the checkout's free-standing rounded summary
  /// card (292: Items row, hairline, bold Total) — and the Continue
  /// button carrying the total, OUTSIDE the card in 293's treatment.
  Widget _summary(BuildContext context, PosCartState state) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 0),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: AppStyle.cardDark,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        AppHelpers.getTranslation(TrKeys.items),
                        style: AppStyle.interRegular(
                          size: 14,
                          color: AppStyle.textDarkSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _trimQty(state.itemCount),
                        style: AppStyle.interRegular(size: 14),
                      ),
                    ],
                  ),
                  10.verticalSpace,
                  Divider(height: 1.h, color: AppStyle.strokeDarkSubtle),
                  10.verticalSpace,
                  Row(
                    children: [
                      Text(
                        AppHelpers.getTranslation(TrKeys.total),
                        style: AppStyle.interSemi(size: 18),
                      ),
                      const Spacer(),
                      Text(
                        AppHelpers.numberFormat(number: state.total),
                        style: AppStyle.interSemi(
                          size: 20,
                          color: AppStyle.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            16.verticalSpace,
            // KEYPAD AUTODIAL (approved design strip section 42): an
            // empty ticket normally has nowhere to go — but with autodial
            // armed the pad IS how the ticket gets built, and the pad
            // lives on the payment surface, so Continue stays live to
            // carry the attendant there. Money in first, item on the
            // ticket with one key, no menu hunting. Unarmed shops see
            // exactly the gate they always saw.
            GestureDetector(
              onTap: state.lines.isEmpty && !_autodialArmed
                  ? null
                  : () => _openCheckout(context),
              child: Container(
                key: const Key('posContinue'),
                width: double.infinity,
                height: 56.r,
                decoration: BoxDecoration(
                  color: state.lines.isEmpty && !_autodialArmed
                      ? AppStyle.primary.withOpacity(0.4)
                      : AppStyle.primary,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${AppHelpers.getTranslation(TrKeys.continueText)}  •  ${AppHelpers.numberFormat(number: state.total)}',
                  style: AppStyle.interSemi(
                    size: 16,
                    color: AppStyle.blackColor,
                  ),
                ),
              ),
            ),
            // NAV CLEARANCE (tour run 33952102598, phone still 05): on the
            // one-plane phone page the shell's floating pill rides the
            // Scaffold's centerFloat slot, over this column's foot, and
            // sat on top of Continue. The foot now clears the pill by the
            // shell's own figures (managerNavClearance) — the pill itself
            // is neither moved nor hidden. Plane widths keep the 12 gap:
            // the shell docks the nav as a rail beside the pages there.
            SizedBox(
              height: (Planes.maybeOf(context)?.count ?? 1) == 1
                  ? managerNavClearance()
                  : 12.h,
            ),
          ],
        ),
      ),
    );
  }

  /// Chip 282's dialog: decimal quantity edit for weighed units.
  Future<void> _editQuantity(
    BuildContext context,
    int index,
    PosCartLine line,
  ) async {
    final controller =
        TextEditingController(text: _trimQty(line.quantity));
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppStyle.cardDark,
        title: Text(
          AppHelpers.getTranslation(TrKeys.editQuantity),
          style: AppStyle.interSemi(size: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppStyle.interSemi(size: 18),
          decoration: InputDecoration(
            hintText: AppHelpers.getTranslation(TrKeys.typeHere),
            hintStyle: AppStyle.interRegular(
              size: 16,
              color: AppStyle.textDarkFaint,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              AppHelpers.getTranslation(TrKeys.cancel),
              style: AppStyle.interSemi(
                size: 14,
                color: AppStyle.textDarkSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: Text(
              AppHelpers.getTranslation(TrKeys.done),
              style: AppStyle.interSemi(size: 14, color: AppStyle.blue),
            ),
          ),
        ],
      ),
    );
    final quantity = double.tryParse((entered ?? '').replaceAll(',', '.'));
    if (quantity != null) {
      ref.read(posCartProvider.notifier).setQuantity(index, quantity);
    }
  }

  /// Chip 277's sheet: manual product search by name or barcode.
  void _openAddItemsSheet(BuildContext context) {
    AppHelpers.showCustomModalBottomSheet(
      paddingTop: MediaQuery.paddingOf(context).top + 100,
      context: context,
      modal: const _AddItemsSearch(),
      isDarkMode: false,
    );
  }

  /// "2" not "2.0", "0.75" as typed — quantities are decimal for weighed
  /// units but read as integers when they are whole.
  static String _trimQty(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.round().toString();
    }
    return quantity.toString();
  }
}

/// The Add Items experience: the 171-pattern bare title row (317), a
/// search field over the POS catalog with one-tap add (318–320). Rides
/// the same posCartProvider search state.
///
/// Two homes, one widget (Ray's 12:02Z sheet fork):
///  * the PHONE sheet (frame 11j, chips 316–321) — opened by the Add
///    Items lane, rounded top, autofocused, closing on an add, with the
///    section-12 back-only floating pill (321) as its single drawn close
///    affordance;
///  * the PERMANENT PANE of the three-plane till (frame 11m, plane 2) —
///    [asPane]: on the plane grid with no sheet chrome, no pill and no
///    autofocus (a pane must not raise the keyboard on every till
///    visit), and an add keeps the pane and its query up for the next
///    item, and 11m's category chip bar (349) sits under the search field
///    — All first, then the shop's categories from the catalog seam; a
///    tapped chip narrows the rows to that category (with nothing typed
///    it lists the category), All widens them again. The bar is the
///    pane's alone: the phone sheet (11j) draws 316–321, no chips.
class _AddItemsSearch extends ConsumerStatefulWidget {
  final bool asPane;

  const _AddItemsSearch({super.key, this.asPane = false});

  @override
  ConsumerState<_AddItemsSearch> createState() => _AddItemsSearchState();
}

class _AddItemsSearchState extends ConsumerState<_AddItemsSearch> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // The chip bar's categories (349): fetched once per till session, by
    // the pane that draws them — the sheet never shows the bar, so a
    // phone never asks. The answer lands after this frame.
    if (widget.asPane && ref.read(posCartProvider).categories.isEmpty) {
      unawaited(ref.read(posCartProvider.notifier).loadCategories());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(posCartProvider.notifier).search(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(posCartProvider);
    final bool asPane = widget.asPane;
    final Widget content = Padding(
      padding: EdgeInsets.all(16.r),
      child: Column(
        mainAxisSize: asPane ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // Chip 317 (frame 11j): the 171-pattern bare title row applied
          // to the sheet — interSemi 18, no AppBar (the strip's header
          // convention; the held code opened title-less).
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(bottom: 12.r),
              child: Text(
                AppHelpers.getTranslation(TrKeys.addItems),
                style: AppStyle.interSemi(size: 18),
              ),
            ),
          ),
          TextField(
            key: const Key('posAddItemsSearchField'),
            controller: _controller,
            autofocus: !asPane,
            onChanged: _onChanged,
            style: AppStyle.interSemi(size: 16),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Remix.search_line,
                size: 20.r,
                color: AppStyle.textDarkSecondary,
              ),
              hintText: AppHelpers.getTranslation(TrKeys.searchProducts),
              hintStyle: AppStyle.interRegular(
                size: 15,
                color: AppStyle.textDarkFaint,
              ),
              filled: true,
              fillColor: AppStyle.cardDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          12.verticalSpace,
          // Chip 349 (frame 11m): the category chip bar, pane only.
          if (asPane) ...[
            PosCategoryChipBar(
              key: const Key('posCategoryChipBar'),
              categories: state.categories,
              selectedId: state.categoryId,
              onSelect: (id) =>
                  ref.read(posCartProvider.notifier).selectCategory(id),
            ),
            if (state.categories.isNotEmpty) 12.verticalSpace,
          ],
          if (state.isSearching)
            Padding(
              padding: EdgeInsets.all(24.r),
              child: const CircularProgressIndicator.adaptive(),
            )
          else
            Flexible(
              fit: asPane ? FlexFit.tight : FlexFit.loose,
              child: ListView.separated(
                shrinkWrap: !asPane,
                itemCount: state.searchResults.length,
                separatorBuilder: (context, index) => 8.verticalSpace,
                itemBuilder: (context, index) {
                  final product = state.searchResults[index];
                  final price = (product.stocks?.isNotEmpty ?? false)
                      ? product.stocks!.first.price
                      : null;
                  return ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8.w),
                    leading: CommonImage(
                      url: product.img,
                      width: 44.r,
                      height: 44.r,
                      radius: 10,
                    ),
                    title: Text(
                      product.translation?.title ?? '',
                      style: AppStyle.interSemi(size: 15),
                    ),
                    subtitle: price == null
                        ? null
                        : Text(
                            AppHelpers.numberFormat(number: price),
                            style: AppStyle.interRegular(
                              size: 13,
                              color: AppStyle.textDarkSecondary,
                            ),
                          ),
                    trailing: Icon(
                      Remix.add_line,
                      size: 22.r,
                      color: AppStyle.blue,
                    ),
                    onTap: () {
                      ref
                          .read(posCartProvider.notifier)
                          .addProduct(product);
                      // The sheet closes on an add; the pane stays up.
                      if (!asPane) Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          // Chip 321 (frame 11j): the back-only floating pill — the
          // section-12 pill housing carrying ONLY the labelled back
          // segment (301's DNA). Its default tap is Navigator.maybePop,
          // which dismisses the sheet; per the one-back pattern the sheet
          // draws no other back/close affordance. The PANE draws none:
          // it is part of a top-level page (11m shows the full nav).
          if (!asPane) ...[
            12.verticalSpace,
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
        ],
      ),
    );
    // The pane sits on the till's own surface (the Scaffold's ground) and
    // paints the rows' ink on a Material of its own — a coloured box
    // between the rows and the Scaffold's Material would hide it. The
    // sheet keeps its rounded surfaceDark housing (316).
    if (asPane) {
      return Material(type: MaterialType.transparency, child: content);
    }
    return Container(
      decoration: BoxDecoration(
        color: AppStyle.surfaceDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      child: content,
    );
  }
}
