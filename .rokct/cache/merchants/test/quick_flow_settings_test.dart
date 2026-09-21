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

// QUICK FLOW settings — the SDK slice behind the section-42 surface
// (approved design strip section 42): the settings model's reads, and the
// notifier's write-through-and-revert discipline.
//
// The surface has no Save button on purpose (two of its three switches
// change what the till does the moment they move), so "the switch never
// sits on a state the shop does not hold" is the property that matters
// most here and it gets its own cases.

import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/models/data/product_data.dart';
import 'package:base_sdk/src/models/data/translation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchants_sdk/src/manager/application/quick_flow/quick_flow_notifier.dart';
import 'package:merchants_sdk/src/manager/domain/interface/quick_flow.dart';
import 'package:merchants_sdk/src/manager/infrastructure/repositories/mock_quick_flow_repository.dart';

ProductData _product(String id, String title, num price) => ProductData(
      id: id,
      translation: Translation(title: title, locale: 'en'),
      stocks: [Stocks(id: id, price: price)],
    );

/// A repository that refuses every write — the revert case.
class _RefusingRepository implements QuickFlowRepositoryFacade {
  _RefusingRepository(this._settings);

  final QuickFlowSettings _settings;
  int writes = 0;

  @override
  Future<ApiResult<QuickFlowSettings>> getQuickFlowSettings() async =>
      ApiResult.success(data: _settings);

  @override
  Future<ApiResult<QuickFlowSettings>> updateQuickFlowSettings({
    bool? autoAcceptOrders,
    bool? autoCompleteAtReady,
    bool? keypadAutodial,
    List<QuickFlowPreset>? presets,
  }) async {
    writes++;
    return const ApiResult.failure(error: 'nope', statusCode: 500);
  }
}

/// Records exactly which keys a write carried.
class _RecordingRepository implements QuickFlowRepositoryFacade {
  QuickFlowSettings settings = const QuickFlowSettings();
  final List<Map<String, Object?>> calls = [];

  @override
  Future<ApiResult<QuickFlowSettings>> getQuickFlowSettings() async =>
      ApiResult.success(data: settings);

  @override
  Future<ApiResult<QuickFlowSettings>> updateQuickFlowSettings({
    bool? autoAcceptOrders,
    bool? autoCompleteAtReady,
    bool? keypadAutodial,
    List<QuickFlowPreset>? presets,
  }) async {
    calls.add({
      'autoAcceptOrders': autoAcceptOrders,
      'autoCompleteAtReady': autoCompleteAtReady,
      'keypadAutodial': keypadAutodial,
      'presets': presets?.map((p) => p.digit).toList(),
    });
    settings = settings.copyWith(
      autoAcceptOrders: autoAcceptOrders,
      autoCompleteAtReady: autoCompleteAtReady,
      keypadAutodial: keypadAutodial,
      presets: presets,
    );
    return ApiResult.success(data: settings);
  }
}

void main() {
  group('QuickFlowSettings', () {
    test('parses the server payload, presets sorted by digit', () {
      final settings = QuickFlowSettings.fromJson({
        'shop_name': 'Blue Tap Water Refill',
        'auto_accept_orders': 1,
        'platform_auto_approve': true,
        'auto_complete_at_ready': 0,
        'keypad_autodial': '1',
        'digit_presets': [
          {
            'digit': '3',
            'product': {
              'id': '3',
              'translation': {'title': '20 L refill'},
              'stocks': [
                {'id': 's3', 'price': 35},
              ],
            },
          },
          {
            'digit': '1',
            'product': {
              'id': '1',
              'translation': {'title': '5 L refill'},
              'stocks': [
                {'id': 's1', 'price': 12},
              ],
            },
          },
        ],
      });
      expect(settings.shopName, 'Blue Tap Water Refill');
      expect(settings.autoAcceptOrders, isTrue);
      expect(settings.platformAutoApprove, isTrue);
      expect(settings.autoCompleteAtReady, isFalse);
      expect(settings.keypadAutodial, isTrue);
      expect(settings.presets.map((p) => p.digit), [1, 3]);
      expect(settings.presetFor(3)!.title, '20 L refill');
      expect(settings.presetFor(3)!.price, 35);
      expect(settings.presetCount, 2);
    });

    test('drops preset rows it cannot read rather than guessing', () {
      final settings = QuickFlowSettings.fromJson({
        'digit_presets': [
          {'digit': '0', 'product': <String, dynamic>{}},
          {'digit': '10', 'product': <String, dynamic>{}},
          {'digit': '4', 'product': null},
          'nonsense',
        ],
      });
      expect(settings.presets, isEmpty);
    });

    test('an unset digit is inert, not an error', () {
      expect(MockQuickFlowRepository.seed.presetFor(9), isNull);
      expect(MockQuickFlowRepository.seed.presetFor(3), isNotNull);
    });

    test('autodial needs BOTH the switch and at least one preset', () {
      const off = QuickFlowSettings(keypadAutodial: false);
      expect(off.autodialArmed, isFalse);
      final onButEmpty = const QuickFlowSettings(keypadAutodial: true);
      expect(onButEmpty.autodialArmed, isFalse);
      final armed = QuickFlowSettings(
        keypadAutodial: true,
        presets: [
          QuickFlowPreset(digit: 1, product: _product('1', 'Refill', 12)),
        ],
      );
      expect(armed.autodialArmed, isTrue);
      expect(armed.copyWith(keypadAutodial: false).autodialArmed, isFalse);
    });

    test('a preset serializes back as digit + product id', () {
      final preset =
          QuickFlowPreset(digit: 7, product: _product('42', 'Ice', 28));
      expect(preset.toJson(), {'digit': '7', 'product': '42'});
    });
  });

  group('QuickFlowNotifier', () {
    test('load fills the surface and marks it read', () async {
      final notifier = QuickFlowNotifier(MockQuickFlowRepository());
      expect(notifier.state.loaded, isFalse);
      await notifier.load();
      expect(notifier.state.loaded, isTrue);
      expect(notifier.state.settings.shopName, 'Blue Tap Water Refill');
      expect(notifier.state.settings.presetCount, 5);
      notifier.dispose();
    });

    test('each switch writes ONLY its own key', () async {
      final repository = _RecordingRepository();
      final notifier = QuickFlowNotifier(repository);
      await notifier.setAutoCompleteAtReady(true);
      expect(repository.calls.single['autoCompleteAtReady'], isTrue);
      expect(repository.calls.single['autoAcceptOrders'], isNull);
      expect(repository.calls.single['keypadAutodial'], isNull);
      expect(repository.calls.single['presets'], isNull);
      notifier.dispose();
    });

    test('a refused write REVERTS the switch', () async {
      final repository = _RefusingRepository(
        const QuickFlowSettings(autoCompleteAtReady: false),
      );
      final notifier = QuickFlowNotifier(repository);
      await notifier.load();
      expect(notifier.state.settings.autoCompleteAtReady, isFalse);
      await notifier.setAutoCompleteAtReady(true);
      expect(repository.writes, 1);
      // The shop never took it, so the row must not claim it did.
      expect(notifier.state.settings.autoCompleteAtReady, isFalse);
      expect(notifier.state.error, 'nope');
      notifier.dispose();
    });

    test('setting a preset replaces that digit and keeps the map sorted',
        () async {
      final notifier = QuickFlowNotifier(MockQuickFlowRepository());
      await notifier.load();
      await notifier.setPreset(
        QuickFlowPreset(digit: 3, product: _product('99', 'Ice block', 30)),
      );
      expect(notifier.state.settings.presetFor(3)!.title, 'Ice block');
      expect(notifier.state.settings.presetCount, 5);
      await notifier.setPreset(
        QuickFlowPreset(digit: 8, product: _product('8', 'Bottle cap', 2)),
      );
      expect(
        notifier.state.settings.presets.map((p) => p.digit),
        [1, 2, 3, 4, 5, 8],
      );
      notifier.dispose();
    });

    test('clearing a preset returns the key to inert', () async {
      final notifier = QuickFlowNotifier(MockQuickFlowRepository());
      await notifier.load();
      await notifier.clearPreset(3);
      expect(notifier.state.settings.presetFor(3), isNull);
      expect(notifier.state.settings.presetCount, 4);
      notifier.dispose();
    });
  });
}
