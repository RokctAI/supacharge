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
import 'package:auth_sdk/src/presentation/pages/auth/confirmation/register_confirmation_page.dart';
import 'package:auth_sdk/src/presentation/pages/auth/login/login_page.dart';
import 'package:auth_sdk/src/presentation/pages/auth/register/register_page.dart';
import 'package:auth_sdk/src/presentation/pages/auth/reset/reset_password_page.dart';
import 'package:supacharge/core/presentation/routes/lms_route_pages.dart';
import 'package:supacharge/core/presentation/routes/onboarding_route_pages.dart';
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
    MaterialRoute(path: '/courses', page: CourseCatalogRoute.page),
    MaterialRoute(path: '/schedule', page: ScheduleRoute.page),
    MaterialRoute(path: '/library', page: LibraryRoute.page),
    MaterialRoute(path: '/profile', page: StudentProfileRoute.page),
    MaterialRoute(path: '/partner-invite', page: PartnerInviteRoute.page),
    MaterialRoute(path: '/partner-dashboard', page: PartnerDashboardRoute.page),
    MaterialRoute(path: '/partner-add-student', page: AddStudentRoute.page),
    MaterialRoute(path: '/redeem-partner-code', page: RedeemPartnerCodeRoute.page),
    MaterialRoute(path: '/login', page: LoginRoute.page),
    MaterialRoute(path: '/register', page: RegisterRoute.page),
    MaterialRoute(path: '/register-confirmation', page: RegisterConfirmationRoute.page),
    MaterialRoute(path: '/reset-password', page: ResetPasswordRoute.page),
    MaterialRoute(path: '/subscriptions', page: ManagerSubscriptionsRoute.page),
    MaterialRoute(path: '/assistant-chat', page: AssistantChatRoute.page),
    CupertinoRoute(path: '/tasks', page: TasksRoute.page),
    MaterialRoute(path: '/onboarding-intro', page: OnboardingRoute.page),
// @generated-routes-end
      ];
}
