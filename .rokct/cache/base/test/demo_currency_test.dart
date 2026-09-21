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


// Every demo amount must print in rand. The wallet history in the guided
// tour read "42.50USD" / "1,500.00USD": nothing in a demo run selected a
// currency, so AppHelpers.numberFormat fell through to intl's locale default.
// The kernel now seeds ZAR at boot and falls back to it while the store is
// empty; a real session is untouched. "Demo" is DemoSession.demoActive: the
// tour build OR the runtime session, so a demo account signing in after
// boot is seeded on the flip, and a session ending wipes nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/constants/demo_currency.dart';
import 'package:base_sdk/src/models/data/currency_data.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/demo_session.dart';
import 'package:base_sdk/src/services/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  tearDown(() async {
    // The session and the listener are app-global; never let one test leak
    // into the next.
    DemoCurrency.stopFollowingDemoSession();
    await DemoSession.instance.clear();
  });

  test('the demo currency is South African rand, symbol before the amount',
      () {
    expect(DemoCurrency.rand.id, 'ZAR');
    expect(DemoCurrency.rand.symbol, 'R');
    expect(DemoCurrency.rand.position, 'before');
    expect(DemoCurrency.rand.rate, 1);
  });

  test('seed stores rand in a demo session with nothing selected', () async {
    await DemoSession.instance.activate();
    expect(LocalStorage.getSelectedCurrency(), isNull);

    DemoCurrency.seed();

    expect(LocalStorage.getSelectedCurrency()?.id, 'ZAR');
    expect(LocalStorage.getSelectedCurrency()?.symbol, 'R');
    expect(LocalStorage.getSelectedCurrency()?.position, 'before');
  });

  test('seed never overwrites a currency that is already selected', () async {
    await DemoSession.instance.activate();
    await LocalStorage.setSelectedCurrency(
      CurrencyData(id: 'EUR', symbol: '€', position: 'before', rate: 1),
    );

    DemoCurrency.seed();

    expect(LocalStorage.getSelectedCurrency()?.id, 'EUR');
  });

  test('seed is a no-op outside a demo session', () {
    expect(DemoSession.demoActive, isFalse);

    DemoCurrency.seed();

    expect(LocalStorage.getSelectedCurrency(), isNull);
    expect(DemoCurrency.fallback, isNull);
  });

  test('numberFormat prints the wallet ledger amounts in rand once seeded',
      () async {
    await DemoSession.instance.activate();
    DemoCurrency.seed();

    expect(AppHelpers.numberFormat(number: 1500), 'R1,500.00');
    expect(AppHelpers.numberFormat(number: 42.5), 'R42.50');
    expect(AppHelpers.numberFormat(number: 264), 'R264.00');
    expect(AppHelpers.numberFormat(number: 0), 'R0.00');
  });

  test('numberFormat prints rand in a demo session even with an empty store',
      () async {
    await DemoSession.instance.activate();
    expect(LocalStorage.getSelectedCurrency(), isNull);

    final rendered = AppHelpers.numberFormat(number: 1500);

    expect(rendered, 'R1,500.00');
    expect(rendered, isNot(contains('USD')));
  });

  test('an explicit order symbol still wins over the demo currency',
      () async {
    await DemoSession.instance.activate();
    DemoCurrency.seed();

    expect(
      AppHelpers.numberFormat(number: 10, symbol: r'$', isOrder: true),
      r'$10.00',
    );
  });

  test('a real session with nothing selected keeps intl\'s own default', () {
    expect(DemoSession.demoActive, isFalse);

    final rendered = AppHelpers.numberFormat(number: 1500);

    expect(rendered, isNot(startsWith('R')));
  });

  group('runtime demo session', () {
    test('fallback follows the session, the only switch there is', () async {
      expect(DemoCurrency.fallback, isNull);

      await DemoSession.instance.activate();
      expect(DemoCurrency.fallback?.id, 'ZAR');

      await DemoSession.instance.clear();
      expect(DemoCurrency.fallback, isNull);
    });

    test('followDemoSession seeds rand when the session flips on', () async {
      DemoCurrency.followDemoSession();
      // Session off outside a tour build: the boot-time seed is a no-op.
      expect(LocalStorage.getSelectedCurrency(), isNull);

      await DemoSession.instance.activate();

      expect(LocalStorage.getSelectedCurrency()?.id, 'ZAR');
      expect(AppHelpers.numberFormat(number: 1500), 'R1,500.00');
    });

    test('a session ending leaves the selected currency untouched',
        () async {
      DemoCurrency.followDemoSession();
      await DemoSession.instance.activate();
      expect(LocalStorage.getSelectedCurrency()?.id, 'ZAR');

      await DemoSession.instance.clear();

      // Never a delete: what was selected stays selected.
      expect(LocalStorage.getSelectedCurrency()?.id, 'ZAR');
    });

    test('a currency a real account selected survives a demo session',
        () async {
      DemoCurrency.followDemoSession();
      await LocalStorage.setSelectedCurrency(
        CurrencyData(id: 'EUR', symbol: '€', position: 'before', rate: 1),
      );

      await DemoSession.instance.activate();
      expect(LocalStorage.getSelectedCurrency()?.id, 'EUR');

      await DemoSession.instance.clear();
      expect(LocalStorage.getSelectedCurrency()?.id, 'EUR');
    });

    test('one listener per process however often the kernel registers',
        () async {
      DemoCurrency.followDemoSession();
      DemoCurrency.followDemoSession();
      DemoCurrency.followDemoSession();

      // removeListener drops ONE registration: if three had been added,
      // two would survive this and the flip below would still seed.
      DemoCurrency.stopFollowingDemoSession();
      await DemoSession.instance.activate();

      expect(LocalStorage.getSelectedCurrency(), isNull);
    });
  });
}
