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
import 'package:flutter/rendering.dart';
import 'package:auto_route/auto_route.dart';
import 'package:remixicon/remixicon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'widgets/logout_modal.dart';
import 'widgets/sections_item.dart';
import 'widgets/edit_restaurant_modal.dart';
import 'package:${package}/presentation/routes/app_router.dart';
import 'package:base_sdk/src/presentation/components/custom_toggle3.dart';
import 'package:base_sdk/src/presentation/components/title_icon.dart';
import 'package:base_sdk/src/presentation/pages/profile/edit_profile_sheet.dart';
import 'package:base_sdk/src/presentation/pages/profile/generic_profile_page.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/presentation/pages/profile/widgets/base_profile_footer.dart';
import 'package:base_sdk/src/presentation/pages/profile/widgets/base_wallet_card.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/demo_session.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:merchants_sdk/src/manager/application/main/main_provider.dart';
import 'package:merchants_sdk/src/manager/application/restaurant/restaurant_provider.dart';
import 'package:merchants_sdk/src/manager/presentation/restaurant/restaurant_hub_plane_flow.dart';
import 'package:merchants_sdk/src/manager/presentation/restaurant/shop_title_row.dart';
import 'package:merchants_sdk/src/manager/utils/restaurant_helpers.dart';
// Composer seams (sdk_installer_base.py update_layout_integrations): an
// SDK that this page never imports (ADR-005 - SDKs import only base)
// claims an import slot through its manifest 'integrations' entry; the
// installer inserts the replacement on the line UNDER the marker and
// keeps the marker. Each column-0 line below is one such slot; its
// widget twin sits at its own indent inside the section it feeds (the
// bare text is a prefix of the -imports marker, and the installer
// replaces every occurrence, so the indent is part of the contract).
// @calc-memory-row-imports
// @productivity-tasks-row-imports
// @revenue-manager-wallet-imports

// The manager restaurant tab, rebuilt as a host of base_sdk's generic
// profile page (GenericProfilePage + ProfileSectionRegistry) — approved
// design 2026-08-28 (profile-host page, section 7): standard host header
// (identity card, theme toggle, sign-out), NO cover art (the old
// ShopBanner sliver is retired), and an edit pencil (shop-edit flow)
// trailing the shop title row — on the SHOP element, not the wallet card.
//
// Every content block of the old hand-built page returns as a registered
// section, top to bottom in the old order:
//   * 'merchants.open_toggle' (top-row action) — the old floating
//     Open/Closed CustomToggle, now riding the host's top controls row;
//     the old floating logout button maps to the host's sign-out
//     affordance (registry.onLogout, LogoutModal's confirmed branch).
//   * 'merchants.shop_info' — shop title + rating + promo/flash glyphs +
//     edit pencil (shop-edit flow) + description.
//   * 'merchants.working_hours' — today's working-hours pill.
//   * 'merchants.wallet' — base_sdk's BaseWalletCard (no action strip, no
//     history arrow), replacing the hand-built balance box; same data
//     source (the cached shop JSON's seller wallet). When revenue_sdk is
//     composed its manifest swaps in ManagerWalletPane (frame 49l, the
//     Withdraw action) through the wallet marker - see
//     MerchantWalletSection.
//   * 'merchants.sections' — the Sections list (restaurant settings /
//     income / order history / notifications / sync issues / delete
//     account), links unchanged.
//   * 'base.footer' — base_sdk's default footer plus the old page's
//     bottom-nav scroll clearance.
//
// Tab-hosted wiring is untouched: the merchants home shell
// (pages/main/main_page.dart) still imports this page directly, so it
// carries no @RoutePage and the manifest declares no route for it (same
// contract as orders_sdk's OrdersHomePage).
//
// PLANES (approved 1f / 7d / 7e, the 4c profile cap): being tab-hosted,
// no PlaneHost sits above this page by itself, so the page wraps the host
// in RestaurantHubPlaneFlow — the profile's two-plane declaration — the
// way the sibling tabs wrap themselves in their flows. GenericProfilePage
// then spreads over two balanced columns at two planes or more and keeps
// its phone list at one; without the flow it rendered the phone list
// stretched across the whole window (tablet store review 2026-09-02,
// still 08-restaurant_hub).
//
// Route call-sites still route to the OWNING SDKs' installed pages:
// ManagerIncomeRoute (revenue_sdk), ManagerOrderHistoryRoute (orders_sdk).
// NotificationListRoute stays a HOST route until the comms_sdk consume
// repoints it (fork plan S-3/H-10).

/// Registers the merchant profile sections with base_sdk's
/// [ProfileSectionRegistry]. Idempotent (guarded, and the registry itself
/// is first-wins per id); called from [RestaurantPage]'s initState so the
/// registrations precede the host page's mount — the same ordering as a
/// boot-time di_hooks registration.
void registerMerchantProfileSections() {
  final registry = ProfileSectionRegistry.I;
  if (registry.contains('merchants.shop_info')) return;

  // The host's top-row sign-out button (behind the host's own logout
  // confirmation): the confirmed branch of the old floating logout
  // button's LogoutModal, verbatim. `??=` so a host that already owns
  // sign-out keeps its wiring.
  registry.onLogout ??= (context) {
    LocalStorage.logout();
    context.router.popUntilRoot();
    context.replaceRoute(const LoginRoute());
  };

  // The user-card edit pencil (chip 109, approved frame 4d 2026-08-30):
  // wiring onEditProfile turns on the host's own pencil in the unified
  // identity card (generic_profile_page.dart's gated IconButton), giving
  // the manager an edit-OWN-details path — the gap Ray reported after
  // the chip-243 shop-pencil move (PR #80). The target is base_sdk's
  // shared edit sheet (the shipped customer flow, promoted in base_sdk
  // 1.45.0), presented as the same drag bottom sheet the customer app
  // uses; its Save drives base_sdk's editProfileProvider into the
  // self-scoped update_user_profile endpoint. Distinct from the SHOP
  // pencil (chip 243) on the shop info row below, which stays untouched.
  // `??=` so a host that already owns the edit affordance keeps its
  // wiring.
  registry.onEditProfile ??= (context) {
    AppHelpers.showCustomModalBottomDragSheet(
      context: context,
      modal: (c) => EditProfileScreen(controller: c),
      isDarkMode: LocalStorage.getAppThemeMode(),
    );
  };

  // The old floating Open/Closed toggle, re-homed to the host's top
  // controls row (between the page title and the theme toggle).
  registry.registerTopRowAction(
    id: 'merchants.open_toggle',
    order: 10,
    builder: (context) => const MerchantOpenToggle(),
  );

  registry.register(ProfileSection(
    id: 'merchants.shop_info',
    order: 110,
    builder: (context) => const MerchantShopInfoSection(),
  ));

  registry.register(ProfileSection(
    id: 'merchants.working_hours',
    order: 120,
    builder: (context) => const MerchantWorkingHoursSection(),
  ));

  // The PRODUCTIVITY gate (approved frame 7e, chip 391 — Ray 2026-08-29
  // 15:06Z "we can expose it. that will be productivity gate", approved
  // 15:41Z): the composed-but-orphaned productivity_sdk /tasks page gains
  // its one entry point — a PRODUCTIVITY group with the Tasks row. Order
  // 125 slots it after the restaurant content (shop info + working hours)
  // and before the wallet: with the host's contiguous item-count balance
  // that CLOSES PLANE 1 under the restaurant group at two-plane widths,
  // while wallet / sections / footer keep plane 2 — exactly the approved
  // 7d distribution, per the 7e legend. The /tasks screen behind the door
  // is NOT designed here (coverage-map group M owns that pass); this
  // registration is gate exposure only.
  registry.register(ProfileSection(
    id: 'merchants.productivity',
    order: 125,
    builder: (context) => const MerchantProductivitySection(),
  ));

  registry.register(ProfileSection(
    id: 'merchants.wallet',
    order: 130,
    builder: (context) => const MerchantWalletSection(),
  ));

  registry.register(ProfileSection(
    id: 'merchants.sections',
    order: 140,
    builder: (context) => const MerchantSectionsList(),
  ));

  // base.footer override: the host's default meta-row footer plus the old
  // page's bottom clearance, so the last content clears the manager
  // shell's floating bottom bar (first-wins beats ensureDefaultSections,
  // which runs when the host mounts).
  registry.register(ProfileSection(
    id: BaseProfileFooter.sectionId,
    order: BaseProfileFooter.sectionOrder,
    builder: (context) => Column(
      children: [
        const BaseProfileFooter(),
        SizedBox(height: 100.h),
      ],
    ),
  ));
}

class RestaurantPage extends ConsumerStatefulWidget {
  const RestaurantPage({super.key});

  @override
  ConsumerState<RestaurantPage> createState() => _RestaurantPageState();
}

class _RestaurantPageState extends ConsumerState<RestaurantPage> {
  @override
  void initState() {
    super.initState();
    registerMerchantProfileSections();
    // The legacy app fetched the shop at splash/login; in the composed app
    // those flows are host-owned and may not know this provider, so the tab
    // fetches lazily when it has no shop yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(restaurantProvider).shop == null) {
        ref.read(restaurantProvider.notifier).fetchMyShop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The old page's ScrollController listener drove the manager shell's
    // bottom-bar collapse; the host owns its own scroll view, so the same
    // signal now comes from scroll notifications bubbling out of it.
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction == ScrollDirection.reverse) {
          ref.read(mainProvider.notifier).changeScrolling(true);
        } else if (notification.direction == ScrollDirection.forward) {
          ref.read(mainProvider.notifier).changeScrolling(false);
        }
        return false;
      },
      child: RestaurantHubPlaneFlow(
        hubBuilder: (context) => const GenericProfilePage(),
      ),
    );
  }
}

/// The Open/Closed shop toggle in the host's top controls row — the old
/// floating LogoutButton's CustomToggle without the blur chrome (the
/// logout half of that widget is the host's sign-out button now).
class MerchantOpenToggle extends ConsumerWidget {
  const MerchantOpenToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(restaurantProvider).shop?.open ?? false;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.r),
      child: CustomToggle(
        isText: true,
        key: UniqueKey(),
        controller: ValueNotifier<bool>(isOpen),
        onChange: (value) {
          ref.read(restaurantProvider.notifier).setOnlineOffline();
        },
      ),
    );
  }
}

/// The shop info block, carried over from the old page's list head: shop
/// title + rating row (promo / flash glyphs kept) and the description.
/// The title row now trails an edit pencil opening the shop-edit flow
/// ([EditRestaurantModal] — the same invocation as [MerchantSectionsList]'s
/// "Restaurant settings" row): the pencil belongs on the SHOP element it
/// edits, not on the wallet card.
/// Colors ride the host's mode-resolving text tokens instead of the old
/// white-scaffold blackColor so the block stays legible in dark mode.
class MerchantShopInfoSection extends ConsumerWidget {
  const MerchantShopInfoSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(restaurantProvider);
    // base_sdk keeps the shop as raw JSON; typed state first, cached JSON
    // as fallback (legacy read the typed LocalStorage.getShop()).
    final shopJson = LocalStorage.getShopJson();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The title row lives in lib (ShopTitleRow) so the widget test can
        // pump it at the 240 dpi tablet geometry where the old bare Row
        // overflowed its column by 22 px (tour run 33952102598): the title
        // gives way (ellipsis) and the badges keep the end edge.
        ShopTitleRow(
          title: RestaurantHelpers.truncate(
            state.shop?.translation?.title ??
                (shopJson?['translation']?['title'] as String?) ??
                "",
            16,
          ),
          rating: state.shop?.avgRate ?? '0.0',
          // The shop-edit pencil (approved fix 2026-08-28): it edits the
          // SHOP, so it rides the shop title row — moved here from its
          // earlier wallet-card overlay.
          onEdit: () => AppHelpers.showCustomModalBottomSheet(
            paddingTop: MediaQuery.paddingOf(context).top + 60,
            context: context,
            modal: const EditRestaurantModal(),
            isDarkMode: false,
          ),
        ),
        Text(
          '${state.shop?.translation?.description}',
          style: AppStyle.interNormal(
            size: 13.sp,
            color: AppStyle.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Today's working-hours pill (the Shop Working Day mapping stays
/// RestaurantHelpers'). The pill's hairline rides the host's mode-resolving
/// [AppStyle.strokeDark] — the same stroke token GenericProfilePage paints
/// its own card edges with — instead of the polarity-pinned
/// [AppStyle.borderColor] (#E6E6E6), which shouted as a near-white outline
/// on the dark page (15.25:1) and all but vanished on the light one
/// (1.06:1 against #ECECEF).
class MerchantWorkingHoursSection extends ConsumerWidget {
  const MerchantWorkingHoursSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(restaurantProvider);
    return Container(
      height: 46.r,
      margin: EdgeInsets.only(top: 24.h, bottom: 10.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: AppStyle.strokeDark,
          width: 1.r,
        ),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Remix.time_fill,
            size: 20.r,
            color: AppStyle.textPrimary,
          ),
          10.horizontalSpace,
          Builder(
            builder: (context) {
              final todayTime =
                  RestaurantHelpers.workingTimeForToday(state.shop);
              return RichText(
                text: TextSpan(
                  text: todayTime == null
                      ? ''
                      : '${AppHelpers.getTranslation(TrKeys.workingHours)}:',
                  style: AppStyle.interRegular(
                    color: AppStyle.textPrimary,
                    size: 12.sp,
                  ),
                  children: [
                    TextSpan(
                      text:
                          ' ${todayTime ?? AppHelpers.getTranslation(TrKeys.theRestaurantIsClosedToday)}',
                      style: AppStyle.interSemi(
                        color: AppStyle.textPrimary,
                        size: 13.sp,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The shop the composed wallet pane stands on (design strip frame 49l):
/// revenue_sdk's `ManagerWalletScope(shopId:, shopName:)` is built from
/// these two values by the replacement its manifest inserts under the
/// wallet marker in [MerchantWalletSection]. Typed state first, the
/// cached shop JSON as fallback — the same resolution
/// [MerchantShopInfoSection] uses for the title. A public top-level
/// function on purpose: it has no caller until revenue_sdk is composed,
/// and a private or local seam would read as dead code to the analyzer.
({String shopId, String? shopName}) merchantWalletScope(WidgetRef ref) {
  final shop = ref.watch(restaurantProvider).shop;
  final shopJson = LocalStorage.getShopJson();
  return (
    shopId: shop?.id ?? shopJson?['id']?.toString() ?? '',
    shopName: shop?.translation?.title ??
        shopJson?['translation']?['title'] as String?,
  );
}

/// The shop balance as base_sdk's [BaseWalletCard] (approved parameter:
/// no actions strip, no history arrow — the old hand-built box had no
/// history navigation either, its bar-chart glyph was inert). The card
/// carries no edit pencil: the shop-edit pencil lives on the shop title
/// row ([MerchantShopInfoSection]), the element it actually edits.
/// No explicit snapshot is passed: with `wallet:` null the card
/// self-sources from the profile fetch (profileProvider, falling back
/// to LocalStorage.getWalletData()), which GenericProfilePage's
/// initState refreshes via get_user_profile — and that payload now
/// carries the merchant's live Wallet balance. The merchant IS the
/// logged-in user, so the profile wallet is the seller balance.
///
/// FRAME 49l (approved 2026-08-31, "49d, 49f-l approved") puts ONE action
/// on this card's strip — Withdraw (chip 989) — and that action lives in
/// revenue_sdk, which this page never imports. So the card is chosen
/// through a composer seam: the wallet marker heads a candidate list and
/// the section renders `.first`. Without revenue_sdk the list holds only
/// base's bare card (this SDK's own tests see exactly that); with it, the
/// installer inserts `ManagerWalletPane(scope: ManagerWalletScope(...))`
/// under the marker and the pane wins, the bare card is never built.
/// Nothing is deleted at compose time, so the marker's indent (six
/// spaces) is part of the contract with revenue's manifest.
class MerchantWalletSection extends ConsumerWidget {
  const MerchantWalletSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Widget> wallet = <Widget>[
      // @revenue-manager-wallet
      const BaseWalletCard(
        actions: [],
        onHistory: null,
      ),
    ];
    return Column(
      children: [
        wallet.first,
        16.verticalSpace,
      ],
    );
  }
}

/// The PRODUCTIVITY group (approved frame 7e, chip 391): a group title,
/// the Tasks row and - since section 45's frame 45b - the Calculator row
/// (chip 842), the sole entry points for productivity_sdk's composed
/// /tasks page and calc_sdk's composed /calc page. Both route the same
/// way every other hub row routes — the host's generated route class
/// (TasksRoute from productivity_sdk's manifest /tasks entry,
/// CalculatorRoute from calc_sdk's /calc entry) via the already-imported
/// app_router; manager composes carry both SDKs (paas_manager
/// composer.json), so the classes are always generated here.
///
/// Both rows are PLAIN — title, glyph, tap — in this SDK. What each row
/// says under its title belongs to the SDK that owns the data, and
/// merchants_sdk cannot reach either (ADR-005 — SDKs import only base),
/// so each row is followed by a composer marker the owning SDK claims
/// through its manifest 'integrations' entry (the seeded demo glances
/// that stood in for this until 1.26.0 are gone, in demo builds too):
///   * design strip frame 46i (chip 859): productivity_sdk >= 1.2.0
///     inserts `PausedRunLine` under the Tasks row — a line that reads
///     the local run store and is exactly nothing when no run is paused.
///   * frame 45b (chip 842): calc_sdk owns the calculator memory (an
///     in-memory autoDispose StateNotifier today), so the memory glance
///     is its seam under the Calculator row; no calc_sdk entry claims it
///     yet, and until one does the row stays single-line.
/// Without the owning SDK the marker is an inert comment and the row is
/// the same single-line shape every pre-7e hub row keeps.
class MerchantProductivitySection extends StatelessWidget {
  const MerchantProductivitySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TitleAndIcon(
          title: AppHelpers.getTranslation(TrKeys.productivity),
          // TitleAndIcon's own titleColor default is the polarity-pinned
          // AppStyle.black, which is correct for its many white-sheet call
          // sites (ModalWrap) but invisible on this host's dark page — so
          // the hub passes the mode-resolving token explicitly.
          titleColor: AppStyle.textPrimary,
        ),
        20.verticalSpace,
        SectionsItem(
          title: AppHelpers.getTranslation(TrKeys.tasks),
          icon: Remix.task_line,
          onTap: () => context.pushRoute(const TasksRoute()),
        ),
        // Frame 46i's paused-run line lands here (productivity_sdk's
        // manifest; the eight-space indent is the contract - see the
        // imports block).
        // @productivity-tasks-row
        // CHIP 842 - the Calculator row (approved design strip frame
        // 45b, GATE 1 of section 45): calc_sdk ships a live /calc route
        // that NOTHING navigated to. This is its door, in the group 7e
        // already built. Frame 45b names the fork explicitly - "either
        // the row drops the sub-line, or memory gets persisted" - and the
        // memory lives in an in-memory autoDispose StateNotifier inside
        // calc_sdk (calculator_provider.dart), so the glance is calc's to
        // claim through the marker under the row once it persists it.
        SectionsItem(
          title: AppHelpers.getTranslation(TrKeys.calculator),
          icon: Remix.calculator_line,
          onTap: () => context.pushRoute(CalculatorRoute()),
        ),
        // @calc-memory-row
      ],
    );
  }
}

/// The Sections list, link for link from the old page's `_sections`
/// column (restaurant settings modal, income, order history,
/// notifications, sync issues, delete account behind the demo flag).
class MerchantSectionsList extends StatelessWidget {
  const MerchantSectionsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TitleAndIcon(
          title: AppHelpers.getTranslation(TrKeys.sections),
          // See MerchantProductivitySection: the shared default is pinned
          // black for white-sheet hosts; this page is dark-surfaced.
          titleColor: AppStyle.textPrimary,
        ),
        20.verticalSpace,
        SectionsItem(
          title: AppHelpers.getTranslation(TrKeys.restaurantSettings),
          icon: Remix.restaurant_line,
          onTap: () => AppHelpers.showCustomModalBottomSheet(
            paddingTop: MediaQuery.paddingOf(context).top + 60,
            context: context,
            modal: const EditRestaurantModal(),
            isDarkMode: false,
          ),
        ),
        // QUICK FLOW (approved design strip section 42, chip 795): the
        // shop's order-automation surface — auto-accept, auto-complete at
        // Ready, and the till keypad's digit presets. Inserted SECOND,
        // right under Restaurant settings, because it is shop setup and
        // not a report; the other five rows are untouched.
        SectionsItem(
          title: AppHelpers.getTranslation(TrKeys.quickFlow),
          icon: Remix.flashlight_line,
          onTap: () => context.pushRoute(const ManagerQuickFlowRoute()),
        ),
        SectionsItem(
          title: AppHelpers.getTranslation(TrKeys.income),
          icon: Remix.line_chart_line,
          onTap: () => context.pushRoute(const ManagerIncomeRoute()),
        ),
        SectionsItem(
          title: AppHelpers.getTranslation(TrKeys.myOrderHistory),
          icon: Remix.history_line,
          onTap: () => context.pushRoute(const ManagerOrderHistoryRoute()),
        ),
        SectionsItem(
          title: AppHelpers.getTranslation(TrKeys.notifications),
          icon: Remix.notification_2_line,
          onTap: () => context.pushRoute(const NotificationListRoute()),
        ),
        // Park-and-surface: records whose offline push the backend rejected,
        // with per-record retry/discard (merchants_sdk's own installed page).
        SectionsItem(
          title: AppHelpers.getTranslation(TrKeys.syncIssues),
          icon: Remix.refresh_line,
          onTap: () => context.pushRoute(const ManagerSyncIssuesRoute()),
        ),
        // A demo build or a demo session (base_sdk's runtime switch) has no
        // account to delete. A plain read: the hub is built after the login
        // flow has already settled the switch and routed here, and a sign-out
        // tears it down, so it is never on screen while the switch flips.
        if (!DemoSession.demoActive)
          SectionsItem(
            title: AppHelpers.getTranslation(TrKeys.deleteAccount),
            icon: Remix.logout_box_r_line,
            onTap: () {
              AppHelpers.showCustomModalBottomSheet(
                context: context,
                modal: const LogoutModal(isDeleteAccount: true),
                isDarkMode: false,
              );
            },
          ),
      ],
    );
  }
}
