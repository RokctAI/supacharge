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


// Fix-wave 2026-09-02 (G4, fixplan M20/M21): the manager product-authoring
// and catalog repositories now reach merchants' `seller_product.py` as
// `api.seller_product.*` gateway cmds, with payloads shaped to the server
// signatures (product_name + product_data, group_name + group_data,
// value_name + value_data, limit_start + limit_page_length). These cases pin
// that wire contract without opening a socket; only the REQUEST is asserted.
//
// `updateStocks` / `updateExtras` are deliberately NOT covered: they have no
// whitelisted server method and stay on the dead per-method path (flagged).

import 'dart:convert';
import 'dart:typed_data';

import 'package:base_sdk/src/handlers/http_service.dart';
import 'package:base_sdk/src/handlers/platform_gateway.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:products_sdk/src/manager/infrastructure/repositories/seller_catalog_repository.dart';
import 'package:products_sdk/src/manager/infrastructure/repositories/seller_products_repository.dart';
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

  group('SellerProductsRepository (M20)', () {
    test('product reads', () async {
      final repo = SellerProductsRepository();
      await repo.getProducts(page: 3, query: 'burger', needAddons: true);
      expect(http.last.path, kPlatformGatewayPath);
      expect(http.last.cmd, 'api.seller_product.get_seller_products');
      expect(http.last.payload, containsPair('limit_start', 40));
      expect(http.last.payload, containsPair('limit_page_length', 20));
      expect(http.last.payload, containsPair('search', 'burger'));
      expect(http.last.payload, containsPair('addon', 1));

      await repo.getProductDetails('PROD-1');
      expect(http.last.cmd, 'api.seller_product.get_product_details');
      expect(http.last.payload, containsPair('product_name', 'PROD-1'));
    });

    test('updateProduct names the product and wraps the body', () async {
      await SellerProductsRepository().updateProduct(
        uuid: 'PROD-1',
        product: {'title': 'Burger'},
      );
      expect(http.last.cmd, 'api.seller_product.update_seller_product');
      expect(http.last.payload, {
        'product_name': 'PROD-1',
        'product_data': {'title': 'Burger'},
      });
    });

    test('extras groups', () async {
      final repo = SellerProductsRepository();
      await repo.getExtrasGroups(page: 1);
      expect(http.last.cmd, 'api.seller_product.get_seller_extra_groups');
      expect(http.last.payload, containsPair('limit_start', 0));
      expect(http.last.payload, containsPair('valid', true));

      await repo.createExtrasGroup(group: {'title': 'Heat'});
      expect(http.last.cmd, 'api.seller_product.create_seller_extra_group');
      expect(http.last.payload, {
        'group_data': {'title': 'Heat'},
      });

      await repo.updateExtrasGroup(groupId: 'G-1', group: {'title': 'Spice'});
      expect(http.last.cmd, 'api.seller_product.update_seller_extra_group');
      expect(http.last.payload, {
        'group_name': 'G-1',
        'group_data': {'title': 'Spice'},
      });

      await repo.deleteExtrasGroup(groupId: 'G-1');
      expect(http.last.cmd, 'api.seller_product.delete_seller_extra_group');
      expect(http.last.payload, {'group_name': 'G-1'});
    });

    test('extras values, including one delete cmd per id', () async {
      final repo = SellerProductsRepository();
      await repo.getExtras(groupId: 'G-1');
      expect(http.last.cmd, 'api.seller_product.get_seller_extra_values');
      expect(http.last.payload, containsPair('group_name', 'G-1'));

      await repo.createExtrasItem(item: {'value': 'Mild'});
      expect(http.last.cmd, 'api.seller_product.create_seller_extra_value');
      expect(http.last.payload, {
        'value_data': {'value': 'Mild'},
      });

      await repo.updateExtrasItem(extrasId: 'V-1', item: {'value': 'Hot'});
      expect(http.last.cmd, 'api.seller_product.update_seller_extra_value');
      expect(http.last.payload, {
        'value_name': 'V-1',
        'value_data': {'value': 'Hot'},
      });

      http.calls.clear();
      await repo.deleteExtrasItem(ids: ['V-1', 'V-2']);
      expect(http.calls, hasLength(2));
      expect(
        http.calls.map((c) => c.cmd).toSet(),
        {'api.seller_product.delete_seller_extra_value'},
      );
      expect(
        http.calls.map((c) => c.payload!['value_name']).toList(),
        ['V-1', 'V-2'],
      );
    });
  });

  group('SellerCatalogRepository (M21)', () {
    test('units and categories', () async {
      final repo = SellerCatalogRepository();
      await repo.getUnits();
      expect(http.last.cmd, 'api.seller_product.get_seller_units');
      expect(http.last.payload, containsPair('limit_page_length', 100));

      await repo.getCategories(page: 2, query: 'dr');
      expect(http.last.cmd, 'api.seller_product.get_seller_categories');
      expect(http.last.payload, containsPair('limit_start', 20));
      expect(http.last.payload, containsPair('type', 'main'));
      expect(http.last.payload, containsPair('active', 1));
      expect(http.last.payload, containsPair('search', 'dr'));

      await repo.getCategoriesSub();
      expect(http.last.payload, containsPair('type', 'sub_shop'));
    });

    test('category create wraps category_data; delete names the uuid',
        () async {
      final repo = SellerCatalogRepository();
      await repo.createCategory(title: 'Drinks', input: '3');
      expect(http.last.cmd, 'api.seller_product.create_seller_category');
      final data = http.last.payload!['category_data'] as Map;
      expect(data['title'], isA<Map>());
      expect(data['input'], '3');
      expect(data['type'], 'main');
      expect(data['active'], 1);

      await repo.deleteCategory(id: 'CAT-1');
      expect(http.last.cmd, 'api.seller_product.delete_seller_category');
      expect(http.last.payload, {'uuid': 'CAT-1'});
    });
  });
}
