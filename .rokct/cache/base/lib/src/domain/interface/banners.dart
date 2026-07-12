import 'package:base_sdk/src/models/models.dart';
import 'package:base_sdk/src/handlers/handlers.dart';

abstract class BannersRepositoryFacade {
  Future<ApiResult<BannersPaginateResponse>> getBannersPaginate({
    required int page,
  });

  Future<ApiResult<BannersPaginateResponse>> getAdsPaginate({
    required int page,
  });

  Future<ApiResult<BannerData>> getBannerById(int? bannerId);

  Future<ApiResult<BannerData>> getAdsById(int? bannerId);

  Future<ApiResult<void>> likeBanner(int? bannerId);
}
