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
// The approved 35e quick-adjust state machine: counts only — steppers
// clamped at zero, Low/Out triage judged on the LOADED quantity, the
// batch save riding the EXISTING updateStocks call per changed product
// with every non-quantity field passed through untouched.

import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:products_sdk/src/common/domain/interface/seller_products.dart';
import 'package:products_sdk/src/common/infrastructure/models/data/seller_product_data.dart';
import 'package:products_sdk/src/common/infrastructure/models/data/seller_extras.dart';
import 'package:products_sdk/src/common/infrastructure/models/data/seller_stock.dart';
import 'package:products_sdk/src/common/infrastructure/models/response/single_seller_product_response.dart';
import 'package:products_sdk/src/manager/application/catalog/quick_stock_notifier.dart';
import 'package:products_sdk/src/manager/application/catalog/quick_stock_state.dart';
import 'package:products_sdk/src/manager/presentation/catalog/stock_grammar.dart';

class _RecordedSave {
  final String uuid;
  final List<Map<String, dynamic>> stocks;
  final List<String> deletedStockIds;
  _RecordedSave(this.uuid, this.stocks, this.deletedStockIds);
}

class _FakeRepository extends Fake implements SellerProductsRepositoryFacade {
  final List<_RecordedSave> saves = [];
  bool failNext = false;

  @override
  Future<ApiResult<SingleSellerProductResponse>> updateStocks({
    required String uuid,
    required List<Map<String, dynamic>> stocks,
    List<String> deletedStockIds = const [],
    bool isAddon = false,
  }) async {
    if (failNext) {
      failNext = false;
      return const ApiResult.failure(error: 'boom', statusCode: 500);
    }
    saves.add(_RecordedSave(uuid, stocks, deletedStockIds));
    return ApiResult.success(data: SingleSellerProductResponse());
  }
}

SellerProductData product(
  String id, {
  required List<int> quantities,
  num price = 50,
}) =>
    SellerProductData(
      id: id,
      uuid: 'uuid-$id',
      stocks: [
        for (var i = 0; i < quantities.length; i++)
          SellerStock(
            id: 'stk-$id-$i',
            price: price,
            quantity: quantities[i],
            sku: 'SKU-$id-$i',
          ),
      ],
    );

void main() {
  late _FakeRepository repository;
  late QuickStockNotifier notifier;

  setUp(() {
    repository = _FakeRepository();
    notifier = QuickStockNotifier(repository);
  });

  test('seeds one stepper row per stock row; stockless products are skipped',
      () {
    notifier.seedFrom([
      product('a', quantities: [7]),
      product('b', quantities: [12, 0]),
      SellerProductData(id: 'c', uuid: 'uuid-c'), // no stocks — form's job
    ]);
    expect(notifier.state.rows.length, 3);
    expect(notifier.state.rows.map((r) => r.key),
        ['a#0', 'b#0', 'b#1']);
  });

  test('stepper state: +/- move the current count, clamped at zero, and '
      'dirty tracks the delta both ways', () {
    notifier.seedFrom([
      product('a', quantities: [7]),
    ]);
    notifier.increment('a#0');
    expect(notifier.state.rows.single.current, 8);
    expect(notifier.state.dirtyCount, 1);

    notifier.decrement('a#0');
    expect(notifier.state.rows.single.current, 7);
    // Back at the loaded count — no longer a change to save.
    expect(notifier.state.dirtyCount, 0);

    for (var i = 0; i < 10; i++) {
      notifier.decrement('a#0');
    }
    // A shelf never holds -1.
    expect(notifier.state.rows.single.current, 0);
    expect(notifier.state.rows.single.currentLevel, StockLevel.out);
  });

  test('triage chips: Low/Out filter + counts judged on the LOADED '
      'quantity, so a row stays in its triage list while being corrected',
      () {
    notifier.seedFrom([
      product('healthy', quantities: [42]),
      product('low', quantities: [7]),
      product('out', quantities: [0]),
    ]);
    expect(notifier.state.lowCount, 1);
    expect(notifier.state.outCount, 1);

    notifier.setFilter(QuickStockFilter.low);
    expect(notifier.state.visibleRows.single.key, 'low#0');

    // Correcting the low row above the line does NOT eject it mid-count.
    for (var i = 0; i < 10; i++) {
      notifier.increment('low#0');
    }
    expect(notifier.state.visibleRows.single.key, 'low#0');
    expect(notifier.state.lowCount, 1);

    notifier.setFilter(QuickStockFilter.out);
    expect(notifier.state.visibleRows.single.key, 'out#0');
    notifier.setFilter(QuickStockFilter.all);
    expect(notifier.state.visibleRows.length, 3);
  });

  test('saveAll: one updateStocks per CHANGED product — full rows resent '
      'with only quantities swapped, nothing deleted', () async {
    notifier.seedFrom([
      product('a', quantities: [7]),
      product('b', quantities: [12, 0]),
      product('untouched', quantities: [5]),
    ]);
    notifier.increment('a#0'); // 7 -> 8
    notifier.increment('b#1'); // 0 -> 1

    int? saved;
    await notifier.saveAll(updated: (count) => saved = count);

    expect(saved, 2);
    expect(repository.saves.length, 2);

    final aSave = repository.saves.firstWhere((s) => s.uuid == 'uuid-a');
    expect(aSave.stocks.single['quantity'], 8);
    expect(aSave.stocks.single['stock_id'], 'stk-a-0');
    expect(aSave.stocks.single['price'], 50); // untouched fields ride along
    expect(aSave.stocks.single['sku'], 'SKU-a-0');
    expect(aSave.deletedStockIds, isEmpty); // counts only — never deletes

    final bSave = repository.saves.firstWhere((s) => s.uuid == 'uuid-b');
    // The product's FULL stock list goes up, dirty or not.
    expect(bSave.stocks.length, 2);
    expect(bSave.stocks[0]['quantity'], 12);
    expect(bSave.stocks[1]['quantity'], 1);

    // The untouched product was never sent.
    expect(repository.saves.any((s) => s.uuid == 'uuid-untouched'), isFalse);
  });

  test('saveAll with nothing dirty is a no-op (no calls, updated(0))',
      () async {
    notifier.seedFrom([
      product('a', quantities: [7]),
    ]);
    int? saved;
    await notifier.saveAll(updated: (count) => saved = count);
    expect(saved, 0);
    expect(repository.saves, isEmpty);
  });

  test('a failed product save surfaces the error and fires failed()',
      () async {
    notifier.seedFrom([
      product('a', quantities: [7]),
    ]);
    notifier.increment('a#0');
    repository.failNext = true;

    bool failed = false;
    await notifier.saveAll(failed: () => failed = true);
    expect(failed, isTrue);
    expect(notifier.state.error, isNotNull);
    expect(notifier.state.isSaving, isFalse);
  });

  test('variant labels derive from the extras combination', () {
    final stock = SellerStock(
      id: 'stk-v',
      price: 98,
      quantity: 12,
      extras: [
        SellerExtras(id: 'ex-1', value: 'Large'),
        SellerExtras(id: 'ex-2', value: 'Chakalaka'),
      ],
    );
    final withVariants = SellerProductData(
      id: 'v',
      uuid: 'uuid-v',
      stocks: [stock],
    );
    notifier.seedFrom([withVariants]);
    expect(notifier.state.rows.single.variantLabel, 'LARGE · CHAKALAKA');

    notifier.seedFrom([
      product('plain', quantities: [3]),
    ]);
    expect(notifier.state.rows.single.variantLabel, isNull);
  });
}
