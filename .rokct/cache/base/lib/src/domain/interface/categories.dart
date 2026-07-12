import 'package:base_sdk/src/models/response/categories_paginate_response.dart';
import 'package:base_sdk/src/handlers/handlers.dart';

abstract class CategoriesRepositoryFacade {
  Future<ApiResult<CategoriesPaginateResponse>> getAllCategories({
    required int page,
  });

  Future<ApiResult<CategoriesPaginateResponse>> searchCategories({
    required String text,
  });

  Future<ApiResult<CategoriesPaginateResponse>> getCategoriesByShop({
    required String shopId,
  });
}
