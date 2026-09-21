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


// The generic profile host in a compose that registers NONE of the three
// commerce facades ProfileNotifier is built from.
//
// UserRepositoryFacade comes from users_sdk, ShopsRepositoryFacade from
// merchants_sdk and GalleryRepositoryFacade from products_sdk. A home-SDK
// compose can legitimately install none of them - radio does, and every
// launcher compose does (launcher_auth_control.dart already documents the
// hazard and deliberately routes around profileProvider because of it).
// The page is advertised as knowing about no feature SDK (ADR-005), so it
// has to MOUNT in that compose.
//
// It did not: profileProvider resolved all three out of get_it in its
// factory, so GenericProfilePage's first build threw
//
//   Bad state: GetIt: Object/factory with type UserRepositoryFacade is not
//   registered inside GetIt.
//
// and radio's guided tour published a flat #440000 RenderErrorBox as its
// profile screenshot (RokctAI/radio run 33628026749, step 05).
//
// Every other profile test in this suite registers fakes in setUpAll, so
// none of them could see this; this one deliberately registers nothing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/application/profile/profile_provider.dart';
import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/gallery.dart';
import 'package:base_sdk/src/domain/interface/shops.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/presentation/pages/profile/generic_profile_page.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/services/local_storage.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  setUp(() async {
    // The whole point: an EMPTY service locator, the way a radio or
    // launcher compose leaves it.
    await getIt.reset();
    ProfileSectionRegistry.I.reset();
  });

  test('profileProvider builds without the commerce facades registered', () {
    expect(getIt.isRegistered<UserRepositoryFacade>(), isFalse);
    expect(getIt.isRegistered<ShopsRepositoryFacade>(), isFalse);
    expect(getIt.isRegistered<GalleryRepositoryFacade>(), isFalse);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(() => container.read(profileProvider), returnsNormally);
  });

  testWidgets('the generic profile host mounts in an unbacked compose',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(800, 600),
          builder: (context, _) => const MaterialApp(
            home: GenericProfilePage(),
          ),
        ),
      ),
    );
    // Two pumps: the first build, then the post-frame fetchUser the host
    // schedules in initState (which is where the second half of the crash
    // came from - "thrown during a scheduler callback").
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.byType(GenericProfilePage), findsOneWidget);
  });
}
