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

// The demo switch. A real account the production backend marks as demo
// signs in through the real backend; the login flow then calls activate()
// and the app serves that session from the in-app fixtures.
// Session-scoped: persisted so a relaunch keeps it, cleared by clear()
// and by every sign-out (LocalStorage.logout). The guided-tour build keeps
// its fixtures through AppConstants.isTour; demoActive is the OR of the
// two, and the only demo switch the fleet has.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/constants/app_constants.dart';
import 'package:base_sdk/src/services/demo_session.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:base_sdk/src/services/secure_storage.dart';
import 'package:base_sdk/src/services/storage_keys.dart';

/// In-memory SecureStore so logout() never reaches a platform channel.
class _MemorySecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SecureStorage.store = _MemorySecureStore();
  });

  tearDown(() async {
    // The session is app-global; never let one test leak into the next.
    await DemoSession.instance.clear();
  });

  group('DemoSession', () {
    test('is off by default, outside a tour build', () {
      expect(DemoSession.instance.active, isFalse);
      expect(DemoSession.demoActive, isFalse);
    });

    test('activate turns the session on and clear turns it off', () async {
      await DemoSession.instance.activate();
      expect(DemoSession.instance.active, isTrue);
      expect(DemoSession.demoActive, isTrue);

      await DemoSession.instance.clear();
      expect(DemoSession.instance.active, isFalse);
      expect(DemoSession.demoActive, isFalse);
    });

    test('persists under demo_session_active so a relaunch keeps it',
        () async {
      await DemoSession.instance.activate();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(StorageKeys.keyDemoSessionActive), isTrue);
      expect(StorageKeys.keyDemoSessionActive, 'demo_session_active');

      // A relaunch: a fresh LocalStorage over the same stored values.
      SharedPreferences.setMockInitialValues({
        StorageKeys.keyDemoSessionActive: true,
      });
      await LocalStorage.init();
      expect(DemoSession.instance.active, isTrue);
      expect(DemoSession.demoActive, isTrue);

      await DemoSession.instance.clear();
      expect(
        (await SharedPreferences.getInstance())
            .getBool(StorageKeys.keyDemoSessionActive),
        isNull,
      );
    });

    test('notifies listeners once per flip, never on a no-op', () async {
      var notifications = 0;
      void listener() => notifications++;
      DemoSession.instance.addListener(listener);
      addTearDown(() => DemoSession.instance.removeListener(listener));

      await DemoSession.instance.clear(); // already off: silent
      expect(notifications, 0);

      await DemoSession.instance.activate();
      expect(notifications, 1);
      await DemoSession.instance.activate(); // already on: silent
      expect(notifications, 1);

      await DemoSession.instance.clear();
      expect(notifications, 2);
    });

    test('sign-out clears it: LocalStorage.logout ends the demo session',
        () async {
      await DemoSession.instance.activate();
      expect(DemoSession.instance.active, isTrue);

      LocalStorage.logout();

      expect(DemoSession.instance.active, isFalse);
      expect(DemoSession.demoActive, isFalse);
    });

    test('outside a tour build demoActive is the session and nothing else',
        () async {
      // The tour build is the only other source, and it is a compile-time
      // constant no test run sets (no --dart-define=TOUR_MODE here), so
      // here the OR reduces to the session exactly.
      expect(AppConstants.isTour, isFalse);
      expect(DemoSession.demoActive, DemoSession.instance.active);

      await DemoSession.instance.activate();
      expect(DemoSession.demoActive, isTrue);
      expect(DemoSession.demoActive, DemoSession.instance.active);

      await DemoSession.instance.clear();
      expect(DemoSession.demoActive, isFalse);
      expect(DemoSession.demoActive, DemoSession.instance.active);
    });

    test('reads false, not a cached stale value, before storage is ready',
        () async {
      // Nothing is cached in memory: the answer always comes from the
      // store, so a read that lands early can never pin a stale false.
      await DemoSession.instance.activate();
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      expect(DemoSession.instance.active, isFalse);
    });
  });
}
