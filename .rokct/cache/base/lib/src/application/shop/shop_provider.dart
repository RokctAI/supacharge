import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:base_sdk/src/di/injection.dart';

import 'package:base_sdk/src/application/shop/shop_notifier.dart';
import 'package:base_sdk/src/application/shop/shop_state.dart';

final shopProvider = StateNotifierProvider<ShopNotifier, ShopState>(
  (ref) => ShopNotifier(
    shopsRepository,
    productsRepository,
    categoriesRepository,
    drawRepository,
    brandsRepository,
  ),
);
