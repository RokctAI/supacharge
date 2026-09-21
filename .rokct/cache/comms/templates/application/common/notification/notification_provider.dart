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


// Ported from paas_manager lib/application/notification/notification_provider.dart
// (comms_sdk manager consume, fork plan S-3 / migration bucket b).
// Resolution via base_sdk's injection getters: NotificationRepositoryFacade
// is registered by CommsSdkDependencies.register in the generated
// main.dart sdk-di block.
//
// Shared manager+driver template (driver migration S-D5): paas_driver's host
// twin resolved the same facade through its host dependency_manager
// (notificationRepo); base's injection getter is the SDK-side equivalent.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:base_sdk/src/di/injection.dart';

import 'notification_notifier.dart';
import 'notification_state.dart';

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
  (ref) => NotificationNotifier(notificationRepo),
);
