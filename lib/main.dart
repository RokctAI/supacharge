// ==========================================
// [GENERATED TEMPLATE FILE]
// This file was installed from: base_sdk
// Feel free to modify and customize this code.
// Note: If you edit this file, the SDK installer will detect your changes
// and automatically skip overwriting it during future upgrades.
// ==========================================

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:base_sdk/base_sdk.dart';
import 'package:base_sdk/src/presentation/theme/theme.dart';
import 'package:supacharge/presentation/app_widget.dart';
import 'package:supacharge/presentation/routes/app_router.dart';
import 'package:supacharge/presentation/routes/onboarding_route_pages.dart';
import 'package:supacharge/presentation/theme/theme.dart';

// @generated-sdk-imports-start
import 'package:base_sdk/base_sdk.dart';
import 'package:agent_sdk/agent_sdk.dart';
import 'package:auth_sdk/auth_sdk.dart';
import 'package:comms_sdk/comms_sdk.dart';
import 'package:corporate_sdk/corporate_sdk.dart';
import 'package:fav_sdk/fav_sdk.dart';
import 'package:lms_sdk/lms_sdk.dart';
import 'package:merchants_sdk/merchants_sdk.dart';
import 'package:onboarding_sdk/onboarding_sdk.dart';
import 'package:payments_sdk/payments_sdk.dart';
import 'package:processing_sdk/processing_sdk.dart';
import 'package:productivity_sdk/productivity_sdk.dart';
import 'package:products_sdk/products_sdk.dart';
import 'package:replay_sdk/replay_sdk.dart';
import 'package:subscriptions_sdk/subscriptions_sdk.dart';
import 'package:users_sdk/users_sdk.dart';
import 'package:wallet_sdk/wallet_sdk.dart';
// @generated-sdk-imports-end

/// Wires [introPage] plus the login footer's [policyPage]/[termPage]
/// (corporate_sdk's existing pages — corporate owns policy/terms, so any
/// composition with auth_sdk includes corporate_sdk); every other
/// EmbeddedWidgets method keeps the unset registry's behavior (a
/// descriptive StateError) via noSuchMethod, so nothing is silently
/// stubbed with a blank widget.
class _SupachargeEmbeddedWidgets implements EmbeddedWidgets {
  @override
  Widget introPage() => const OnboardingIntroRouteView();

  @override
  Widget policyPage() => const PolicyPage();

  @override
  Widget termPage() => const TermPage();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'EmbeddedWidgets.I.${invocation.memberName} has not been implemented '
      'by Supacharge — only intro/policy/term pages are wired.');
}

/// AppRoutes.I: SDK-resident code (splash, auth flows) navigates through
/// this indirection since it cannot reference host-generated route classes
/// directly. auth_sdk deliberately registers zero routes of its own
/// (ADR-005) — wiring this was a missing composition step, which is why the
/// app previously hung forever on splash (AppRoutes.I threw on first real
/// navigation attempt). Only the methods splash/auth actually call are
/// wired for real; base_sdk's shop/parcel/order navigation vocabulary
/// (leftover from the generic marketplace-app template) doesn't apply to
/// Supacharge and keeps throwing via noSuchMethod until something needs it.
class _SupachargeAppRoutes implements AppRoutes {
  @override
  // Splash lands here after an auth check fails/expires. auth_sdk's real
  // LoginPage (not the onboarding carousel directly) is the entry point —
  // it already has Login/Register buttons AND a "Skip" action that falls
  // through to EmbeddedWidgets.I.introPage() (Supacharge's onboarding
  // carousel), so nobody is forced through a registration wall, but every
  // visitor gets the identity-capture opportunity first.
  Future<Object?> replaceLoginRoute(BuildContext context) =>
      context.router.replace(LoginRoute());

  /// No single "main shell" route exists — each top-level tab (Schedule,
  /// Tutors, Library, Profile/Subscribe) is independently routed and
  /// carries its own SupachargeNav bottom bar (decision #24). Schedule is
  /// the landing tab a freshly-authenticated student sees.
  @override
  Future<Object?> replaceMainRoute(BuildContext context) =>
      context.router.replace(ScheduleRoute());

  @override
  Future<Object?> replaceClosedRoute(BuildContext context) =>
      context.router.replace(ClosedRoute());

  @override
  Future<Object?> replaceNoConnectionRoute(BuildContext context) =>
      context.router.replace(NoConnectionRoute());

  @override
  Future<Object?> replaceUiTypeRoute(BuildContext context) =>
      context.router.replace(UiTypeRoute());

  @override
  Future<Object?> replaceSplashRoute(BuildContext context) =>
      context.router.replace(SplashRoute());

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'AppRoutes.I.${invocation.memberName} has not been implemented by '
      'Supacharge — this app has no shop/parcel/order routes.');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inject this app's brand palette into the shared AppStyle tokens before
  // the first frame (the kernel ships neutral defaults only).
  applyAppBrandColors();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppStyle.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppStyle.transparent,
      systemNavigationBarDividerColor: AppStyle.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await LocalStorage.init();
  BaseSdkDependencies.register(GetIt.instance);
  // @generated-sdk-di-start
  BaseSdkDependencies.register(GetIt.instance);
  AgentSdkDependencies.register(GetIt.instance);
  AuthSdkDependencies.register(GetIt.instance);
  CommsSdkDependencies.register(GetIt.instance);
  CorporateSdkDependencies.register(GetIt.instance);
  FavSdkDependencies.register(GetIt.instance);
  LmsSdkDependencies.register(GetIt.instance);
  MerchantsSdkDependencies.register(GetIt.instance);
  OnboardingSdkDependencies.register(GetIt.instance);
  PaymentsSdkDependencies.register(GetIt.instance);
  ProcessingSdkDependencies.register(GetIt.instance);
  ProductivitySdkDependencies.register(GetIt.instance);
  ProductsSdkDependencies.register(GetIt.instance);
  ReplaySdkDependencies.register(GetIt.instance);
  SubscriptionsSdkDependencies.register(GetIt.instance);
  UsersSdkDependencies.register(GetIt.instance);
  WalletSdkDependencies.register(GetIt.instance);
// @generated-sdk-di-end

  // EmbeddedWidgets.I: auth_sdk shows intro via this indirection so it
  // never imports onboarding_sdk directly (ADR-005). Only introPage is
  // wired for real; the other 15 methods keep throwing the same
  // descriptive StateError as the unset default until a host actually
  // needs them — implementing all 16 blind isn't this task's job.
  EmbeddedWidgets.I = _SupachargeEmbeddedWidgets();
  AppRoutes.I = _SupachargeAppRoutes();

  runApp(const ProviderScope(child: AppWidget()));
}
