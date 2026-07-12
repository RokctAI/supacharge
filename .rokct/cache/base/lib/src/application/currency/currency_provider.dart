import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:base_sdk/src/di/injection.dart';

import 'package:base_sdk/src/application/currency/currency_notifier.dart';
import 'package:base_sdk/src/application/currency/currency_state.dart';

final currencyProvider = StateNotifierProvider<CurrencyNotifier, CurrencyState>(
  (ref) => CurrencyNotifier(currenciesRepository),
);
