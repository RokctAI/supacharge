# Changelog

## 1.11.0

* feat(demo): demo repositories follow the runtime demo session. base_sdk
  1.61.0's `DemoSession` adds the runtime half of the demo switch (a
  server-marked demo account signs in through the real login and the app
  serves that session from the same fixtures the tour uses; nothing on
  screen changes). `ProductsSdkDependencies` now chooses its five demo
  twins (products / categories / brands and the seller products / catalog
  seams) by `DemoSession.demoActive` (a demo build OR a demo session) at
  registration, instead of the compile-time `AppConstants.isDemo` alone,
  and adds ONE listener on `DemoSession.instance` (once, guarded) that
  drops and re-registers exactly the singletons it registered itself when
  the switch flips - after a demo login, before routing, and back on
  sign-out. A host's own registration of the same facade is never
  swapped; a flip before the first `register` call is a no-op; nothing in
  the re-register can throw. Requires base_sdk >= 1.61.0. No screen,
  string or tour fragment changes. `test/demo_session_di_test.dart`
  covers the three states and guards that no `AppConstants.isDemo` read
  remains in lib/ or templates/.

## 1.10.1

* fix(demo): demo stock SKUs stop announcing themselves as demo (Ray
  2026-09-03 21:45Z "demo in text or demo data is not needed").
  `DemoSellerProductsRepository` seeds `SKU-<id>` instead of
  `DEMO-SKU-<id>` for every product's stock and for the empty stock a new
  product gets - the product detail pane prints the SKU verbatim. Ids,
  titles, prices, quantities and counts are unchanged.

## 1.10.0

* THE ADD MOMENT on planes (approved frame 35a's "+ New product", chip 618,
  and section 35 decision-transfer item 2 — "a multi-tab form modal unfolds
  into side-by-side panes at plane widths (35b) and folds back to tabs on
  the phone (35d). Transfers to every 2+ tab modal fleet-wide."; Ray
  2026-08-29 15:41Z "approved: 7e, 11u,35a,35b,35c,35d,35e."). The shipped
  two-tab `CreateProductModal` was still opening as a bottom SHEET over the
  catalog at every width (tablet store still 11-add_product, fleet review
  2026-09-02); the edit form already took the 35b panes.
  * At two or more planes "+ New product" now pushes the SAME
    `ProductEditPage` route the Edit moment uses, with `product: null`:
    the shipped `CreateFoodDetailsBody` | `CreateFoodStocksBody` unfold
    into the Details | Stocks panes (rail | details | stocks at three
    planes, details | stocks at two), the origin catalog rail keeps plane 1
    with nothing highlighted, the nav folds to the corner back pill. No new
    page type, no new form: the create bodies, notifiers, validators and
    satellite picker sheets are the shipped ones.
  * The shipped create ORDER survives the fold: the modal kept its Stocks
    tab behind an `IgnorePointer` until the details save had created the
    product (stocks are saved against `createdProduct.uuid`). New
    `ProductFormSplit.stocksLocked` / `stocksLockedHint` draw that lock on
    the pane — dimmed and inert under "Save details first" until
    `createdProduct` lands — and on one plane keep the Stocks segment
    unselectable, hopping to it when the lock lifts (the shipped `onSave`
    tab hop). The stocks save pops the page exactly as it closed the sheet.
  * Phones are UNCHANGED: on one plane "+ New product" still opens the
    shipped `CreateProductModal` bottom sheet (the 12:02Z sheet fork —
    sheet = phone behaviour). Add-on and extras-group creates are
    single-tab CRUD satellites and stay sheets at every width (transfer
    item 3).
  * `CreateFoodDetailsBody.dark` (default false): on the dark pushed page
    the picker chevrons and toggle labels take the mode-resolving
    `AppStyle.textPrimary`; the sheet keeps its shipped ink.
  * Test: `add_product_plane_flow_test.dart` — 1280 / 800 / 393 logical
    (three planes / the fold / one plane): rail and form plane grants, the
    lock and its hint, the lift, the one-plane segment gate and hop, the
    pill; and the edit moment untouched (unlocked, no hint).

## 1.9.0

* Tablet fixes 2026-09-02 (manager tablet review against the approved
  renders). `CatalogHeader`
  (`lib/src/manager/presentation/catalog/catalog_header.dart`): the manager
  catalog's installed `foods_page.dart` template header now lays itself out by
  the planes it actually holds - span >= 2 the approved 35a single row, span
  == 1 on a multi-plane screen two rows (title + compact actions, then the tab
  pill), a single-plane screen the shipped phone row - with the tab pill
  always horizontally scrollable. At the two-plane fold the catalog keeps one
  393 px plane and the header used to overflow it by ~234 px; it no longer
  does. Test: `catalog_header_test.dart`.

## 1.8.1

* Demo seed data (`--dart-define=IS_DEMO=true`): `MockProductsRepository`,
  `MockCategoriesRepository` and `MockBrandsRepository` take their imagery
  from base_sdk's inline `DemoImages` instead of a public placeholder host.
  A demo build talks to no backend and the CI emulator that walks the guided
  tour has no dependable route to that host, so every seeded product,
  category and brand rendered as a broken-image glyph - which is what the
  published store screenshots showed.
* Same repositories, renamed seed strings (nothing removed): "Demo Product"
  -> "Flame-grilled beef burger", "Another Product" -> "Margherita pizza",
  "Adults Only Demo Product" -> "Craft lager 440ml" (still `isAdult: true`,
  still the 18+ badge/age-gate seed, now named for what it is), "Demo Brand"
  -> "Karoo Grill Co.", "Another Brand" -> "Highveld Dairy".

## 1.8.0

* Fix-wave 2026-09-02 (Dart SDK audit, G4 M20/M21, G3 M7). The manager
  product-authoring and catalog repositories no longer post to the dead
  per-method `/api/method/paas.api.seller_product...` URLs; they reach
  merchants' `seller_product.py` as `api.seller_product.*` gateway cmds with
  payloads shaped to the server signatures: `get_seller_products` /
  `get_seller_categories` / `get_seller_units` / `get_seller_extra_groups`
  (`limit_start` + `limit_page_length` paging), `get_product_details
  {product_name}`, `create_product {product_data}` (the exact cmd the offline
  outbox handler already replayed), `update_seller_product {product_name,
  product_data}`, `create_seller_category {category_data}`,
  `delete_seller_category {uuid}`, `{create,update,delete}_seller_extra_group`
  (`group_name` + `group_data`), `get_seller_extra_values {group_name}` and
  `{create,update,delete}_seller_extra_value` (`value_name` + `value_data`;
  the legacy bulk delete becomes one cmd per id).
* FLAGGED, not built: `updateStocks` and `updateExtras` have no whitelisted
  server method (seller_product.py's `update_product_stocks` /
  `update_product_extras` are un-aliased placeholders that answer
  `{status: true}` without touching data, so aliasing them would fake
  success). They stay on the dead path with a `TODO(fix-wave 2026-09-02)`.
* `dotted_border: ^2.1.0` added to pubspec (the manager multi-image picker
  template imports it; pinned from the pre-fork POS pubspec).
* Tests: `test/seller_repositories_gateway_test.dart` pins cmd + payload per
  rewritten call over a recording HttpService (no socket).

## 1.7.1

* `menu`'s tour caption keeps its wording and moves its highlight. The
  marked phrase was the whole list, "products, add-ons and extras" — and a
  highlight phrase never splits across a line wrap, so its chip measured
  1102px against a 936px wrap width and ran 94px off the 1080px canvas,
  cutting "extras" down to "extra" in the published Play still. The mark
  now sits on "Your whole menu", which is the caption's actual key phrase;
  the list stays, unmarked and wrapping normally. shared-workflows'
  assembler now fails the run on a row too long to fit, so this cannot
  silently return.

## 1.7.0

* `DemoSellerProductsRepository` + `DemoSellerCatalogRepository` — demo data
  behind the manager's foods tab. `ProductsSdkDependencies.register` now
  selects them over `SellerProductsRepository` / `SellerCatalogRepository`
  under `--dart-define=IS_DEMO=true`, the same `AppConstants.isDemo` ternary
  this SDK already applies to its customer-facing products, categories and
  brands facades. Nothing about the production path changed.
  * WHY: the guided tour runs the app in demo with zero backend calls, so
    the `menu` still was capturing three empty tabs.
  * WHAT THEY SERVE: six sellable dishes over three categories (Mains,
    Sides, Drinks), two add-ons, two extras groups (Heat, Portion), three
    units, and a sub-shop category pair — enough for the catalog strip, the
    add-ons tab, the extras tab and the create-product form's pickers to
    render stocked without spilling past one screen.
  * WRITES are acknowledged in memory: creating, editing, re-stocking or
    deleting during a tour sticks for the session and resets on the next
    launch. No HTTP client is ever constructed and nothing leaves the
    device.
  * The seeded dishes deliberately match orders_sdk's demo order board.
    Duplicated rather than shared (ADR-005).
* Tour fragment: the demo-grounding note and the `menu` caption no longer
  frame the screen as a brand-new shop's empty menu.

## 1.6.0

* The APPROVED product management + stock update surfaces (Ray 2026-08-29
  15:41Z "approved: 7e, 11u,35a,35b,35c,35d,35e." — coverage groups F + G,
  frames 35a–35e), replacing the light foods page + edit modal presentation
  with the settled plane-model workspace. Machinery is analyzable, tested
  package code under `lib/src/manager/` (orders_sdk 1.11.0 / kitchen_sdk
  1.3.0's architecture); the installed templates are thin glue plus the
  shipped form bodies re-dressed.
  * CATALOG (35a/35c): FoodsPage becomes a workspace whose catalog
    declares ALL planes (`CatalogPlaneFlow`, the kitchen's 13:06Z
    "takes all until another come" precedent) — grid over planes 1–2
    (span + 1 columns), search + category chips (the approved 11m
    language) + the Foods/Add-ons/Extras inner tabs with counts in the
    header, and the selected product's READ-ONLY detail in the last
    plane (`ProductDetailPane`) with wide-screen auto-select. Phones
    keep the one-plane list and the shipped tap-straight-to-edit — the
    tablet-only read stop is the approved deliberate asymmetry.
  * STOCK-STATE GRAMMAR (35a/35f, the parked paas_pos 32a idea landed):
    amber "Low · N left" badge + amber count BELOW 10, red badge +
    price-replacement AT 0, silence when healthy — thresholds are the
    named constant `kLowStockThreshold` (`StockGrammar`, unit-tested);
    card tint and pulsing icon deliberately NOT carried (badge + count
    color is the dark-language redraw).
  * PROFITABILITY STRIP (35a, the 14:51Z groundwork): Price · Cost ·
    Margin on the read detail, CLIENT-SIDE from the existing price +
    manager-only cost fields (`ProductMargin`, unit-tested; "cost not
    set" when cost is missing/zero, negative margins shown red). The
    revenue-aggregates endpoint stays group I's later work.
  * EDIT (35b/35d): tapping Edit pushes `ProductEditPage` as a REAL
    route over the whole shell (the 12:36Z nav fold; kitchen_detail_page
    precedent) — the form declares TWO planes and the shipped modal's
    Details|Stocks tabs unfold into side-by-side panes
    (`ProductEditPlaneFlow` + `ProductFormSplit`), the origin catalog
    keeping plane 1 as the compressed `CatalogEditRail` (12:26Z origin
    rule); one plane folds back to the segmented tabs. The shipped
    bodies keep their notifiers, validators, request shaping and
    satellite picker sheets UNCHANGED — presentation only moved to the
    dark language (units|kitchen, interval|min|max, tax|cost-with-helper
    row groupings; variant cards labelled by their extras combination;
    "+ Add variant" surfacing the notifier's existing `addEmptyStock`).
    EditProductModal stays in the tree but is no longer opened.
  * QUICK STOCK UPDATE (35e): the approved standalone counts-only
    surface group G never had — `QuickStockView` + `QuickStockNotifier`:
    a stepper per stock row, Low-stock/Out triage chips (triage judged
    on the LOADED quantity so a row stays put while being corrected),
    "Save N changes" batch save riding the EXISTING `updateStocks`
    endpoint per changed product (full rows resent with only quantities
    swapped — no new backend). Bottom sheet on phones; a pushed plane
    pane at plane widths (the 12:02Z sheet fork) with the corner pill.
  * The ~10 CRUD satellite modals (categories/units/kitchens/extras/
    addons) stay the sheets they were — reachable from the new surfaces,
    untouched (the decision-transfer rule: sheets overlay, never take
    planes). The create flow (CreateProductModal + FAB-dispatch
    siblings) keeps its shipped sheet shape, now opened from the
    header's "+ New product" (no FAB in the floating-nav language —
    merchants_sdk 1.14.1 retires the shell FAB on the foods tab).
  * Requires base_sdk >= 1.43.0; new manager tr_keys for the new
    surface language (see manifest).

* Tour fragment kept in step (the tour-sync rule): the add-product step's
  prose now points at FoodsPage's own "+ New product" header button — the
  same `Remix.add_line` tap target, so the step's dart is unchanged — and
  the header notes the shell FAB no longer covers the foods tab
  (merchants_sdk 1.14.1).

## 1.5.1

* Tour fragment: the foods step selects home-shell tab index 3
  (merchants_sdk 1.14.0 mounts the Kitchen tab at 2, shifting foods
  right; the fragment had already gone stale at index 1 when the
  POS-first shift moved foods to 2 — it was landing the tour on the
  order queue). No code changes.

## 1.5.0 and earlier

* See the repository history — this changelog starts at 1.5.1.
