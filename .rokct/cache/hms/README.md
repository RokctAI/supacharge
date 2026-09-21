# hms_sdk

Huawei Mobile Services (HMS) support for RokctApp compositions, built the
same way `desktop_sdk` is: an SDK module the composer installs, **not**
Android `productFlavors` (flavors would change every app's `flutter build`
invocation and break CI).

## What it does

- **`DeviceServices`** — answers `{gms, hms, neither}` for the device,
  once, then caches. Non-Android platforms and every detection error
  resolve to `gms` (fail-open), so the existing comms_sdk FCM path stays
  the owner of push unless a device is *positively* GMS-free and
  HMS-capable (Huawei/Honor hardware without Play Services).
- **`HmsPushBootstrap`** — manifest boot hook (order 30, after comms'
  Firebase boot). Strict no-op on GMS devices; on the HMS path it turns on
  Push Kit, obtains the HMS push token from the token stream, and registers
  it through the SAME universal-gateway call the FCM token uses —
  `POST /api/v1/method/rokct.platform.api` with
  `cmd: api.user.register_device_token` — sending `provider: 'hms'`
  (the backend stores `provider` verbatim on its Device Token doc, so no
  backend change is needed to tell the token kinds apart).

Everything is fail-open: a failure anywhere debugPrints and the app boots
normally with no HMS push.

## Build-side wiring

The AGConnect Gradle wiring (Huawei maven repo, `com.huawei.agconnect:agcp`
classpath, conditional plugin apply, `android/app/agconnect-services.json`
expectation) lives statically in core's Android template
(`core/base/dart/templates/android`), gated on the env var
`BUILD_HMS == "true"` — the fixed contract with CI. With `BUILD_HMS`
unset a build behaves exactly as before. The `huawei_push` /
`huawei_hmsavailability` Flutter plugins inject the Huawei maven repo into
the Gradle build themselves, so plain GMS builds of a composed app resolve
without any of this.

## Adopting in an app

Add `hms_sdk` to the app's composition profile
(`the-rokct-protocol/core/utils/flutter/composer/<app>.json`) and the
app's own `composer.json`, like any SDK. To ship an actual HMS build the
app additionally needs its `agconnect-services.json` secret materialized
into `android/app/` and `BUILD_HMS=true` exported in the build job.
