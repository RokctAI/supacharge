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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the injection contract of the installed shell template
/// (templates/routes/onboarding_route_pages.dart): The-Rokct-Protocol's
/// sdk_installer_base.py rewrites the marker blocks below on every compose
/// (update_onboarding_slides() for the slide/import blocks,
/// update_layout_integrations() appends at the complete-hook), so renaming
/// or dropping any of them silently breaks slide injection for every
/// consuming app — exactly the kind of drift a test should catch, not a
/// composed app hanging on splash.
void main() {
  test('shell template carries every injection marker the installer targets',
      () {
    final template = File('templates/routes/onboarding_route_pages.dart')
        .readAsStringSync();

    const markers = [
      '// @generated-onboarding-imports-start',
      '// @generated-onboarding-imports-end',
      '// @generated-onboarding-slides-start',
      '// @generated-onboarding-slides-end',
      '// @onboarding-complete-hook',
    ];
    for (final marker in markers) {
      expect(template.contains(marker), isTrue,
          reason: 'template lost injection marker: $marker');
    }

    // The slides block must sit inside the IntroDeps slides list, before the
    // imports the installer adds are of any use — cheap structural sanity:
    // markers appear in declaration order.
    final order = markers.map(template.indexOf).toList();
    expect(order, orderedEquals(List.of(order)..sort()),
        reason: 'injection markers out of expected order');

    // The route shell the app's manifest route points at must keep its
    // generated name and class: main-dart-level code (e.g. supacharge's
    // EmbeddedWidgets.introPage) constructs it by name.
    expect(template.contains("@RoutePage(name: 'OnboardingRoute')"), isTrue);
    expect(template.contains('class OnboardingIntroRouteView'), isTrue);
  });
}
