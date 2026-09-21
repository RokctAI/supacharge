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

// The IS_DEMO currency seed in ManagerMerchantsDependencies — RUN WITH
// `flutter test --dart-define=IS_DEMO=true`. Pins the fix for the POS
// till printing "0.00USD" (intl's locale fallback when LocalStorage holds
// no selected currency) instead of "R0.00" like every other seller fixture.

import 'package:base_sdk/src/constants/app_constants.dart';
import 'package:base_sdk/src/models/data/currency_data.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:merchants_sdk/src/manager/di/manager_merchants_di.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    LocalStorage.deleteSelectedCurrency();
  });

  test('IS_DEMO seeds the rand when no currency is selected, so money '
      'formats as R0.00 rather than 0.00USD', () async {
    expect(AppConstants.isDemo, isTrue,
        reason: 'run this suite with --dart-define=IS_DEMO=true');
    expect(LocalStorage.getSelectedCurrency(), isNull);

    ManagerMerchantsDependencies.register(GetIt.asNewInstance());

    final seeded = LocalStorage.getSelectedCurrency();
    expect(seeded, isNotNull);
    expect(seeded!.id, 'ZAR');
    expect(seeded.symbol, 'R');
    expect(seeded.position, 'before');
    expect(AppHelpers.numberFormat(number: 0), 'R0.00');
    expect(AppHelpers.numberFormat(number: 150), 'R150.00');
  });

  test('an already selected currency is never overwritten by the seed',
      () async {
    await LocalStorage.setSelectedCurrency(
      CurrencyData(id: 'USD', symbol: '\$', position: 'before', rate: 1),
    );

    ManagerMerchantsDependencies.register(GetIt.asNewInstance());

    expect(LocalStorage.getSelectedCurrency()?.id, 'USD');
    expect(AppHelpers.numberFormat(number: 0), '\$0.00');
  });
}
