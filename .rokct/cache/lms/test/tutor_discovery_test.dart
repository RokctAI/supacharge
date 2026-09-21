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


import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';

class _FakeCatalog implements TutorCatalog {
  @override
  Future<List<TutorProfile>> getTutors({int? grade}) async {
    const all = [
      TutorProfile(
          id: 't1',
          name: 'A',
          title: 'T',
          subject: 'Maths',
          grade: 12,
          styleTag: 's',
          sampleLessonId: 'lesson-1'),
      TutorProfile(
          id: 't2',
          name: 'B',
          title: 'T',
          subject: 'Maths',
          grade: 10,
          styleTag: 's'),
    ];
    if (grade == null) return all;
    return all.where((t) => t.grade == grade).toList();
  }
}

class _FakePlans implements LessonPlans {
  int getPlansCalls = 0;

  @override
  Future<List<LessonPlanOption>> getPlans() async {
    getPlansCalls++;
    return const [LessonPlanOption(id: 'p1', title: 'Monthly', price: 99)];
  }

  @override
  Future<LessonPurchaseResult> purchase(String planId) async =>
      const LessonPurchaseResult.completed(total: 299);

  @override
  Future<LessonPurchaseResult> purchaseForLesson(String planId,
          {required String lesson}) =>
      purchase(planId);
}

/// Server-refused checkout: the wallet needs a top-up. The message is the
/// SERVER's, named amount included — the client never composes one.
class _RefusingPlans implements LessonPlans {
  @override
  Future<List<LessonPlanOption>> getPlans() async =>
      const [LessonPlanOption(id: 'p1', title: 'Monthly', price: 99)];

  @override
  Future<LessonPurchaseResult> purchase(String planId) async =>
      const LessonPurchaseResult.failed(
          message: 'Top up your wallet: this checkout needs 299.0.');

  @override
  Future<LessonPurchaseResult> purchaseForLesson(String planId,
          {required String lesson}) =>
      purchase(planId);
}

class _AlwaysSubscribed implements SubscriptionStatusProvider {
  @override
  Future<bool> hasActiveSubscription(String studentId) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('browsing is free: no paywall from swiping OR flipping into detail; '
      'only "Start with tutor" triggers it, once, with loaded plans',
      () async {
    final plans = _FakePlans();
    final n = TutorDiscoveryNotifier(catalog: _FakeCatalog(), plans: plans);
    await n.init();

    expect(n.state.plansVisible, isFalse);
    n.nextCard();
    n.previousCard();
    expect(n.state.plansVisible, isFalse, reason: 'swiping never paywalls');

    // Flipping to read about a tutor is still browsing — no paywall.
    n.openDetail(n.state.tutors.first);
    expect(n.state.plansVisible, isFalse,
        reason: 'opening/flipping detail is free browsing');

    // Starting with a tutor is the intent-to-commit action that paywalls.
    n.startWithTutor(n.state.tutors.first);
    expect(n.state.plansVisible, isTrue);
    expect(n.state.plansTrigger, 'start');
    await Future<void>.delayed(Duration.zero);
    expect(n.state.plans, hasLength(1));

    // Dismiss and re-trigger: fires only once per visit.
    n.dismissPlans();
    n.startWithTutor(n.state.tutors.last);
    expect(n.state.plansVisible, isFalse);
    expect(plans.getPlansCalls, 1);
    n.dispose();
  });

  test('sample-lesson watch triggers the paywall and returns the lesson id',
      () async {
    final n =
        TutorDiscoveryNotifier(catalog: _FakeCatalog(), plans: _FakePlans());
    await n.init();
    final lessonId = n.watchSample(n.state.tutors.first);
    expect(lessonId, 'lesson-1');
    expect(n.state.plansVisible, isTrue);
    expect(n.state.plansTrigger, 'sample');
    n.dispose();
  });

  test('grade filters the tutor stack to matching tutors only', () async {
    final n = TutorDiscoveryNotifier(
        catalog: _FakeCatalog(), plans: _FakePlans(), grade: 12);
    await n.init();
    expect(n.state.tutors, hasLength(1));
    expect(n.state.tutors.single.id, 't1');
    n.dispose();
  });

  test('purchase completion marks subscribed and closes the sheet', () async {
    final n =
        TutorDiscoveryNotifier(catalog: _FakeCatalog(), plans: _FakePlans());
    await n.init();
    n.startWithTutor(n.state.tutors.first);
    await Future<void>.delayed(Duration.zero);
    await n.purchase(n.state.plans.first);
    expect(n.state.purchaseOutcome, LessonPurchaseOutcome.completed);
    expect(n.state.subscribed, isTrue);
    expect(n.state.plansVisible, isFalse);
    n.dispose();
  });

  test('a refused purchase keeps the sheet open and carries the SERVER\'s '
      'own message (named amount) for the error line', () async {
    final n = TutorDiscoveryNotifier(
        catalog: _FakeCatalog(), plans: _RefusingPlans());
    await n.init();
    n.startWithTutor(n.state.tutors.first);
    await Future<void>.delayed(Duration.zero);
    await n.purchase(n.state.plans.first);
    expect(n.state.purchaseOutcome, LessonPurchaseOutcome.failed);
    expect(n.state.purchaseMessage,
        'Top up your wallet: this checkout needs 299.0.');
    expect(n.state.subscribed, isFalse);
    expect(n.state.plansVisible, isTrue,
        reason: 'a failed checkout leaves the sheet up so the student can '
            'retry once the wallet is topped up');

    // Retrying clears the previous outcome and message while in flight.
    final retry = n.purchase(n.state.plans.first);
    expect(n.state.purchaseMessage, isNull);
    await retry;
    n.dispose();
  });
}
