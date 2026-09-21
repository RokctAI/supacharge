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

// WelcomeText's panel restyles itself the moment the theme mode changes, with
// the banner still mounted (Ray, 2026-09-19: "glance doesnt change test
// immediately untill you come back if you switched theme mode" — the same
// defect, found here by the fleet audit that followed).
//
// The banner's fill was AppStyle.textPrimary, a mode-resolving static and not
// an inherited widget, and nothing else it reads is one either: its greeting
// comes from LocalStorage and its copy from AppHelpers. The widget has a
// const constructor and no mount site anywhere in this repo, so no parent
// rebuild can be assumed to deliver the flip — a const instance is handed
// back identical and its element is never rebuilt. It is mounted behind
// ThemeFlipHost's capture here for exactly that reason.
//
// The banner also paints host artwork (assets/images/order.png) that no SDK
// package ships, so OnePixelAssetBundle stands in for the host's bundle. Only
// the colour around the image is under test.

import 'package:base_sdk/src/models/data/profile_data.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:onboarding_sdk/src/common/presentation/pages/welcome/text.dart';

import 'theme_flip_host.dart';

void main() {
  setUp(() async {
    // The banner dereferences LocalStorage.getUser()!.firstname, so the store
    // has to hold a profile before it can be painted at all.
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await LocalStorage.setUser(
        ProfileData(firstname: 'Thandi', lastname: 'Mokoena'));
  });

  tearDown(() => AppStyle.setBrightness(Brightness.dark));

  testWidgets('WelcomeText — the greeting panel follows a theme-mode flip',
      (tester) async {
    // The banner's own outermost Container — the panel whose fill is the
    // colour under test. It names `color:`, not a BoxDecoration.
    final Finder panel = find
        .descendant(of: find.byType(WelcomeText), matching: find.byType(Container))
        .first;
    await expectRestylesOnFlip(
      tester,
      child: DefaultAssetBundle(
        bundle: OnePixelAssetBundle(),
        child: const WelcomeText(),
      ),
      read: (t) => t.widget<Container>(panel).color,
      expected: AppStyle.inkFor,
    );
  });
}
