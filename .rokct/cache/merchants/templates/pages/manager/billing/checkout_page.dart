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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:remixicon/remixicon.dart';

import 'package:base_sdk/src/constants/app_constants.dart';
// ApiResult's `when` lives in the freezed extension declared by this
// library, so the import is load-bearing even though no type is named.
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:base_sdk/src/presentation/components/helper/common_image.dart';
import 'package:base_sdk/src/presentation/components/keypad/money_keypad.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/key_sound.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:merchants_sdk/src/manager/application/pos_cart/pos_cart_provider.dart';
import 'package:merchants_sdk/src/manager/application/pos_cart/pos_cart_state.dart';
import 'package:merchants_sdk/src/manager/application/pos_cart/pos_sale_finish.dart';
import 'package:merchants_sdk/src/manager/application/quick_flow/quick_flow_provider.dart';
import 'package:merchants_sdk/src/manager/domain/interface/pos_orders.dart';
import 'package:merchants_sdk/src/manager/domain/interface/quick_flow.dart';
import 'package:merchants_sdk/src/manager/presentation/pos/receipt_preview_page.dart';
import 'package:merchants_sdk/src/manager/presentation/pos/receipt_slip.dart';
import 'package:merchants_sdk/src/manager/utils/pos_connectivity.dart';
import 'package:merchants_sdk/src/manager/utils/pos_pay_verification.dart';
import 'package:merchants_sdk/src/manager/utils/pos_receipt_printer.dart';

// The POS checkout — approved design 2026-08-28 (strip section 11,
// frames 11c–11i, "approved: 11i, 11c-h" per Ray 19:32Z):
//   * the 171-pattern page header (chip 304): the bare host top-row —
//     interSemi 18 textPrimary title on the page surface, trailing slots
//     empty, NO app bar (GenericProfilePage `_TopRow`'s language);
//   * In-store | Send for delivery fulfillment toggle (312/313) and the
//     Cash | QR (pay-link) method toggle (288/289);
//   * QR: the pay-link QR card the customer scans and pays on their own
//     phone (290), with the online phase gate "I've Scanned, Wait for
//     Code" (291);
//   * customer attach — the "Billing to" card (305) with the credit
//     outstanding "owes" chip (306); REQUIRED before credit/partial
//     unlocks (the debt lands on a real customer's wallet);
//   * THE KEY PAD (chip 390, base_sdk MoneyKeypad — approved frames 11u
//     tablet 2026-08-29 15:41Z and 11y phone 2026-08-30): the amount
//     paying now is entered on OUR keypad (digits, the 00 money key, ⌫,
//     the . | OK confirm row), never the OS keyboard — the amount
//     display cannot focus. Every keypress plays the fleet key feedback
//     (KeySound: paas_pos tap.wav + light haptic, default-ON gate);
//     refusals play the wrong.wav error buzz. At plane widths the keys
//     simply grow wider (11u's two-plane spread); on phone the pad is
//     the 11y one-plane fold;
//   * credit / partly-paid (11g/11h): "Amount paying now" (307) with the
//     Full / R0-all-on-credit quick actions (308), the remainder-due
//     banner (309) with the Shop.credit_allowance gate line (310), the
//     summary's Paying-now / On-credit split rows (292), and the finish
//     button's takes/records sublabel (311). All-on-credit rides the
//     merged credit machinery end to end; partly-paid records the
//     paid-now Transaction and the remainder auto-collects FIFO from
//     the customer's next wallet top-up;
//   * send-for-delivery (11i): the delivery address card (314) and
//     "Send for delivery & Finish" (315) — the sale enters the NORMAL
//     order queue at Ready through the EXISTING seller create-order
//     pipeline (Ray: "you just need to add scanned ones to that
//     pipeline"); a credit marking rides along per the settlement rules;
//   * receipt-style order summary (292) and the dual finish: "Print
//     Receipt & Finish" — atomic print-then-record (293) — and "Finish
//     without Receipt" (294). Per approved frame 11k (Ray 2026-08-29
//     13:53Z) 293 lands on the RECEIPT PREVIEW first (ReceiptPreviewPage:
//     the paper slip, 322, with the same dual finish beneath it) —
//     printing happens from there, never blind; 294 records straight
//     away, as shipped. Both run ONE pipeline, PosSaleFinish;
//   * OFFLINE INVERSION (frames 11e/11f): when the till is offline the
//     phase gate is replaced by straight-to-code entry — offline banner
//     (295), 6-digit confirmation code (296). The QR STAYS: the
//     customer's phone is online even when the till is not; the code and
//     the pay-link both carry the PAYING-NOW amount, verified locally by
//     PosPayVerification, zero server contact.
//
// OFFLINE-FIRST PIPELINE (Ray's rulings): every finished sale goes
// through PosOrdersFacade.submitSale — local drift store FIRST, then the
// existing SyncEngine order.create queue; checkout never blocks on the
// network, and the sale goes up with the status it is in ('delivered'
// in-store, 'ready' send-for-delivery — an offline delivery sale HOLDS
// at Ready until the sync drains it). With no facade registered the
// checkout degrades honestly: no customer/credit surface, local-only
// completion (demo builds register the mock).
//
// ONE BACK (strip section 12, merged core#125): the floating nav's
// back-only pill (FloatingNavBack) is this screen's single back
// affordance — no PopButton, no app-bar arrow.
//
// TABLET MODE — frame 11n (approved by Ray 2026-08-29 13:06Z: "approved:
// 5b,11n, 11o, 11r, ..."): on plane widths the till hosts this page IN
// ITS PLANES (BillingPage's PlaneHost) instead of pushing the route —
// the checkout claims TWO planes and spreads ITSELF by its own sections,
// the SAME widgets as the phone column regrouped: ORDER TRUTH (304 title,
// merchant row, fulfillment + Cash | QR toggles, customer attach, the
// 292 summary) | TENDER (QR banner, pay-link QR, phase gate / code
// entry, amount-paying-now + remainder, the 293/294 finish). The host
// draws the ONE back pill at the bottom-END corner (12d, the two-state
// nav) and pops this page; so hosted, this page draws no pill of its own
// — on the pushed phone route it draws the pill exactly as before.
// [onClose] is how the host pops it (a finished sale leaves the same
// way); null means the route, and Navigator.maybePop as shipped.
// 11n's live receipt slip (322, the 11k paper slip — ReceiptSlip) sits
// directly ABOVE 292 in the order-truth column, compact so 292 stays on
// screen, and updates live as the tender changes (Ray 12:26Z "that
// recipt sit above 292"). The phone column carries no slip: 11k is the
// phone's receipt. [onReceipt] is how the host takes 293 on planes —
// frame 11r: the checkout POPS and the receipt takes ONE plane; null
// means the phone route, where the preview is pushed above this page.
//
// Installed by the manifest to lib/presentation/pages/billing/ with the
// /pos-checkout route; @RoutePage(name: 'PosCheckoutRoute') so the host's
// generated router owns the route class. BillingPage reaches it by path,
// so both templates compile without the host router (standalone test
// harness compiles them directly).

/// The host's receipt hand-off (11r): the checkout hands the finished
/// sale's receipt and its finish record to whoever hosts it.
///
/// Declared HERE, in the routed page's own library, on purpose: the
/// host's generated router (auto_route_generator 10.3.x) copies every
/// constructor parameter type into `PosCheckoutRoute`/`PosCheckoutRouteArgs`
/// but only imports the page file, so an inline
/// `void Function(PosReceiptData, PosSaleFinish)?` leaves both types
/// unresolved in `app_router.gr.dart` ("Type 'PosReceiptData' not found",
/// paas_manager guided tour run 34040704424). A typedef is resolved
/// through this library, which the router already imports.
typedef PosReceiptHandler = void Function(
  PosReceiptData receipt,
  PosSaleFinish sale,
);

@RoutePage(name: 'PosCheckoutRoute')
class CheckoutPage extends ConsumerStatefulWidget {
  /// Pops this page when it is hosted in the till's planes (11n). Null on
  /// the pushed phone route, where leaving is Navigator.maybePop.
  final VoidCallback? onClose;

  /// Hosted in the till's planes: "Print Receipt & Finish" hands the
  /// receipt to the host, which swaps this page for the one-plane
  /// receipt (11r). Null on the pushed phone route, where this page
  /// pushes the preview itself (11k).
  final PosReceiptHandler? onReceipt;

  const CheckoutPage({super.key, this.onClose, this.onReceipt});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

enum _PayMethod { cash, qr }

enum _Fulfillment { inStore, delivery }

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  _PayMethod _method = _PayMethod.qr;
  _Fulfillment _fulfillment = _Fulfillment.inStore;

  /// Null while the probe runs; the offline inversion renders on false.
  bool? _online;

  /// Online phase gate (chip 291): the cashier taps "I've Scanned, Wait
  /// for Code" once the customer has scanned, and the code entry appears.
  bool _scannedGatePassed = false;

  /// Set when a typed 6-digit code verified locally; cleared on edits.
  bool _codeVerified = false;
  bool _codeRejected = false;
  final TextEditingController _codeController = TextEditingController();

  /// Credit / partly-paid state (chips 305–311). The customer attach is
  /// REQUIRED before any of it unlocks.
  PosCustomer? _customer;
  double? _customerOutstanding;
  final TextEditingController _paidNowController = TextEditingController();
  String _prefilledForOrderId = '';

  /// Calculator-entry freshness for the keypad (chip 390): while the
  /// entry is "fresh" (just prefilled, quick-chipped or OK-confirmed)
  /// the next digit/decimal REPLACES it instead of appending — the
  /// paas_pos tender-pad feel; ⌫ edits in place.
  bool _paidNowFresh = true;

  /// The route chip 843 opens. `pick=true` asks calc_sdk's /calc page
  /// for its number back (design strip chip 840).
  static const String _calcPickRoute = '/calc?pick=true';

  /// Send-for-delivery address (chip 314).
  String _address = '';

  /// A submit in flight — the finish buttons ignore re-taps.
  bool _finishing = false;

  /// KEYPAD AUTODIAL (approved design strip section 42, frame 42c —
  /// chips 806/807/808): the last preset a digit key dropped on the
  /// ticket, for the result strip. Cleared when the ticket empties again.
  QuickFlowPreset? _lastAutodial;

  @override
  void initState() {
    super.initState();
    unawaited(_probe());
    // Autodial's arming condition is shop state, so the till has to know
    // it before the first key press — a digit must never wait on the
    // network. One read, shared with the Quick flow settings surface
    // through the same provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(quickFlowProvider).loaded) {
        unawaited(ref.read(quickFlowProvider.notifier).load());
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _paidNowController.dispose();
    super.dispose();
  }

  Future<void> _probe() async {
    final online = await PosConnectivity.check();
    if (mounted) setState(() => _online = online);
  }

  PosOrdersFacade? get _posOrders => GetIt.I.isRegistered<PosOrdersFacade>()
      ? GetIt.I<PosOrdersFacade>()
      : null;

  String get _shopId =>
      (LocalStorage.getShopJson()?['id'])?.toString() ?? '';

  /// Per-shop shared secret for the offline code (see PosPayVerification:
  /// the shop uuid today, a rotating secret in the backend contract).
  String get _sharedSecret =>
      (LocalStorage.getShopJson()?['uuid'])?.toString() ?? _shopId;

  /// Whether this shop completes sales on credit at all
  /// (Shop.enable_credit; absent means enabled — the allowance solvency
  /// guard is the backend's, surfaced in the gate line).
  bool get _creditEnabled {
    final flag = LocalStorage.getShopJson()?['enable_credit'];
    return flag != 0 && flag != false && flag != '0';
  }

  /// The shop's item-commission rate, for the gate line's fronting
  /// figure (chip 310): at a counter sale the shop fronts the item
  /// commission — there is no delivery fee.
  double get _commissionRate =>
      double.tryParse(
        LocalStorage.getShopJson()?['percentage']?.toString() ?? '',
      ) ??
      0;

  /// Chip 307's value: the amount collected right now. Empty/invalid
  /// entry (and no attached customer) means the full total.
  double _payingNow(PosCartState state) {
    if (_customer == null) return state.total;
    final raw = _paidNowController.text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(raw);
    if (parsed == null) return state.total;
    return posRoundCents(parsed.clamp(0, state.total).toDouble());
  }

  double _remainder(PosCartState state) =>
      posRoundCents(state.total - _payingNow(state));

  bool _creditActive(PosCartState state) =>
      _customer != null && _remainder(state) > 0.005;

  /// The pay link the customer scans (chip 290), carrying the PAYING-NOW
  /// amount (the credit remainder never rides the link). Keyed to the
  /// STABLE order id (minted once in the cart notifier — never here in
  /// build, a held-build finding), so the QR does not re-key
  /// mid-checkout.
  String _payLink(PosCartState state) =>
      '${AppConstants.baseUrl}/pos/pay?order=${state.orderId}'
      '&amount=${_payingNow(state).toStringAsFixed(2)}&shop=$_shopId';

  void _onCodeChanged(String code) {
    final state = ref.read(posCartProvider);
    if (code.length < 6) {
      if (_codeVerified || _codeRejected) {
        setState(() {
          _codeVerified = false;
          _codeRejected = false;
        });
      }
      return;
    }
    final ok = PosPayVerification.verify(
      enteredCode: code,
      orderId: state.orderId,
      amount: _payingNow(state),
      shopId: _shopId,
      sharedSecret: _sharedSecret,
    );
    if (!ok) KeySound.error();
    setState(() {
      _codeVerified = ok;
      _codeRejected = !ok;
    });
  }

  /// Keypad (chip 390) handlers — MoneyEntry carries the shared money
  /// string rules; freshness gives the prefilled total calculator-entry
  /// replacement semantics.
  void _onKeypadDigit(String digit) {
    // KEYPAD AUTODIAL (approved 42c): while there is NOTHING on the
    // ticket, a digit key is not money — it is the item the shop mapped
    // to that key. The moment an item is on, the keys are money again,
    // which is why the whole rule hangs off the cart being empty and
    // nothing else. base_sdk's MoneyKeypad is untouched by any of this:
    // it emits the same key event it always did, and the till decides
    // what the press MEANS. Chip 390's contract stays intact fleet-wide.
    if (_autodial(digit)) return;
    setState(() {
      final current = _paidNowFresh ? '' : _paidNowController.text;
      _paidNowFresh = false;
      _paidNowController.text = MoneyEntry.appendDigit(current, digit);
    });
  }

  /// The armed pad's read of one key. Returns true when the press was
  /// consumed as an item.
  ///
  /// An unset digit is INERT — it consumes the press and does nothing
  /// (chip 805: an unset digit is not an error), because falling through
  /// to money entry on a pad the cashier is using as an item pad would
  /// silently type into a field they cannot see.
  bool _autodial(String digit) {
    if (!_autodialArmed(ref.read(posCartProvider))) return false;
    if (digit.length != 1) return true;
    final int? key = int.tryParse(digit);
    if (key == null || key < 1 || key > 9) return true;
    final preset =
        ref.read(quickFlowProvider).settings.presetFor(key);
    if (preset == null) return true;
    ref.read(posCartProvider.notifier).addProduct(preset.product);
    setState(() => _lastAutodial = preset);
    return true;
  }

  /// Armed = the shop turned autodial on AND mapped at least one digit
  /// AND the ticket is empty. All three, every time.
  bool _autodialArmed(PosCartState state) =>
      state.isEmpty && ref.read(quickFlowProvider).settings.autodialArmed;

  void _onKeypadDecimal() {
    setState(() {
      final current = _paidNowFresh ? '' : _paidNowController.text;
      _paidNowFresh = false;
      _paidNowController.text = MoneyEntry.decimal(current);
    });
  }

  void _onKeypadBackspace() {
    setState(() {
      _paidNowFresh = false;
      _paidNowController.text =
          MoneyEntry.backspace(_paidNowController.text);
    });
  }

  /// OK (the confirm row): normalizes the entry to what the sale will
  /// actually take — parsed, clamped 0..total, two decimals — and marks
  /// it fresh (the next digit starts a new entry).
  void _onKeypadOk(PosCartState state) {
    setState(() {
      _paidNowController.text = _payingNow(state).toStringAsFixed(2);
      _paidNowFresh = true;
    });
  }

  /// The dual finish (chips 293/294, and 315 for send-for-delivery).
  /// With a receipt the print is ATOMIC: the sale is only recorded after
  /// the printer returns — a throwing printer leaves the sale open (the
  /// Spazafy checkout recorded first and a dead printer silently ate
  /// receipts). The pipeline submit is OFFLINE-FIRST (local store +
  /// sync queue) so it never blocks on the network; a submit failure is
  /// a local storage failure and leaves the sale open too.
  Future<void> _finish({required bool withReceipt}) async {
    if (_finishing) return;
    final state = ref.read(posCartProvider);
    if (state.isEmpty) return;
    final facade = _posOrders;
    final delivery = _fulfillment == _Fulfillment.delivery;

    if (delivery && facade != null) {
      if (_customer == null) {
        KeySound.error();
        AppHelpers.showCheckTopSnackBar(
          context,
          AppHelpers.getTranslation(TrKeys.deliveryNeedsCustomer),
        );
        return;
      }
      if (_address.trim().isEmpty) {
        KeySound.error();
        AppHelpers.showCheckTopSnackBar(
          context,
          AppHelpers.getTranslation(TrKeys.deliveryNeedsAddress),
        );
        return;
      }
    }

    final sale = _saleFinish(state, facade: facade, delivery: delivery);

    // 11k: "Print Receipt & Finish" lands on the receipt preview first —
    // printing happens from there, never blind. The preview runs the
    // same pipeline and clears the cart; this page then leaves.
    if (withReceipt) {
      await _openReceiptPreview(_receipt(state), sale);
      return;
    }

    _finishing = true;
    try {
      final failure = await sale.run(withReceipt: false, facade: facade);
      if (failure != null) {
        KeySound.error();
        if (mounted) {
          AppHelpers.showCheckTopSnackBar(
            context,
            failure.printFailed
                ? AppHelpers.getTranslation(TrKeys.printFailed)
                : failure.message ??
                    AppHelpers.getTranslation(
                      TrKeys.somethingWentWrongWithTheServer,
                    ),
          );
        }
        return;
      }

      ref.read(posCartProvider.notifier).finishSale();
      if (!mounted) return;
      AppHelpers.showCheckTopSnackBarDone(
        context,
        AppHelpers.getTranslation(TrKeys.saleCompleted),
      );
      _afterFinished();
    } finally {
      _finishing = false;
    }
  }

  /// The sale is recorded and the cart cleared (here, or on the receipt
  /// preview): the tender state resets for the next sale and the page
  /// leaves.
  void _afterFinished() {
    setState(() {
      _customer = null;
      _customerOutstanding = null;
      _address = '';
      _paidNowController.clear();
      _prefilledForOrderId = '';
      _paidNowFresh = true;
      // The ticket is empty again, so the pad re-arms from scratch.
      _lastAutodial = null;
    });
    _leave();
  }

  /// 11k / 11r: the receipt preview. Hosted in the till's planes the host
  /// takes it (the checkout pops, the receipt claims ONE plane — 11r);
  /// on the phone it is pushed above this page as a plain route (no
  /// generated router needed — the standalone harness pumps it too) and
  /// pops `true` once the sale is recorded.
  Future<void> _openReceiptPreview(
    PosReceiptData receipt,
    PosSaleFinish sale,
  ) async {
    final onReceipt = widget.onReceipt;
    if (onReceipt != null) {
      onReceipt(receipt, sale);
      return;
    }
    final finished = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (routeContext) => ReceiptPreviewPage(
          receipt: receipt,
          sale: sale,
          onFinished: () => Navigator.of(routeContext).pop(true),
        ),
      ),
    );
    if (finished == true && mounted) _afterFinished();
  }

  /// What the dual finish records — the receipt lines exactly as
  /// PosReceiptPrinter takes them, and the offline-first draft (Ray's
  /// ruling: the sale goes up with the status it is IN — an in-store
  /// sale is already handed over, 'delivered'; a packed send-for-delivery
  /// sale is 'ready', and HOLDS there locally while offline until the
  /// sync drains it). No facade: local-only completion.
  PosSaleFinish _saleFinish(
    PosCartState state, {
    required PosOrdersFacade? facade,
    required bool delivery,
  }) {
    return PosSaleFinish(
      orderId: state.orderId,
      lines: _receiptLines(state),
      total: state.total,
      draft: facade == null
          ? null
          : PosSaleDraft(
              orderId: state.orderId,
              lines: [
                for (final line in state.lines)
                  PosDraftLine(
                    productId: line.product.id ?? '',
                    quantity: line.quantity,
                  ),
              ],
              total: state.total,
              deliveryType: delivery ? 'delivery' : 'pickup',
              status: delivery ? 'ready' : 'delivered',
              customerId: _customer?.id,
              phone: _customer?.phone,
              address: delivery ? _address.trim() : null,
              paidNow: _payingNow(state),
              onCredit: _creditActive(state),
            ),
    );
  }

  List<PosReceiptLine> _receiptLines(PosCartState state) => [
        for (final l in state.lines)
          PosReceiptLine(
            title: l.title,
            quantity: l.quantity,
            lineTotal: l.lineTotal,
          ),
      ];

  /// Chip 322's data: the slip prints what this page already computes —
  /// the printer's lines and total, the paying-now tender under the
  /// selected method, the on-credit remainder when the sale splits, the
  /// attached customer and the delivery line when send-for-delivery is
  /// on. Nothing is invented (no unit price, no tax, no change: the till
  /// takes an amount, it never counts cash handed over).
  PosReceiptData _receipt(PosCartState state) {
    final shopJson = LocalStorage.getShopJson();
    final delivery = _fulfillment == _Fulfillment.delivery;
    final address = _address.trim();
    return PosReceiptData(
      shopName: (shopJson?['translation']?['title'] as String?) ?? '',
      orderId: state.orderId,
      issuedAt: DateTime.now(),
      lines: _receiptLines(state),
      total: state.total,
      tender: [
        PosReceiptTender(
          label: AppHelpers.getTranslation(
            _method == _PayMethod.cash ? TrKeys.cash : TrKeys.qrPayLink,
          ),
          amount: _payingNow(state),
        ),
        if (_creditActive(state))
          PosReceiptTender(
            label: AppHelpers.getTranslation(TrKeys.onCredit),
            amount: _remainder(state),
          ),
      ],
      customerName: _customer?.fullName,
      delivery: delivery,
      deliveryAddress: delivery && address.isNotEmpty ? address : null,
    );
  }

  /// Leaves the checkout: the plane host's pop when hosted (11n), else
  /// plain Navigator (the floating back pill's own default) so the page
  /// never needs the host's router at runtime — the standalone harness
  /// pumps it directly.
  void _leave() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }
    unawaited(Navigator.of(context).maybePop());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(posCartProvider);
    // Prefill the paying-now entry once per order (the stable order id
    // is minted in the notifier, so this cannot re-fire per rebuild).
    if (_prefilledForOrderId != state.orderId && state.total > 0) {
      _prefilledForOrderId = state.orderId;
      _paidNowController.text = state.total.toStringAsFixed(2);
      _paidNowFresh = true;
    }
    final facade = _posOrders;
    final offline = _online == false;
    final showQr = _method == _PayMethod.qr;
    final showCodeEntry = showQr && (offline || _scannedGatePassed);
    final showGate = showQr && !offline && !_scannedGatePassed;
    final delivery = _fulfillment == _Fulfillment.delivery;
    final creditActive = _creditActive(state);
    // Hosted in the till's planes (11n)? Then the host owns the back pill
    // (bottom-END, 12d) and, granted two planes, this page spreads.
    final Planes? planes = Planes.maybeOf(context);
    final bool inPlanes = planes != null && planes.count > 1;
    final bool spread = inPlanes && planes.span >= 2;
    // While the pad is armed the ticket is empty, so there is no payment
    // to split and no second keypad on the page: the autodial card IS
    // the pad until an item lands.
    final bool showPayingNow =
        _customer != null && _creditEnabled && !_autodialArmed(state);
    final bool showAutodial = _autodialArmed(state) || _lastAutodial != null;

    Widget column(List<Widget> children) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.all(16.r),
              sliver: SliverList(delegate: SliverChildListDelegate(children)),
            ),
          ],
        );

    final Widget body;
    if (spread) {
      // 11n's two sections, the same widgets in the same order as the
      // phone column, dealt into the checkout's two planes.
      final orderTruth = <Widget>[
        _header(context),
        20.verticalSpace,
        _shopRow(context),
        20.verticalSpace,
        if (facade != null) ...[
          _fulfillmentToggle(context),
          14.verticalSpace,
        ],
        _methodToggle(context),
        20.verticalSpace,
        if (facade != null) ...[
          _billingToCard(context),
          14.verticalSpace,
          if (delivery) ...[
            _deliversToCard(context),
            14.verticalSpace,
          ],
          6.verticalSpace,
        ],
        // 11n: the live slip (322) sits directly ABOVE 292 — compact so
        // the summary stays on screen — and re-prints as the tender
        // changes (the same build that redraws 292 redraws the paper).
        ReceiptSlip(receipt: _receipt(state), compact: true),
        14.verticalSpace,
        _summary(context, state),
        120.verticalSpace,
      ];
      final tender = <Widget>[
        if (showQr) ...[
          if (offline) _offlineBanner(context) else _qrHintBanner(context),
          20.verticalSpace,
          _qrCard(context, state),
          20.verticalSpace,
          if (showGate) _phaseGate(context),
          if (showCodeEntry) _codeEntryCard(context),
          20.verticalSpace,
        ],
        if (facade != null) ...[
          if (showPayingNow) ...[
            _amountPayingNowCard(context, state),
            14.verticalSpace,
          ],
          if (creditActive) ...[
            _remainderBanner(context, state),
            14.verticalSpace,
          ],
        ],
        if (showAutodial) ...[
          _autodialCard(context, state),
          20.verticalSpace,
        ],
        _finishButtons(context, state),
        120.verticalSpace,
      ];
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: column(orderTruth)),
          // The seam between the two planes: the columns then sit
          // exactly on the plane grid.
          SizedBox(width: planes.gap),
          Expanded(child: column(tender)),
        ],
      );
    } else {
      body = column([
        _header(context),
        20.verticalSpace,
        _shopRow(context),
        20.verticalSpace,
        if (facade != null) ...[
          _fulfillmentToggle(context),
          14.verticalSpace,
        ],
        _methodToggle(context),
        20.verticalSpace,
        if (showQr) ...[
          if (offline) _offlineBanner(context) else _qrHintBanner(context),
          20.verticalSpace,
          _qrCard(context, state),
          20.verticalSpace,
          if (showGate) _phaseGate(context),
          if (showCodeEntry) _codeEntryCard(context),
          20.verticalSpace,
        ],
        if (facade != null) ...[
          _billingToCard(context),
          14.verticalSpace,
          if (delivery) ...[
            _deliversToCard(context),
            14.verticalSpace,
          ],
          if (showPayingNow) ...[
            _amountPayingNowCard(context, state),
            14.verticalSpace,
          ],
          if (creditActive) ...[
            _remainderBanner(context, state),
            14.verticalSpace,
          ],
          6.verticalSpace,
        ],
        _summary(context, state),
        if (showAutodial) ...[
          14.verticalSpace,
          _autodialCard(context, state),
        ],
        20.verticalSpace,
        _finishButtons(context, state),
        120.verticalSpace,
      ]);
    }

    return Scaffold(
      backgroundColor: AppStyle.surfaceDark,
      body: Stack(
        children: [
          body,
          // The floating nav's back-only pill (FloatingNavBack, core#125 —
          // design strip section 12's one-back rule): the shared pill
          // housing carrying only the leading back segment, this screen's
          // ONE back affordance. Back-only (empty tab list) because the
          // shell's root tabs are not reachable from this pushed route.
          // Hosted in planes the HOST draws the one pill (END corner), so
          // none here — one back per screen, never two.
          if (!inPlanes)
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FloatingBottomNav(
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
              ),
            ),
        ],
      ),
    );
  }

  /// Chip 304: the 171-pattern page header — GenericProfilePage
  /// `_TopRow`'s language: a bare row on the page surface, interSemi 18
  /// textPrimary leading title with ellipsis, trailing slots empty. The
  /// big-title app-bar block is gone (Ray 2026-08-28).
  Widget _header(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            AppHelpers.getTranslation(TrKeys.checkout),
            style: AppStyle.interSemi(
              size: 18.sp,
              color: AppStyle.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _shopRow(BuildContext context) {
    final shopJson = LocalStorage.getShopJson();
    return Row(
      children: [
        CommonImage(
          url: shopJson?['logo_img'] as String?,
          width: 56.r,
          height: 56.r,
          radius: 28,
        ),
        14.horizontalSpace,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (shopJson?['translation']?['title'] as String?) ?? '',
              style: AppStyle.interSemi(size: 18),
            ),
            2.verticalSpace,
            Text(
              AppHelpers.getTranslation(TrKeys.activeTransaction),
              style: AppStyle.interRegular(
                size: 13,
                color: AppStyle.textDarkSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Chips 312/313: the In-store | Send for delivery fulfillment toggle
  /// (added per Ray 15:23Z — "are you sure till cant update status to
  /// ready and a deliveryman come and collect?").
  Widget _fulfillmentToggle(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _methodPill(
            icon: Remix.store_2_line,
            label: AppHelpers.getTranslation(TrKeys.inStore),
            selected: _fulfillment == _Fulfillment.inStore,
            onTap: () =>
                setState(() => _fulfillment = _Fulfillment.inStore),
          ),
        ),
        14.horizontalSpace,
        Expanded(
          child: _methodPill(
            icon: Remix.e_bike_2_line,
            label: AppHelpers.getTranslation(TrKeys.sendForDelivery),
            selected: _fulfillment == _Fulfillment.delivery,
            onTap: () =>
                setState(() => _fulfillment = _Fulfillment.delivery),
          ),
        ),
      ],
    );
  }

  /// Chips 288/289: the Cash | QR / Pay link method toggle.
  Widget _methodToggle(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _methodPill(
            icon: Remix.cash_line,
            label: AppHelpers.getTranslation(TrKeys.cash),
            selected: _method == _PayMethod.cash,
            onTap: () => setState(() => _method = _PayMethod.cash),
          ),
        ),
        14.horizontalSpace,
        Expanded(
          child: _methodPill(
            icon: Remix.qr_code_line,
            label: AppHelpers.getTranslation(TrKeys.qrPayLink),
            selected: _method == _PayMethod.qr,
            onTap: () {
              setState(() => _method = _PayMethod.qr);
              // Re-probe when entering the QR flow — the inversion should
              // reflect the till's connectivity at decision time.
              unawaited(_probe());
            },
          ),
        ),
      ],
    );
  }

  Widget _methodPill({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = selected ? AppStyle.blue : AppStyle.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52.r,
        decoration: BoxDecoration(
          color: selected
              ? AppStyle.blue.withOpacity(0.08)
              : AppStyle.cardDark,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: selected ? AppStyle.blue : AppStyle.strokeDark,
            width: 1.r,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20.r, color: color),
            8.horizontalSpace,
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyle.interSemi(size: 15, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qrHintBanner(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppStyle.cardDarkAlt,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppStyle.strokeDarkSubtle, width: 1.r),
      ),
      child: Row(
        children: [
          Icon(Remix.qr_scan_2_line, size: 24.r, color: AppStyle.blue),
          12.horizontalSpace,
          Expanded(
            child: Text(
              AppHelpers.getTranslation(TrKeys.letCustomerScanQr),
              style: AppStyle.interRegular(size: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Chip 295: the offline inversion banner.
  Widget _offlineBanner(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        // Red tint over the mode surface rather than the fixed light
        // redBg constant, so the banner reads in dark mode too.
        color: AppStyle.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppStyle.red.withOpacity(0.4),
          width: 1.r,
        ),
      ),
      child: Row(
        children: [
          Icon(Remix.wifi_off_line, size: 24.r, color: AppStyle.red),
          12.horizontalSpace,
          Expanded(
            child: Text(
              AppHelpers.getTranslation(TrKeys.tillOfflineBanner),
              style: AppStyle.interRegular(size: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Chip 290: the pay-link QR card. Deliberately white in BOTH modes —
  /// scanners want quiet-zone contrast, and the render keeps it so.
  Widget _qrCard(BuildContext context, PosCartState state) {
    return Center(
      child: Container(
        // Keyed for the standalone harness (PrettyQrView.data returns a
        // package-private widget type, so tests find the card by key).
        key: const Key('posPayQrCard'),
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: AppStyle.white,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: SizedBox(
          width: 220.r,
          height: 220.r,
          child: PrettyQrView.data(
            data: _payLink(state),
            decoration: const PrettyQrDecoration(
              shape: PrettyQrSmoothSymbol(color: Color(0xFF000000)),
            ),
          ),
        ),
      ),
    );
  }

  /// Chip 291: the online phase gate.
  Widget _phaseGate(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _scannedGatePassed = true),
      child: Container(
        width: double.infinity,
        height: 56.r,
        decoration: BoxDecoration(
          color: AppStyle.blue.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: AppStyle.blue.withOpacity(0.5),
            width: 1.r,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          AppHelpers.getTranslation(TrKeys.iveScannedWaitForCode),
          style: AppStyle.interSemi(size: 15, color: AppStyle.blue),
        ),
      ),
    );
  }

  /// Chip 296: the 6-digit confirmation code entry (offline inversion —
  /// and the online post-gate phase). Verified locally, zero server
  /// contact (PosPayVerification), against the PAYING-NOW amount.
  Widget _codeEntryCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: AppStyle.blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppStyle.blue.withOpacity(0.35),
          width: 1.r,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              AppHelpers.getTranslation(TrKeys.confirmByCode),
              style: AppStyle.interSemi(size: 20, color: AppStyle.blue),
            ),
          ),
          10.verticalSpace,
          Center(
            child: Text(
              AppHelpers.getTranslation(TrKeys.enterSixDigitCode),
              textAlign: TextAlign.center,
              style: AppStyle.interRegular(
                size: 14,
                color: AppStyle.textDarkSecondary,
              ),
            ),
          ),
          18.verticalSpace,
          Text(
            AppHelpers.getTranslation(TrKeys.sixDigitCode),
            style: AppStyle.interSemi(size: 12),
          ),
          4.verticalSpace,
          TextField(
            controller: _codeController,
            onChanged: _onCodeChanged,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: AppStyle.interSemi(size: 20, letterSpacing: 2),
            decoration: InputDecoration(
              counterText: '',
              hintText: AppHelpers.getTranslation(TrKeys.typeHere),
              hintStyle: AppStyle.interRegular(
                size: 16,
                color: AppStyle.textDarkFaint,
              ),
            ),
          ),
          if (_codeVerified) ...[
            10.verticalSpace,
            Row(
              children: [
                Icon(
                  Remix.checkbox_circle_fill,
                  size: 18.r,
                  color: AppStyle.green,
                ),
                6.horizontalSpace,
                Text(
                  AppHelpers.getTranslation(TrKeys.paymentConfirmed),
                  style:
                      AppStyle.interSemi(size: 14, color: AppStyle.green),
                ),
              ],
            ),
          ] else if (_codeRejected) ...[
            10.verticalSpace,
            Text(
              AppHelpers.getTranslation(TrKeys.invalidCode),
              style: AppStyle.interRegular(size: 13, color: AppStyle.red),
            ),
          ],
        ],
      ),
    );
  }

  /// Chips 305/306: the "Billing to" customer attach card with the
  /// credit-outstanding "owes" chip. Optional for a full cash/QR sale,
  /// REQUIRED before credit/partial unlocks.
  Widget _billingToCard(BuildContext context) {
    final customer = _customer;
    final outstanding = _customerOutstanding ?? 0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppStyle.cardDark,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppHelpers.getTranslation(TrKeys.billingTo).toUpperCase(),
                style: AppStyle.interSemi(
                  size: 12,
                  color: AppStyle.textDarkSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => unawaited(_pickCustomer(context)),
                child: Text(
                  AppHelpers.getTranslation(
                    customer == null
                        ? TrKeys.addCustomer
                        : TrKeys.changeCustomer,
                  ),
                  style:
                      AppStyle.interSemi(size: 14, color: AppStyle.blue),
                ),
              ),
            ],
          ),
          if (customer != null) ...[
            12.verticalSpace,
            Row(
              children: [
                Container(
                  width: 44.r,
                  height: 44.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppStyle.blue.withOpacity(0.12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    customer.initials,
                    style: AppStyle.interSemi(
                      size: 15,
                      color: AppStyle.blue,
                    ),
                  ),
                ),
                12.horizontalSpace,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.fullName,
                        style: AppStyle.interSemi(size: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      2.verticalSpace,
                      Text(
                        customer.phone ?? '',
                        style: AppStyle.interRegular(
                          size: 13,
                          color: AppStyle.textDarkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (outstanding > 0.005) ...[
                  8.horizontalSpace,
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppStyle.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(100.r),
                      border: Border.all(
                        color: AppStyle.primary.withOpacity(0.5),
                        width: 1.r,
                      ),
                    ),
                    child: Text(
                      '${_decap(AppHelpers.getTranslation(TrKeys.owes))} ${AppHelpers.numberFormat(number: outstanding)}',
                      style: AppStyle.interSemi(
                        size: 12,
                        color: AppStyle.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Chip 314: the delivery address card — tap Change to enter/edit the
  /// attached customer's shipping address; the delivery fee joins the
  /// order downstream (the normal pipeline computes it).
  Widget _deliversToCard(BuildContext context) {
    final hasAddress = _address.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppStyle.cardDark,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Remix.map_pin_2_line,
                size: 16.r,
                color: AppStyle.textDarkSecondary,
              ),
              6.horizontalSpace,
              Text(
                AppHelpers.getTranslation(TrKeys.deliversTo).toUpperCase(),
                style: AppStyle.interSemi(
                  size: 12,
                  color: AppStyle.textDarkSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => unawaited(_editAddress(context)),
                child: Text(
                  AppHelpers.getTranslation(TrKeys.changeCustomer),
                  style:
                      AppStyle.interSemi(size: 14, color: AppStyle.blue),
                ),
              ),
            ],
          ),
          10.verticalSpace,
          Text(
            hasAddress
                ? _address
                : AppHelpers.getTranslation(TrKeys.addDeliveryAddress),
            style: hasAddress
                ? AppStyle.interSemi(size: 15)
                : AppStyle.interRegular(
                    size: 14,
                    color: AppStyle.textDarkFaint,
                  ),
          ),
          4.verticalSpace,
          Text(
            AppHelpers.getTranslation(TrKeys.deliveryFeeJoins),
            style: AppStyle.interRegular(
              size: 13,
              color: AppStyle.textDarkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Chips 307/308/336/390: the "Amount paying now" card — prefilled
  /// with the total; editing below the total splits the sale. Quick
  /// actions: Full and "R0 — all on credit". The entry surface is THE
  /// KEY PAD (chip 390, base_sdk MoneyKeypad — approved 11u/11y): the
  /// amount display (336) is a plain read-out that CANNOT focus, so the
  /// OS keyboard never appears; digits, 00, ⌫ and the . | OK confirm
  /// row do the editing, with the fleet key feedback on every press.
  Widget _amountPayingNowCard(BuildContext context, PosCartState state) {
    final entered = _paidNowController.text;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppStyle.cardDark,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppHelpers.getTranslation(TrKeys.amountPayingNow).toUpperCase(),
            style: AppStyle.interSemi(
              size: 12,
              color: AppStyle.textDarkSecondary,
              letterSpacing: 1.2,
            ),
          ),
          8.verticalSpace,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                // The amount display (336): NOT a text field — a bare
                // read-out of the keypad entry (hint-styled total when
                // empty). Keyed for the standalone harness.
                child: Container(
                  key: const Key('posPaidNowField'),
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: Text(
                    entered.isEmpty
                        ? state.total.toStringAsFixed(2)
                        : entered,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyle.interSemi(
                      size: 28,
                      color: entered.isEmpty
                          ? AppStyle.textDarkFaint
                          : AppStyle.textPrimary,
                    ),
                  ),
                ),
              ),
              10.horizontalSpace,
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Text(
                  '${_decap(AppHelpers.getTranslation(TrKeys.payingOf))} ${AppHelpers.numberFormat(number: state.total)} ${AppHelpers.getTranslation(TrKeys.total).toLowerCase()}',
                  style: AppStyle.interRegular(
                    size: 14,
                    color: AppStyle.textDarkSecondary,
                  ),
                ),
              ),
            ],
          ),
          12.verticalSpace,
          Wrap(
            spacing: 10.w,
            runSpacing: 8.h,
            children: [
              _quickAmountChip(
                label:
                    '${AppHelpers.getTranslation(TrKeys.fullAmount)} ${AppHelpers.numberFormat(number: state.total)}',
                onTap: () => setState(() {
                  _paidNowController.text =
                      state.total.toStringAsFixed(2);
                  _paidNowFresh = true;
                }),
              ),
              _quickAmountChip(
                label:
                    '${AppHelpers.numberFormat(number: 0)} ${AppHelpers.getTranslation(TrKeys.allOnCredit)}',
                onTap: () => setState(() {
                  _paidNowController.text = '0';
                  _paidNowFresh = true;
                }),
              ),
              // CHIP 843 - the till's calculator shortcut (design strip
              // frame 45c). Deliberately NOT a header button and NOT a
              // FAB: it sits exactly where the till's other
              // amount-shortcuts already live, so it reads as one more
              // way to FILL THE AMOUNT rather than a detour. Calc does
              // not replace the keypad - it feeds it.
              _quickAmountChip(
                key: const Key('posCalcShortcut'),
                icon: Remix.calculator_line,
                primary: true,
                label: AppHelpers.getTranslation(TrKeys.calculator),
                onTap: () => unawaited(_openCalculator()),
              ),
            ],
          ),
          14.verticalSpace,
          // THE KEY PAD (390) — at plane widths the keys grow to the
          // card's full width (11u's two-plane spread); on phone this is
          // the 11y one-plane fold. Same shared component either way.
          MoneyKeypad(
            onDigit: _onKeypadDigit,
            onBackspace: _onKeypadBackspace,
            onDecimal: _onKeypadDecimal,
            onOk: () => _onKeypadOk(state),
          ),
        ],
      ),
    );
  }

  /// KEYPAD AUTODIAL, on the till (approved design strip section 42,
  /// frame 42c — an illustration of the 802 behaviour, rendered here as
  /// the thing itself).
  ///
  /// While the ticket is empty and the shop has mapped at least one
  /// digit, the pad is an ITEM pad: the hint strip (chip 807) states the
  /// rule in one line and is present ONLY under that condition — it is
  /// the visible form of the arming rule — and each armed key prints its
  /// preset's name UNDER THE NUMERAL (chip 806), which is the detail the
  /// till's width buys. The moment a key lands an item, the strip along
  /// the bottom says what happened and that the keys are money again
  /// (chip 808).
  ///
  /// The pad is base_sdk's shared [MoneyKeypad], UNMODIFIED — same
  /// component, same public API, same key events. The captions are a
  /// caller-side overlay laid out on the pad's own published geometry
  /// ([MoneyKeypad.keyHeight] / [MoneyKeypad.gap], passed explicitly here
  /// so the grid is deterministic), sitting under an [IgnorePointer] so
  /// every tap still reaches the real key beneath it. Nothing about chip
  /// 390's pure-input-surface contract changes for anyone else.
  Widget _autodialCard(BuildContext context, PosCartState state) {
    final armed = _autodialArmed(state);
    final settings = ref.watch(quickFlowProvider).settings;
    final double keyHeight = 68.r;
    final double gap = 8.r;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppStyle.cardDark,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (armed) ...[
            // Chip 807 — the empty-ticket hint strip.
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppStyle.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppStyle.primary.withValues(alpha: .35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Remix.flashlight_line,
                    size: 16.r,
                    color: AppStyle.primary,
                  ),
                  10.horizontalSpace,
                  Expanded(
                    child: Text(
                      AppHelpers.getTranslation(TrKeys.autodialArmedHint),
                      style: AppStyle.interRegular(size: 13),
                    ),
                  ),
                ],
              ),
            ),
            14.verticalSpace,
            Stack(
              children: [
                MoneyKeypad(
                  keyHeight: keyHeight,
                  gap: gap,
                  onDigit: _onKeypadDigit,
                  onBackspace: _onKeypadBackspace,
                  onDecimal: _onKeypadDecimal,
                  onOk: () => _onKeypadOk(state),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: _presetCaptions(
                      settings,
                      keyHeight: keyHeight,
                      gap: gap,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_lastAutodial != null) ...[
            if (armed) 14.verticalSpace,
            // Chip 808 — the result strip.
            Row(
              children: [
                Container(
                  width: 26.r,
                  height: 26.r,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppStyle.primary.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(7.r),
                  ),
                  child: Text(
                    '${_lastAutodial!.digit}',
                    style: AppStyle.interSemi(
                      size: 12,
                      color: AppStyle.primary,
                    ),
                  ),
                ),
                10.horizontalSpace,
                Expanded(
                  child: Text(
                    _lastAutodial!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyle.interSemi(size: 13),
                  ),
                ),
                8.horizontalSpace,
                Text(
                  AppHelpers.numberFormat(number: _lastAutodial!.price),
                  style: AppStyle.interRegular(
                    size: 13,
                    color: AppStyle.textDarkSecondary,
                  ),
                ),
              ],
            ),
            if (!armed) ...[
              8.verticalSpace,
              Text(
                AppHelpers.getTranslation(TrKeys.keysAreMoneyAgain),
                style: AppStyle.interRegular(
                  size: 12,
                  color: AppStyle.textDarkSecondary,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Chip 806 — the preset name under the numeral, laid out on the
  /// keypad's own grid: four rows of [keyHeight] separated by [gap],
  /// three equal columns separated by [gap]. Only keys 1-9 that actually
  /// hold a preset carry a caption; `00`, `0` and the backspace never do
  /// (they are not item keys), and neither does the confirm row.
  Widget _presetCaptions(
    QuickFlowSettings settings, {
    required double keyHeight,
    required double gap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) SizedBox(height: gap),
          SizedBox(
            height: keyHeight,
            child: Row(
              children: [
                for (var col = 0; col < 3; col++) ...[
                  if (col > 0) SizedBox(width: gap),
                  Expanded(
                    child: _presetCaption(
                      settings,
                      row * 3 + col + 1,
                      row: row,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _presetCaption(QuickFlowSettings settings, int digit,
      {required int row}) {
    if (row > 2) return const SizedBox.shrink();
    final preset = settings.presetFor(digit);
    if (preset == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: 9.h, left: 4.w, right: 4.w),
        child: Text(
          preset.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppStyle.interRegular(size: 11, color: AppStyle.primary),
        ),
      ),
    );
  }

  /// CHIP 843 -> CHIP 840: open /calc and take the number back.
  ///
  /// `pick=true` is what makes the calculator grow its "use this
  /// amount" pill and pop its display; without it /calc pops nothing
  /// (design strip section 45, flag (a) - fixed in calc_sdk 1.1.0).
  /// Navigation is BY ROUTE PATH, so merchants_sdk never imports
  /// calc_sdk (ADR-005); on a composition without calc_sdk, or on an
  /// older one, the push simply returns null and the amount is
  /// untouched.
  ///
  /// The result fills the AMOUNT DISPLAY and nothing else - it never
  /// touches the cart, the order or a balance.
  Future<void> _openCalculator() async {
    final picked = await context.router.pushNamed(_calcPickRoute);
    if (!mounted) return;
    if (picked is String) {
      final amount = double.tryParse(picked.trim().replaceAll(',', '.'));
      if (amount == null || amount < 0) return;
      setState(() {
        _paidNowController.text = amount.toStringAsFixed(2);
        _paidNowFresh = true;
      });
    }
  }

  Widget _quickAmountChip({
    required String label,
    required VoidCallback onTap,
    Key? key,
    IconData? icon,
    bool primary = false,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: primary
              ? AppStyle.primary.withValues(alpha: .12)
              : AppStyle.cardDarkAlt,
          borderRadius: BorderRadius.circular(100.r),
          border: Border.all(
            color: primary
                ? AppStyle.primary.withValues(alpha: .45)
                : AppStyle.strokeDarkSubtle,
            width: 1.r,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15.r,
                color: primary ? AppStyle.primary : AppStyle.textPrimary,
              ),
              6.horizontalSpace,
            ],
            Text(
              label,
              style: AppStyle.interSemi(
                size: 13,
                color: primary ? AppStyle.primary : AppStyle.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chips 309/310: the remainder-due banner — the remainder completes
  /// as a CREDIT order on the customer's account and auto-collects in
  /// full from their next wallet top-up (oldest debt first) — with the
  /// Shop.credit_allowance gate line (at a counter sale the shop fronts
  /// the item commission; there is no delivery fee).
  Widget _remainderBanner(BuildContext context, PosCartState state) {
    final remainder = _remainder(state);
    final fronting = posRoundCents(state.total * _commissionRate / 100);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppStyle.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppStyle.primary.withOpacity(0.55),
          width: 1.r,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Remix.wallet_3_line,
                size: 20.r,
                color: AppStyle.primary,
              ),
              10.horizontalSpace,
              Expanded(
                child: Text(
                  '${AppHelpers.numberFormat(number: remainder)} ${_decap(AppHelpers.getTranslation(TrKeys.creditRemainder))}',
                  style: AppStyle.interRegular(size: 14),
                ),
              ),
            ],
          ),
          10.verticalSpace,
          Divider(height: 1.h, color: AppStyle.primary.withOpacity(0.25)),
          10.verticalSpace,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Remix.shield_check_line,
                size: 18.r,
                color: AppStyle.blue,
              ),
              10.horizontalSpace,
              Expanded(
                child: Text(
                  _creditEnabled
                      ? '${AppHelpers.getTranslation(TrKeys.creditAvailableFronts)} ${AppHelpers.numberFormat(number: fronting)} ${AppHelpers.getTranslation(TrKeys.commissionAllowanceCovers)}'
                      : AppHelpers.getTranslation(TrKeys.creditUnavailable),
                  style: AppStyle.interRegular(
                    size: 13,
                    color: AppStyle.textDarkSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Chip 292: the receipt-style order summary — with the Paying-now /
  /// On-credit split rows when a credit split is active (11g).
  Widget _summary(BuildContext context, PosCartState state) {
    final creditActive = _creditActive(state);
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppStyle.cardDark,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          if (!creditActive) ...[
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
          ],
          Row(
            children: [
              Text(
                AppHelpers.getTranslation(TrKeys.total),
                style: AppStyle.interSemi(size: 18),
              ),
              const Spacer(),
              Text(
                AppHelpers.numberFormat(number: state.total),
                style: AppStyle.interSemi(size: 20, color: AppStyle.blue),
              ),
            ],
          ),
          if (creditActive) ...[
            10.verticalSpace,
            Divider(height: 1.h, color: AppStyle.strokeDarkSubtle),
            10.verticalSpace,
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${AppHelpers.getTranslation(TrKeys.payingNow)} · ${AppHelpers.getTranslation(_method == _PayMethod.cash ? TrKeys.cash : TrKeys.qrPayLink)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyle.interRegular(
                      size: 14,
                      color: AppStyle.textDarkSecondary,
                    ),
                  ),
                ),
                8.horizontalSpace,
                Text(
                  AppHelpers.numberFormat(number: _payingNow(state)),
                  style: AppStyle.interSemi(size: 15),
                ),
              ],
            ),
            10.verticalSpace,
            Divider(height: 1.h, color: AppStyle.strokeDarkSubtle),
            10.verticalSpace,
            Row(
              children: [
                Text(
                  AppHelpers.getTranslation(TrKeys.onCredit),
                  style: AppStyle.interRegular(
                    size: 14,
                    color: AppStyle.textDarkSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  AppHelpers.numberFormat(number: _remainder(state)),
                  style: AppStyle.interSemi(
                    size: 15,
                    color: AppStyle.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Chips 293/294 — and 315 when Send for delivery is selected: the
  /// primary button becomes "Send for delivery & Finish" (the sale
  /// enters the normal order queue at Ready). Chip 311: the split's
  /// takes/records sublabel.
  Widget _finishButtons(BuildContext context, PosCartState state) {
    final delivery = _fulfillment == _Fulfillment.delivery;
    final creditActive = _creditActive(state);
    final String primaryLabel = AppHelpers.getTranslation(
      delivery ? TrKeys.sendForDeliveryFinish : TrKeys.printReceipt,
    );
    final String? primarySub = delivery
        ? AppHelpers.getTranslation(TrKeys.entersOrderQueue)
        : creditActive
            ? '${_decap(AppHelpers.getTranslation(TrKeys.takes))} ${AppHelpers.numberFormat(number: _payingNow(state))} ${_decap(AppHelpers.getTranslation(TrKeys.nowWord))} · ${_decap(AppHelpers.getTranslation(TrKeys.records))} ${AppHelpers.numberFormat(number: _remainder(state))} ${_decap(AppHelpers.getTranslation(TrKeys.due))}'
            : null;
    return Column(
      children: [
        GestureDetector(
          onTap: () => unawaited(_finish(withReceipt: !delivery)),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: 56.r),
            padding:
                EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
            decoration: BoxDecoration(
              color: AppStyle.primary,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  primaryLabel,
                  textAlign: TextAlign.center,
                  style: AppStyle.interSemi(
                    size: 16,
                    color: AppStyle.blackColor,
                  ),
                ),
                if (primarySub != null) ...[
                  2.verticalSpace,
                  Text(
                    primarySub,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyle.interRegular(
                      size: 12,
                      color: AppStyle.blackColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        14.verticalSpace,
        GestureDetector(
          onTap: () => unawaited(_finish(withReceipt: false)),
          child: Container(
            width: double.infinity,
            height: 56.r,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppStyle.blue, width: 1.r),
            ),
            alignment: Alignment.center,
            child: Text(
              AppHelpers.getTranslation(TrKeys.finish),
              style: AppStyle.interSemi(size: 16, color: AppStyle.blue),
            ),
          ),
        ),
      ],
    );
  }

  /// Chip 305's picker: the shop-scoped customer search (the same
  /// create-order picker data, reused at checkout).
  Future<void> _pickCustomer(BuildContext context) async {
    final facade = _posOrders;
    if (facade == null) return;
    final picked = await showModalBottomSheet<PosCustomer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: MediaQuery.viewInsetsOf(sheetContext),
        child: _CustomerPickerSheet(facade: facade),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customer = picked;
      _customerOutstanding = null;
    });
    final outstanding = await facade.customerCreditOutstanding(picked.id);
    if (mounted && _customer?.id == picked.id) {
      setState(() => _customerOutstanding = outstanding);
    }
  }

  /// Chip 314's editor: plain address entry (the manager flow's shipping
  /// address field, at the till).
  Future<void> _editAddress(BuildContext context) async {
    final controller = TextEditingController(text: _address);
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppStyle.cardDark,
        title: Text(
          AppHelpers.getTranslation(TrKeys.deliversTo),
          style: AppStyle.interSemi(size: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppStyle.interSemi(size: 16),
          decoration: InputDecoration(
            hintText: AppHelpers.getTranslation(TrKeys.addDeliveryAddress),
            hintStyle: AppStyle.interRegular(
              size: 15,
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
    if (entered != null && mounted) {
      setState(() => _address = entered.trim());
    }
  }

  /// De-capitalizes ONLY the first character of a humanized fallback so
  /// mid-sentence fragments read as designed ("owes R89.50", "takes ...
  /// now") while interior casing (CREDIT, Ready) survives.
  static String _decap(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  static String _trimQty(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.round().toString();
    }
    return quantity.toString();
  }
}

/// The "Billing to" card's picker sheet: a debounced search over the
/// shop's customers with one-tap attach (pops the picked customer).
class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet({required this.facade});

  final PosOrdersFacade facade;

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<PosCustomer> _results = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
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
      unawaited(_search(text));
    });
  }

  Future<void> _search(String text) async {
    setState(() => _searching = true);
    final result =
        await widget.facade.searchCustomers(query: text.trim());
    if (!mounted) return;
    result.when(
      success: (customers) => setState(() {
        _results = customers;
        _searching = false;
      }),
      failure: (error, statusCode) => setState(() => _searching = false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyle.surfaceDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      padding: EdgeInsets.all(16.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            style: AppStyle.interSemi(size: 16),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Remix.user_line,
                size: 20.r,
                color: AppStyle.textDarkSecondary,
              ),
              hintText:
                  AppHelpers.getTranslation(TrKeys.searchCustomers),
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
          if (_searching)
            Padding(
              padding: EdgeInsets.all(24.r),
              child: const CircularProgressIndicator.adaptive(),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (context, index) => 8.verticalSpace,
                itemBuilder: (context, index) {
                  final customer = _results[index];
                  // Material ancestor for the tile's ink — the sheet's
                  // decorated container would otherwise hide it (and
                  // trip the framework's debug assertion in tests).
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8.w),
                    leading: Container(
                      width: 40.r,
                      height: 40.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppStyle.blue.withOpacity(0.12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        customer.initials,
                        style: AppStyle.interSemi(
                          size: 14,
                          color: AppStyle.blue,
                        ),
                      ),
                    ),
                    title: Text(
                      customer.fullName,
                      style: AppStyle.interSemi(size: 15),
                    ),
                    subtitle: customer.phone == null
                        ? null
                        : Text(
                            customer.phone!,
                            style: AppStyle.interRegular(
                              size: 13,
                              color: AppStyle.textDarkSecondary,
                            ),
                          ),
                      onTap: () =>
                          Navigator.of(context).pop(customer),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
