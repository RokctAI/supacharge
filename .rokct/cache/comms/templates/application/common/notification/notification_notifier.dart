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


// Ported from paas_manager lib/application/notification/notification_notifier.dart
// (comms_sdk manager consume, fork plan S-3 / migration bucket b), adapted
// to SDK conventions: manager's Laravel-era NotificationInterface becomes
// base_sdk's NotificationRepositoryFacade (comms_sdk registers its Frappe
// implementation via CommsSdkDependencies), manager models/services become
// their base_sdk twins, and snackbar calls use base's positional signature.
//
// Shared manager+driver template (driver migration S-D5): paas_driver's host
// lib/application/notification/notification_notifier.dart is the same file
// modulo import paths, so both app_type blocks install this one source from
// templates/application/common/ to the same host destination — one copy, no
// role divergence to drift.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'package:base_sdk/src/domain/interface/notification.dart';
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/models/response/notification_response.dart';
import 'package:base_sdk/src/services/app_connectivity.dart';
import 'package:base_sdk/src/services/app_helpers.dart';

import 'notification_state.dart';

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationRepositoryFacade _notificationRepository;

  int _notificationPage = 0;

  NotificationNotifier(this._notificationRepository)
      : super(const NotificationState());

  Future<void> fetchAllNotifications(BuildContext context) async {
    state = state.copyWith(isAllNotificationsLoading: true);

    final response = await _notificationRepository.getNotifications();
    response.when(
      success: (data) {
        state = state.copyWith(
            isAllNotificationsLoading: false, notifications: data.data ?? []);
      },
      failure: (failure, s) {
        AppHelpers.showCheckTopSnackBar(context, failure);
      },
    );
  }

  Future<void> fetchNotificationsPaginate(
      {VoidCallback? checkYourNetwork,
      RefreshController? refreshController,
      bool isRefresh = false}) async {
    final connected = await AppConnectivity.connectivity();
    if (isRefresh) {
      _notificationPage = 0;
    }
    if (connected) {
      final response = await _notificationRepository.getNotifications(
        page: ++_notificationPage,
      );
      response.when(
        success: (data) async {
          final List<NotificationModel> newList =
              List.from(state.notifications);
          newList.addAll(data.data ?? []);
          state = state.copyWith(
            notifications: isRefresh ? (data.data ?? []) : newList,
          );
          if (data.data?.isEmpty ?? true) {
            refreshController?.loadNoData();
          }
          if (isRefresh) {
            refreshController?.refreshCompleted();
          } else {
            refreshController?.loadComplete();
          }
        },
        failure: (failure, s) {
          debugPrint('==> get notifications more failure: $failure');
        },
      );
    } else {
      checkYourNetwork?.call();
    }
  }

  Future<void> readAll(BuildContext context) async {
    List<NotificationModel> notif = List.from(state.notifications);
    for (var i = 0; i < notif.length; i++) {
      if (notif[i].readAt == null) {
        notif[i] = notif[i].copyWith(readAt: DateTime.now());
      }
    }
    state = state.copyWith(
      notifications: notif,
      countOfNotifications:
          state.countOfNotifications?.copyWith(notification: 0),
    );

    final response = await _notificationRepository.readAll();
    response.when(
      success: (data) {},
      failure: (failure, s) {
        AppHelpers.showCheckTopSnackBar(context, failure);
      },
    );
  }

  Future<void> readOne(BuildContext context,
      {String? id, required int index}) async {
    List<NotificationModel> notif = List.from(state.notifications);
    notif[index] = notif[index].copyWith(
      readAt: DateTime.now(),
    );
    final notification = state.countOfNotifications?.copyWith(
        notification: (state.countOfNotifications?.notification ?? 0) - 1);
    state = state.copyWith(
        notifications: notif, countOfNotifications: notification);
    final response = await _notificationRepository.readOne(id: id);
    response.when(
      success: (data) {},
      failure: (failure, s) {
        AppHelpers.showCheckTopSnackBar(context, failure);
      },
    );
  }

  Future<void> fetchCount(BuildContext context) async {
    final response = await _notificationRepository.getCount();
    response.when(
      success: (data) {
        state = state.copyWith(countOfNotifications: data);
      },
      failure: (failure, s) {
        AppHelpers.showCheckTopSnackBar(context, failure);
      },
    );
  }
}
