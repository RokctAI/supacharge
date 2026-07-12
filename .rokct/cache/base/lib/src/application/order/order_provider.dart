import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:base_sdk/src/di/injection.dart';

import 'package:base_sdk/src/application/order/order_notifier.dart';
import 'package:base_sdk/src/application/order/order_state.dart';

final orderProvider =
    StateNotifierProvider.autoDispose<OrderNotifier, OrderState>(
  (ref) => OrderNotifier(
    ordersRepository,
    shopsRepository,
    paymentsRepository,
    cartRepository,
    drawRepository,
  ),
);
