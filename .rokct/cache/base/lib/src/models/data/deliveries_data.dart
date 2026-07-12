import 'package:base_sdk/src/models/models.dart';

class DeliveriesData {
  final int shopId;
  final List<ShopDelivery> shopDeliveries;

  DeliveriesData(this.shopId, this.shopDeliveries);
}
