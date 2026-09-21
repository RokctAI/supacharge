# merchants_sdk (manager slice) — Frappe endpoint contract

What the ported Dart client calls, what exists server-side today, and what the
backend workstream still needs to close. Deliverable of the paas_manager fork,
not a blocker on it (orders_sdk / revenue_sdk pattern): contracts are declared
on the facades and unanswered calls fail visibly through `ApiResult.failure`;
nothing is stubbed or faked.

Source of the port: `paas_manager/lib/infrastructure/repositories/
users_repository.dart` (the shop-management subset) and
`table_repository.dart` (the sections/tables subset with a surviving reader).

## SellerShopRepositoryFacade (`src/manager/infrastructure/repositories/seller_shop_repository.dart`)

| Call | Legacy path | Calls now | Exists today? |
|---|---|---|---|
| `createShop` | `POST /api/v1/dashboard/user/shops` (full "become a seller" payload: per-locale `title`/`description`/`address` maps, delivery pricing, category, documents, `images[]`) | `shop.create_shop` (`shop_data` flat dict: `shop_name` + optional `phone`, `address`; `user`/`uuid`/`slug` server-derived) | **Yes** — backs the shop-setup registration step (`ShopSetupSlide` via the installed `merchants_adapters.dart`). Deliberately minimal: the legacy funnel's management material (images, tax, delivery settings, prices, documents) lands post-create through `updateShop`. **Gaps:** endpoint requires the `Seller` (or `System Manager`) role, so a freshly registered manager-app account must already carry it; created shop starts in Frappe's default `status` (no auto-approve flow from the app). |
| `getMyShop` | `GET /api/v1/dashboard/seller/shops` | `seller_shop.get_shop` | **Yes** — returns a flat dict (`title`/`description`/`address` as strings; `MyShopResponse` synthesizes the `translation` object). **Gaps in payload:** no `seller.wallet` (restaurant page balance tile reads cached raw JSON, degrades to 0), no `rating_avg` (star tile shows 0.0), no `order_payment` (dropdown falls back to `'before'`), no `shop_working_days` (fetched separately, below). |
| `updateShop` | `PUT /api/v1/dashboard/seller/shops` (per-locale `title`/`description` maps, `images[]`) | `seller_shop.update_shop` (`shop_data` flat dict: `title`, `description`, `address`, `phone`, `tax`, `min_amount`, `logo_img`, `background_img`, `delivery_time_*`) | **Yes.** `order_payment` is sent but not in the endpoint's allowed fields — **gap** until accepted server-side. Legacy per-locale translation maps collapsed to single values (Frappe stores one). |
| `setWorkingStatus` | `POST .../seller/shops/working/status` (no body, server-side toggle) | `seller_shop.set_shop_working_status` (`status`) | **Yes** — semantics changed from toggle to explicit set; the notifier computes the target from current state and flips optimistically. |
| `getShopWorkingDays` | (rode on the legacy shop payload) | `seller_shop_settings.get_seller_shop_working_days` | **Yes** — returns `[{day_of_week, opening_time, closing_time, is_closed}]`; repo maps onto base_sdk `ShopWorkingDay` (`day/from/to/disabled`). |
| `updateShopWorkingDays` | `PUT .../seller/shop-working-days/{uuid}` (`dates: [{day, from, to, disabled}]`) | `seller_shop_settings.update_seller_shop_working_days` (`working_days_data: [{day_of_week, opening_time, closing_time, is_closed}]`) | **Yes** — full-replace semantics (endpoint deletes and reinserts). |

## SellerSectionsTablesRepositoryFacade (`.../seller_sections_tables_repository.dart`)

The owner side of orders_sdk's ADR-005 `PosSectionsTablesFacade` seam: the
manager host's installed `orders_adapters.dart` should delegate its
`getSections`/`getTables` here (its transitional direct-endpoint bodies call
the same URLs, so the swap is behavior-neutral).

| Call | Legacy path | Calls now | Exists today? |
|---|---|---|---|
| `getSections` | `GET /api/v1/dashboard/{role}/shop-sections` | `seller_operations.get_seller_sections` | **Yes** (contra the stale "gap" note in orders_sdk's contract doc) — but returns bare `{name, title}` rows: no `search` filter, no `area`/`img`/`translation`. Models map `name`→`id`, `title`→`translation.title`. |
| `getTables` | `GET /api/v1/dashboard/{role}/tables` | `seller_operations.get_seller_tables` | **Yes** — bare `{name, table_number, capacity}` rows; **gaps:** no `search`, no `shop_section_id` filter, no `active` flag; ids are Frappe doc names (strings). |
| `createSection` | `POST .../shop-sections` | `seller_operations.create_seller_section` | Endpoint exists but is a **stub** (`{"status": True}`, persists nothing) — **gap.** |
| `deleteTable` | `DELETE .../tables/delete` | `seller_operations.delete_seller_tables` (`table_id`) | **Yes** (single-id; legacy bulk `ids[]` collapsed). |

## Legacy `TableInterface` members NOT ported (no surviving reader)

`createNewTable`, `deleteSection`, `getTableOrders`, `getTableInfo`,
`disableDates`, `getBookings`, `setBookings`, `getWorkingDay`, `getCloseDay`,
`changeOrderStatus` (booking status), `getStatistic` — all belonged to
paas_manager's unrouted table-booking screens. Server-side, partial
counterparts exist (`get_table_disable_dates`, `get_booking_working_days`,
`create_seller_booking`, `update_booking_status`, `get_seller_shop_closed_days`
— the plan's `getCloseDay` note); if the booking vertical is ever revived it
starts from these. Recording per fork plan W3; nothing calls them from Dart.

## Related but owned elsewhere

- Image upload: base_sdk `GalleryRepositoryFacade.uploadImage` (`shopsLogo`/`shopsBack`).
- Delete account / profile: users_sdk (S-2); the logout modal keeps the host's
  `application/profile` slice via `${package}` until then.
- Income statistics: revenue_sdk. Delivery zones: zones_sdk.
