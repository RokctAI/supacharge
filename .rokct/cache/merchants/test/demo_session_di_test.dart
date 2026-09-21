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

// The demo repositories follow base_sdk's RUNTIME demo switch
// (DemoSession, base_sdk >= 1.61.0): the real repositories with the switch
// off, the demo twins once a demo session is activated, the real ones
// again once it is cleared - including the host-owned PosOrdersFacade seam
// (displaced for the session, restored after) and the rand seed. The two
// installed template gates are pinned at source level (the analyzer
// excludes templates/). `DemoSession.isDemoOverride = false` pins the
// compile-time half so the suite reads the same with or without
// --dart-define=IS_DEMO=true.

import 'dart:io';

import 'package:base_sdk/src/domain/interface/shops.dart';
import 'package:base_sdk/src/models/data/currency_data.dart';
import 'package:base_sdk/src/services/demo_session.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:merchants_sdk/src/common/di/merchants_di.dart';
import 'package:merchants_sdk/src/common/infrastructure/repositories/mock_shops_repository.dart';
import 'package:merchants_sdk/src/common/infrastructure/repositories/shops_repository.dart';
import 'package:merchants_sdk/src/manager/di/manager_merchants_di.dart';
import 'package:merchants_sdk/src/manager/domain/interface/pos_catalog.dart';
import 'package:merchants_sdk/src/manager/domain/interface/pos_orders.dart';
import 'package:merchants_sdk/src/manager/domain/interface/quick_flow.dart';
import 'package:merchants_sdk/src/manager/domain/interface/seller_shop.dart';
import 'package:merchants_sdk/src/manager/infrastructure/repositories/demo_seller_shop_repository.dart';
import 'package:merchants_sdk/src/manager/infrastructure/repositories/mock_pos_orders_repository.dart';
import 'package:merchants_sdk/src/manager/infrastructure/repositories/mock_products_repository.dart';
import 'package:merchants_sdk/src/manager/infrastructure/repositories/mock_quick_flow_repository.dart';
import 'package:merchants_sdk/src/manager/infrastructure/repositories/pos_catalog_repository.dart';
import 'package:merchants_sdk/src/manager/infrastructure/repositories/quick_flow_repository.dart';
import 'package:merchants_sdk/src/manager/infrastructure/repositories/seller_shop_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A host's own shops facade: the hook must never swap it.
class _HostShops implements ShopsRepositoryFacade {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// The host's installed POS orders adapter, as the checkout would see it.
class _HostPosOrders implements PosOrdersFacade {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void _expectManagerReal(GetIt getIt) {
  expect(getIt<SellerShopRepositoryFacade>(), isA<SellerShopRepository>());
  expect(getIt<PosCatalogRepositoryFacade>(), isA<PosCatalogRepository>());
  expect(getIt<QuickFlowRepositoryFacade>(), isA<QuickFlowRepository>());
}

void _expectManagerDemo(GetIt getIt) {
  expect(getIt<SellerShopRepositoryFacade>(), isA<DemoSellerShopRepository>());
  expect(getIt<PosCatalogRepositoryFacade>(), isA<MockProductsRepository>());
  expect(getIt<QuickFlowRepositoryFacade>(), isA<MockQuickFlowRepository>());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  setUp(() async {
    DemoSession.isDemoOverride = false;
    await DemoSession.instance.clear();
    LocalStorage.deleteSelectedCurrency();
  });

  tearDown(() async {
    await DemoSession.instance.clear();
    DemoSession.isDemoOverride = null;
  });

  group('MerchantsSdkDependencies', () {
    test('switch off and no session: the real shops repository', () {
      final getIt = GetIt.asNewInstance();
      MerchantsSdkDependencies.register(getIt);
      expect(getIt<ShopsRepositoryFacade>(), isA<ShopsRepository>());
    });

    test(
      'activate swaps in the demo shop; clear swaps the real one back',
      () async {
        final getIt = GetIt.asNewInstance();
        MerchantsSdkDependencies.register(getIt);

        await DemoSession.instance.activate();
        expect(getIt<ShopsRepositoryFacade>(), isA<MockShopsRepository>());

        await DemoSession.instance.clear();
        expect(getIt<ShopsRepositoryFacade>(), isA<ShopsRepository>());
      },
    );

    test(
      'a registration made while the session is already demo is the twin',
      () async {
        await DemoSession.instance.activate();
        final getIt = GetIt.asNewInstance();
        MerchantsSdkDependencies.register(getIt);
        expect(getIt<ShopsRepositoryFacade>(), isA<MockShopsRepository>());
      },
    );

    test("register stays idempotent and a host's own facade is never "
        'swapped', () async {
      final getIt = GetIt.asNewInstance();
      final host = _HostShops();
      getIt.registerSingleton<ShopsRepositoryFacade>(host);
      MerchantsSdkDependencies.register(getIt);
      MerchantsSdkDependencies.register(getIt);
      expect(identical(getIt<ShopsRepositoryFacade>(), host), isTrue);
      await DemoSession.instance.activate();
      expect(identical(getIt<ShopsRepositoryFacade>(), host), isTrue);
    });
  });

  group('ManagerMerchantsDependencies', () {
    test('switch off and no session: the real repositories, no POS orders '
        'mock, no rand seed', () {
      final getIt = GetIt.asNewInstance();
      ManagerMerchantsDependencies.register(getIt);
      _expectManagerReal(getIt);
      expect(getIt.isRegistered<PosOrdersFacade>(), isFalse);
      expect(LocalStorage.getSelectedCurrency(), isNull);
    });

    test('activate swaps in the demo twins, the POS orders mock and the rand '
        'seed; clear swaps the real ones back and drops the mock', () async {
      final getIt = GetIt.asNewInstance();
      ManagerMerchantsDependencies.register(getIt);

      await DemoSession.instance.activate();
      _expectManagerDemo(getIt);
      expect(getIt<PosOrdersFacade>(), isA<MockPosOrdersRepository>());
      expect(LocalStorage.getSelectedCurrency()?.id, 'ZAR');

      await DemoSession.instance.clear();
      _expectManagerReal(getIt);
      expect(getIt.isRegistered<PosOrdersFacade>(), isFalse);
    });

    test(
      'a registration made while the session is already demo is the twin',
      () async {
        await DemoSession.instance.activate();
        final getIt = GetIt.asNewInstance();
        ManagerMerchantsDependencies.register(getIt);
        _expectManagerDemo(getIt);
        expect(getIt<PosOrdersFacade>(), isA<MockPosOrdersRepository>());
      },
    );

    test("a wired host's POS orders adapter is displaced for the session "
        'and put back after it', () async {
      final getIt = GetIt.asNewInstance();
      ManagerMerchantsDependencies.register(getIt);
      final host = _HostPosOrders();
      getIt.registerSingleton<PosOrdersFacade>(host);
      // A repeat boot call leaves the host's adapter alone, as before.
      ManagerMerchantsDependencies.register(getIt);
      expect(identical(getIt<PosOrdersFacade>(), host), isTrue);

      await DemoSession.instance.activate();
      expect(getIt<PosOrdersFacade>(), isA<MockPosOrdersRepository>());

      await DemoSession.instance.clear();
      expect(identical(getIt<PosOrdersFacade>(), host), isTrue);
    });

    test(
      'an already selected currency is never overwritten by the seed',
      () async {
        await LocalStorage.setSelectedCurrency(
          CurrencyData(id: 'USD', symbol: '\$', position: 'before', rate: 1),
        );
        final getIt = GetIt.asNewInstance();
        ManagerMerchantsDependencies.register(getIt);
        await DemoSession.instance.activate();
        expect(LocalStorage.getSelectedCurrency()?.id, 'USD');
      },
    );
  });

  group('installed template gates (templates/ is outside the analyzer)', () {
    test('the restaurant hub hides delete-account and the till keeps the '
        'camera unmounted on DemoSession.demoActive', () {
      final hub = File(
        'templates/pages/manager/restaurant/restaurant_page.dart',
      ).readAsStringSync();
      expect(hub, contains('if (!DemoSession.demoActive)'));
      expect(
        hub,
        contains("import 'package:base_sdk/src/services/demo_session.dart';"),
      );
      final till = File(
        'templates/pages/manager/billing/billing_page.dart',
      ).readAsStringSync();
      expect(till, contains('if (!DemoSession.demoActive) {'));
      expect(
        till,
        contains("import 'package:base_sdk/src/services/demo_session.dart';"),
      );
    });
  });

  group('source contract', () {
    test('no AppConstants.isDemo read remains in lib/ or templates/ - the '
        'demo seams ask DemoSession.demoActive', () {
      final hits = <String>[];
      for (final dir in const ['lib', 'templates']) {
        final root = Directory(dir);
        if (!root.existsSync()) continue;
        for (final file in root.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].contains('AppConstants.isDemo')) {
              hits.add('${file.path}:${i + 1}');
            }
          }
        }
      }
      expect(hits, isEmpty);
    });
  });
}
