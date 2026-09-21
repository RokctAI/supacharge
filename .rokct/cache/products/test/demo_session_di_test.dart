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
// again once it is cleared. `DemoSession.isDemoOverride = false` pins the
// compile-time half so the suite reads the same with or without
// --dart-define=IS_DEMO=true.

import 'dart:io';

import 'package:base_sdk/src/domain/interface/brands.dart';
import 'package:base_sdk/src/domain/interface/categories.dart';
import 'package:base_sdk/src/domain/interface/products.dart';
import 'package:base_sdk/src/services/demo_session.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:products_sdk/src/common/di/products_di.dart';
import 'package:products_sdk/src/common/domain/interface/seller_catalog.dart';
import 'package:products_sdk/src/common/domain/interface/seller_products.dart';
import 'package:products_sdk/src/common/infrastructure/repositories/brands_repository.dart';
import 'package:products_sdk/src/common/infrastructure/repositories/categories_repository.dart';
import 'package:products_sdk/src/common/infrastructure/repositories/mock_brands_repository.dart';
import 'package:products_sdk/src/common/infrastructure/repositories/mock_categories_repository.dart';
import 'package:products_sdk/src/common/infrastructure/repositories/mock_products_repository.dart';
import 'package:products_sdk/src/common/infrastructure/repositories/products_repository.dart';
import 'package:products_sdk/src/manager/infrastructure/repositories/demo_seller_catalog_repository.dart';
import 'package:products_sdk/src/manager/infrastructure/repositories/demo_seller_products_repository.dart';
import 'package:products_sdk/src/manager/infrastructure/repositories/seller_catalog_repository.dart';
import 'package:products_sdk/src/manager/infrastructure/repositories/seller_products_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A host's own facade: the hook must never swap it, whichever way the
/// switch flips.
class _HostProducts implements ProductsRepositoryFacade {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void _expectReal(GetIt getIt) {
  expect(getIt<ProductsRepositoryFacade>(), isA<ProductsRepository>());
  expect(getIt<CategoriesRepositoryFacade>(), isA<CategoriesRepository>());
  expect(getIt<BrandsRepositoryFacade>(), isA<BrandsRepository>());
  expect(
    getIt<SellerProductsRepositoryFacade>(),
    isA<SellerProductsRepository>(),
  );
  expect(
    getIt<SellerCatalogRepositoryFacade>(),
    isA<SellerCatalogRepository>(),
  );
}

void _expectDemo(GetIt getIt) {
  expect(getIt<ProductsRepositoryFacade>(), isA<MockProductsRepository>());
  expect(getIt<CategoriesRepositoryFacade>(), isA<MockCategoriesRepository>());
  expect(getIt<BrandsRepositoryFacade>(), isA<MockBrandsRepository>());
  expect(
    getIt<SellerProductsRepositoryFacade>(),
    isA<DemoSellerProductsRepository>(),
  );
  expect(
    getIt<SellerCatalogRepositoryFacade>(),
    isA<DemoSellerCatalogRepository>(),
  );
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
  });

  tearDown(() async {
    await DemoSession.instance.clear();
    DemoSession.isDemoOverride = null;
  });

  group('ProductsSdkDependencies', () {
    test('switch off and no session: the real repositories', () {
      final getIt = GetIt.asNewInstance();
      ProductsSdkDependencies.register(getIt);
      _expectReal(getIt);
    });

    test('activate swaps in the five demo twins; clear swaps the real ones '
        'back', () async {
      final getIt = GetIt.asNewInstance();
      ProductsSdkDependencies.register(getIt);

      await DemoSession.instance.activate();
      _expectDemo(getIt);

      await DemoSession.instance.clear();
      _expectReal(getIt);
    });

    test(
      'a registration made while the session is already demo is the twin',
      () async {
        await DemoSession.instance.activate();
        final getIt = GetIt.asNewInstance();
        ProductsSdkDependencies.register(getIt);
        _expectDemo(getIt);
      },
    );

    test('register is still idempotent, and a second call does not double '
        'the flip', () async {
      final getIt = GetIt.asNewInstance();
      ProductsSdkDependencies.register(getIt);
      final first = getIt<ProductsRepositoryFacade>();
      ProductsSdkDependencies.register(getIt);
      expect(identical(getIt<ProductsRepositoryFacade>(), first), isTrue);

      await DemoSession.instance.activate();
      _expectDemo(getIt);
      await DemoSession.instance.clear();
      _expectReal(getIt);
    });

    test("a host's own facade is never swapped by a flip", () async {
      final getIt = GetIt.asNewInstance();
      final host = _HostProducts();
      getIt.registerSingleton<ProductsRepositoryFacade>(host);
      ProductsSdkDependencies.register(getIt);
      expect(identical(getIt<ProductsRepositoryFacade>(), host), isTrue);

      await DemoSession.instance.activate();
      expect(identical(getIt<ProductsRepositoryFacade>(), host), isTrue);
      // The seams the hook did register still follow.
      expect(
        getIt<CategoriesRepositoryFacade>(),
        isA<MockCategoriesRepository>(),
      );

      await DemoSession.instance.clear();
      expect(identical(getIt<ProductsRepositoryFacade>(), host), isTrue);
      expect(getIt<CategoriesRepositoryFacade>(), isA<CategoriesRepository>());
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
