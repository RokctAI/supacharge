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


import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';

/// The locked-lesson pay-for-this-lesson CTA (#55 follow-up): offered only
/// when the SERVER catalog carries an active, priced Per Lesson plan for a
/// lesson-linked student view; checkout failures surface the server's own
/// message verbatim; success unlocks straight into the lesson.
void main() {
  const lapsed = AccessStatus(subscription: SubscriptionState.lapsed);

  const perLesson = LessonPlanOption(
    id: 'per-lesson',
    title: 'Pay Per Lesson',
    price: 49,
    months: 0,
    kind: PlanKind.perLesson,
  );
  const monthly = LessonPlanOption(
    id: 'standard-monthly',
    title: 'Full Access',
    price: 299,
    months: 1,
  );

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  LessonNotifier build({
    LessonPlans? plans,
    String? lessonId = 'L1',
    AccessStatus access = lapsed,
    LessonPlaybackEngine? engine,
  }) =>
      LessonNotifier(
        engine: engine ?? _FakeEngine(),
        sessionId: 's1',
        lessonId: lessonId,
        accessSource: _FixedAccess(access),
        plans: plans,
      );

  test('an active priced Per Lesson plan surfaces the offer, server price',
      () async {
    final notifier = build(plans: _FakePlans(catalog: [monthly, perLesson]));
    await notifier.init();
    await pump();
    expect(notifier.state.accessBlocked, isTrue);
    expect(notifier.state.perLessonOffer?.id, 'per-lesson');
    expect(notifier.state.perLessonOffer?.price, 49);
    notifier.dispose();
  });

  test('no per-lesson plan in the catalog: no offer, zero behavior change',
      () async {
    final notifier = build(plans: _FakePlans(catalog: [monthly]));
    await notifier.init();
    await pump();
    expect(notifier.state.accessBlocked, isTrue);
    expect(notifier.state.perLessonOffer, isNull);
    notifier.dispose();
  });

  test('an unpriced per-lesson plan is never offered (no client prices)',
      () async {
    const unpriced = LessonPlanOption(
      id: 'per-lesson',
      title: 'Pay Per Lesson',
      price: 0,
      months: 0,
      kind: PlanKind.perLesson,
    );
    final notifier = build(plans: _FakePlans(catalog: const [unpriced]));
    await notifier.init();
    await pump();
    expect(notifier.state.perLessonOffer, isNull);
    notifier.dispose();
  });

  test('no lesson id (raw session route): no offer', () async {
    final notifier =
        build(plans: _FakePlans(catalog: [perLesson]), lessonId: null);
    await notifier.init();
    await pump();
    expect(notifier.state.perLessonOffer, isNull);
    notifier.dispose();
  });

  test('a partner viewer gets no offer — reporting-only, cannot attend',
      () async {
    final notifier = build(
      plans: _FakePlans(catalog: [perLesson]),
      access: AccessStatus.partner,
    );
    await notifier.init();
    await pump();
    expect(notifier.state.accessBlocked, isTrue);
    expect(notifier.state.perLessonOffer, isNull);
    notifier.dispose();
  });

  test('a throwing catalog fails silent: blocked screen, no CTA', () async {
    final notifier = build(plans: _ThrowingPlans());
    await notifier.init();
    await pump();
    expect(notifier.state.accessBlocked, isTrue);
    expect(notifier.state.perLessonOffer, isNull);
    notifier.dispose();
  });

  test(
      'refusal keeps the screen blocked with the server message verbatim; '
      'retry succeeds and enters the lesson', () async {
    final engine = _FakeEngine();
    final plans = _FakePlans(
      catalog: [perLesson],
      results: [
        const LessonPurchaseResult.failed(
            message: 'Top up your wallet: this checkout needs 49.0.'),
        const LessonPurchaseResult.completed(total: 49),
      ],
    );
    final notifier = build(plans: plans, engine: engine);
    await notifier.init();
    await pump();

    await notifier.payForLesson();
    expect(notifier.state.accessBlocked, isTrue);
    expect(notifier.state.payingForLesson, isFalse);
    expect(notifier.state.payForLessonFailed, isTrue);
    expect(notifier.state.payForLessonError,
        'Top up your wallet: this checkout needs 49.0.');
    expect(engine.prepared, isFalse);

    await notifier.payForLesson();
    expect(notifier.state.payForLessonFailed, isFalse);
    expect(notifier.state.payForLessonError, isNull);
    expect(notifier.state.accessBlocked, isFalse);
    expect(engine.prepared, isTrue);
    expect(notifier.state.playing, isTrue);
    notifier.dispose();
  });

  test('checkout names the offered plan and THIS lesson', () async {
    final plans = _FakePlans(catalog: [perLesson]);
    final notifier = build(plans: plans);
    await notifier.init();
    await pump();
    await notifier.payForLesson();
    expect(plans.purchasedPlanIds, ['per-lesson']);
    expect(plans.purchasedLessons, ['L1']);
    notifier.dispose();
  });

  test('no offer loaded: payForLesson is a no-op, nothing charged', () async {
    final plans = _FakePlans(catalog: [monthly]);
    final notifier = build(plans: plans);
    await notifier.init();
    await pump();
    await notifier.payForLesson();
    expect(plans.purchasedPlanIds, isEmpty);
    expect(notifier.state.accessBlocked, isTrue);
    notifier.dispose();
  });
}

class _FixedAccess implements AccessStatusSource {
  final AccessStatus status;
  _FixedAccess(this.status);

  @override
  Future<AccessStatus> current() async => status;
}

class _FakePlans implements LessonPlans {
  final List<LessonPlanOption> catalog;

  /// Consumed one per purchaseForLesson call; defaults to completed.
  final List<LessonPurchaseResult> results;
  final List<String> purchasedPlanIds = [];
  final List<String> purchasedLessons = [];

  _FakePlans({required this.catalog, List<LessonPurchaseResult>? results})
      : results = List.of(results ?? const []);

  @override
  Future<List<LessonPlanOption>> getPlans() async => catalog;

  @override
  Future<LessonPurchaseResult> purchase(String planId) async =>
      const LessonPurchaseResult.completed();

  @override
  Future<LessonPurchaseResult> purchaseForLesson(String planId,
      {required String lesson}) async {
    purchasedPlanIds.add(planId);
    purchasedLessons.add(lesson);
    return results.isEmpty
        ? const LessonPurchaseResult.completed(total: 49)
        : results.removeAt(0);
  }
}

class _ThrowingPlans implements LessonPlans {
  @override
  Future<List<LessonPlanOption>> getPlans() async =>
      throw StateError('catalog unreachable');

  @override
  Future<LessonPurchaseResult> purchase(String planId) async =>
      const LessonPurchaseResult.failed();

  @override
  Future<LessonPurchaseResult> purchaseForLesson(String planId,
          {required String lesson}) =>
      purchase(planId);
}

class _FakeEngine implements LessonPlaybackEngine {
  final _controller = StreamController<LessonPlaybackEvent>.broadcast();
  bool prepared = false;

  @override
  Future<LessonReadiness> prepare(String sessionId) async {
    prepared = true;
    return const LessonReadiness(isReady: true);
  }

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
