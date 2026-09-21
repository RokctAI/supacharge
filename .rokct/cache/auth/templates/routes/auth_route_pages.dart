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

// Host composition file (ADR-005). auth_sdk's real pages (LoginPage,
// RegisterPage, ResetPasswordPage, RegisterConfirmationPage) are
// @RoutePage()-annotated inside auth_sdk itself, but auto_route's codegen
// in this app only generates route classes for @RoutePage widgets that
// live in the HOST's own lib/ — it never reaches into a path-dependency
// SDK's lib/ to generate one for a page defined there. Every other working
// route in this app (LessonRoute, ScheduleRoute, LibraryRoute, ...) follows
// this same pattern: a thin host wrapper class, not the SDK's raw page.
//
// So auth_sdk's manifest.json "routes" entries point at THIS file (via the
// ${package} placeholder, same as lms_sdk's manifest already does), not at
// auth_sdk's page files directly — these wrappers are what actually gets a
// route class generated.

import 'package:auto_route/auto_route.dart';
// Re-exported (not just imported): the generated app_router.gr.dart shares
// app_router.dart's library scope, and RegisterConfirmationRoute's
// generated args class references UserModel by type — it needs to be
// visible there, not just inside this file.
export 'package:base_sdk/src/models/models.dart';

import 'package:base_sdk/src/models/models.dart';
import 'package:flutter/material.dart';
import 'package:auth_sdk/src/common/presentation/pages/auth/login/login_page.dart';
import 'package:auth_sdk/src/common/presentation/pages/auth/register/register_page.dart';
import 'package:auth_sdk/src/common/presentation/pages/auth/confirmation/register_confirmation_page.dart';
import 'package:auth_sdk/src/common/presentation/pages/auth/reset/reset_password_page.dart';
// Imported unconditionally so a manifest-contributed line in
// applyComposedRegistrationConfig below always compiles.
import 'package:auth_sdk/src/common/services/registration_config.dart';
// Imported unconditionally so a manifest-contributed line in
// applyComposedEntryConfig below always compiles.
import 'package:auth_sdk/src/common/services/entry_config.dart';
// The session-policy shell installed next to this file (${package} is
// substituted with the host app's package name at install time, same as the
// manifest "routes" imports).
import 'package:${package}/presentation/routes/auth_session_policy.dart';

/// Composition hook for registration capabilities (the registration twin of
/// applyComposedSessionPolicy): which EXTRA fields this app's register form
/// asks for is composition data, declared by the app's home SDK through a
/// manifest "integrations" entry targeting the placeholder below — e.g.
/// lms_sdk contributing `AuthRegistrationConfig.collectsBirthDate = true;`
/// so registration captures a date of birth. With no contribution the block
/// stays empty, every AuthRegistrationConfig flag keeps its off default,
/// and the form (and the register_user payload) is exactly the pre-terms
/// one — apps without the need are untouched.
void applyComposedRegistrationConfig() {
  // @auth-registration-config
}

/// Composition hook for entry-surface capabilities (the login twin of
/// applyComposedRegistrationConfig): whether this app's login page offers
/// the guest "Skip" affordance is composition data, declared by the app's
/// home SDK through a manifest "integrations" entry targeting the
/// placeholder below — e.g. delivery_sdk's driver flavor contributing
/// `AuthEntryConfig.showsGuestSkip = false;` because the courier app has no
/// guest surface. With no contribution the block stays empty and every
/// AuthEntryConfig flag keeps its default (Skip SHOWN — consumer apps let
/// people browse without an account).
void applyComposedEntryConfig() {
  // @auth-entry-config
}

@RoutePage(name: 'LoginRoute')
class LoginRouteView extends StatelessWidget {
  const LoginRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    // Put the composition-declared session policy (auth_session_policy.dart,
    // installed next to this file) in force before the login page builds:
    // every sign-in path goes through this route, so this is the one wiring
    // point the policy needs. A no-op when the app declares no policy.
    applyComposedSessionPolicy();
    // Registration capabilities ride the same wiring point: the register
    // sheet opens from the login page, so the flags are in force before any
    // register form builds.
    applyComposedRegistrationConfig();
    // Entry-surface capabilities too (guest Skip visibility): applied
    // before the login page builds so the affordance renders correctly on
    // the first frame.
    applyComposedEntryConfig();
    return const LoginPage();
  }
}

// RegisterPage, RegisterConfirmationPage and ResetPasswordPage are written
// as bottom-sheet CONTENT: in the normal flow showModalBottomSheet wraps
// them in the sheet's own Material, so they carry none of their own. Routed
// directly (deep link, or any replaceNamed to these paths) nothing provides
// that ancestor and their AppBarBottomSheet's IconButton throws "No
// Material widget found", rendering the red error screen. The Material
// wrapper below restores the routed path without touching the sheet path
// (a second Material under the sheet's is harmless and never built there —
// these wrappers only build when the page is ROUTED to).

@RoutePage(name: 'RegisterRoute')
class RegisterRouteView extends StatelessWidget {
  final bool isOnlyEmail;

  const RegisterRouteView({super.key, this.isOnlyEmail = false});

  @override
  Widget build(BuildContext context) {
    // Deep-linked registration never passes through LoginRoute, so the
    // composed registration capabilities are applied here too (idempotent).
    applyComposedRegistrationConfig();
    return Material(
      child: RegisterPage(isOnlyEmail: isOnlyEmail),
    );
  }
}

@RoutePage(name: 'RegisterConfirmationRoute')
class RegisterConfirmationRouteView extends StatelessWidget {
  final UserModel userModel;
  final bool isResetPassword;
  final String verificationId;

  const RegisterConfirmationRouteView({
    super.key,
    required this.userModel,
    required this.verificationId,
    this.isResetPassword = false,
  });

  @override
  Widget build(BuildContext context) => Material(
        child: RegisterConfirmationPage(
          userModel: userModel,
          verificationId: verificationId,
          isResetPassword: isResetPassword,
        ),
      );
}

@RoutePage(name: 'ResetPasswordRoute')
class ResetPasswordRouteView extends StatelessWidget {
  const ResetPasswordRouteView({super.key});

  @override
  Widget build(BuildContext context) => const Material(
        child: ResetPasswordPage(),
      );
}
