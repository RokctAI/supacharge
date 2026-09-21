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

// Host composition file (ADR-005), the corporate_sdk twin of auth_sdk's
// auth_route_pages.dart. TermPage and PolicyPage are @RoutePage()-annotated
// inside corporate_sdk itself, but auto_route's codegen in a composed app
// only generates route classes for @RoutePage widgets that live in the
// HOST's own lib/ — it never reaches into a path-dependency SDK's lib/. So
// the manifest's "routes" entries point at THIS file (installed to
// lib/presentation/routes/ via the manifest "installs" entry), and these
// thin wrappers are what actually gets a TermRoute / PolicyRoute generated.
//
// The pre-fork paas_customer router served the same pages at `/term` and
// `/policy`; those path strings are kept so deep links and push payloads
// keep working. auth's login footer still reaches the pages through
// EmbeddedWidgets.I.termPage()/policyPage() (manifest embedded_widgets) —
// this file only adds the routed entry, it does not replace that seam.

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:corporate_sdk/src/common/presentation/pages/policy_term/policy_page.dart';
import 'package:corporate_sdk/src/common/presentation/pages/policy_term/term_page.dart';

@RoutePage(name: 'TermRoute')
class TermRouteView extends StatelessWidget {
  const TermRouteView({super.key});

  @override
  Widget build(BuildContext context) => const TermPage();
}

@RoutePage(name: 'PolicyRoute')
class PolicyRouteView extends StatelessWidget {
  const PolicyRouteView({super.key});

  @override
  Widget build(BuildContext context) => const PolicyPage();
}
