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
//
// The approved session plane ruling (frame 52, Ray 2026-08-31): "know
// attendees and lesson player is same page, why cant it just own two
// planes? this will make 52c not need back and 52b will never be empty",
// narrowed the same day to "schedule doesnt go ... i thought if it is
// there you will see schedule in first and lesson in second. inside
// lesson you can already swipe to see attendees".
//
// So the session's claim GROWS instead of demanding: one plane like any
// other page, plus a second ONLY when it would otherwise sit empty.
//   * one plane  -> the schedule keeps it; the session is a pushed route
//                   with attendees a swipe away inside it (unchanged);
//   * two planes -> schedule | lesson, the lesson still holding its
//                   swipe — the schedule is never displaced;
//   * three      -> schedule | board | attendees, nothing empty.

import 'dart:async';

import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_screenutil/flutter_screenutil.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lms_sdk/src/common/application/lesson/lesson_notifier.dart';
import 'package:lms_sdk/src/common/controllers/whiteboard_player.dart';
import 'package:lms_sdk/src/common/domain/interface/lesson_playback_engine.dart';
import 'package:lms_sdk/src/common/domain/models/lesson_models.dart';
import 'package:lms_sdk/src/common/presentation/pages/lesson/lesson_player_page.dart';
import 'package:lms_sdk/src/common/presentation/pages/lesson/lesson_session_plane_flow.dart';
import 'package:lms_sdk/src/common/presentation/pages/lesson/widgets/lesson_attendees_panel.dart';

/// A playback engine that is ready and then says nothing — enough for the
/// page to render its lesson surface without a real replay asset.
class _IdleEngine implements LessonPlaybackEngine {
  final _controller = StreamController<LessonPlaybackEvent>.broadcast();

  @override
  Future<LessonReadiness> prepare(String sessionId) async =>
      const LessonReadiness(isReady: true);

  @override
  Future<void> start() async {}

  @override
  Stream<LessonPlaybackEvent> get events => _controller.stream;

  @override
  void pause() {}

  @override
  void primeTo(double toSeconds) {}

  @override
  void playStandingClip(String ref) {}

  @override
  void resumeAtLivePosition() {}

  @override
  void resume() {}

  @override
  void dispose() {
    _controller.close();
  }
}

/// The real session inside the real flow, at [width] logical pixels.
Future<void> pumpFlow(
  WidgetTester tester,
  double width, {
  required WhiteboardPlayer player,
  required LessonScreenDeps deps,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: ScreenUtilInit(
        designSize: Size(width, 900),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: LmsSessionPlaneFlow(
              sessionOpen: true,
              scheduleBuilder: (context) => const Text('SCHEDULE'),
              sessionBuilder: (context) =>
                  LessonPlayerPage(deps: deps, player: player),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Labels go through AppHelpers.getTranslation, which reads
    // LocalStorage — seed an empty store so the humanized-key fallback
    // answers (same setup as profile_plane_flow_test).
    SharedPreferences.setMockInitialValues(const {});
    await LocalStorage.init();
  });

  group('LmsSessionPlaneFlow — the claim at one, two and three planes', () {
    final captured = <String, Planes>{};

    Future<void> pump(
      WidgetTester tester,
      double width, {
      required bool sessionOpen,
    }) async {
      captured.clear();
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: Size(width, 800),
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: LmsSessionPlaneFlow(
                sessionOpen: sessionOpen,
                scheduleBuilder: (context) {
                  captured['schedule'] = Planes.of(context);
                  return const Text('SCHEDULE');
                },
                sessionBuilder: (context) {
                  captured['session'] = Planes.of(context);
                  return const Text('SESSION');
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
        'ONE plane (a phone): the schedule keeps it and the session is not '
        'in the flow at all — it stays the pushed route it has always been',
        (tester) async {
      await pump(tester, 500, sessionOpen: true);
      expect(find.text('SCHEDULE'), findsOneWidget);
      expect(find.text('SESSION'), findsNothing);
      expect(captured['schedule']!.count, 1);
      expect(captured['schedule']!.span, 1);
      expect(LmsSessionPlaneFlow.holdsSession(500), isFalse);
    });

    testWidgets(
        'TWO planes: schedule | lesson. The schedule is NOT displaced and '
        'the lesson holds ONE plane, keeping its swipe to attendees',
        (tester) async {
      await pump(tester, 700, sessionOpen: true);
      expect(find.text('SCHEDULE'), findsOneWidget);
      expect(find.text('SESSION'), findsOneWidget);
      expect(captured['schedule']!.count, 2);
      expect(captured['schedule']!.index, 0);
      expect(captured['schedule']!.span, 1);
      expect(captured['session']!.index, 1);
      // The whole point of the narrowed ruling: a flat PlaneSpan.two
      // would be 2 here and would have pushed the schedule off.
      expect(captured['session']!.span, 1);
      expect(captured['session']!.isLast, isTrue);
    });

    testWidgets(
        'THREE planes: schedule | board | attendees — the session grows '
        'into the plane that would otherwise have been empty',
        (tester) async {
      await pump(tester, 1000, sessionOpen: true);
      expect(captured['schedule']!.count, 3);
      expect(captured['schedule']!.index, 0);
      expect(captured['schedule']!.span, 1);
      expect(captured['session']!.index, 1);
      expect(captured['session']!.span, 2);
      expect(captured['session']!.isLast, isTrue);
    });

    testWidgets('no session open: the schedule alone, no corner pill',
        (tester) async {
      await pump(tester, 1000, sessionOpen: false);
      expect(find.text('SESSION'), findsNothing);
      expect(captured['schedule']!.span, 1);
      // Frame 52a: the session's own header exit is the screen's one
      // leave affordance, so the flow raises no back pill in any state.
      expect(find.byType(FloatingBackPill), findsNothing);
    });

    testWidgets('a session open at plane widths raises NO corner back pill',
        (tester) async {
      await pump(tester, 1000, sessionOpen: true);
      expect(find.byType(FloatingBackPill), findsNothing);
      await pump(tester, 700, sessionOpen: true);
      expect(find.byType(FloatingBackPill), findsNothing);
    });
  });

  group('LessonPlayerPage — board and attendees on the planes it is given',
      () {
    late _IdleEngine engine;
    late WhiteboardPlayer player;
    late LessonScreenDeps deps;

    setUp(() {
      engine = _IdleEngine();
      player = WhiteboardPlayer();
      deps = LessonScreenDeps(
        sessionId: 'test-session',
        engine: engine,
        tutor: const TutorPersona(id: 'tutor', displayName: 'Mr Dlamini'),
      );
    });

    tearDown(() => engine.dispose());

    Future<void> pumpPage(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: ScreenUtilInit(
            designSize: Size(width, 900),
            builder: (_, __) => MaterialApp(
              home: LessonPlayerPage(deps: deps, player: player),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('the claim is the growing one, never a flat two', (_) async {
      expect(LessonPlayerPage.span, PlaneSpan.twoIfSpare);
      // A flat two would take both planes of a two-plane screen; the
      // growing claim takes one and leaves the schedule where it is.
      expect(PlaneSpan.twoIfSpare.claimFor(2), 1);
      expect(PlaneSpan.twoIfSpare.growthCapFor(3), 2);
    });

    testWidgets(
        'phone: attendees is reachable exactly as before — the second '
        'page of the session PageView, one swipe away', (tester) async {
      await pumpPage(tester, 390);
      final pageView = find.byType(PageView);
      expect(pageView, findsOneWidget);
      // The PageView builds its pages lazily, so attendees arrives when
      // the swipe reaches it — exactly the shipped behaviour.
      expect(find.byType(LessonAttendeesPanel), findsNothing);
      // No pumpAndSettle: the live indicator pulses forever, so the
      // tree never settles. Fixed pumps carry the page swipe instead.
      await tester.drag(pageView, const Offset(-400, 0));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(find.byType(LessonAttendeesPanel), findsOneWidget);
    });

    testWidgets(
        'granted two planes the page spreads: board beside attendees, no '
        'PageView and no swipe left to make', (tester) async {
      // Wide enough for three planes: the page hosts its own claim when
      // no flow is above it and grows into the spare plane.
      await pumpPage(tester, 1200);
      expect(find.byType(LessonAttendeesPanel), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
    });

    // A plane is NARROWER than a phone: 293 logical at the two-plane
    // floor (600), 271 at the three-plane floor (840), against a phone's
    // ~390. The board's content carries no absolute authored size — the
    // scaler maps normalized coordinates straight onto the surface — so
    // it renders at those widths; these two pin that it does, at exactly
    // the widths where the planes are narrowest.
    testWidgets('the board renders at the two-plane floor (a 293pt plane)',
        (tester) async {
      await pumpFlow(tester, 600, player: player, deps: deps);
      expect(tester.takeException(), isNull);
      // 600 -> two planes of (600 - 14) / 2 = 293. Nothing is spare, so
      // the session holds one of them, board full-bleed inside it.
      expect(find.text('SCHEDULE'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('the board renders at the three-plane floor (a 271pt plane)',
        (tester) async {
      await pumpFlow(tester, 840, player: player, deps: deps);
      expect(tester.takeException(), isNull);
      // 840 -> three planes of (840 - 28) / 3 = 270.67; the session holds
      // two of them, so the board itself is one 271pt column.
      expect(find.text('SCHEDULE'), findsOneWidget);
      expect(find.byType(LessonAttendeesPanel), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets(
        'a single granted plane keeps the swipe — the page folds to its '
        'phone layout inside the plane', (tester) async {
      // The schedule shell's shape at two planes: the flow beneath has
      // taken the first plane, so the session gets exactly one.
      await pumpFlow(tester, 700, player: player, deps: deps);
      expect(find.text('SCHEDULE'), findsOneWidget);
      final pageView = find.byType(PageView);
      expect(pageView, findsOneWidget);
      // And the swipe still reaches attendees inside that one plane.
      await tester.drag(pageView, const Offset(-250, 0));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(find.byType(LessonAttendeesPanel), findsOneWidget);
    });
  });
}
