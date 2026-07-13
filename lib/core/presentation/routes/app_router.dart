// ==========================================
// [GENERATED TEMPLATE FILE]
// This file was installed from: base_sdk
// Feel free to modify and customize this code.
// Note: If you edit this file, the SDK installer will detect your changes
// and automatically skip overwriting it during future upgrades.
// ==========================================

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
// @generated-imports-start
import 'package:supacharge/core/presentation/routes/lms_route_pages.dart';
import 'package:supacharge/core/presentation/routes/route_pages.dart';
import 'package:supacharge/manager/presentation/pages/tasks/tasks_page.dart';
import 'package:supacharge/presentation/pages/agent/assistant_chat_page.dart';
import 'package:supacharge/presentation/pages/subscriptions/subscriptions_page.dart';
// @generated-imports-end

part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
// @generated-routes-start
    MaterialRoute(path: '/', page: SplashRoute.page),
    MaterialRoute(path: '/no-connection', page: NoConnectionRoute.page),
    MaterialRoute(path: '/closed', page: ClosedRoute.page),
    MaterialRoute(path: '/ui-type', page: UiTypeRoute.page),
    MaterialRoute(path: '/lesson-session', page: LessonRoute.page),
    MaterialRoute(path: '/tutors', page: TutorDiscoveryRoute.page),
    MaterialRoute(path: '/subscriptions', page: ManagerSubscriptionsRoute.page),
    MaterialRoute(path: '/assistant-chat', page: AssistantChatRoute.page),
    CupertinoRoute(path: '/tasks', page: TasksRoute.page),
// @generated-routes-end
      ];
}
