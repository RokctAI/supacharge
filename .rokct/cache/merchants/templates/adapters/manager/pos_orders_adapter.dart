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

import 'package:base_sdk/src/handlers/handlers.dart';
import 'package:base_sdk/src/handlers/platform_gateway.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:merchants_sdk/src/manager/domain/interface/pos_orders.dart';
import 'package:orders_sdk/src/manager/infrastructure/services/pos_sale_queue.dart';

/// Host-side wiring for merchants_sdk's POS checkout order seam
/// ([PosOrdersFacade]) — ADR-005, the orders_sdk `orders_adapters.dart` /
/// zones_sdk `zones_adapters.dart` precedent.
///
/// merchants_sdk owns the POS checkout screens but must not import
/// orders_sdk (the create-order pipeline, the local-first store, the
/// sync handler) from its lib/. This file is host-composition code: it
/// lives in templates/ and installs into the app at compose time
/// (manager flavour only), which is why it may reference any composed
/// SDK. The validator scans SDK lib/ only, so nothing here is a
/// cross-SDK import violation.
///
/// Register in the host's main(), OUTSIDE the @generated-sdk-di markers,
/// after ManagerMerchantsDependencies.register:
///
///   ManagerMerchantsDependencies.register(GetIt.instance);
///   GetIt.instance.registerLazySingleton<PosOrdersFacade>(
///       () => ManagerPosOrdersAdapter());
///
/// Without this registration the checkout renders no customer / credit
/// surface and a finished sale completes locally only (demo builds
/// register merchants_sdk's MockPosOrdersRepository instead).
class ManagerPosOrdersAdapter implements PosOrdersFacade {
  /// Mirrors the backend's `limit_page_length` default.
  static const int _pageSize = 20;

  @override
  Future<ApiResult<List<PosCustomer>>> searchCustomers({
    String? query,
    int page = 1,
  }) async {
    try {
      // merchants' shop-scoped seller_shop_settings.get_shop_users — the
      // SAME rows the manager create-order customer picker renders
      // (orders_sdk's ManagerPosCustomersAdapter calls it too; both stay
      // on the transitional direct endpoint until users_sdk grows a
      // seller-scoped facade, per that adapter's note).
      final response = await const PlatformGateway().tenant(
        'api.seller_shop_settings.get_shop_users',
        {
          if (query != null && query.isNotEmpty) 'search': query,
          'limit_start': (page - 1) * _pageSize,
          'limit_page_length': _pageSize,
        },
      );
      final rows = response is List
          ? response
          : ((response as Map)['data'] as List? ?? const []);
      return ApiResult.success(
        data: [
          for (final row in rows.whereType<Map>())
            PosCustomer(
              id: (row['id'] ?? row['user'] ?? '').toString(),
              firstname: row['firstname']?.toString(),
              lastname: row['lastname']?.toString(),
              phone: row['phone']?.toString(),
              img: row['img']?.toString(),
            ),
        ],
      );
    } catch (e) {
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
        statusCode: NetworkExceptions.getDioStatus(e),
      );
    }
  }

  @override
  Future<double?> customerCreditOutstanding(String customerId) async {
    if (customerId.isEmpty) return null;
    try {
      // The customer's open Credit orders (merchants'
      // seller_order.get_seller_orders, additive order_user +
      // payment_status filters). Outstanding per order is total_price
      // minus the till-collected pos_paid_amount (absent on unmigrated
      // sites -> 0), summed here — chip 306's "owes" figure.
      final response = await const PlatformGateway().tenant(
        'api.seller_order.get_seller_orders',
        {
          'order_user': customerId,
          'payment_status': 'Credit',
          'limit_page_length': 100,
        },
      );
      final rows = response is List
          ? response
          : ((response as Map)['data'] as List? ?? const []);
      var outstanding = 0.0;
      for (final row in rows.whereType<Map>()) {
        final total =
            double.tryParse(row['total_price']?.toString() ?? '') ?? 0;
        final paid =
            double.tryParse(row['pos_paid_amount']?.toString() ?? '') ?? 0;
        outstanding += (total - paid).clamp(0, double.infinity);
      }
      return outstanding;
    } catch (_) {
      // Unknown, not zero: the chip simply doesn't render.
      return null;
    }
  }

  @override
  Future<ApiResult<String>> submitSale(PosSaleDraft draft) async {
    try {
      // Offline-first by construction: local drift store first, then the
      // existing SyncEngine order.create queue — never a blocking
      // network call. The engine drains moments later when the backend
      // is reachable (backend @idempotent + offline_uuid dedupe).
      final localId = await PosSaleQueue.queueSale(
        offlineUuid: draft.orderId,
        lines: [
          for (final line in draft.lines)
            PosSaleLine(productId: line.productId, quantity: line.quantity),
        ],
        deliveryType: draft.deliveryType,
        status: draft.status,
        quotedTotal: draft.total,
        userId: draft.customerId,
        phone: draft.phone,
        address: draft.address,
        paidNow: draft.paidNow,
        onCredit: draft.onCredit,
      );
      return ApiResult.success(data: localId);
    } catch (e) {
      return ApiResult.failure(
        error: AppHelpers.errorHandler(e),
        statusCode: NetworkExceptions.getDioStatus(e),
      );
    }
  }

  @override
  Future<int> pendingSaleCount() => PosSaleQueue.pendingCount();
}
