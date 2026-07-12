import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:base_sdk/src/di/injection.dart';

import 'package:base_sdk/src/application/parcels_list/parcel_list_notifier.dart';
import 'package:base_sdk/src/application/parcels_list/parcel_list_state.dart';

final parcelListProvider =
    StateNotifierProvider<ParcelListNotifier, ParcelListState>(
  (ref) => ParcelListNotifier(parcelRepository),
);
