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

// Demo login in production, phase 2: this SDK's repositories follow the
// runtime demo switch. A real session gets the HTTP repositories, a demo
// session (flipped after the real backend accepted a marked account) gets
// the in-app twins, and sign-out swaps the real ones back - all through
// the one DI hook the composed main.dart already calls, with no host
// change and nothing new on screen.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/domain/interface/address.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/services/demo_session.dart';
import 'package:base_sdk/src/services/local_storage.dart';

import 'package:users_sdk/src/common/di/users_di.dart';
import 'package:users_sdk/src/common/infrastructure/repositories/address_repository.dart';
import 'package:users_sdk/src/common/infrastructure/repositories/mock_address_repository.dart';
import 'package:users_sdk/src/common/infrastructure/repositories/mock_user_repository.dart';
import 'package:users_sdk/src/common/infrastructure/repositories/user_repository.dart';

void _expectReal(GetIt getIt, {String? reason}) {
  expect(getIt<UserRepositoryFacade>(), isA<UserRepository>(), reason: reason);
  expect(
    getIt<AddressRepositoryFacade>(),
    isA<AddressRepository>(),
    reason: reason,
  );
}

void _expectDemoTwins(GetIt getIt, {String? reason}) {
  expect(
    getIt<UserRepositoryFacade>(),
    isA<MockUserRepository>(),
    reason: reason,
  );
  expect(
    getIt<AddressRepositoryFacade>(),
    isA<MockAddressRepository>(),
    reason: reason,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GetIt getIt;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    DemoSession.isDemoOverride = false;
    getIt = GetIt.asNewInstance();
  });

  tearDown(() async {
    await DemoSession.instance.clear();
    DemoSession.isDemoOverride = null;
    await getIt.reset();
  });

  test('a real session registers the real repositories', () {
    UsersSdkDependencies.register(getIt);
    _expectReal(getIt);
  });

  test(
    'a demo session swaps in the twins, and sign-out swaps them back',
    () async {
      UsersSdkDependencies.register(getIt);
      _expectReal(getIt, reason: 'before sign-in');

      // The login flow flips the switch after the real backend accepted the
      // account and before routing; nothing re-runs the DI hook.
      await DemoSession.instance.activate();
      _expectDemoTwins(getIt, reason: 'after a marked account signed in');

      // Every sign-out path ends in LocalStorage.logout(), which clears it.
      await DemoSession.instance.clear();
      _expectReal(getIt, reason: 'after sign-out');
    },
  );

  test(
    'a demo session restored at boot registers the twins directly',
    () async {
      // The flag is persisted: a relaunch that restores the stored token
      // restores the demo session before the DI hook runs.
      await DemoSession.instance.activate();

      UsersSdkDependencies.register(getIt);
      _expectDemoTwins(getIt);

      await DemoSession.instance.clear();
      _expectReal(getIt, reason: 'after sign-out');
    },
  );

  test('a demo build registers the twins whatever the session', () async {
    DemoSession.isDemoOverride = true;

    UsersSdkDependencies.register(getIt);
    _expectDemoTwins(getIt);

    // A clear on an inactive session is a no-op; the build flag still wins.
    await DemoSession.instance.clear();
    _expectDemoTwins(getIt, reason: 'the build flag stays');
  });

  test('registering twice keeps the instances and one subscription', () async {
    UsersSdkDependencies.register(getIt);
    final user = getIt<UserRepositoryFacade>();
    final address = getIt<AddressRepositoryFacade>();

    UsersSdkDependencies.register(getIt);
    expect(identical(getIt<UserRepositoryFacade>(), user), isTrue);
    expect(identical(getIt<AddressRepositoryFacade>(), address), isTrue);

    // Whether one listener or two ran, exactly one set of twins must end
    // up registered (a stacked subscription would throw on the second
    // registerSingleton and surface here).
    await DemoSession.instance.activate();
    _expectDemoTwins(getIt);
    await DemoSession.instance.clear();
    _expectReal(getIt);
  });

  test('a flip with nothing registered never throws', () async {
    UsersSdkDependencies.register(getIt);
    // A container reset (hot restart, a host that tore its DI down) leaves
    // the subscription pointing at an empty container.
    await getIt.reset();
    expect(getIt.isRegistered<UserRepositoryFacade>(), isFalse);

    await DemoSession.instance.activate();
    _expectDemoTwins(getIt, reason: 'the listener registers afresh');

    await DemoSession.instance.clear();
    _expectReal(getIt);
  });

  test('the switch is the runtime one, not the compile-time constant', () {
    final source = File('lib/src/common/di/users_di.dart').readAsStringSync();
    expect(source, contains('DemoSession.demoActive'));
    expect(source, isNot(contains('AppConstants.isDemo')));
  });
}
