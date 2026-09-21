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

// Generic onboarding shell route (decision #22's correction, 2026-07-20):
// onboarding_sdk owns only sequencing, the progress indicator and the role
// choice. EVERYTHING app-specific arrives declaratively:
//
//   * slides — each installed SDK's manifest.json may declare an
//     "onboarding_slides" list; sdk_installer_base.py's
//     update_onboarding_slides() injects those OnboardingSlide(...) bodies
//     into the @generated-onboarding-slides block below (with their
//     "imports" landing in the @generated-onboarding-imports block), exactly
//     the way update_app_routes() fills main.dart's _HostAppRoutes block.
//     e.g. lms_sdk declares its school + grade capture steps.
//
//   * completion behaviour — the default is AppHelpers.goHome; an SDK that
//     needs extra completion logic injects it above the default via a
//     manifest "integrations" entry targeting this file's
//     @onboarding-complete-hook placeholder.
//
// This file is installed as host composition code (it may end up importing
// several SDKs via injected slide imports, which ADR-005 forbids inside any
// single SDK's own lib/ but is exactly what lib/presentation/routes/*
// host-composition files are for).

import 'package:auto_route/auto_route.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:flutter/material.dart';
import 'package:onboarding_sdk/onboarding_sdk.dart';

// @generated-onboarding-imports-start
// @generated-onboarding-imports-end

/// Host route shell for [IntroPage] (onboarding_sdk-resident page).
///
/// Stateful so [IntroDeps] — and the slide list inside it — is built ONCE:
/// it is the riverpod family key for the flow's notifier, so rebuilding it
/// per frame would reset onboarding mid-way.
@RoutePage(name: 'OnboardingRoute')
class OnboardingIntroRouteView extends StatefulWidget {
  const OnboardingIntroRouteView({super.key});

  @override
  State<OnboardingIntroRouteView> createState() =>
      _OnboardingIntroRouteViewState();
}

class _OnboardingIntroRouteViewState extends State<OnboardingIntroRouteView> {
  late final IntroDeps _deps = IntroDeps(
    slides: [
      // @generated-onboarding-slides-start
      // @generated-onboarding-slides-end
    ],
    onComplete: _onComplete,
  );

  /// Where each role lands after onboarding. The default is the app's home
  /// entry; SDK-injected completion logic (see the file header) runs first
  /// and may route elsewhere and return.
  void _onComplete(BuildContext context, OnboardingRole role) {
    // @onboarding-complete-hook
    AppHelpers.goHome(context);
  }

  @override
  Widget build(BuildContext context) => IntroPage(deps: _deps);
}
