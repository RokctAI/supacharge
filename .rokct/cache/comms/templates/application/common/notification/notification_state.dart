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


// Ported from paas_manager lib/application/notification/notification_state.dart
// (comms_sdk manager consume, fork plan S-3 / migration bucket b), models
// swapped for their base_sdk twins (NotificationModel lives in base's
// notification_response.dart; CountNotificationModel in
// count_of_notifications_data.dart).
//
// Shared manager+driver template (driver migration S-D5): paas_driver's host
// twin declares the identical four fields. notification_state.freezed.dart
// is deliberately not shipped — the host's own build_runner pass regenerates
// it after install.
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:base_sdk/src/models/data/count_of_notifications_data.dart';
import 'package:base_sdk/src/models/response/notification_response.dart';

part 'notification_state.freezed.dart';

@freezed
abstract class NotificationState with _$NotificationState {
  const factory NotificationState({
    @Default([]) List<NotificationModel> notifications,
    @Default(null) CountNotificationModel? countOfNotifications,
    @Default(false) bool isReadAllLoading,
    @Default(false) bool isAllNotificationsLoading,
  }) = _NotificationState;

  const NotificationState._();
}
