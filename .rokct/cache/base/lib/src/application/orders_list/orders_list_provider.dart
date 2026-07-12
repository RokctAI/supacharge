import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:base_sdk/src/di/injection.dart';

import 'package:base_sdk/src/application/orders_list/orders_list_notifier.dart';
import 'package:base_sdk/src/application/orders_list/orders_list_state.dart';

final ordersListProvider =
    StateNotifierProvider<OrdersListNotifier, OrdersListState>(
  (ref) => OrdersListNotifier(ordersRepository),
);
