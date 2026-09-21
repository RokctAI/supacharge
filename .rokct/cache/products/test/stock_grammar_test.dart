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
//
// The approved stock-state grammar (35a/35f: amber below 10, red at 0 —
// the thresholds are part of the approved design) and the 35a
// profitability strip's client-side arithmetic (margin = price − cost,
// "cost not set" when cost is missing/zero).

import 'package:flutter_test/flutter_test.dart';
import 'package:products_sdk/src/common/infrastructure/models/data/seller_product_data.dart';
import 'package:products_sdk/src/common/infrastructure/models/data/seller_stock.dart';
import 'package:products_sdk/src/manager/presentation/catalog/stock_grammar.dart';

SellerProductData product({List<int>? quantities, num? price, num? cost}) =>
    SellerProductData(
      id: 'prod-1',
      cost: cost,
      stocks: quantities == null
          ? null
          : [
              for (final q in quantities)
                SellerStock(id: 'stk-$q', price: price, quantity: q),
            ],
    );

void main() {
  group('StockGrammar thresholds (approved 35a: amber below 10, red at 0)',
      () {
    test('the low line is the named constant, 10 — the parked POS 32a line',
        () {
      expect(kLowStockThreshold, 10);
    });

    test('0 is OUT, 1..9 are LOW, 10 and up are healthy', () {
      expect(StockGrammar.levelFor(0), StockLevel.out);
      expect(StockGrammar.levelFor(-3), StockLevel.out);
      expect(StockGrammar.levelFor(1), StockLevel.low);
      expect(StockGrammar.levelFor(7), StockLevel.low);
      expect(StockGrammar.levelFor(9), StockLevel.low);
      // AT the threshold is healthy — the badge reads "below the line".
      expect(StockGrammar.levelFor(10), StockLevel.healthy);
      expect(StockGrammar.levelFor(42), StockLevel.healthy);
    });

    test('a product sums its stock rows', () {
      expect(StockGrammar.productQuantity(product(quantities: [7, 12, 0])), 19);
      expect(StockGrammar.productLevel(product(quantities: [7, 12, 0])),
          StockLevel.healthy);
      expect(StockGrammar.productLevel(product(quantities: [3, 4])),
          StockLevel.low);
      expect(StockGrammar.productLevel(product(quantities: [0, 0])),
          StockLevel.out);
    });

    test('no stocks at all is OUT — the shipped food_item rule', () {
      expect(StockGrammar.productLevel(product(quantities: null)),
          StockLevel.out);
      expect(StockGrammar.productLevel(product(quantities: [])),
          StockLevel.out);
      expect(StockGrammar.productQuantity(product(quantities: null)), 0);
    });
  });

  group('ProductMargin (approved 35a strip: client-side, price − cost)', () {
    test('the frame arithmetic: 78 price, 48 cost -> 30 margin, 38%', () {
      final margin = ProductMargin.of(price: 78, cost: 48)!;
      expect(margin.margin, 30);
      expect(margin.percent.round(), 38);
    });

    test('missing or zero cost is the honest "cost not set" (null)', () {
      expect(ProductMargin.of(price: 78, cost: null), isNull);
      expect(ProductMargin.of(price: 78, cost: 0), isNull);
      expect(ProductMargin.of(price: 78, cost: -5), isNull);
    });

    test('no usable price is also null (no fake 100% margins)', () {
      expect(ProductMargin.of(price: null, cost: 48), isNull);
      expect(ProductMargin.of(price: 0, cost: 48), isNull);
    });

    test('selling below cost is SHOWN, not hidden — negative margin', () {
      final margin = ProductMargin.of(price: 40, cost: 48)!;
      expect(margin.margin, -8);
      expect(margin.percent, lessThan(0));
    });

    test('ofProduct reads the first stock price + the cost field', () {
      final margin = ProductMargin.ofProduct(
        product(quantities: [7], price: 78, cost: 48),
      )!;
      expect(margin.margin, 30);
      // No stocks -> no price -> null.
      expect(ProductMargin.ofProduct(product(quantities: null, cost: 48)),
          isNull);
    });
  });
}
