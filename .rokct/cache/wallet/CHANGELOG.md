## 1.6.4

* **Fix: wallet history compiles against base_sdk >= 1.65.0.** `base_sdk`
  deleted `AppConstants.isDemo` (the `--dart-define=IS_DEMO=true` build
  flag) in 1.65.0, but `WalletHistoryPage` still read it in five places, so
  any host that composes this SDK - supacharge reaches it transitively
  through payments_sdk - died at the kernel snapshot with `Member not
  found: 'isDemo'`, taking the Android and Windows builds with it. All five
  reads now ask `DemoSession.demoActive`, base_sdk's one demo switch (the
  guided-tour build OR a live server-marked demo session), which is what
  every one of these sites meant: serve the in-app seed because there is no
  backend to ask. None of the five was a tour-only check, so none became
  `AppConstants.isTour`. Each site reads the switch where the decision is
  taken - at the fetch in `initState`, once per `build` for the bound rows
  and the spinner, and inside the pull-to-refresh and load-more callbacks -
  rather than caching it at construction, so a demo session activated by a
  sign-in after the page mounted is honoured. Behaviour is unchanged in a
  real session and under the tour.

## 1.6.3

* **Fix: top-up and history pages now follow the app's colour mode.**
  Both pages pinned light-only tokens (`bgGrey` grounds, `white` cards,
  `black` ink and dividers, `borderColor` strokes, `textGrey` secondary
  text, and `isDarkMode: false` on their bottom sheets), so the guided
  tour captured them light while the rest of the app was dark. They now
  read base_sdk's mode-resolving tokens (`surfaceDark`, `cardDark`,
  `strokeDark`, `textPrimary`, `textDarkSecondary`, `AppStyle.isDark`)
  and render correctly in both modes. Brand-on-primary labels (white on
  the primary buttons) are unchanged.

## 1.6.2

* **Fix: wallet history no longer shows a permanent spinner in demo
  builds;** the loading flag is ignored when the demo history is bound
  (`isLoadingHistory` defaults to `true` and the demo path never fetched).

## 1.6.1

* **Wallet history header no longer overflows on tablets.** The
  `CommonAppBar` child on `/wallet-history` stacked a rigid
  `55.verticalSpace` above the Transactions/Top-up/Send row, but the app
  bar's box is `76.h` plus the status-bar inset less `20.h` of padding, so
  the row only ever had `1.h + inset` of room. Wherever ScreenUtil scales
  1:1 (any window >= 600 dp wide, i.e. the guided tour's tablet leg) that
  is 25 dp for a 35 dp row - the "BOTTOM OVERFLOWED BY 10.0 PIXELS" stripe
  in the tablet still. The spacer is now `Flexible`, so it keeps its full
  height wherever it fits (phones render pixel-identically) and yields
  only the shortfall elsewhere.
* **Demo history seeded; empty state actually shows.** A demo build
  (`--dart-define=IS_DEMO=true`) talks to no backend and users_sdk's
  `UserRepositoryFacade.getWalletHistories` has no demo variant, so the
  tour captured a blank list. New `DemoWalletHistory` (five Rand rows:
  a card top-up, purchases at Corner Kitchen and Nonna's Pizzeria, a
  partial refund and a cash-out, timestamps relative to now) renders in
  place of the fetch under `AppConstants.isDemo`; pull-to-refresh and
  load-more complete locally there. Independently, the page now falls
  through to its `EmptyBadge` whenever the bound list is empty - base_sdk's
  notifier never sets `isEmptyWallet`, so a real account with no rows (or
  a failed fetch) previously rendered nothing at all. Guarded by
  `test/demo_wallet_history_test.dart`.

## 1.6.0

* **Design strip frames 49g/49h/49i — the bank-deposit route (client
  half).** A driver whose wallet went negative (cash docked at Delivered)
  pays into the tenant's bank account, photographs the slip, and a person
  approves it; nothing moves in the wallet until then. New, exported from
  the barrel: `WalletDepositRepositoryFacade` (this SDK's own seam —
  base_sdk carries no deposit facade), `WalletDepositRepository` over the
  platform gateway (`cmd: api.wallet.get_deposit_destination /
  submit_deposit_request / list_deposit_requests /
  list_pending_deposit_requests / approve_deposit_request /
  reject_deposit_request`), and the typed records
  `WalletDepositDestination`, `WalletDepositRecord`, `WalletDepositStatus`,
  `WalletDepositSubmitResponse`, `WalletDepositResolution`.
  `WalletSdkDependencies.register` registers the facade (guarded). The slip
  is uploaded through the fleet's multipart gallery seam by the caller;
  only its URL rides the envelope. Guarded by
  `test/wallet_deposit_repository_gateway_test.dart`. Requires the
  matching wallet backend (frappe manifest keys `{app_name}.api.wallet.*`,
  doctypes `Wallet Deposit Request` + `Wallet Deposit Settings`, Wallet
  History type `Deposit`).

## 1.5.0

* Implements base_sdk's `AppRoutes.pushWalletHistoryRoute` seam: the
  manifest now declares an `app_routes` entry whose body pushes the
  `WalletHistoryRoute` this SDK already declares at `/wallet-history`.
  Hosts that compose wallet_sdk get the method injected into
  `_HostAppRoutes` (the seam previously threw `noSuchMethod`'s
  StateError from marketplace_sdk's profile page). Guarded by
  `test/manifest_wiring_test.dart`.

## 1.4.2

* `WalletRepository.getWalletHistory` goes through the platform gateway
  (`POST /api/v1/method/rokct.platform.api`, `cmd:
  api.user.get_wallet_history`, payload `{start, limit}`) instead of the
  legacy per-method `/api/method/paas.api.user.get_wallet_history` GET,
  which no composed backend serves. The response is unwrapped per the
  gateway envelope (`api_response(data=rows)`). Optional `start`/`limit`
  kwargs mirror the server signature; facade callers get the first page
  as before. Cross-SDK edge: the `api.user.get_wallet_history` alias is
  whitelisted by the users frappe half, not this SDK's.

## 1.4.0

* Saved-card top-up no longer handles the gateway reuse credential.
  `get_saved_cards` stopped returning it, so `WalletTopUpScreen` picks a
  card by its docname and `walletTopUp` sends that on `saved_card`. The
  credential is resolved server-side. Requires the matching wallet
  backend: an older backend reads `token` and will reject the top-up
  rather than charge the wrong thing.

## 1.3.0

* Floating-nav back conversion (approved design strip section 12, "no
  double back buttons" — base_sdk 1.39.0 / core#125): `WalletHistoryPage`
  replaces its standalone `PopButton` with the shared `FloatingBottomNav`
  carrying only the leading back segment — one back per screen. Back-only
  (empty tab list) because the host app's root tabs are not reachable
  from this SDK's pushed route; embedded hosts that pass
  `isBackButton: false` still render no back at all.

## 0.0.1

* TODO: Describe initial release.
