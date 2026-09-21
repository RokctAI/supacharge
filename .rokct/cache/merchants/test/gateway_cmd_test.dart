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


// Fix-wave 2026-09-02 (G1 M1-M3, G4 M22/M24-M27): the customer shops
// repository and the manager shop / quick-flow / sections-tables
// repositories reach merchants' own frappe half as `api.shop.*`,
// `api.seller_shop.*`, `api.seller_shop_settings.*` and
// `api.seller_operations.*` gateway cmds (the create_seller_section /
// delete_seller_tables aliases were added to merchants/frappe/manifest.json
// in the same change). These cases pin the cmd names and payload keys
// without opening a socket; only the REQUEST is asserted.

import 'dart:convert';
import 'dart:typed_data';

import 'package:base_sdk/src/handlers/http_service.dart';
import 'package:base_sdk/src/handlers/platform_gateway.dart';
import 'package:base_sdk/src/models/data/address_old_data.dart';
import 'package:base_sdk/src/models/data/location.dart';
import 'package:base_sdk/src/models/data/shop_data.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:merchants_sdk/src/common/infrastructure/repositories/shops_repository.dart';
import 'package:merchants_sdk/src/manager/infrastructure/repositories/quick_flow_repository.dart';
import 'package:merchants_sdk/src/manager/infrastructure/repositories/seller_sections_tables_repository.dart';
import 'package:merchants_sdk/src/manager/infrastructure/repositories/seller_shop_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A recording stand-in for base_sdk's [HttpService]: every Dio the
/// repositories ask for answers through [_RecordingAdapter], which captures
/// the gateway envelope (`{cmd, payload}`), the request path and headers, and
/// answers a canned `{"message": ...}` body (unwrapped by the same
/// FrappeResponseInterceptor production uses). No socket is ever opened.
class FakeGatewayHttp extends HttpService {
  final List<RecordedCall> calls = [];
  dynamic reply = <String, dynamic>{};

  RecordedCall get last => calls.last;

  @override
  Dio client({bool requireAuth = false, bool routing = false}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
      ..httpClientAdapter = _RecordingAdapter(this, requireAuth)
      ..interceptors.add(const FrappeResponseInterceptor());
    return dio;
  }
}

class RecordedCall {
  final String path;
  final bool requireAuth;
  final Map<String, dynamic> body;
  final Map<String, dynamic> headers;

  RecordedCall(this.path, this.requireAuth, this.body, this.headers);

  String? get cmd => body['cmd'] as String?;
  Map<String, dynamic>? get payload =>
      (body['payload'] as Map?)?.cast<String, dynamic>();
}

class _RecordingAdapter implements HttpClientAdapter {
  final FakeGatewayHttp owner;
  final bool requireAuth;

  _RecordingAdapter(this.owner, this.requireAuth);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final dynamic data = options.data;
    owner.calls.add(RecordedCall(
      options.path,
      requireAuth,
      data is Map ? data.cast<String, dynamic>() : <String, dynamic>{},
      Map<String, dynamic>.from(options.headers),
    ));
    return ResponseBody.fromString(
      jsonEncode({'message': owner.reply}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeGatewayHttp http;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  setUp(() {
    http = FakeGatewayHttp();
    if (GetIt.I.isRegistered<HttpService>()) {
      GetIt.I.unregister<HttpService>();
    }
    GetIt.I.registerSingleton<HttpService>(http);
  });

  group('ShopsRepository (customer)', () {
    test('recommend payload prefers the selected address (M1)', () {
      final payload = ShopsRepository.recommendPayload(
        selected: AddressData(
          location: LocationModel(latitude: -26.2, longitude: 28.04),
        ),
        fallbackLatitude: 1.0,
        fallbackLongitude: 2.0,
      );
      expect(payload, {'latitude': -26.2, 'longitude': 28.04});
    });

    test('recommend payload falls back to the initial location (M1)', () {
      expect(
        ShopsRepository.recommendPayload(
          selected: null,
          fallbackLatitude: 1.0,
          fallbackLongitude: 2.0,
        ),
        {'latitude': 1.0, 'longitude': 2.0},
      );
      expect(ShopsRepository.recommendPayload(), isEmpty);
    });

    test('getShopsRecommend never sends page (M1)', () async {
      await ShopsRepository().getShopsRecommend(4);
      expect(http.last.cmd, 'api.shop.get_shops_recommend');
      expect(http.last.payload ?? const {}, isNot(contains('page')));
      expect(http.last.requireAuth, isFalse);
    });

    test('joinOrder drops shop_id; getTags drops category_id (M2/M3)',
        () async {
      final repo = ShopsRepository();
      await repo.joinOrder(shopId: 'S-1', name: 'Ann', cartId: 'C-1');
      expect(http.last.cmd, 'api.cart.join_order');
      expect(http.last.payload, {'cart_id': 'C-1', 'user_name': 'Ann'});

      await repo.getTags('CAT-1');
      expect(http.last.cmd, 'api.tag.get_tags');
      expect(http.last.payload, isNull);
    });

    test('single shop and pickup shops use api.shop cmds (M22/M24)',
        () async {
      final repo = ShopsRepository();
      await repo.getSingleShop(uuid: 'UUID-1');
      expect(http.last.path, kPlatformGatewayPath);
      expect(http.last.cmd, 'api.shop.get_shop_details');
      expect(http.last.payload, {'uuid': 'UUID-1'});
      expect(http.last.requireAuth, isFalse);

      await repo.getPickupShops();
      expect(http.last.cmd, 'api.shop.get_shops');
      expect(http.last.payload, {'takeaway': 1});
    });
  });

  group('SellerShopRepository (M25)', () {
    test('read / update / working status / working days', () async {
      final repo = SellerShopRepository();
      await repo.getMyShop();
      expect(http.last.cmd, 'api.seller_shop.get_shop');

      await repo.updateShop(phone: '+27821234567', tax: '15');
      expect(http.last.cmd, 'api.seller_shop.update_shop');
      expect(http.last.payload, {
        'shop_data': {'phone': '27821234567', 'tax': '15'},
      });

      await repo.setWorkingStatus(open: true);
      expect(http.last.cmd, 'api.seller_shop.set_working_status');
      expect(http.last.payload, {'status': true});

      await repo.getShopWorkingDays();
      expect(
        http.last.cmd,
        'api.seller_shop_settings.get_seller_shop_working_days',
      );

      await repo.updateShopWorkingDays(workingDays: [
        ShopWorkingDay(day: 'monday', from: '09:00', to: '17:00'),
      ]);
      expect(
        http.last.cmd,
        'api.seller_shop_settings.update_seller_shop_working_days',
      );
      final days = http.last.payload!['working_days_data'] as List;
      expect(days.single, {
        'day_of_week': 'monday',
        'opening_time': '09:00',
        'closing_time': '17:00',
        'is_closed': 0,
      });
    });
  });

  group('QuickFlowRepository (M26)', () {
    test('read and partial update', () async {
      final repo = QuickFlowRepository();
      await repo.getQuickFlowSettings();
      expect(http.last.cmd, 'api.seller_shop.get_quick_flow_settings');

      await repo.updateQuickFlowSettings(keypadAutodial: true);
      expect(http.last.cmd, 'api.seller_shop.update_quick_flow_settings');
      expect(http.last.payload, {
        'settings': {'keypad_autodial': true},
      });
    });
  });

  group('SellerSectionsTablesRepository (M27)', () {
    test('lists page with limit_start; create/delete use the new aliases',
        () async {
      final repo = SellerSectionsTablesRepository();
      await repo.getSections(page: 2);
      expect(http.last.cmd, 'api.seller_operations.get_seller_sections');
      expect(http.last.payload, containsPair('limit_start', 14));
      expect(http.last.payload, containsPair('limit_page_length', 14));

      await repo.getTables(page: 1, shopSectionId: 7);
      expect(http.last.cmd, 'api.seller_operations.get_seller_tables');
      expect(http.last.payload, containsPair('limit_start', 0));

      await repo.createSection(name: 'Patio', area: 40);
      expect(http.last.cmd, 'api.seller_operations.create_seller_section');
      expect(http.last.payload, {
        'section_data': {'title': 'Patio', 'area': 40},
      });

      await repo.deleteTable(tableId: 'T-1');
      expect(http.last.cmd, 'api.seller_operations.delete_seller_tables');
      expect(http.last.payload, {'table_id': 'T-1'});
    });
  });
}
