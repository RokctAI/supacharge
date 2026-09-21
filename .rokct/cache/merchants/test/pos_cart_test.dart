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


// The POS cart (posCartProvider's notifier) — RUN WITH
// `flutter test --dart-define=IS_DEMO=true`: the demo gate in
// ManagerMerchantsDependencies routes the product lookup to this SDK's
// MockProductsRepository, the exact path a headless tour takes.
//
// Pins the held build's found-bug fixes: money cents-rounded at the state
// boundary (never exponential), the 2s scan dedupe, a derived (never
// stale) total, and the stable per-order id.

import 'package:base_sdk/src/constants/app_constants.dart';
import 'package:base_sdk/src/models/data/currency_data.dart';
import 'package:base_sdk/src/models/data/product_data.dart';
import 'package:base_sdk/src/models/data/translation.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:merchants_sdk/src/manager/application/pos_cart/pos_cart_notifier.dart';
import 'package:merchants_sdk/src/manager/di/manager_merchants_di.dart';
import 'package:merchants_sdk/src/manager/domain/interface/pos_catalog.dart';
import 'package:merchants_sdk/src/manager/infrastructure/repositories/mock_products_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProductData _product({
  required String id,
  required String title,
  required num price,
}) =>
    ProductData(
      id: id,
      shopId: '1',
      active: true,
      translation: Translation(title: title, locale: 'en'),
      stocks: [Stocks(id: 's$id', price: price, quantity: 100)],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await LocalStorage.setSelectedCurrency(
      CurrencyData(id: 'ZAR', symbol: 'R', position: 'before', rate: 1),
    );
    ManagerMerchantsDependencies.register(GetIt.instance);
  });

  PosCartNotifier notifier() =>
      PosCartNotifier(GetIt.instance<PosCatalogRepositoryFacade>());

  test('IS_DEMO routes the barcode lane to MockProductsRepository: '
      'a scan lands Flame-grilled beef burger at R150.00 × 1', () async {
    expect(AppConstants.isDemo, isTrue,
        reason: 'run this suite with --dart-define=IS_DEMO=true');
    expect(GetIt.instance<PosCatalogRepositoryFacade>(),
        isA<MockProductsRepository>(),
        reason: 'the DI demo gate must serve the mock catalog');

    final cart = notifier();
    final added = await cart.addByBarcode('6001067890123');

    expect(added, isTrue);
    expect(cart.state.lines, hasLength(1));
    final line = cart.state.lines.single;
    expect(line.title, 'Flame-grilled beef burger');
    expect(line.unitPrice, 150);
    expect(line.quantity, 1);
    expect(AppHelpers.numberFormat(number: line.lineTotal), 'R150.00');
  });

  test('money is cents-rounded at the state boundary: '
      '18.99×3 + 150×0.75 is exactly 169.47, rendered R169.47 — '
      'never exponential', () async {
    final cart = notifier();
    final bread = _product(id: 'p1', title: 'Bread', price: 18.99);
    cart.addProduct(bread);
    cart.addProduct(bread);
    cart.addProduct(bread); // qty 3
    cart.addProduct(_product(id: 'p2', title: 'Loose Tomatoes (kg)', price: 150));
    cart.setQuantity(1, 0.75);

    // The raw float sum is 169.47000000000003; the state boundary rounds.
    expect(cart.state.total, 169.47);
    expect(cart.state.itemCount, 3.75);

    final rendered = AppHelpers.numberFormat(number: cart.state.total);
    expect(rendered, 'R169.47');
    // The Spazafy exponential bug (numberFormat's 16-char guard falling
    // into toStringAsExponential — on-screen "R1.0473000000e+2") must be
    // unreachable.
    expect(rendered, isNot(contains('e')));
    expect(cart.state.total.toString(), isNot(contains('e')));
  });

  test('a barcode re-fired inside the 2s window is one physical scan — '
      'never re-added per camera frame', () async {
    final cart = notifier();
    final first = await cart.addByBarcode('600999');
    final replay = await cart.addByBarcode('600999'); // same frame-stream
    final other = await cart.addByBarcode('600111'); // different code

    expect(first, isTrue);
    expect(replay, isFalse);
    expect(other, isTrue);
    // Demo catalog answers every code with the same burger, so the
    // accepted second scan STEPS the one line instead of duplicating it.
    expect(cart.state.lines, hasLength(1));
    expect(cart.state.lines.single.quantity, 2);
  });

  test('the order id is minted once per order and Clear All resets '
      'everything — the total can never go stale', () async {
    final cart = notifier();
    expect(cart.state.orderId, isEmpty);

    await cart.addByBarcode('600123');
    final orderId = cart.state.orderId;
    expect(orderId, startsWith('POS-'));

    // Mutations do NOT re-mint the id (held-build finding: a re-keyed id
    // mid-checkout re-keys the pay-link QR and the offline code).
    cart.increment(0);
    cart.setQuantity(0, 2.5);
    expect(cart.state.orderId, orderId);

    // Clear All: lines gone AND the derived total reads zero immediately
    // (the Spazafy source cached the sum and cleared only the list).
    cart.clearAll();
    expect(cart.state.lines, isEmpty);
    expect(cart.state.total, 0);
    expect(cart.state.itemCount, 0);
    expect(cart.state.orderId, isEmpty);

    // The next order gets a FRESH id; finishing a sale resets the same way.
    await cart.addByBarcode('600124');
    final secondId = cart.state.orderId;
    expect(secondId, isNotEmpty);
    expect(secondId, isNot(orderId));
    final receipt = cart.finishSale();
    expect(receipt.orderId, secondId);
    expect(receipt.total, 150);
    expect(cart.state.lines, isEmpty);
    expect(cart.state.total, 0);
    expect(cart.state.orderId, isEmpty);
  });
}
