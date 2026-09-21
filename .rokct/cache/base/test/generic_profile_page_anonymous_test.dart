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


// The generic profile host in a composition that registers NONE of the
// account facades — radio's exact shape (radio_sdk, base_sdk, comms_sdk,
// telemetry_sdk, desktop_sdk, hms_sdk: no users_sdk, no merchants_sdk, no
// products_sdk). Pumping the page used to throw `Bad state: GetIt:
// Object/factory with type UserRepositoryFacade is not registered` out of
// profileProvider's first watch. Now the host degrades to its anonymous
// surface, says so once over telemetry, and shows nothing about it on
// screen; with only the account facade present the identity surface
// renders and contributions needing the others are omitted; with all
// three the page is what it always was. The same class of seam as
// splash_boot_test's undeclared-route case: the composition is the
// fixture, and the assertion is that the host lands somewhere real.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/application/profile/profile_host_capabilities.dart';
import 'package:base_sdk/src/application/profile/profile_notifier.dart';
import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/domain/interface/gallery.dart';
import 'package:base_sdk/src/domain/interface/shops.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/presentation/pages/profile/generic_profile_page.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_host_scope.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_section_registry.dart';
import 'package:base_sdk/src/presentation/pages/profile/widgets/app_usage_badge.dart';
import 'package:base_sdk/src/presentation/pages/profile/widgets/base_profile_footer.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/telemetry.dart';

// The page never calls into a repository in these tests (no stored token,
// so fetchUser returns before its first repository call); the notifier
// only needs constructible instances where a facade is registered at all.
class _FakeUserRepository extends Fake implements UserRepositoryFacade {}

class _FakeShopsRepository extends Fake implements ShopsRepositoryFacade {}

class _FakeGalleryRepository extends Fake implements GalleryRepositoryFacade {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> telemetry;

  /// Everything the app sends through the one telemetry door, decoded.
  void captureTelemetry() {
    telemetry = <Map<String, dynamic>>[];
    TelemetryClient.configure(transport: (cmd, payload) async {
      final context = payload['context'];
      telemetry.add(<String, dynamic>{
        'cmd': cmd,
        'error_message': payload['error_message'],
        if (context is String) ...jsonDecode(context) as Map<String, dynamic>,
      });
    });
  }

  Map<String, dynamic>? eventOfType(String type) {
    for (final event in telemetry) {
      if (event['type'] == type) return event;
      if (event['error_message'] == type) return event;
    }
    return null;
  }

  Iterable<Map<String, dynamic>> eventsOfType(String type) =>
      telemetry.where((event) => event['type'] == type);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  setUp(() async {
    // The EMPTY locator is the composition under test: nothing another
    // test registered may leak in, and each group registers only what its
    // composition would.
    await getIt.reset();
    ProfileSectionRegistry.I.reset();
    GenericProfilePage.resetAnonymousModeReport();
    captureTelemetry();
  });

  tearDown(() async {
    TelemetryClient.configure();
    GenericProfilePage.resetAnonymousModeReport();
    await getIt.reset();
  });

  /// Pumps the host at [width] logical pixels (390 = the design phone;
  /// 1280 = a desktop window). Without a PlaneHost above it the page keeps
  /// its phone layout at any width, so the two runs share one code path
  /// bar ScreenUtil's scaling.
  Future<void> pumpProfile(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(390, 1400),
          builder: (context, _) =>
              const MaterialApp(home: GenericProfilePage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// A contributed section that reports the capabilities the host handed
  /// it — read from the WIDGET's own context, below the host's scope.
  ProfileSection probeSection(
    String id,
    void Function(ProfileHostCapabilities seen) onBuild, {
    Set<ProfileFacade> requires = const {},
  }) {
    return ProfileSection(
      id: id,
      order: 500,
      requires: requires,
      builder: (_) => Builder(
        builder: (context) {
          onBuild(ProfileHostScope.of(context));
          return SizedBox(
            key: ValueKey(id),
            height: 40,
            width: double.infinity,
          );
        },
      ),
    );
  }

  ProfileSection plainSection(
    String id, {
    Set<ProfileFacade> requires = const {},
  }) =>
      ProfileSection(
        id: id,
        order: 100,
        requires: requires,
        builder: (_) => SizedBox(
          key: ValueKey(id),
          height: 40,
          width: double.infinity,
        ),
      );

  /// Nothing the person at the screen can read may carry the reason.
  void expectNoDiagnosticsOnScreen(WidgetTester tester) {
    final shown = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' | ')
        .toLowerCase();
    for (final leak in [
      'stateerror',
      'exception',
      'getit',
      'not registered',
      'facade',
      'anonymous',
    ]) {
      expect(shown.contains(leak), isFalse,
          reason: 'diagnostic detail leaked to the screen: $shown');
    }
  }

  group('ProfileHostCapabilities', () {
    test('detect reads registration off the locator without resolving', () {
      final locator = GetIt.asNewInstance();
      expect(
        ProfileHostCapabilities.detect(locator: locator),
        const ProfileHostCapabilities(
          hasAccount: false,
          hasShops: false,
          hasGallery: false,
        ),
      );
      locator.registerSingleton<UserRepositoryFacade>(_FakeUserRepository());
      final partial = ProfileHostCapabilities.detect(locator: locator);
      expect(partial.hasAccount, isTrue);
      expect(partial.hasShops, isFalse);
      expect(partial.hasGallery, isFalse);
      expect(partial.isAnonymous, isFalse);
      expect(partial.isComplete, isFalse);
      expect(partial.missingFacades,
          ['ShopsRepositoryFacade', 'GalleryRepositoryFacade']);
      expect(partial.satisfies(const {}), isTrue);
      expect(partial.satisfies(const {ProfileFacade.account}), isTrue);
      expect(partial.satisfies(const {ProfileFacade.shops}), isFalse);
      expect(
        partial.satisfies(
          const {ProfileFacade.account, ProfileFacade.gallery},
        ),
        isFalse,
      );
    });

    test('ProfileNotifier.fromLocator constructs against an empty locator',
        () {
      final notifier =
          ProfileNotifier.fromLocator(locator: GetIt.asNewInstance());
      expect(notifier.capabilities.isAnonymous, isTrue);
      expect(notifier.capabilities.missingFacades, [
        'UserRepositoryFacade',
        'ShopsRepositoryFacade',
        'GalleryRepositoryFacade',
      ]);
      notifier.dispose();
    });

    test('the positional constructor derives capabilities from its arguments',
        () {
      final notifier = ProfileNotifier(
        _FakeUserRepository(),
        null,
        _FakeGalleryRepository(),
      );
      expect(
        notifier.capabilities,
        const ProfileHostCapabilities(
          hasAccount: true,
          hasShops: false,
          hasGallery: true,
        ),
      );
      notifier.dispose();
    });
  });

  group('anonymous mode: no account facade registered', () {
    testWidgets('pumps without throwing and shows the anonymous layout',
        (tester) async {
      // What a shell like radio contributes: a links section and an
      // onLogout it believes it owns. Neither needs an account facade.
      ProfileSectionRegistry.I.onLogout = (_) {};
      ProfileSectionRegistry.I.register(plainSection('shell.links'));

      await pumpProfile(tester);

      expect(tester.takeException(), isNull,
          reason: 'the empty locator must not throw out of the first build');
      expect(find.byType(GenericProfilePage), findsOneWidget);

      // No identity surface, no sign-out, no usage badge ...
      expect(find.byKey(GenericProfilePage.accountHeaderKey), findsNothing);
      expect(find.byIcon(Remix.logout_circle_r_line), findsNothing);
      expect(find.byType(AppUsageBadge), findsNothing);
      // ... and no header card at all while the plan slot is unclaimed.
      expect(find.byKey(GenericProfilePage.anonymousHeaderKey), findsNothing);

      // The shell's contribution and the footer are there.
      expect(find.byKey(const ValueKey('shell.links')), findsOneWidget);
      expect(find.byType(BaseProfileFooter), findsOneWidget);

      expectNoDiagnosticsOnScreen(tester);
    });

    testWidgets(
        "the shell's plan slot still renders, alone in the header card",
        (tester) async {
      ProfileSectionRegistry.I.registerHeaderSlot(
        ProfileHeaderSlot.plan,
        id: 'shell.plan',
        builder: (_) => const Text('Free', key: ValueKey('shell.plan')),
      );

      await pumpProfile(tester);

      expect(tester.takeException(), isNull);
      expect(
          find.byKey(GenericProfilePage.anonymousHeaderKey), findsOneWidget);
      expect(find.byKey(const ValueKey('shell.plan')), findsOneWidget);
      expect(find.byIcon(Remix.vip_crown_line), findsOneWidget);
      expect(find.byKey(GenericProfilePage.accountHeaderKey), findsNothing);
    });

    testWidgets(
        'an EMPTY locator renders the anonymous card at phone and desktop '
        'widths without an error widget', (tester) async {
      // Nothing registered at all — no ShopsRepositoryFacade, no user, no
      // gallery: the launcher-shaped composition the profile host used to
      // throw out of. The shell's plan slot is what the anonymous card
      // shows.
      expect(getIt.isRegistered<UserRepositoryFacade>(), isFalse);
      expect(getIt.isRegistered<ShopsRepositoryFacade>(), isFalse);
      expect(getIt.isRegistered<GalleryRepositoryFacade>(), isFalse);
      ProfileSectionRegistry.I.registerHeaderSlot(
        ProfileHeaderSlot.plan,
        id: 'shell.plan',
        builder: (_) => const Text('Free', key: ValueKey('shell.plan')),
      );
      ProfileSectionRegistry.I.register(plainSection('shell.links'));

      for (final width in const [390.0, 1280.0]) {
        await pumpProfile(tester, width: width);

        expect(tester.takeException(), isNull,
            reason: 'the empty locator threw at width $width');
        expect(find.byType(ErrorWidget), findsNothing,
            reason: 'an error widget rendered at width $width');
        expect(find.byKey(GenericProfilePage.anonymousHeaderKey),
            findsOneWidget,
            reason: 'no anonymous card at width $width');
        expect(find.byKey(const ValueKey('shell.plan')), findsOneWidget);
        expect(find.byKey(GenericProfilePage.accountHeaderKey), findsNothing);
        expect(find.byKey(const ValueKey('shell.links')), findsOneWidget);
        expect(find.byType(BaseProfileFooter), findsOneWidget);
        expect(find.byType(AppUsageBadge), findsNothing);
        expectNoDiagnosticsOnScreen(tester);
      }
    });

    testWidgets('hands the resolved capabilities to contributed widgets',
        (tester) async {
      ProfileHostCapabilities? seen;
      ProfileSectionRegistry.I
          .register(probeSection('probe', (c) => seen = c));

      await pumpProfile(tester);

      expect(
        seen,
        const ProfileHostCapabilities(
          hasAccount: false,
          hasShops: false,
          hasGallery: false,
        ),
      );
      expect(seen!.isAnonymous, isTrue);
    });

    testWidgets('says so once per process over telemetry, never on screen',
        (tester) async {
      await pumpProfile(tester);

      final event = eventOfType(GenericProfilePage.anonymousModeEvent);
      expect(event, isNotNull);
      expect(event!['cmd'],
          anyOf(TelemetryClient.cmd, TelemetryClient.controlCmd));
      final context = event['context'] as Map<String, dynamic>;
      expect(context['stage'], 'profile');
      expect(context['missing_facades'], [
        'UserRepositoryFacade',
        'ShopsRepositoryFacade',
        'GalleryRepositoryFacade',
      ]);
      expectNoDiagnosticsOnScreen(tester);

      // Mount the host again in the same process — a fresh page, a fresh
      // notifier — and the event does not repeat.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpProfile(tester);
      expect(
          eventsOfType(GenericProfilePage.anonymousModeEvent), hasLength(1));
    });
  });

  group('account facade only: no shops, no gallery', () {
    setUp(() {
      getIt.registerSingleton<UserRepositoryFacade>(_FakeUserRepository());
    });

    testWidgets(
        'renders the identity card at phone and desktop widths with no '
        'ShopsRepositoryFacade or GalleryRepositoryFacade registered',
        (tester) async {
      // The launcher composition: an account, no shops SDK, no gallery.
      // The identity card must draw without either.
      expect(getIt.isRegistered<UserRepositoryFacade>(), isTrue);
      expect(getIt.isRegistered<ShopsRepositoryFacade>(), isFalse);
      expect(getIt.isRegistered<GalleryRepositoryFacade>(), isFalse);
      ProfileSectionRegistry.I.onLogout = (_) {};
      ProfileSectionRegistry.I.register(plainSection('users.links'));

      for (final width in const [390.0, 1280.0]) {
        await pumpProfile(tester, width: width);

        expect(tester.takeException(), isNull,
            reason: 'the account-only locator threw at width $width');
        expect(find.byType(ErrorWidget), findsNothing,
            reason: 'an error widget rendered at width $width');
        expect(find.byKey(GenericProfilePage.accountHeaderKey), findsOneWidget,
            reason: 'no identity card at width $width');
        expect(find.byKey(GenericProfilePage.anonymousHeaderKey), findsNothing);
        expect(find.byIcon(Remix.logout_circle_r_line), findsOneWidget);
        expect(find.byKey(const ValueKey('users.links')), findsOneWidget);
        expect(find.byType(BaseProfileFooter), findsOneWidget);
        expectNoDiagnosticsOnScreen(tester);
      }
    });

    testWidgets(
        'renders the identity header; contributions needing shops or '
        'gallery are omitted', (tester) async {
      ProfileSectionRegistry.I.onLogout = (_) {};
      ProfileHostCapabilities? seen;
      ProfileSectionRegistry.I
        ..register(probeSection('users.links', (c) => seen = c))
        ..register(plainSection('merchants.shop',
            requires: const {ProfileFacade.shops}))
        ..register(plainSection('products.gallery',
            requires: const {ProfileFacade.gallery}))
        ..register(plainSection('merchants.listings',
            requires: const {ProfileFacade.shops, ProfileFacade.gallery}));

      await pumpProfile(tester);

      expect(tester.takeException(), isNull);
      // The account surface, as always: header, sign-out, usage badge.
      expect(find.byKey(GenericProfilePage.accountHeaderKey), findsOneWidget);
      expect(find.byIcon(Remix.logout_circle_r_line), findsOneWidget);
      expect(find.byType(AppUsageBadge), findsOneWidget);
      expect(find.byType(BaseProfileFooter), findsOneWidget);
      expect(find.byKey(GenericProfilePage.anonymousHeaderKey), findsNothing);

      // Only the contributions the composition can host.
      expect(find.byKey(const ValueKey('users.links')), findsOneWidget);
      expect(find.byKey(const ValueKey('merchants.shop')), findsNothing);
      expect(find.byKey(const ValueKey('products.gallery')), findsNothing);
      expect(find.byKey(const ValueKey('merchants.listings')), findsNothing);

      expect(
        seen,
        const ProfileHostCapabilities(
          hasAccount: true,
          hasShops: false,
          hasGallery: false,
        ),
      );
      // Not anonymous: no anonymous-mode event.
      expect(eventOfType(GenericProfilePage.anonymousModeEvent), isNull);
    });

    testWidgets(
        'a header slot needing a missing facade stays empty; one needing '
        'the account renders', (tester) async {
      var shopsGateRan = false;
      ProfileSectionRegistry.I
        ..registerHeaderSlot(
          ProfileHeaderSlot.stats,
          id: 'merchants.stats',
          requires: const {ProfileFacade.shops},
          // The gate must never run against a facade that is not there.
          visible: () async {
            shopsGateRan = true;
            return true;
          },
          builder: (_) => const SizedBox(key: ValueKey('merchants.stats')),
        )
        ..registerHeaderSlot(
          ProfileHeaderSlot.badge,
          id: 'users.badge',
          requires: const {ProfileFacade.account},
          builder: (_) => const SizedBox(key: ValueKey('users.badge')),
        );

      await pumpProfile(tester);

      expect(find.byKey(const ValueKey('merchants.stats')), findsNothing);
      expect(shopsGateRan, isFalse);
      expect(find.byKey(const ValueKey('users.badge')), findsOneWidget);
    });
  });

  group('every facade registered', () {
    setUp(() {
      getIt.registerSingleton<UserRepositoryFacade>(_FakeUserRepository());
      getIt.registerSingleton<ShopsRepositoryFacade>(_FakeShopsRepository());
      getIt.registerSingleton<GalleryRepositoryFacade>(
          _FakeGalleryRepository());
    });

    testWidgets('renders the account surface exactly as before',
        (tester) async {
      ProfileSectionRegistry.I.onLogout = (_) {};
      ProfileHostCapabilities? seen;
      ProfileSectionRegistry.I
        ..register(probeSection('users.links', (c) => seen = c))
        ..register(plainSection('merchants.listings',
            requires: const {ProfileFacade.shops, ProfileFacade.gallery}));

      await pumpProfile(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(GenericProfilePage.accountHeaderKey), findsOneWidget);
      expect(find.byIcon(Remix.logout_circle_r_line), findsOneWidget);
      expect(find.byType(AppUsageBadge), findsOneWidget);
      expect(find.byType(BaseProfileFooter), findsOneWidget);
      expect(find.byKey(const ValueKey('users.links')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('merchants.listings')), findsOneWidget);
      expect(seen, ProfileHostCapabilities.all);
      expect(eventOfType(GenericProfilePage.anonymousModeEvent), isNull);
    });
  });
}
