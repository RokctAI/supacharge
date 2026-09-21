## 1.31.0

* feat(demo): demo repositories follow the runtime demo session. base_sdk
  1.61.0's `DemoSession` adds the runtime half of the demo switch (a
  server-marked demo account signs in through the real login and the app
  serves that session from the same fixtures the tour uses; nothing on
  screen changes). This SDK's demo seams now ask that switch,
  `DemoSession.demoActive` (a demo build OR a demo session), instead of
  the compile-time `AppConstants.isDemo` alone:
  * `MerchantsSdkDependencies` (shops twin) and
    `ManagerMerchantsDependencies` (seller-shop, POS catalog and quick-flow
    twins, the rand seed) choose by `DemoSession.demoActive` at
    registration and add ONE listener each on `DemoSession.instance`
    (once, guarded) that drops and re-registers exactly the singletons the
    hook itself registered when the switch flips - after a demo login,
    before routing, and back on sign-out. A host's own registration of the
    same facade is never swapped. The one exception is `PosOrdersFacade`,
    whose real side is the host's installed `ManagerPosOrdersAdapter`: a
    demo session beginning in a wired host displaces that adapter with
    `MockPosOrdersRepository` (the session must not create real orders),
    remembers it, and puts it back when the session ends; an unwired host
    gets the mock for the session and nothing after. Boot behaviour is
    unchanged. A flip before the first `register` call is a no-op; nothing
    in the re-register can throw.
  * The installed restaurant hub's delete-account gate
    (`restaurant_page.dart`) and the till's camera gate
    (`billing_page.dart`) read `DemoSession.demoActive` - plain reads, not
    listeners: both screens are built after the login flow has settled the
    switch and are torn down by a sign-out, so neither is on screen while
    it flips.
  * Requires base_sdk >= 1.61.0. No screen, string or tour fragment
    changes. `test/demo_session_di_test.dart` covers the three states,
    the host-adapter displacement, the rand seed, and guards that no
    `AppConstants.isDemo` read remains in lib/ or templates/;
    `hub_markers_test.dart` pins the delete-account gate on the new read.

## 1.30.0

* feat(pos): the Add Items pane's category chip bar - approved design
  strip frame 11m, chip 349 (Ray 2026-08-29 10:52Z "11m looks good but no
  search for items and no categories"; approved 13:53Z "approved: ...
  11m"): "a horizontal pill row (All / ...) in the dark till tokens,
  patterned on the paas_pos products-page category chips". The last
  "not built" flag on the till (`billing_page.dart`) is closed; the
  2026-09-07 tablet audit listed it as defect 5 (pos_scan / pos_cart
  stills show the search field only).
  * NEW `lib/src/manager/presentation/pos/pos_category_chip_bar.dart`
    `PosCategoryChipBar`: All first, then the shop's categories, in the
    foods page's own chip dress (products_sdk FoodsBody._categoryChips -
    34-high horizontal row, `primary` fill when active, `cardDark` on a
    `strokeDark` hairline otherwise, 100 radius). Draws nothing when the
    shop has no categories. Keys `posCategoryChipBar`,
    `posCategoryChip-all`, `posCategoryChip-<id>`.
  * `templates/pages/manager/billing/billing_page.dart`: the bar sits
    under the search field (318) in the PANE only - the phone sheet (11j,
    chips 316-321) is unchanged; the pane loads the categories once per
    till session. A tapped chip narrows the rows to its category, and
    with nothing typed lists the category outright; All widens again.
  * `PosCatalogRepositoryFacade` (`domain/interface/pos_catalog.dart`):
    `searchProducts` gains an optional `categoryId`; NEW `categories()`.
    `PosCatalogRepository` lists a category through base_sdk's
    `ProductsRepositoryFacade.getProductsPaginate(categoryId:)`, narrows
    a text search by each `ProductData.categoryId`, and reads the shop's
    categories through `CategoriesRepositoryFacade.getCategoriesByShop`
    (the kernel's cached own shop, `LocalStorage.getShopJson()`; the
    marketplace's first page when none is cached; an empty answer when no
    categories facade is registered). `MockProductsRepository` seeds the
    SAME three categories products_sdk's demo seller catalog seeds
    (Mains / Sides / Drinks) with the burger in Mains, so the demo till
    and the demo foods tab stay one shop.
  * `PosCartState` carries `query`, `categories` and `categoryId`;
    `PosCartNotifier.selectCategory` / `loadCategories`; Clear All, an
    emptied cart and a finished sale reset to `PosCartState.emptied()`,
    which keeps the catalog browsing state so the bar never blinks out
    between customers. A stale answer (a later query or chip already
    moved on) is dropped.
  * NEW `test/pos_category_chip_bar_test.dart` (run with
    `--dart-define=IS_DEMO=true`).
* fix(tour): the tablet leg never captured the approved plane checkout
  and receipt (frames 11n / 11r; tablet audit 2026-09-07, defect 2).
  `templates/tour/merchants.tour.yaml` pos_checkout was `action: route
  /pos-checkout` - the PHONE checkout, which the tablet leg stretched to
  one column over all planes, and whose receipt is the pushed 11k route,
  never the one-plane 11r. At plane widths the till never pushes that
  route: the checkout is only reached by Continue (287) inside the till's
  PlaneHost (`BillingPage._openCheckout`). The step is now a dart action
  that reads the plane count from the Continue button's own context, the
  way `_openCheckout` does - taps Continue where planes host the checkout
  (11n, then 293 hands the receipt to the till as one plane, 11r), and
  replaces to `/pos-checkout` on one plane (the phone leg's stills are
  unchanged). Step keys, captions and settles are unchanged; the
  fragment imports base_sdk's `planes.dart` for `Planes.maybeOf`.

## 1.29.3

* fix(manager): the composed shell did not compile against the host's
  pinned flutter_svg (paas_manager guided tour run 34049266887, shell main
  521c2214, merchants 1.29.2): `shop_nav_avatar.dart:78:9: Error: No named
  parameter with the name 'errorBuilder'`. 1.29.1 gave the SVG branch of
  ShopNavAvatar the same initials fallback as the raster branch through
  `SvgPicture.network(errorBuilder: ...)`, but flutter_svg only added that
  parameter in 2.0.17 and this package's floor was `^2.0.9`; paas_manager
  and paas_driver commit a pubspec.lock that pins flutter_svg 2.0.10+1,
  which satisfies `^2.0.9`, so the composer's plain `flutter pub get` kept
  the pin and the frontend rejected the call (this package's own lock
  resolves 2.3.0, which is why its unit test passed). The floor is now
  `flutter_svg: ^2.0.17`. The composer lists merchants_sdk as a path
  dependency of the host (sdk_composer.py update_pubspec_dependencies), so
  the host's resolution has to satisfy this constraint and `flutter pub
  get` re-resolves the stale lock entry to a >= 2.0.17 release instead of
  keeping it. No source change: the SVG errorBuilder fallback stays.
  `test/flutter_svg_floor_guard_test.dart` fails the standalone harness
  if the floor ever drops below 2.0.17 again, since this package's own
  lock cannot reproduce the shell's break.

## 1.29.2

* fix(manager): the composed shell's generated router did not compile
  (paas_manager guided tour run 34040704424, shell main 521c2214,
  merchants 1.29.0/1.29.1): `app_router.gr.dart` failed with "Type
  'PosReceiptData' not found" / "Type 'PosSaleFinish' not found" at the
  `PosCheckoutRoute` constructor and `PosCheckoutRouteArgs` field.
  auto_route_generator 10.3.1 copies every routed-page constructor
  parameter type into the generated route, but an inline function type
  (`void Function(PosReceiptData, PosSaleFinish)?`, the `onReceipt`
  hand-off 1.29.0 added to `checkout_page.dart`) has no element to
  import from, so the generator imported only the page file and left both
  argument types unresolved. The template now declares
  `typedef PosReceiptHandler = void Function(PosReceiptData receipt,
  PosSaleFinish sale);` in the page's own library and types the field /
  constructor parameter `PosReceiptHandler? onReceipt`; the generator
  resolves the alias through the page file it already imports and emits
  `PosReceiptHandler? onReceipt`. No behaviour change: `PosReceiptData`,
  `PosSaleFinish` and the receipt flow are untouched, and the till's
  `onReceipt: _openReceipt` tear-off is assignable to the alias unchanged.
  Reproduced and verified in a minimal auto_route 10.3.0 /
  auto_route_generator 10.3.1 host with merchants_sdk as a path dependency:
  4 `undefined_class` errors in the generated router before, none after.
  Version 1.29.1 -> 1.29.2 so version-aware cache reconciliation
  re-extracts the composed checkout page.

## 1.29.1

* fix(manager): three UI defects from the paas_manager guided tour (run
  33952102598, main 6af4b05).
  * The restaurant hub's shop title row (`restaurant_page.dart`,
    `MerchantShopInfoSection`) overflowed its column by 22 px at tablet
    density 240 dpi (1280x800 logical: three planes, the hub capped at
    two, so the narrowest section column of any leg; 320 dpi's 960x600
    two-plane column was wide enough). The title was a fixed-width `Text`
    with a `Spacer` before the badges, so a full-length title plus the
    promo/flash badges and the edit pencil simply did not fit. The row is
    now `lib/src/manager/presentation/restaurant/shop_title_row.dart`
    (`ShopTitleRow`): the leading title • rating group is `Expanded` and
    the title inside it `Flexible` with an ellipsis, so the title gives
    way and the badges keep the end edge on every width — no hardcoded
    widths; the template only hands it the title, rating and edit tap.
    New `test/shop_title_row_test.dart` pumps the row where the template
    mounts it (a ProfileSection under GenericProfilePage /
    RestaurantHubPlaneFlow) at 1280x800 dpr 1.5 and at the 390x844 phone
    and asserts no overflow and the reading order.
  * The POS till's Continue button (`billing_page.dart`, phone still 05)
    sat under the shell's floating bottom pill: the installed
    `main_page.dart` parks the pill in its Scaffold's centerFloat
    `floatingActionButton` slot, over the page body, and the phone
    column's foot left only 12 under Continue. New
    `lib/src/manager/presentation/main/manager_nav_clearance.dart`
    (`managerNavPillHeight` = the pill's 60.r, `managerNavClearance` =
    pill + `kFloatingActionButtonMargin` + the frames' 12 gap, the safe
    inset excluded as the page's own SafeArea adds it — the same shape as
    zones' `driverRootNavClearance`, there being no core helper); the
    one-plane phone foot uses it, plane widths keep the 12 (the shell
    docks the nav as a rail there). The pill is neither moved nor hidden;
    `main_page.dart` now reads its height from the same helper so the two
    figures cannot drift. New `test/pos_continue_nav_clearance_test.dart`
    mounts BillingPage in the shell's slot geometry and asserts Continue's
    bottom edge is above the pill's top edge on a 390x844 phone.
  * The profile tab's avatar drew a broken-image glyph when the shop's
    `logo_img` could not be resolved (demo / offline): `_profileItem`
    handed the URL to base_sdk's `CustomNetworkImage`, whose error state
    IS that glyph. New
    `lib/src/manager/presentation/main/shop_nav_avatar.dart`
    (`ShopNavAvatar`) degrades the way the profile header's avatar does
    — the shop's initial on the brand circle, or a person glyph with no
    name — through `Image`'s own errorBuilder over a
    `CachedNetworkImageProvider` (`cached_network_image` becomes a direct
    dependency, same rail as base_sdk); inline `data:` logos still go
    through `CustomNetworkImage` and SVG URLs through `SvgPicture.network`
    with the same fallback. New `test/shop_nav_avatar_test.dart` proves
    the fallback with an image provider that throws, the no-URL and
    no-name cases, and that the demo shop's inline mark still draws.

## 1.29.0

* feat(pos): the receipt preview, the live receipt slip and the receipt
  as ONE plane - approved design strip frames 11k / 11n / 11r (Ray
  2026-08-29 13:53Z "approved: ... 11k ..." and 13:06Z "approved:
  5b,11n, 11o, 11r ..."; "the best ui ever, 11r"). The three "not
  built" flags in `billing_page.dart` and `checkout_page.dart` are
  closed; 11m's category chip bar (349) stays flagged.
  * `ReceiptSlip` (`lib/src/manager/presentation/pos/receipt_slip.dart`,
    chip 322): the receipt as PAPER - a 58mm-style thermal strip drawn
    on the screen (off-white paper, speckle + feed bands, serrated tear
    edges, monospace receipt type): centered shop masthead (323), the
    printed line rows exactly as `PosReceiptLine` carries them - title,
    QTY, line total, no unit price invented (324), the dashed tear line
    (325), TOTAL in printed ink (326), then the tender the checkout
    already computes (Cash / QR paying-now, On credit remainder), the
    attached customer and the delivery line when send-for-delivery is
    on, and a footer. Paper and ink are fixed in both modes; the
    surround follows `AppStyle.isDark` (shadow on dark, hairline edge on
    light). Intrinsic width, never stretched; grows as lines print.
    `PosReceiptData` is its input.
  * `ReceiptPreviewPage`
    (`lib/src/manager/presentation/pos/receipt_preview_page.dart`, 11k):
    the step between checkout and print. "Print Receipt & Finish" (293)
    on the checkout now lands here first - the 171-pattern bare title
    "Receipt" (304), the slip, and the checkout's dual finish beneath
    the paper, verbatim: 293 prints THEN records (atomic, a dead printer
    leaves the sale open), 294 records without printing. On a phone it
    is pushed above the checkout as a plain route with the section-12
    back-only pill (301/302); "Finish without Receipt" on the checkout
    itself still records straight away, as shipped.
  * 11r - the receipt as ONE plane: hosted in the till's planes, 293
    pops the checkout off the `PlaneHost` stack and pushes the preview
    claiming `PlaneSpan.one` (the default), so the receipt takes the
    last plane at its natural size and the till returns beneath on the
    leftover planes (scan | cart at three); the host's END-corner back
    pill (12c/12d) pops it. New `CheckoutPage.onReceipt` seam.
  * 11n - the live slip: on the two-plane checkout spread the compact
    slip sits directly ABOVE the 292 summary in the order-truth column
    and re-prints as the tender changes. The phone column carries no
    slip (11k is the phone's receipt).
  * `PosSaleFinish`
    (`lib/src/manager/application/pos_cart/pos_sale_finish.dart`): the
    checkout's print-then-submit pipeline extracted as a value the
    preview can run after the checkout has popped - one codepath for
    both finishes, unchanged order (print first, record only after the
    printer returned; offline-first `submitSale`).
  * tr_keys (manager): `receipt`, `saleReceipt`, `receiptOrder`, `qty`,
    `paid`, `thankYou`.
  * Tests: new `test/pos_receipt_slip_test.dart` (fixture cart, dark and
    light); `pos_checkout_page_test` follows 293's preview step;
    `pos_till_plane_flow_test` gains the 11r case (receipt one plane at
    the END, till on two, finish from the plane).
* Tour: receipt preview step added to the POS fragment.

## 1.28.2

* fix(demo): the POS till prints rand, not "0.00USD" (Ray 2026-09-04
  13:13Z "in fact you should go check all tour of the app shells"; phone
  still 05, `billing_page.dart`'s empty-cart summary). Money on the till
  goes through `AppHelpers.numberFormat`, which reads LocalStorage's
  selected currency; nothing in a composed manager app seeds one under
  IS_DEMO (comms_sdk registers the real `CurrenciesRepository` regardless,
  and no manager shell calls `CurrencyNotifier.fetchCurrency`), so intl
  fell back to the locale's ISO code as a suffix while every other seller
  fixture trades in rand. `ManagerMerchantsDependencies.register` now seeds
  the new `demoCurrency` fixture (`lib/src/manager/infrastructure/
  demo_currency.dart`: id `ZAR`, symbol `R`, position `before`, rate 1 -
  orders_sdk's `DemoSellerOrdersRepository._rand` field for field) once,
  only under IS_DEMO and only when no currency is selected, so a real
  currency or a test harness's own seed is never overwritten. The real
  path and `numberFormat` itself are untouched. New
  `test/demo_currency_seed_test.dart` pins "R0.00"/"R150.00" and the
  no-overwrite rule.

## 1.28.1

* fix(demo): the IS_DEMO POS catalog no longer announces itself as demo
  (Ray 2026-09-03 21:45Z "demo in text or demo data is not needed").
  `MockProductsRepository`'s one product renames "Demo Product" /
  "This is a demo product description" -> "Flame-grilled beef burger" /
  "Flame-grilled beef patty, toasted bun, house sauce" - the same title
  products_sdk's customer-side mock already serves for the shared
  `demo_product_uuid`, and a fit for the seeded "Corner Kitchen" shop.
  Everything else is identical: id `1`, uuid, shop `1`, one stock at
  150.00 x 100, every barcode (6001067890123 included) and search text
  still resolves to it. The DI comment, the tour fragment's demo-grounding
  notes and the three POS tests that assert the title
  (`pos_billing_page_test`, `pos_till_plane_flow_test`, `pos_cart_test`)
  follow the rename; no step, caption or timing changed.

## 1.28.0

* Admins sign in to the manager app too (Ray 2026-09-02 15:18Z "admin
  just wont see his order but everyones orders"; 15:56Z "if you decide
  to lift gate you can just do a toast saying you are seller, admin
  etc"). The app_type.manager `session_policy` now admits two more
  roles after seller, both on the same `/main` landing: `"admin"` - the
  string auth_sdk's demo MockAuthRepository maps admin@demo.rokct.ai to
  (the guided tour) - and `"System Manager"` - the string users' real
  `api.user.login` puts in the login response for the tenant owner (its
  primary_role block: Administrator -> "Administrator", System Manager
  -> "System Manager", everyone else -> "user"; auth_sdk's login_notifier passes
  `data.user.role` to DeclaredSessionPolicy.allows verbatim, no
  normalisation). No fallback `*`, so any other role is still rejected
  to /login with `access.denied` exactly as before (DeclaredSessionPolicy
  resolves exact roles; sdk_installer_base.py's update_session_policy()
  emits one map entry per role).
  * The installed manager `main_page.dart` template shows ONE top
    snackbar on its first frame per session - "Signed in as seller" /
    "Signed in as admin" - through the new
    `lib/src/manager/presentation/main/signed_in_role_toast.dart`
    (`SignedInRoleToast.showOnce`): the role is `LocalStorage.getUser()?.role`
    as the backend sent it, keyed on the session token so a re-mount of
    the shell or a tab switch never repeats it and a new sign-in in the
    same process shows it again; role-less sessions show nothing. New
    manager tr_key `signedInAs` ("Signed in as"), injected into the host's
    TrKeys like every other manager key.
  * Backend `get_seller_orders` (merchants/frappe seller_order.py, the
    ONE cmd orders_sdk's board already sends through the gateway - no
    shop, no role on the wire) drops the `shop` filter when the caller
    `_signs_in_as_admin` - the SAME predicate users' `api.user.login`
    uses to emit "System Manager" (Administrator or System Manager ROLE;
    never user_type, since the Seller role has desk_access and so every
    shop owner is a System User), so the accounts the client admits as
    admin and the accounts this cmd widens for are one set - so an admin
    gets every shop's orders and is never refused by `_get_seller_shop`
    for having no Shop row. Sellers keep the exact legacy one-shop scope;
    status/date/customer/payment filters apply to both. Pinned by the
    bench-less `merchants/frappe/tests/test_seller_orders_admin_scope.py`.

## 1.27.0

* Tablet mode for the POS till and checkout — the approved plane layout
  of design strip section 11 (frames 11m, approved by Ray 2026-08-29
  13:53Z "approved: 34a , 33d,33b,11s,11k,11j,11p,11m"; 11n, approved
  13:06Z "approved: 5b,11n, 11o, 11r, 34b,34c,34d"; 12d, approved 14:38Z
  "approved: 33c,12d,12c,"), built on base_sdk's `PlaneHost` — the
  manager tablet stills 05/06/07 showed the phone till stretched to the
  full width with the checkout's back pill drawn at the START edge.
  * `BillingPage` (the till) is the flow's root and declares ALL planes,
    spreading itself: at three planes scan | Add Items | cart (11m) — the
    Add Items search is a PERMANENT PANE there (no sheet, Ray's 12:02Z
    sheet fork) and the Add Items lane (277) leaves the scan plane
    ("227 in 11m is redundent as they already show"); at two planes
    scan | cart with the lane, since no pane shows; on a phone the
    shipped column, byte for byte.
  * Continue on plane widths pushes the checkout INTO the planes instead
    of the `/pos-checkout` route: `CheckoutPage` claims TWO (11n, Ray
    12:26Z "what i came from should take first plane") and spreads its
    own sections — order truth | tender — while the till yields to its
    scan plane (273 + the 277 lane); at a two-plane fold the payment
    claim takes both and the till slides off (the plane model's
    min(claim, count) grant). The host's `FloatingBackPill` at the
    bottom-END corner (12d) is the ONE back affordance and pops the
    checkout; hosted this way the checkout draws no pill of its own —
    on the pushed phone route it draws it exactly as before.
  * `CheckoutPage` gains an optional `onClose` (the host's pop; a
    finished sale leaves through it too). Null keeps the route's
    `Navigator.maybePop`. Phone behaviour is unchanged.
  * Widget tests at 393, 800 and 1280 logical widths
    (`pos_till_plane_flow_test.dart`).
  * NOT built from the approved frames, flagged in the page docs rather
    than invented: 11m's category chip bar (chip 349 —
    `PosCatalogRepositoryFacade` only searches, it exposes no categories)
    and 11n's live receipt slip (322, the 11k paper slip — no slip widget
    exists in this SDK). The manager shell's start rail no longer
    overlays plane 1: 1.25.0's `NavRailLayout` reserves its footprint
    beside the pages, so the till's planes count on the remaining width.
  * Nothing about the manifest's installs or routes changed; the
    checkout template now imports `checkout_page.dart` relatively from
    the billing template (same install directory, the restaurant
    template's idiom).

## 1.26.0

* **Manager hub composer seams (design strip frames 46i and 49l, and the
  45b memory glance).** `templates/pages/manager/restaurant/restaurant_page.dart`
  gains three marker pairs that SDKs the hub never imports (ADR-005)
  claim through their own manifest `integrations` entries, the mechanism
  productivity_sdk already uses for the launcher glance: column-0 imports
  markers `// @productivity-tasks-row-imports`, `// @calc-memory-row-imports`,
  `// @revenue-manager-wallet-imports` under the last import, and widget
  markers `// @productivity-tasks-row` (eight-space indent, right under the
  Tasks row - productivity_sdk >= 1.2.0 inserts `PausedRunLine`, frame 46i
  chip 859), `// @calc-memory-row` (eight-space indent, under the Calculator
  row - reserved for calc_sdk, no entry claims it yet) and
  `// @revenue-manager-wallet` (six-space indent, FIRST in
  `MerchantWalletSection`'s candidate list; the section renders `.first`, so
  the `ManagerWalletPane(scope: ManagerWalletScope(...))` revenue_sdk >= 1.11.1
  inserts wins over base's bare `BaseWalletCard(actions: [], onHistory: null)`
  without deleting it - frame 49l chip 989). The widget markers carry their
  indent because the bare text is a prefix of the `-imports` marker and the
  installer replaces every occurrence. Without the owning SDK every marker is
  an inert comment and the hub renders exactly as before.
* `MerchantWalletSection` is a `ConsumerWidget` now and the page exposes
  `merchantWalletScope(WidgetRef ref)` - shop id + display name from
  `restaurantProvider`, cached shop JSON as fallback - the only host symbol
  revenue's replacement names.
* The seeded demo glances under the Tasks row (`'3 open · 1 due today'`) and
  the Calculator row (`'Memory holds 1 240.50'`), both gated on
  `AppConstants.isDemo`, are removed: the rows are single-line in every
  build until the owning SDK's seam fills them. The delete-account
  `isDemo` gate and every other demo behaviour are untouched.
* Tests: `test/hub_markers_test.dart` pins each marker (once, at its
  indent, in its section), the absence of the demo glances, and simulates
  `sdk_installer_base.py`'s `update_layout_integrations` insert with the
  byte-for-byte productivity 1.2.0 and revenue 1.11.1 replacement strings
  (lands once, in the right slot, idempotent, brackets balanced). The
  composed page itself cannot compile here (no productivity_sdk /
  revenue_sdk in this package), so the compile of the inserted widgets is
  the host compose's to prove. Manifest 1.25.0 -> 1.26.0; pubspec on its
  own rail.

## 1.25.0

* Tablet fixes 2026-09-02 (manager tablet review against the approved
  renders). Two layout defects in the manager shell, no redesign:
  * `NavRailLayout` (`lib/src/manager/presentation/main/nav_rail_layout.dart`):
    the installed `main_page.dart` template now lays the tablet-mode nav rail
    out BESIDE the tab pages (a Row with the rail column at start or end,
    RTL-aware) instead of a Stack overlay with no inset, so every shell tab
    (POS, hub, catalog, orders, kitchen) starts clear of the rail's 92 logical
    px footprint. A `PlaneHost` beside the rail counts its planes on the
    remaining width (800 tablet -> 708 -> still two planes).
  * `RestaurantHubPlaneFlow`
    (`lib/src/manager/presentation/restaurant/restaurant_hub_plane_flow.dart`):
    the installed `restaurant_page.dart` template hosts the hub's
    `GenericProfilePage` in a one-step `PlaneHost` (`PlaneSpan.two`, no back
    pill) like the sibling tabs' flows, so at two planes the restaurant hub
    (approved frame 08) spreads into its columns instead of rendering the
    phone list.
  * Tests: `nav_rail_layout_test.dart`, `restaurant_hub_plane_flow_test.dart`.

## 1.24.1

* Demo seed data (`--dart-define=IS_DEMO=true`), `MockShopsRepository`: the
  fictional shop is now "Corner Kitchen" ("Flame-grilled favourites, ready
  in minutes", 42 Marula Avenue, Sandton) instead of "Demo Shop" / "Best
  demo food in town" / "123 Demo St", and its imagery comes from base_sdk's
  inline `DemoImages` instead of a public placeholder host that a demo build
  cannot reach - the guided tour published both, verbatim, into
  `paas_customer`'s store screenshots (the word "Demo" three times over, and
  a broken-image glyph wherever a photo belonged). Nothing was removed: the
  same shop, the same fields, renamed.
* Same repository: the delivery window is seeded `from: "30", to: "45"`
  (the cards render `"$from - $to min"`, so the old pair printed the window
  backwards as "45 - 30 min"), the location is Johannesburg - where the demo
  delivery address is - rather than San Francisco, and the seller is named
  rather than "John Doe".
* New `MockShopsRepository.demoShopSecond` ("Nonna's Pizzeria"): `getAllShops`
  returned `[demoShop, demoShop]`, so every browse-all/search capture showed
  the identical card twice. Both shops are built by one `_seedShop` factory,
  so the shared economics stay in one place. `demoShop` itself is unchanged
  in identity and is still what the manager side's `DemoSellerShopRepository`
  serves.

## 1.24.0

* Fix-wave 2026-09-02 (Dart SDK audit, G1 M1-M3, G4 M22-M27, G6). Frappe
  half: `api.seller_operations.create_seller_section` and
  `api.seller_operations.delete_seller_tables` are now whitelisted in
  `merchants/frappe/manifest.json` (the defs existed, the aliases did not);
  `tests/test_manifest_aliases.py` keeps every alias in the table resolving
  to a `@frappe.whitelist()` def.
* Dart, customer `ShopsRepository`: `getSingleShop` ->
  `api.shop.get_shop_details {uuid}`; `getPickupShops` -> `api.shop.get_shops
  {takeaway: 1}`; `getShopsRecommend` sends the coordinates
  `get_shops_recommend(latitude, longitude)` REQUIRES - the selected
  address, else the tenant's initial location (`ShopsRepository.recommendPayload`)
  - and no `page` (the server has none; the base_sdk facade signature is
  unchanged); `joinOrder` drops `shop_id` and `getTags` drops `category_id`
  (neither kwarg exists server-side - every Tag row comes back, recorded
  behaviour).
* Dart, manager: `SellerShopRepository` -> `api.shop.create_shop`,
  `api.seller_shop.get_shop` / `update_shop` / `set_working_status`,
  `api.seller_shop_settings.get_seller_shop_working_days` /
  `update_seller_shop_working_days`; `QuickFlowRepository` ->
  `api.seller_shop.get_quick_flow_settings` / `update_quick_flow_settings`;
  `SellerSectionsTablesRepository` -> `api.seller_operations.get_seller_sections`
  / `get_seller_tables` / `create_seller_section` / `delete_seller_tables`.
* Customer routes recovered (fix-wave route map): a new `app_type.customer`
  block declares `/shop` (ShopRoute, `?shopId=` deep links via @QueryParam)
  and `/shops_detail` (ShopDetailRoute) with shells in
  `templates/routes/merchants_customer_route_pages.dart`, filling base_sdk's
  `pushShopRoute` / `replaceShopRoute` / `pushShopDetailRoute` seams that
  marketplace, promotions and base_sdk call.
* FLAGGED, not built: `getShopBranch` has no customer-facing server method
  (`get_seller_branches` is seller-session scoped); stays on the dead path
  with a `TODO(fix-wave 2026-09-02)`.
* Tests: `test/gateway_cmd_test.dart` and `test/manifest_wiring_test.dart`.

## 1.23.1

* `pos_checkout`'s tour caption shortened to fit the store still. At 192
  characters it wrapped to 8 rows on the phone leg, one more than the
  caption box holds, so the assembler clamped the block to the canvas
  margin and pasted the phone frame over the last row — the published
  Play still lost "the sale syncs itself later." entirely. The caption now
  wraps to 6 of the 7 rows available. Nothing but the wording changed; the
  offer it makes (cash, a pay-link QR the customer scans on their own
  phone, a 6-digit code confirming an offline sale that syncs itself
  later) is intact. shared-workflows' assembler now fails the run on a
  caption that does not fit, so this cannot silently return.
## 1.22.0

* `DemoSellerShopRepository` — the demo manager finally has a shop.
  `ManagerMerchantsDependencies.register` now selects it over
  `SellerShopRepository` under `--dart-define=IS_DEMO=true`, alongside the
  POS catalog, POS orders and quick-flow seams this SDK already gates.
  Nothing about the production path changed.
  * The shop it serves is `MockShopsRepository.demoShop` ITSELF, not a
    second invention: that field moved from a private instance field to a
    public static one so the manager side can share the identity the
    customer-facing `ShopsRepositoryFacade` already serves in demo. A
    manager who renames or closes the shop in the hub is renaming or
    closing the shop a demo customer browses. Same SDK, so no cross-SDK
    import is involved (ADR-005).
  * Working days are seeded as a plausible trading week (late Friday and
    Saturday, Sunday disabled) and are session-local; `order_payment`
    answers 'before', the value the UI otherwise defaults to.
* Tour fragment: a new `restaurant_hub` step captures the manager home's
  tab 4 — the restaurant hub, the app's navigational spine, whose rows
  already carry `isDemo` sub-lines. It is worth capturing only because of
  the gate above; the stale "NOT demo-gated yet" note is replaced.
* Builds on 1.21.1 (the non-const `CalculatorRoute` compile fix).

## 1.21.0

* Gates 1 and 2 of design strip section 45 — the two doors to `/calc`
  on the manager side (frames 45b and 45c; chips 842 and 843, with 840
  on the calculator's side). `calc_sdk` ships a live `/calc` route
  (composed at `paas_manager/composer.json:162`) that **nothing
  navigated to**; these are the ways in.
  * **842 — the Calculator row on the hub** (frame 45b): a second row
    in the PRODUCTIVITY group that frame 7e created for Tasks, with the
    same earn-your-glance sub-line idiom. Costs nothing structurally —
    one `SectionsItem` in a group that already exists, routing the way
    every other hub row routes (the host's generated `CalculatorRoute`
    via the already-imported `app_router`), and merchants_sdk never
    imports calc_sdk.
    * The approved render's glance ("Memory holds 1 240.50") is SEEDED
      behind `AppConstants.isDemo`, exactly as the Tasks counts are.
      Frame 45b names the fork itself — *"either the row drops the
      sub-line, or memory gets persisted"* — and live memory is not
      readable from here: `calculatorProvider` is an in-memory
      `autoDispose` `StateNotifier` inside calc_sdk, so the value does
      not survive the page, and reading it across SDKs would need a
      base_sdk `LocalStorage` key (a base_sdk change). Real composes
      show the plain row until then.
  * **843 — the till's calculator shortcut** (frame 45c): a THIRD chip
    inside the amount card's quick-chip row, after "Full amount" and
    "R0 all on credit" — deliberately not a header button and not a
    FAB, so it reads as one more way to fill the amount rather than a
    detour. Primary-tinted with the calculator glyph so it reads as an
    action rather than a preset.
    * It opens `/calc?pick=true` and takes the number back into the
      amount display (chip 840, calc_sdk 1.1.0). **Calc feeds the
      keypad; it does not replace it** — chip 390 stays exactly where
      it is and is not modified. The result never touches the cart, the
      order or a balance.
    * Navigation is BY ROUTE PATH, so merchants_sdk still never imports
      calc_sdk (ADR-005). A composition without calc_sdk, or on a
      calc_sdk older than 1.1.0, gets `null` back and the amount is
      untouched — the two PRs are order-independent.
  * `_quickAmountChip` gains an optional glyph and a primary tint; the
    two existing chips render byte-identically.
  * One new manager `tr_key`: `calculator`, declared with the same wire
    value calc_sdk declares, so a double declaration resolves to the
    same string either way.

## 1.20.1

* Dark-mode fix — the manager profile hub's lower two-thirds was
  unreadable. When the hub moved onto base_sdk's `GenericProfilePage`
  (PR #75) its scaffold became `AppStyle.surfaceDark` (#101010 in dark
  mode). The shop block at the head of the page was repointed to the
  mode-resolving ink tokens; the blocks below it were missed, so on a
  dark build:
    - every Sections / PRODUCTIVITY row title painted
      `AppStyle.blackColor` (#000000) — 1.10:1 against the page, i.e.
      invisible. Now `AppStyle.textPrimary` (`sections_item.dart`).
    - both group titles fell through to `TitleAndIcon`'s pinned
      `titleColor` default, `AppStyle.black` (#232B2F) — 1.32:1, also
      invisible. The two hub call sites now pass
      `titleColor: AppStyle.textPrimary` explicitly. The shared default
      in base_sdk is deliberately LEFT pinned: ~90 fleet call sites sit
      on `ModalWrap`'s white sheet (including the two sheets this hub
      opens), and flipping it would blank those instead.
    - the working-hours pill stroked `AppStyle.borderColor` (#E6E6E6) —
      the inverse failure: a near-white 15.25:1 hairline shouting off a
      page whose every other stroke is #2E2E2E, and 1.06:1 (invisible)
      on the light page. Now `AppStyle.strokeDark`, the token
      `GenericProfilePage` strokes its own cards with.
  No layout, copy or routing change; ink and stroke only.
* Test: `profile_hub_dark_mode_test.dart` — pumps `SectionsItem` and
  `TitleAndIcon` in both polarities and holds their resolved ink to the
  WCAG 1.4.3 4.5:1 body floor against the host surface, and gates
  `restaurant_page.dart` (a `${package}` template, unpumpable from this
  package and excluded from CI) on paint tokens that resolve with the
  mode. Fails on the pre-fix tree at 4 passed / 6 failed.


## 1.20.0

* DELIVERY COLLECTED IN PERSON — the server half (approved design strip
  section 43). ONE new atomic seller endpoint,
  `convert_delivery_to_collected(order_id)`, whose whole point is that it
  is one call: a client-orchestrated sequence that fails half way leaves
  an order that is half converted — a Pickup order still carrying a
  driver, or a driver stood down on an order that never converted. Any
  throw rolls the whole request back.
  * Ray's policy rendered literally. **No driver had been dispatched** →
    the delivery fee goes back to the customer's wallet (`deposit_to_wallet`,
    which writes the Transaction audit row) and `delivery_fee` is zeroed,
    so `calculate_totals` drops the order's total by it. **A driver HAD
    been dispatched** → he still drove for it, so the fee is kept and paid
    to HIM as a callout (a new `settle_delivery_callout` in orders'
    settlement module, gross fee credited and delivery commission billed
    back exactly as an ordinary settlement would), the total is unchanged,
    and his task disappears from the driver app the moment `deliveryman`
    is cleared. Either way the goods go over the counter.
  * **THE ORDER OF THE WRITES IS THE POINT.** The Order controller settles
    on every save once the order is Delivered + Paid, and `settle_order`
    credits the deliveryman the FULL `delivery_fee` while he is still
    assigned. So the callout is paid and the assignment cleared in the
    FIRST save, with the order still short of Delivered; only the second
    save moves it to Delivered, by which time it carries no driver and the
    settlement pays him nothing. Reverse the two and he is paid twice.
    `merchants/frappe/tests/test_collect_in_person.py` pins that on his
    wallet balance — 35.00 in the right order, 70.00 in the wrong one.
  * Idempotent (`already_converted`), which is what makes the till's
    offline path safe: the hand-over happens immediately and the
    conversion is replayed on reconnect without moving money twice.
  * `get_seller_order_details` additively serves `deliveryman_name`, so
    the detail can SAY who is on the order rather than showing a user id;
    `get_seller_orders` additively serves `delivery_type`, `delivery_fee`
    and the two new conversion fields the board card needs.
  * Four new read-only Order fields carry it: `collected_in_person`,
    `collect_fee_refunded`, and `callout_settled` / `callout_settled_at`
    (the callout's own once-only flag). `deposit_to_wallet` gained an
    additive `commit` flag so a credit that is part of a larger
    all-or-nothing write is not committed out from under a later failure;
    every existing caller keeps the old behaviour.

## 1.19.0

* QUICK FLOW (approved design strip section 42, frames 42a tablet / 42b
  phone / 42c the till inset): a new merchant settings surface — one
  place where a shop tells the till to run itself between customers —
  reached from a new **Quick flow** row inserted SECOND into the
  restaurant tab's Sections list (chip 795; the other five rows are
  untouched). Three switches, and the surface never pretends they are
  peers:
  * **Auto-accept incoming orders** (797) is `Shop.auto_approve_orders`,
    a field that ALREADY EXISTED and was already honoured by
    `create_order` — the row exposes that exact field and NOTHING
    server-side changed for it, which is what the `LIVE · SERVER` badge
    means. The gate line under it (798, a wide read — dropped on the
    phone) is the doctype's own description: the platform's *Auto Approve
    All Orders* has to be on too, or nothing moves.
  * **Auto-complete at Ready** (799) is NEW on both sides: a new
    `Shop.auto_complete_at_ready` field and a new Order-controller rule
    (commerce/orders, `complete_at_ready_if_due`). Drawn and defaulted
    OFF, carrying the hand-over warning (800) in as many words —
    orders complete with nobody confirming the customer took them.
    PICKUP ONLY, and never on insert: a travelling order is never
    completed by it (settlement pays the deliveryman the full fee on
    Delivered), and a packed send-for-delivery POS sale is created
    holding Ready and must stay there.
  * **Keypad autodial** (802) with the DIGIT PRESETS grid (803/804/805,
    3-up at plane width and 1-up on the phone — the column count is the
    only thing that changes) is a NEW per-shop digit→product map. Slots
    are filled through the till's own catalog seam
    (`PosCatalogRepositoryFacade`), so this SDK still never imports
    products_sdk (ADR-005).
  Planes: a `PlaneHost` whose root is the merchant Sections rail (795,
  Quick flow lit) and whose active step claims TWO planes — more space
  buys more detail, not zoom — folding to one plane on the phone with
  the wide-read extras dropped (42b). The corner back pill at the
  bottom-END (canonical 347) is `PlaneHost`'s own; this is a pushed
  surface, so it is the only nav affordance on screen. Every switch
  writes THROUGH to the shop and REVERTS if the server refuses: no local
  draft and no Save button, because two of the three change what the
  till does the moment they move.
* KEYPAD AUTODIAL on the till (42c): while there is NOTHING on the
  ticket, a digit key is not money — it is the item the shop mapped to
  that key, dropped straight on the ticket; once an item is on, the keys
  are money again. The hint strip (807) is present only while the ticket
  is empty (it is the visible form of the arming rule), each armed key
  prints its preset's name UNDER THE NUMERAL (806), and the strip along
  the bottom says what landed (808). An unset digit is INERT, not an
  error (805). **base_sdk's `MoneyKeypad` (chip 390) is NOT modified** —
  it emits the same key events it always did and the till decides what a
  press MEANS; the captions are a caller-side overlay on the pad's own
  published geometry under an `IgnorePointer`. Chip 390's
  pure-input-surface contract stays intact fleet-wide. The till's
  Continue stays live on an empty ticket ONLY while autodial is armed,
  because the pad lives on the payment surface and is how the ticket
  gets built; unarmed shops see exactly the gate they always saw, and
  while the pad is armed the "Amount paying now" card yields so there is
  never a second keypad on the page.
* Backend (commerce/merchants + commerce/orders): `Shop` gains
  `auto_complete_at_ready`, `keypad_autodial` and the `digit_presets`
  child table (new `Shop Digit Preset` doctype, digit 1-9 → Product);
  `seller_shop.get_quick_flow_settings` / `update_quick_flow_settings`
  read and write the surface as one unit (the writer OWNS the whole 1-9
  map and refuses a bad digit, a digit mapped twice, a missing product
  or another shop's product), serving each preset's product already in
  the client's `ProductData` shape so a digit press never waits on the
  network.
* Tests: `quick_flow_settings_test.dart` (the model's reads and the
  notifier's write-through-and-revert), `quick_flow_page_test.dart` (the
  three switches and what each says about itself, the preset grid and
  its counter, and the fold), `pos_checkout_autodial_test.dart` (the
  arming rule driven through the REAL shared keypad, asserting on the
  cart). Server-side: `test_auto_complete_at_ready.py` (every guard the
  new rule refuses on, bench-free) and `test_seller_quick_flow.py` (the
  two endpoints under composer substitution).

## 1.18.0

* SYNC ISSUES adopts the standard list language (approved design strip
  frame 38c, Ray 2026-08-30 12:23Z: "33 list language = STANDARD for all
  lists ... the box tabs are IN"). The park-and-surface screen is the
  only manager list whose cards carry ACTIONS, which is why the frame
  puts it at the two-plane fold: if the treatment holds here it holds
  anywhere.
  * New `src/manager/presentation/sync_issues/sync_issue_boxes.dart`:
    `SyncIssueBox` — the record's box as a filter (chip 710, the other
    genuinely new affordance Ray ruled IN): All / Shop / Product / Order,
    colour-coded per the 33a set (Shop = base blue, Product = rate
    yellow with dark pill text, Order = primary), each filtering and
    counting its own box. A record from a box with no tab of its own
    still shows under All, so nothing can vanish from the list.
  * New `src/manager/presentation/sync_issues/sync_issue_card.dart`:
    `SyncIssueCard` — the shipped card in the 33 dress (chip 708): box
    glyph + label in the box's own colour, the record summary, the
    server's rejection message in red, and the shipped action pair
    Try again / Discard (chip 709). Plus the needs-attention header hint
    (chip 711).
  * The installed `sync_issues_page.dart` is rebuilt on those pieces plus
    base_sdk's list language: header count pill "N parked" (700), the box
    tabs, cards in plane-aligned columns, the corner back pill (347), and
    the shipped empty state kept. The list declares TWO planes and fills
    the fold exactly. Discard still goes behind the shipped are-you-sure
    dialog; Try again still requeues the parked push.
  * Requires base_sdk >= 1.46.0 (the list language).
  * Test: `sync_issues_list_language_test.dart` — the tab set matching
    `SyncIssuesService.boxes`, per-tab filtering and counts, the untabbed
    box still reachable under All, the 33a colours, and the card's label
    / summary / rejection message / action pair.
