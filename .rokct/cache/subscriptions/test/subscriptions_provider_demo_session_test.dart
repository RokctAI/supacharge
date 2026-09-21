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


import 'package:base_sdk/base_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscriptions_sdk/src/common/application/subscriptions/subscriptions_provider.dart';
import 'package:subscriptions_sdk/src/common/infrastructure/repository/demo_subscriptions_repository.dart';
import 'package:subscriptions_sdk/subscriptions_sdk.dart';

/// The six unoverridden providers in subscriptions_provider.dart resolve
/// against base_sdk's RUNTIME demo switch (`DemoSession.demoActive`) and
/// not the compile-time `AppConstants.isDemo` they used to read. The test
/// binary is a production build (`IS_DEMO` is never defined for
/// `flutter test`), so the demo SESSION is the only half that can be true
/// here — which is exactly the case the compile-time flag could not serve.
///
/// The session is flipped with the runtime API only
/// (`DemoSession.instance.activate()` / `.clear()`); nothing here touches
/// the compile-time constant or a test-only stand-in for it.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const {});
    await LocalStorage.init();
  });

  setUp(() async {
    // Every case states its own starting point; a leaked demo session from
    // an earlier case must not decide the next one.
    await DemoSession.instance.clear();
  });

  tearDown(() async {
    await DemoSession.instance.clear();
  });

  test('no demo session: the host-override contract still throws', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(DemoSession.demoActive, isFalse);
    expect(
      () => container.read(subscriptionRepositoryProvider),
      throwsA(isA<UnimplementedError>()),
    );
    expect(
      () => container.read(paymentsRepositoryProvider),
      throwsA(isA<UnimplementedError>()),
    );
    expect(
      () => container.read(walletPriceProvider),
      throwsA(isA<UnimplementedError>()),
    );
    expect(
      () => container.read(navigateToWebViewProvider),
      throwsA(isA<UnimplementedError>()),
    );
    expect(
      () => container.read(errorNotificationProvider),
      throwsA(isA<UnimplementedError>()),
    );
    expect(
      () => container.read(translationProvider),
      throwsA(isA<UnimplementedError>()),
    );
  });

  test('demo session active: every provider yields its demo implementation',
      () async {
    await DemoSession.instance.activate();
    expect(DemoSession.demoActive, isTrue);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(subscriptionRepositoryProvider),
      isA<DemoSubscriptionsRepository>(),
    );
    expect(
      container.read(paymentsRepositoryProvider),
      isA<DemoSubscriptionPaymentsProvider>(),
    );
    expect(container.read(walletPriceProvider)(), 0);
    expect(container.read(navigateToWebViewProvider), isNotNull);
    expect(container.read(errorNotificationProvider), isNotNull);
    expect(container.read(translationProvider)('subscriptions'),
        'subscriptions');
  });

  test('a session that starts AFTER the first read is still picked up',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // The read that runs first is a production read: it throws, and
    // riverpod caches that error against the provider.
    expect(
      () => container.read(subscriptionRepositoryProvider),
      throwsA(isA<UnimplementedError>()),
    );

    // A server-marked demo account signs in mid-process.
    await DemoSession.instance.activate();

    // demoActiveProvider invalidated itself on the notification, which
    // dropped the cached error above, so the next read re-decides rather
    // than replaying the boot-time answer forever.
    expect(
      container.read(subscriptionRepositoryProvider),
      isA<DemoSubscriptionsRepository>(),
    );
    expect(
      container.read(paymentsRepositoryProvider),
      isA<DemoSubscriptionPaymentsProvider>(),
    );

    // And it flips back when the session ends (sign-out).
    await DemoSession.instance.clear();
    expect(
      () => container.read(subscriptionRepositoryProvider),
      throwsA(isA<UnimplementedError>()),
    );
  });

  test('a host override is untouched by the session either way', () async {
    final host = _HostFacade();
    final container = ProviderContainer(
      overrides: [subscriptionRepositoryProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);

    expect(container.read(subscriptionRepositoryProvider), same(host));
    await DemoSession.instance.activate();
    expect(container.read(subscriptionRepositoryProvider), same(host));
  });
}

/// Stands in for the adapter a host app installs in its ProviderScope.
class _HostFacade implements SubscriptionsFacade {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$_HostFacade is a stand-in');
}
