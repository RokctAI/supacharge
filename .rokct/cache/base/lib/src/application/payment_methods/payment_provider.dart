import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:base_sdk/src/di/injection.dart';

import 'package:base_sdk/src/application/payment_methods/payment_notifier.dart';
import 'package:base_sdk/src/application/payment_methods/payment_state.dart';

final paymentProvider = StateNotifierProvider<PaymentNotifier, PaymentState>(
  (ref) => PaymentNotifier(paymentsRepository),
);
