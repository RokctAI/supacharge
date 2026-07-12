import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:base_sdk/src/models/data/filter_model.dart';

import 'package:base_sdk/src/handlers/handlers.dart';
import 'package:base_sdk/src/models/models.dart';

abstract class ShopsRepositoryFacade {
  Future<ApiResult<ShopsPaginateResponse>> getShopFilter({
    String? categoryId,
    required int page,
    String? subCategoryId,
  });

  Future<ApiResult<ShopsPaginateResponse>> getPickupShops();

  Future<ApiResult<ShopsPaginateResponse>> searchShops({
    required String text,
    String? categoryId,
  });

  Future<ApiResult<ShopsPaginateResponse>> getNearbyShops(
    double latitude,
    double longitude,
  );

  Future<ApiResult<ShopsPaginateResponse>> getAllShops(
    int page, {
    String? categoryId,
    FilterModel? filterModel,
    required bool isOpen,
    bool? verify,
  });

  Future<ApiResult<TagResponse>> getTags(String categoryId);

  Future<ApiResult<bool>> checkDriverZone(LatLng location, {String? shopId});

  Future<ApiResult<PriceModel>> getSuggestPrice();

  Future<ApiResult<ShopsPaginateResponse>> getShopsRecommend(int page);

  Future<ApiResult<List<List<StoryModel?>?>?>> getStory(int page);

  Future<ApiResult<SingleShopResponse>> getSingleShop({required String uuid});

  Future<ApiResult<dynamic>> joinOrder({
    required String shopId,
    required String name,
    required String cartId,
  });

  Future<ApiResult<BranchResponse>> getShopBranch({required String uuid});

  Future<ApiResult<ShopsPaginateResponse>> getShopsByIds(List<String> shopIds);

  Future<ApiResult<void>> createShop({
    required double tax,
    required List<String> documents,
    required double deliveryTo,
    required double deliveryFrom,
    required String deliveryType,
    required String phone,
    required String name,
    required String category,
    required String description,
    required double startPrice,
    required double perKm,
    required AddressNewModel address,
    String? logoImage,
    String? backgroundImage,
  });
}
