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

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:merchants_sdk/src/manager/di/manager_merchants_di.dart';
import 'package:merchants_sdk/src/manager/domain/interface/seller_shop.dart';
import 'package:merchants_sdk/src/manager/presentation/widgets/shop_setup_slide.dart';

/// Host-side wiring for merchants_sdk's manager registration seam (ADR-005,
/// the orders_sdk `orders_adapters.dart` / lms `LmsSchoolCaptureAdapter`
/// precedent).
///
/// merchants_sdk owns the shop-setup step widget ([ShopSetupSlide]) that its
/// manifest `registration_steps` entry injects into auth_sdk's post-register
/// pipeline, and declares [SellerShopSetupCapture] in its own terms; this
/// installed host-composition file supplies the adapter that lands the
/// capture on [SellerShopRepositoryFacade.createShop] (`shop.create_shop`).
/// This file lives in templates/ and installs into the app at compose time
/// (manager flavour only, see manifest.json app_type.manager), which is why
/// it may reach into merchants_sdk's manager `src/` slice.
class MerchantsShopSetupAdapter implements SellerShopSetupCapture {
  SellerShopRepositoryFacade get _repository {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<SellerShopRepositoryFacade>()) {
      ManagerMerchantsDependencies.register(getIt);
    }
    return getIt.get<SellerShopRepositoryFacade>();
  }

  @override
  Future<void> submitShop({
    required String name,
    String? phone,
    String? address,
  }) async {
    // Best-effort by contract (the capture interface's rule): a failed
    // create must never trap a freshly registered seller — the restaurant
    // tab handles the no-shop state, so the failure is logged, not thrown.
    final result = await _repository.createShop(
      name: name,
      phone: phone,
      address: address,
    );
    result.when(
      success: (_) {},
      failure: (failure, statusCode) => debugPrint(
          '==> shop setup create failed: $failure ($statusCode)'),
    );
  }
}
