// Copyright (c) 2026 ROKCT INTELLIGENCE (PTY) LTD
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, version 3.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

// Ported from paas_manager lib/application/profile/profile_notifier.dart
// (users_sdk manager consume, fork plan S-2 / migration bucket b), adapted
// to SDK conventions: manager's Laravel-era UsersInterface becomes
// base_sdk's UserRepositoryFacade (registered by UsersSdkDependencies),
// manager's models/services become their base_sdk twins, and route classes
// resolve via the host's own app_router (${package} import). The retired
// become-seller createShop flow is NOT ported — merchants_sdk's shop-setup
// registration step owns shop creation now.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'package:base_sdk/src/domain/interface/user.dart';
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/services/app_connectivity.dart';
import 'package:base_sdk/src/services/app_helpers.dart';
import 'package:base_sdk/src/services/error_presenter.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:${package}/presentation/routes/app_router.dart';

import 'profile_state.dart';

class ProfileNotifier extends StateNotifier<ProfileState> {
  final UserRepositoryFacade _usersRepository;

  ProfileNotifier(this._usersRepository) : super(const ProfileState());

  Future<void> fetchUser(
    BuildContext context, {
    RefreshController? refreshController,
    ValueChanged<String?>? onSuccess,
  }) async {
    if (LocalStorage.getToken().isNotEmpty) {
      final connected = await AppConnectivity.connectivity();
      if (connected) {
        if (refreshController == null) {
          state = state.copyWith(isLoading: true);
        }
        final response = await _usersRepository.getProfileDetails();
        response.when(
          success: (data) async {
            LocalStorage.setWalletData(data.data?.wallet);
            LocalStorage.setUser(data.data);
            onSuccess?.call(data.data?.phone);
            if (refreshController == null) {
              state = state.copyWith(isLoading: false, userData: data.data);
            } else {
              state = state.copyWith(userData: data.data);
            }
            refreshController?.refreshCompleted();
          },
          failure: (failure, status) {
            if (refreshController == null) {
              state = state.copyWith(isLoading: false);
            }
            if (status == 401) {
              context.router.popUntilRoot();
              context.replaceRoute(const LoginRoute());
            }
            // Standing rule (entry 56): friendly line on screen, verbatim
            // detail to telemetry. A server-authored 4xx line still shows
            // as-is; raw technical detail no longer reaches the snackbar.
            ErrorPresenter.show(
              context,
              type: 'manager_profile_fetch_failed',
              failure: failure,
              statusCode: status,
            );
          },
        );
      } else {
        if (context.mounted) {
          AppHelpers.showNoConnectionSnackBar(context);
        }
      }
    }
  }

  Future<void> deleteAccount(BuildContext context) async {
    final connected = await AppConnectivity.connectivity();
    if (connected) {
      state = state.copyWith(isLoading: true);
      final response = await _usersRepository.deleteAccount();
      response.when(
        success: (data) async {
          LocalStorage.logout();
          context.router.popUntilRoot();
          context.replaceRoute(const LoginRoute());
        },
        failure: (fail, status) {
          state = state.copyWith(isLoading: false);
          // Standing rule (entry 56): friendly line on screen, verbatim
          // detail to telemetry.
          ErrorPresenter.show(
            context,
            type: 'manager_account_delete_failed',
            failure: fail,
            statusCode: status,
          );
        },
      );
    } else {
      if (context.mounted) {
        AppHelpers.showNoConnectionSnackBar(context);
      }
    }
  }
}
