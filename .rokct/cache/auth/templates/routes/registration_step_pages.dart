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

// Registration contributions shell ("auth can do what we do with
// onboarding"): auth_sdk owns only the core account step and the generic
// pipeline that runs after it succeeds. EVERYTHING domain-specific arrives
// declaratively:
//
//   * steps — each installed SDK's manifest.json may declare a
//     "registration_steps" list; sdk_installer_base.py's
//     update_registration_steps() injects those RegistrationStep(...)
//     bodies into the @generated-registration-steps block below (with their
//     "imports" landing in the @generated-registration-imports block),
//     exactly the way update_onboarding_slides() fills the onboarding
//     shell. e.g. lms_sdk declares its school + grade capture steps so a
//     student who registers directly (skipping onboarding) is still asked
//     for both.
//
//   * completion behaviour — the default is RegistrationFlow.defaultLanding
//     (the same goHome landing registration always ended on); an SDK that
//     needs extra completion logic injects it above the
//     default via a manifest "integrations" entry targeting this file's
//     @registration-complete-hook placeholder.
//
// The register flow reaches this shell BY PATH — auth_sdk's manifest
// declares the '/registration-steps' route pointing at this wrapper, and
// RegistrationFlow.completeRegistration() calls
// context.router.replaceNamed('/registration-steps') — because route
// classes are generated in the HOST app only, and base_sdk's AppRoutes
// interface is fixed. With no contributed steps the pipeline falls straight
// through to the default landing, so apps without contributions behave
// exactly as before.
//
// This file is installed as host composition code (it may end up importing
// several SDKs via injected step imports, which ADR-005 forbids inside any
// single SDK's own lib/ but is exactly what lib/presentation/routes/*
// host-composition files are for).

import 'package:auto_route/auto_route.dart';
import 'package:auth_sdk/src/common/presentation/pages/auth/registration/registration_step.dart';
import 'package:auth_sdk/src/common/presentation/pages/auth/registration/registration_steps_page.dart';
import 'package:flutter/material.dart';

// @generated-registration-imports-start
// @generated-registration-imports-end

/// Host route shell for [RegistrationStepsPage] (auth_sdk-resident page).
///
/// Stateful so [RegistrationStepsDeps] — and the step list inside it — is
/// built ONCE: contributed steps may hold their own in-flight state, so
/// rebuilding the list per frame would reset a step mid-way.
@RoutePage(name: 'RegistrationStepsRoute')
class RegistrationStepsRouteView extends StatefulWidget {
  const RegistrationStepsRouteView({super.key});

  @override
  State<RegistrationStepsRouteView> createState() =>
      _RegistrationStepsRouteViewState();
}

class _RegistrationStepsRouteViewState
    extends State<RegistrationStepsRouteView> {
  late final RegistrationStepsDeps _deps = RegistrationStepsDeps(
    steps: [
      // @generated-registration-steps-start
      // @generated-registration-steps-end
    ],
    onComplete: _onComplete,
  );

  /// Where registration lands after the contributed steps. The default is
  /// the same destination registration always had; SDK-injected completion
  /// logic (see the file header) runs first and may route elsewhere and
  /// return.
  void _onComplete(BuildContext context) {
    // @registration-complete-hook
    RegistrationFlow.defaultLanding(context);
  }

  @override
  Widget build(BuildContext context) => RegistrationStepsPage(deps: _deps);
}
