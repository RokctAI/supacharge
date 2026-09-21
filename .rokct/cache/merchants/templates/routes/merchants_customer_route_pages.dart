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


// Host composition file (ADR-005): thin @RoutePage shells for merchants_sdk's
// CUSTOMER-facing shop pages. auto_route's codegen only generates route
// classes for @RoutePage widgets that live in the HOST's own lib/, so the
// manifest's app_type.customer "routes" point at THIS file (installed to
// lib/presentation/routes/) - the same pattern as marketplace_sdk's
// marketplace_route_pages.dart and auth_sdk's auth_route_pages.dart.
//
// Route names and paths are the pre-fork paas_customer ones (fix-wave
// 2026-09-02 route map, rows 10 and 28) so deep links (`/shop?shopId=`)
// and base_sdk's AppRoutes seam (`pushShopRoute` / `replaceShopRoute` /
// `pushShopDetailRoute`, filled by this SDK's manifest "app_routes") keep
// working. Declared under app_type.customer only: the driver and manager
// flavours have their own shop surfaces and no `/shop` path.

import 'package:auto_route/auto_route.dart';
// Re-exported (not just imported): the generated app_router.gr.dart shares
// app_router.dart's library scope, and the ShopRoute / ShopDetailRoute args
// classes reference ShopData by type - it needs to be visible there, not
// just inside this file (auth_route_pages.dart's UserModel precedent).
export 'package:base_sdk/src/models/data/shop_data.dart';

import 'package:base_sdk/src/models/data/shop_data.dart';
import 'package:flutter/material.dart';

import 'package:merchants_sdk/src/common/presentation/pages/shop/shop_detail.dart';
import 'package:merchants_sdk/src/common/presentation/pages/shop/shop_page.dart';

/// `/shop` - a shop's storefront. `shopId` / `productId` / `cartId` also
/// ride as query parameters so the pre-fork `/shop?shopId=<id>` deep links
/// and push payloads still resolve without a typed push.
@RoutePage(name: 'ShopRoute')
class ShopRouteView extends StatelessWidget {
  final String shopId;
  final String? productId;
  final String? cartId;
  final String? ownerId;
  final ShopData? shop;

  const ShopRouteView({
    super.key,
    @QueryParam('shopId') this.shopId = '',
    @QueryParam('productId') this.productId,
    @QueryParam('cartId') this.cartId,
    this.ownerId,
    this.shop,
  });

  @override
  Widget build(BuildContext context) => ShopPage(
        shopId: shopId,
        productId: productId,
        cartId: cartId,
        ownerId: ownerId,
        shop: shop,
      );
}

/// `/shops_detail` - the shop's about sheet (address, hours, contacts).
@RoutePage(name: 'ShopDetailRoute')
class ShopDetailRouteView extends StatelessWidget {
  final ShopData shop;
  final String workTime;

  const ShopDetailRouteView({
    super.key,
    required this.shop,
    this.workTime = '',
  });

  @override
  Widget build(BuildContext context) =>
      ShopDetailPage(shop: shop, workTime: workTime);
}
