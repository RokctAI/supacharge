# Changelog

## 1.3.0

Approved section-40 redesign of the manager /subscriptions screens
(frames 40a/40b/40c, approved 2026-08-30), in the settled dark plane
language. The screens are shops subscribing to THEIR TENANT's plan
catalog (`api.subscription.list_subscriptions` over the tenant
`Subscription` doctype); platform/control-tier plans never appear here.

- `ManagerSubscriptionsPage` rebuilt on base_sdk's `PlaneHost`: the page
  declares two planes (the payment-class money cap — the leftover plane
  trails bare at the END on tablets), header + count pill (chip 700),
  full-width current-plan card (chip 760), and one plan card per plane
  column (chip 761). Pushed page ⇒ bottom-END corner back pill (chip
  347) — deliberately absent while the payment pane is up (the 11u
  payment exception; the escape is the pane's own Cancel).
- Plan cards render the catalog row's real field fork: price + cycle
  (derived from the row's `month`), trial badge (chip 762) only when the
  row carries `trial_period_days`, and the INCLUDES list on the card
  face (chip 763 — `features` lines with badge-markup parsing, falling
  back to the legacy product/order-limit fields); the old "?" info
  dialog is retired. No plan fact is hardcoded; an empty tenant catalog
  gets an honest empty state.
- CURRENT-PLAN GUARD (chip 768): the held plan's card shows a disabled
  "Current plan" CTA instead of erroring after the tap — no accidental
  tap can start a charge; the charge only ever fires from the pane's
  explicit amount-labelled Pay (chip 767).
- `PaymentDialog` skeleton grown into the real purchase surface: shared
  `SubscriptionPaymentBody` (chip 765) used as the last-plane payment
  pane at plane widths and as the shipped phone dialog, with
  payment-method radio rows (chip 766: wallet balance / webview-gateway
  hints, cash filtered by the notifier), Total, fixed-amount Pay +
  Cancel. No keypad by design — the plan price is fixed. The composer's
  `// @subscription-payments-list` / `// @subscription-payments-action`
  layout-integration markers are preserved inside the new pane's widget
  lists.
- `SubscriptionData` gains tolerant `trial_period_days`, `features`, and
  link-string `subscription` (`subscriptionRef`) parsing; new
  `PlanCardLogic` (exported) carries the current-plan guard, includes
  parsing, cycle/trial labels, and an optional client-side `category`
  filter over the tenant catalog's `type` field with the same
  exact-equality semantics as the Next.js frontend's existing plan
  category filtering (a server-side category kwarg would need backend
  work and is out of this wave).

## 1.2.0 and earlier

- Pre-changelog history; see git log.
