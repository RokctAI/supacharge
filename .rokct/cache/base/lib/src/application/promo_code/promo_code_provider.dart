import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:base_sdk/src/di/injection.dart';

import 'package:base_sdk/src/application/promo_code/promo_code_notifier.dart';
import 'package:base_sdk/src/application/promo_code/promo_code_state.dart';

final promoCodeProvider =
    StateNotifierProvider<PromoCodeNotifier, PromoCodeState>(
  (ref) => PromoCodeNotifier(ordersRepository),
);
