import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/models/data/delivery_point_data.dart';

abstract class DeliveryPointsRepositoryFacade {
  Future<ApiResult<List<DeliveryPointData>>> getDeliveryPoints({
    required double latitude,
    required double longitude,
  });

  Future<ApiResult<List<DeliveryPointData>>> getAllDeliveryPoints();
}
