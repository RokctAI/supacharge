import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/application/delivery_points/delivery_points_notifier.dart';
import 'package:base_sdk/src/application/delivery_points/delivery_points_state.dart';

final deliveryPointsProvider =
    StateNotifierProvider<DeliveryPointsNotifier, DeliveryPointsState>(
  (ref) => DeliveryPointsNotifier(deliveryPointsRepository),
);
