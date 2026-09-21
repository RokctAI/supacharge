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

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:comms_sdk/comms_sdk.dart' show PushPermissionService;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:remixicon/remixicon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:proste_indexed_stack/proste_indexed_stack.dart';

import 'package:${package}/presentation/theme/theme.dart';
// Tab pages and create-modals install from their owning SDKs into these host
// paths: merchants_sdk -> the POS billing tab (pages/billing) and the
// restaurant tab, orders_sdk -> pages/orders + the ManagerCreateOrderRoute
// create-order flow, kitchen_sdk -> pages/kitchen (the approved Kitchen
// screen, kitchen_sdk >= 1.3.0), products_sdk -> pages/foods (+ create
// modals). This shell compiles once those app_type.manager installs have
// landed alongside it in the composed app.
import 'package:${package}/presentation/pages/billing/billing_page.dart';
import 'package:${package}/presentation/pages/orders/orders_home_page.dart';
import 'package:${package}/presentation/pages/kitchen/kitchen_page.dart';
import 'package:${package}/presentation/pages/foods/foods_page.dart';
import 'package:${package}/presentation/pages/foods/create/create_product_modal.dart';
import 'package:${package}/presentation/pages/foods/addons/create/create_addon_modal.dart';
import 'package:${package}/presentation/pages/foods/extras/create/create_extras_group_modal.dart';
import 'package:${package}/presentation/pages/restaurant/restaurant_page.dart';
import 'package:${package}/presentation/routes/app_router.dart';
import 'package:${package}/presentation/pages/main/widgets/bottom_navigator_item.dart';
import 'package:${package}/presentation/pages/main/widgets/buttons_bouncing_effect.dart';
import 'package:merchants_sdk/src/manager/application/main/main_provider.dart';
import 'package:merchants_sdk/src/manager/presentation/main/manager_nav_clearance.dart';
import 'package:merchants_sdk/src/manager/presentation/main/nav_rail_layout.dart';
import 'package:merchants_sdk/src/manager/presentation/main/shop_nav_avatar.dart';
import 'package:merchants_sdk/src/manager/presentation/main/signed_in_role_toast.dart';
import 'package:products_sdk/src/manager/application/foods/food_tabs_provider.dart';
import 'package:base_sdk/src/constants/app_constants.dart';
import 'package:base_sdk/src/presentation/adaptive/breakpoints.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_nav_mode.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/presentation/components/blur_wrap.dart';
import 'package:base_sdk/src/presentation/components/keyboard_dismisser.dart';

@RoutePage(name: 'MainRoute')
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // POS first (approved strip section 11): a store owner/manager lands on
  // the till scanner when they open the app. The order queue moved to
  // index 1 — orders_sdk's tour fragment tracks the shift. Kitchen sits
  // at index 2 beside the queue (the approved manager Kitchen screen,
  // kitchen_sdk 1.3.0 frames 34a–34d); foods and the restaurant tab
  // shifted one right — the kitchen/products tour fragments track it.
  List<IndexedStackChild> list = [
    IndexedStackChild(child: const BillingPage(), preload: true),
    IndexedStackChild(child: const OrdersHomePage(), preload: true),
    IndexedStackChild(child: const KitchenHomePage(), preload: false),
    IndexedStackChild(child: const FoodsPage(), preload: false),
    IndexedStackChild(child: const RestaurantPage(), preload: false),
  ];

  @override
  void initState() {
    // firebase_messaging has no Windows/Linux implementation — on desktop
    // Firebase is (correctly) never initialized, so an unguarded
    // FirebaseMessaging.instance throws [core/no-app] synchronously and the
    // whole route mounts as a blank ErrorWidget in release builds. Same
    // platform guard + fail-open idiom as comms' firebase boot hook; Windows
    // notifications go through the comms desktop notification poller instead.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      try {
        // comms_sdk owns the OS notification prompt for every composition
        // (comms_sdk >= 1.15.0). PushPermissionService keeps this call site's
        // platform guard + fail-open idiom AND de-duplicates concurrent
        // requests: a second sign-in inside one process re-mounts this shell
        // and the platform channel refuses a second in-flight request. The
        // service owns the future, so that failure is caught and logged
        // instead of escaping as an uncaught async error past the try below.
        PushPermissionService.request(
          sound: true,
          alert: true,
          badge: false,
        );
        FirebaseMessaging.onBackgroundMessage((RemoteMessage message) async {
          await Firebase.initializeApp();
        });
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {});
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          AppHelpers.showCheckTopSnackBarDone(
            // ignore: use_build_context_synchronously
            context,
            "${AppHelpers.getTranslation(TrKeys.id)} #${message.notification?.title} ${message.notification?.body}",
          );
        });
      } catch (e) {
        debugPrint('==> main page FCM setup skipped: $e');
      }
    }
    // The session_policy admits seller AND admin onto this route, so say
    // which one this session is - once per sign-in, on the first frame,
    // after the overlay exists (SignedInRoleToast owns the once gate).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SignedInRoleToast.showOnce(context);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLtr = LocalStorage.getLangLtr();
    // TABLET-MODE NAV PLACEMENT. In a tablet-mode window (>= 600 logical
    // px) the composed AppConstants.tabletNavPlacement says where this
    // shell's nav sits — the manager app's manifest opts into railStart,
    // so the floating menu moves to a start-edge vertical rail there.
    // Compact (phone-shaped) windows never consult the constant: the
    // floating bottom pill renders exactly as it always has.
    final FloatingNavPlacement placement =
        windowSizeOf(context).isAtLeastMedium
            ? AppConstants.tabletNavPlacement
            : FloatingNavPlacement.bottomCenter;
    final bool isRail = placement == FloatingNavPlacement.railStart ||
        placement == FloatingNavPlacement.railEnd;
    return Directionality(
      textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: KeyboardDismisser(
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              final pages = ProsteIndexedStack(
                index: ref.watch(mainProvider).selectedIndex,
                children: list,
              );
              if (!isRail) return pages;
              // The rail lives in the body, not in the Scaffold's
              // floatingActionButton slot (that slot is anchored to the
              // bottom edge by design). NavRailLayout gives the rail a
              // column of its own on the start (or end) edge and the
              // pages the rest — the rail's footprint is RESERVED, never
              // painted over the pages: every tab's leading content sat
              // under the old Stack overlay (tablet store review
              // 2026-09-02, stills 08 / 10 / 12 / 14). The layout stays
              // RTL-aware: railStart hugs the right edge in a
              // right-to-left app, exactly like the pill's items flip.
              return NavRailLayout(
                placement: placement,
                rail: _railNav(context, ref),
                pages: pages,
              );
            },
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          // In tablet mode with a rail (or hidden) placement the bottom
          // pill is not rendered; on phones — and in tablet mode for
          // apps that keep the default bottomCenter — this Consumer is
          // exactly the pre-existing bottom bar, untouched.
          floatingActionButton: placement != FloatingNavPlacement.bottomCenter
              ? null
              : Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(mainProvider);
              final event = ref.read(mainProvider.notifier);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BlurWrap(
                    radius: BorderRadius.circular(100.r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      decoration: BoxDecoration(
                        color: AppStyle.bottomNavigationBarColor.withOpacity(
                          0.6,
                        ),
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                      // The one figure the POS till's Continue clears
                      // (managerNavClearance) — read from the same place.
                      height: managerNavPillHeight(),
                      child: Padding(
                        padding: REdgeInsets.only(
                          right: 10,
                          left: !state.isScrolling ? 10 : 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // POS till first (scan icon) — the queue and
                            // foods tabs shifted one right.
                            BottomNavigatorItem(
                              isScrolling: state.isScrolling,
                              selectItem: () => event.selectIndex(0),
                              currentIndex: state.selectedIndex,
                              index: 0,
                              selectIcon: Remix.scan_2_fill,
                              unSelectIcon: Remix.scan_2_line,
                            ),
                            BottomNavigatorItem(
                              isScrolling: state.isScrolling,
                              selectItem: () => event.selectIndex(1),
                              index: 1,
                              currentIndex: state.selectedIndex,
                              selectIcon: Remix.file_list_2_fill,
                              unSelectIcon: Remix.file_list_2_line,
                            ),
                            // Kitchen (kitchen_sdk 1.3.0, approved 34a-d).
                            BottomNavigatorItem(
                              isScrolling: state.isScrolling,
                              selectItem: () => event.selectIndex(2),
                              index: 2,
                              currentIndex: state.selectedIndex,
                              selectIcon: Remix.bowl_fill,
                              unSelectIcon: Remix.bowl_line,
                            ),
                            BottomNavigatorItem(
                              isScrolling: state.isScrolling,
                              selectItem: () => event.selectIndex(3),
                              index: 3,
                              currentIndex: state.selectedIndex,
                              selectIcon: Remix.restaurant_fill,
                              unSelectIcon: Remix.restaurant_line,
                            ),
                            _profileItem(() {
                              event.selectIndex(4);
                              event.changeScrolling(false);
                            }, state.selectedIndex),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Create FAB only on the tabs with something to create:
                  // 1 orders (create order). The POS till (0) creates
                  // through the scanner; the kitchen (2) and restaurant
                  // (4) tabs create nothing; foods (3) carries its own
                  // "+ New product" header action now (products_sdk 1.6.0,
                  // approved frames 35a/35c — no FAB in the floating-nav
                  // language).
                  state.selectedIndex == 1
                      ? ButtonsBouncingEffect(
                          child: Hero(
                            tag: AppConstants.heroTagAddOrderButton,
                            child: GestureDetector(
                              onTap: () {
                                if (state.selectedIndex == 1) {
                                  context.pushRoute(
                                    const ManagerCreateOrderRoute(),
                                  );
                                } else {
                                  _showModalBasedOnFoodTab(context, ref);
                                }
                              },
                              child: Container(
                                margin: EdgeInsetsDirectional.only(start: 8.r),
                                width: 56.r,
                                height: 56.r,
                                // Not const: AppStyle.primary is a getter
                                // (brand-injectable), unlike the legacy
                                // Style.primary constant.
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppStyle.primary,
                                ),
                                child: Icon(
                                  Remix.add_line,
                                  size: 26.r,
                                  color: AppStyle.blackColor,
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// The tablet-mode side rail: the SAME three destinations as the
  /// floating bottom pill — orders, foods, the shop profile — in a
  /// Column inside the same BlurWrap pill vocabulary (same blur, fill,
  /// radius, collapse-on-scroll), with the same "+" create button riding
  /// beneath it. Taps go through the same mainProvider calls, so the
  /// rail is the bottom menu having moved, not a second nav.
  Widget _railNav(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mainProvider);
    final event = ref.read(mainProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BlurWrap(
          radius: BorderRadius.circular(100.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              color: AppStyle.bottomNavigationBarColor.withOpacity(0.6),
              borderRadius: BorderRadius.circular(100.r),
            ),
            width: 60.r,
            child: Padding(
              padding: REdgeInsets.only(
                bottom: 10,
                top: !state.isScrolling ? 10 : 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Same destinations as the bottom pill: POS till first,
                  // then the queue, kitchen, foods, and the shop profile.
                  BottomNavigatorItem(
                    isScrolling: state.isScrolling,
                    selectItem: () => event.selectIndex(0),
                    currentIndex: state.selectedIndex,
                    index: 0,
                    selectIcon: Remix.scan_2_fill,
                    unSelectIcon: Remix.scan_2_line,
                  ),
                  BottomNavigatorItem(
                    isScrolling: state.isScrolling,
                    selectItem: () => event.selectIndex(1),
                    index: 1,
                    currentIndex: state.selectedIndex,
                    selectIcon: Remix.file_list_2_fill,
                    unSelectIcon: Remix.file_list_2_line,
                  ),
                  // Kitchen (kitchen_sdk 1.3.0, approved 34a-d).
                  BottomNavigatorItem(
                    isScrolling: state.isScrolling,
                    selectItem: () => event.selectIndex(2),
                    index: 2,
                    currentIndex: state.selectedIndex,
                    selectIcon: Remix.bowl_fill,
                    unSelectIcon: Remix.bowl_line,
                  ),
                  BottomNavigatorItem(
                    isScrolling: state.isScrolling,
                    selectItem: () => event.selectIndex(3),
                    index: 3,
                    currentIndex: state.selectedIndex,
                    selectIcon: Remix.restaurant_fill,
                    unSelectIcon: Remix.restaurant_line,
                  ),
                  _profileItem(
                    () {
                      event.selectIndex(4);
                      event.changeScrolling(false);
                    },
                    state.selectedIndex,
                    // The pill spaces this item sideways; the rail
                    // stacks, so the gap moves above it.
                    margin: EdgeInsets.only(top: 12.r),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Create FAB only on tab 1 (orders) — same rule as the bottom
        // pill's button (foods carries its own header action now).
        state.selectedIndex == 1
            ? ButtonsBouncingEffect(
                child: Hero(
                  // Only ever mounted INSTEAD of the bottom pill's
                  // button, never alongside it, so the shared tag stays
                  // unique per screen.
                  tag: AppConstants.heroTagAddOrderButton,
                  child: GestureDetector(
                    onTap: () {
                      if (state.selectedIndex == 1) {
                        context.pushRoute(const ManagerCreateOrderRoute());
                      } else {
                        _showModalBasedOnFoodTab(context, ref);
                      }
                    },
                    child: Container(
                      margin: EdgeInsetsDirectional.only(top: 8.r),
                      width: 56.r,
                      height: 56.r,
                      // Not const: AppStyle.primary is a getter
                      // (brand-injectable), unlike the legacy
                      // Style.primary constant.
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppStyle.primary,
                      ),
                      child: Icon(
                        Remix.add_line,
                        size: 26.r,
                        color: AppStyle.blackColor,
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ],
    );
  }

  void _showModalBasedOnFoodTab(BuildContext context, WidgetRef ref) {
    final foodTabIndex = ref.read(foodTabsProvider).selectedIndex;
    Widget modal;
    if (foodTabIndex == 0) {
      modal = const CreateProductModal();
    } else if (foodTabIndex == 1) {
      modal = const CreateAddonModal();
    } else {
      modal = const CreateExtrasGroupModal();
    }

    AppHelpers.showCustomModalBottomSheet(
      paddingTop: MediaQuery.of(context).padding.top + 64.h,
      context: context,
      modal: modal,
      isDarkMode: false,
    );
  }

  GestureDetector _profileItem(
    Function() onTap,
    int index, {
    // Null keeps the bottom pill's original sideways gap; the tablet-mode
    // rail passes a vertical one instead.
    EdgeInsetsGeometry? margin,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.r,
        height: 40.r,
        margin: margin ?? EdgeInsets.only(left: 12.r),
        decoration: BoxDecoration(
          border: Border.all(
            // The shop-profile tab moved to index 4 (kitchen took 2).
            color: index == 4 ? AppStyle.primary : AppStyle.transparent,
            width: 2.w,
          ),
          shape: BoxShape.circle,
        ),
        // An unresolvable logo (demo / offline shells) degrades to the
        // shop's initial on the brand circle, never a broken-image glyph
        // (tour run 33952102598).
        child: ShopNavAvatar(
          url: LocalStorage.getShopJson()?['logo_img'] as String?,
          name: LocalStorage.getShopJson()?['translation']?['title']
              as String?,
          size: 40.r,
        ),
      ),
    );
  }
}
