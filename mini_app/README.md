# Supacharge Mini App

A frontend-only PWA that runs the Supacharge experience inside wallet and
messenger containers. It lives here as a folder on purpose: it is an app
shell, not an SDK, and it contains **no backend code**. Static files only,
no build step - host the folder as-is.

## Platform bridges

One codebase, three thin adapters. `js/platform.js` detects the container
and loads exactly one adapter:

| Platform | Adapter | Bridge |
| --- | --- | --- |
| MTN MoMo | `js/adapters/momo.js` | React Native WebView `postMessage` |
| VodaPay | `js/adapters/vodapay.js` | Alipay/mPaaS `my.*` JSAPI |
| Telegram | `js/adapters/telegram.js` | `telegram-web-app.js` (STUB) |

### MTN MoMo

The mini app is this partner-hosted PWA rendered in MTN's React Native
WebView. The container sends `START_JOURNEY` with the user's `msisdn` and
a ~10-minute `micrositeToken`; the app must post an `IS_STILL_ACTIVE`
heartbeat roughly every 45 seconds and listens for the
`AWAITING_FOR_APPROVAL` / `APPROVED` / `REJECTED` payment events.

### VodaPay

Registered as the "PWA (HTML5)" mini-program type on Vodacom's
Alipay/mPaaS stack. Login uses `my.getAuthCode` (the backend exchanges
the code), payment uses the `my.tradePay` native cashier.

### Telegram (experimental stub)

`js/adapters/telegram.js` is a stub. It loads `telegram-web-app.js`,
reads `window.Telegram.WebApp.initData` and hands it to the backend for
HMAC validation via a gateway cmd. The payment path is not implemented:
Telegram runs on bot invoices / Telegram Stars, a different rail from the
wallet bridges. Do not ship it without finishing both paths.

## The gateway rule

Every backend call POSTs to the single platform gateway
`/api/v1/method/rokct.platform.api` with a `cmd` field naming the
manifest method (see `js/api.js`). Never call bare `/api/method/` paths
or invent per-method URLs. The cmd names in `js/api.js` are placeholders
and must be confirmed against the manifest before real calls are wired.

Errors shown to users stay friendly and generic; technical detail goes to
telemetry only (`SupaMiniApi.reportError`).

## Registering the app

- **MoMo**: partner-hosted by URL via the MoMo partner portal
  (partner entry is bilateral, through the MTN partnerships channel).
  Point the portal at the hosted `index.html`.
- **VodaPay**: self-service developer portal; create a mini program of
  type "PWA (HTML5)" and register the hosted URL as the Entrance URL.
  No IDE or package build is needed for this type.
- **Telegram**: create a bot with BotFather and attach the hosted URL as
  a `web_app` (Mini App) link. Experimental - see the stub note above.

## Files

- `index.html` - app entry and minimal status UI
- `js/platform.js` - container detection + adapter loader
- `js/adapters/` - one bridge adapter per platform
- `js/api.js` - single gateway client and telemetry hook
- `manifest.webmanifest`, `sw.js`, `icon.svg` - PWA installability with
  network-first fetch and no aggressive caching
