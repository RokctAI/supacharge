import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/models/data/address_new_data.dart';
import 'package:base_sdk/src/models/data/address_old_data.dart';

import 'package:base_sdk/src/services/app_connectivity.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/local_storage.dart';

import 'package:base_sdk/src/domain/interface/shops.dart';
import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:base_sdk/src/presentation/components/add_address.dart';
import 'package:base_sdk/src/application/map/view_map_state.dart';

class ViewMapNotifier extends StateNotifier<ViewMapState> {
  final ShopsRepositoryFacade _shopsRepository;
  final UserRepositoryFacade _userRepository;

  ViewMapNotifier(this._shopsRepository, this._userRepository)
      : super(const ViewMapState());

  void scrolling(bool scroll) {
    state = state.copyWith(isScrolling: scroll);
  }

  void changePlace(AddressNewModel place) {
    state = state.copyWith(place: place, isSetAddress: true);
  }

  void checkAddress(BuildContext context) {
    AddressData? data = LocalStorage.getAddressSelected();
    if (data?.location?.latitude == null) {
      state = state.copyWith(isSetAddress: false);
      AppHelpers.showAlertDialog(context: context, child: const AddAddress());
    } else {
      state = state.copyWith(isSetAddress: true);
    }
  }

  updateActive() {
    state = state.copyWith(isLoading: true);
  }

  saveLocation(BuildContext context, {VoidCallback? onSuccess}) async {
    final connected = await AppConnectivity.connectivity();
    if (connected) {
      state = state.copyWith(isLoading: true);
      final response = await _userRepository.saveLocation(
        address: state.place?.copyWith(
          title: LocalStorage.getAddressSelected()?.title,
        ),
      );
      response.when(
        success: (data) async {
          state = state.copyWith(isLoading: false);
          onSuccess?.call();
        },
        failure: (failure, status) {
          state = state.copyWith(isLoading: false);
        },
      );
    } else {
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
    }
  }

  updateLocation(
    BuildContext context,
    String? id, {
    VoidCallback? onSuccess,
  }) async {
    final connected = await AppConnectivity.connectivity();
    if (connected) {
      state = state.copyWith(isLoading: true);
      final response = await _userRepository.updateLocation(
        address: state.place?.copyWith(
          title: LocalStorage.getAddressSelected()?.title,
        ),
        addressId: id,
      );
      response.when(
        success: (data) async {
          state = state.copyWith(isLoading: false);
          onSuccess?.call();
        },
        failure: (failure, status) {
          state = state.copyWith(isLoading: false);
        },
      );
    } else {
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
    }
  }

  Future<void> checkDriverZone({
    required BuildContext context,
    required LatLng location,
    String? shopId,
  }) async {
    final connected = await AppConnectivity.connectivity();
    if (connected) {
      state = state.copyWith(isLoading: true, isActive: false);
      final response = await _shopsRepository.checkDriverZone(
        location,
        shopId: shopId,
      );
      response.when(
        success: (data) async {
          state = state.copyWith(isLoading: false, isActive: data);
          if (!data) {
            AppHelpers.showCheckTopSnackBarInfo(
              context,
              AppHelpers.getTranslation(TrKeys.noDriverZone),
            );
          }
        },
        failure: (failure, status) {
          state = state.copyWith(isLoading: false);
          if (!(status == 400 || status == 404)) {
            AppHelpers.showCheckTopSnackBar(context, failure);
          }
        },
      );
    } else {
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
    }
  }
}
