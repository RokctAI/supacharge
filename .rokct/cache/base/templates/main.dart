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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
// Deep adaptive import (same reasoning as the theme import below): the
// phone-only orientation lock IS AppOrientation.shouldLockPortrait() — the
// one copy of that rule, shared with the FreeRotation claim a page uses to
// be excused from it.
import 'package:base_sdk/src/presentation/adaptive/orientation.dart';
// Deep theme import (not the base_sdk barrel — that would produce a
// duplicate_import lint wherever an SDK's wiring imports also pull theme
// symbols): this file itself references AppStyle.systemUiOverlay in the
// SystemChrome call below, so the import must be static, not left to
// the generated wiring blocks (no SDK is obliged to inject it).
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:${package}/presentation/app_widget.dart';
// auto_route and the host app_router are NOT imported statically: the only
// code that references them is injected (app_routes bodies use
// context.router and the generated route classes), and base_sdk's manifest
// declares both under its app_routes "imports", so they arrive via the
// @generated-wiring-imports block below. Importing them here too produced
// duplicate_import lints in every composed app.

// @generated-sdk-imports-start
// @generated-sdk-imports-end

// Wiring imports: each SDK manifest's app_routes / embedded_widgets /
// brand_hook entries may carry an "imports" list of FULL import lines; they
// land here (deduped, sorted) so the injected bodies' symbols (LoginRoute,
// OnboardingIntroRouteView, applyAppBrandColors, ...) resolve without any
// hand-written imports in this file.
// @generated-wiring-imports-start
// @generated-wiring-imports-end

void main() async {
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();

  // Uncaught-error capture, installed before anything else in main() can
  // throw, so a crash leaves a record instead of just disappearing.
  //
  // FlutterError.onError receives what the framework itself catches: errors
  // thrown in build, layout, paint, and in the callbacks it invokes.
  // presentError IS the default handler, so calling it last keeps the existing
  // behaviour exactly - red screen in debug, console dump in release - and the
  // debugPrint ahead of it puts the same exception and stack in the platform
  // log (logcat / the Windows console), where a device bug report can be read
  // after the app is already gone.
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Uncaught Flutter error: ${details.exceptionAsString()}');
    debugPrint('${details.stack}');
    FlutterError.presentError(details);
  };

  // Errors that never pass through the framework arrive here instead: a throw
  // from a platform message handler, an unawaited Future that fails inside a
  // boot hook, anything raised on the root zone after the first frame.
  // Returning true reports the error as handled - the debugPrint above is the
  // record - rather than letting it reach the engine's default reporter.
  //
  // Deliberately no runZonedGuarded: the platform dispatcher hook already
  // covers the whole app, and a zone around runApp here would be wrong, since
  // the bindings are initialized on the line above in the root zone and
  // calling runApp from a different zone is the "Zone mismatch" assertion.
  binding.platformDispatcher.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught platform error: $error');
    debugPrint('$stack');
    return true;
  };

  // Boot hooks: SDK-declared startup statements (each SDK manifest's
  // "boot_hooks" list — id-keyed, order-sequenced; see the installer's
  // update_boot_hooks()). e.g. comms_sdk declares the Firebase/FCM boot, a
  // splash-holding app's home SDK declares FlutterNativeSplash.preserve.
  // Bodies may await — main() is async. Imports ride the wiring block above.
  // @generated-boot-hooks-start
  // @generated-boot-hooks-end

  // Brand hook: at most ONE installed SDK (normally the home SDK) declares
  // "brand_hook" in its manifest — the installer hard-errors on two — and its
  // call is injected here to load the app's brand palette into the shared
  // AppStyle tokens before the first frame. The kernel ships neutral
  // defaults only.
  // @generated-brandhook-start
  // @generated-brandhook-end

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Portrait lock is PHONE-ONLY: desktop platforms and tablet-sized devices
  // (logical shortest side >= AppBreakpoints.medium) keep free rotation —
  // pinning a wide window to portrait defeats the adaptive layouts.
  if (_shouldLockPortrait()) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  // White status/nav icons over transparent bars — the shared token also
  // backs the theme's AppBarTheme and the splash's edge-to-edge re-assert,
  // so the battery/clock stay visible (light) on every screen.
  SystemChrome.setSystemUIOverlayStyle(AppStyle.systemUiOverlay);

  await LocalStorage.init();
  // base_sdk's import and DI registration are injected into the generated
  // blocks below (base_sdk first — update_main_dependencies() orders it ahead
  // of every feature SDK). Do NOT also import/register it by hand up here:
  // that produced a duplicate import and a double
  // BaseSdkDependencies.register() in every composed shell.
  // @generated-sdk-di-start
  // @generated-sdk-di-end

  // DI hooks: SDK-declared DI statements beyond the standard
  // *SdkDependencies.register calls above (each SDK manifest's "di_hooks"
  // list — id-keyed, order-sequenced; see the installer's
  // update_di_hooks()). Placed AFTER the sdk-di block so hook bodies can
  // resolve anything just registered — e.g. orders_sdk's manager role DI
  // and its ADR-005 facade adapters from the installed orders_adapters.dart.
  // Imports ride the wiring block above.
  // @generated-di-hooks-start
  // @generated-di-hooks-end

  // AppRoutes.I: SDK-resident code (splash, auth flows) navigates through
  // this indirection since it can't reference host-generated route classes
  // directly. Methods below this line are injected per-SDK (see each SDK's
  // manifest.json "app_routes" list, e.g. auth_sdk declares
  // replaceLoginRoute) — a method only appears here if some installed SDK
  // actually needs it. Anything not injected keeps throwing a descriptive
  // StateError via noSuchMethod rather than failing silently. If this
  // app needs routing behavior no SDK provides, edit this class directly —
  // the installer detects host edits to main.dart and stops overwriting it.
  //
  // EmbeddedWidgets.I: same indirection for host-composed widgets — SDK code
  // (e.g. auth's "Skip" fall-through to the intro carousel) renders another
  // SDK's pages through it without importing that SDK directly (ADR-005).
  // Methods are injected per-SDK from each manifest's "embedded_widgets"
  // list; anything not injected keeps throwing a descriptive StateError via
  // noSuchMethod rather than silently rendering a blank widget.
  EmbeddedWidgets.I = _HostEmbeddedWidgets();
  AppRoutes.I = _HostAppRoutes();

  runApp(const ProviderScope(child: AppWidget()));
}

/// Whether this launch should pin the app to portrait.
///
/// Only phone-sized mobile devices lock: web and desktop never do, and a
/// mobile device whose logical shortest side reaches AppBreakpoints.medium
/// (a tablet) keeps free rotation. Runs before runApp, so the size comes
/// from the platformDispatcher's views rather than a MediaQuery.
///
/// The rule itself lives in base_sdk's [AppOrientation] and is deliberately
/// NOT copied here: the same answer is what base restores to when a page's
/// [FreeRotation] claim ends, so a second copy could drift from the one the
/// restore uses. This stays as the host's named seam onto it.
bool _shouldLockPortrait() => AppOrientation.shouldLockPortrait();

class _HostEmbeddedWidgets implements EmbeddedWidgets {
  // @generated-embeddedwidgets-start
  // @generated-embeddedwidgets-end

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'EmbeddedWidgets.I.${invocation.memberName} has not been implemented — '
      'no installed SDK declares it in "embedded_widgets", and it was not '
      'added by hand in main.dart.');
}

class _HostAppRoutes implements AppRoutes {
  // @generated-approutes-start
  // @generated-approutes-end

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'AppRoutes.I.${invocation.memberName} has not been implemented — no '
      'installed SDK declares it in "app_routes", and it was not added by '
      'hand in main.dart.');
}
