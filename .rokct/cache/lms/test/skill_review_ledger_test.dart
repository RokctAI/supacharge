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


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';

void main() {
  final base = DateTime(2026, 7, 20, 15, 0);

  group('KvSkillReviewLedger', () {
    test('unreviewed by default; a completed review flips it', () async {
      final ledger = KvSkillReviewLedger(kv: _MemStore(), now: () => base);
      expect(await ledger.isReviewed('maths.factorisation'), isFalse);
      await ledger.recordReviewed('maths.factorisation');
      expect(await ledger.isReviewed('maths.factorisation'), isTrue);
      expect(await ledger.isReviewed('maths.surds'), isFalse);
    });

    test('persists across ledger instances (KV round-trip)', () async {
      final kv = _MemStore();
      await KvSkillReviewLedger(kv: kv, now: () => base)
          .recordReviewed('maths.surds');
      expect(
          await KvSkillReviewLedger(kv: kv, now: () => base)
              .isReviewed('maths.surds'),
          isTrue);
    });
  });

  group('pre-class skill reminder (decision #11.5)', () {
    ScheduledSession session({
      String id = 's1',
      DateTime? start,
      List<String> requires = const ['maths.factorisation'],
    }) =>
        ScheduledSession(
          sessionId: id,
          lessonId: 'L1',
          subject: 'Maths',
          topic: 'Quadratic equations',
          tutorName: 'Grandmaster',
          startTime: start ?? base.add(const Duration(hours: 3)),
          requiresSkills: requires,
        );

    Future<ScheduleNotifier> build({
      ScheduledSession? s,
      bool confirmed = true,
      _MemStore? store,
      KvSkillReviewLedger? ledger,
      _FakePlanner? planner,
    }) async {
      final kv = store ?? _MemStore();
      final sess = s ?? session();
      if (confirmed) {
        await kv.put(ScheduleNotifier.attendanceCollection, sess.sessionId,
            {'state': AttendanceState.confirmed.name});
      }
      final n = ScheduleNotifier(
        schedule: _FakeSchedule([sess]),
        store: kv,
        planner: planner,
        skills: _FakeSkills({
          'maths.factorisation': SkillLessonInfo(
            skillRef: 'maths.factorisation',
            cardId: 'card_f',
            subject: 'Maths',
            status: 'evaluated',
            name: 'Factorisation techniques',
          ),
        }),
        skillLedger: ledger ?? KvSkillReviewLedger(kv: kv, now: () => base),
        now: () => base,
      );
      await n.init();
      return n;
    }

    test('signed-up class due within 24h with unmet skills → reminder + '
        'planner todo (once)', () async {
      final planner = _FakePlanner();
      final store = _MemStore();
      final n = await build(planner: planner, store: store);
      expect(n.state.skillReminder, isNotNull);
      expect(n.state.skillReminder!.session.sessionId, 's1');
      expect(n.state.skillReminder!.skills.map((s) => s.skillRef),
          ['maths.factorisation']);
      expect(planner.reminders, ['s1-skill-review']);

      // A second load never stacks a duplicate todo (KV marker).
      await n.refresh();
      expect(planner.reminders, ['s1-skill-review']);
      n.dispose();
    });

    test('a reviewed skill silences the reminder', () async {
      final kv = _MemStore();
      final ledger = KvSkillReviewLedger(kv: kv, now: () => base);
      await ledger.recordReviewed('maths.factorisation');
      final n = await build(store: kv, ledger: ledger);
      expect(n.state.skillReminder, isNull);
      n.dispose();
    });

    test('not signed up → no reminder (decision #11.5 is for classes the '
        'student signed up to attend)', () async {
      final n = await build(confirmed: false);
      expect(n.state.skillReminder, isNull);
      n.dispose();
    });

    test('a class further out than the 24h lead does not remind yet',
        () async {
      final n =
          await build(s: session(start: base.add(const Duration(hours: 30))));
      expect(n.state.skillReminder, isNull);
      n.dispose();
    });

    test('a class already past never reminds', () async {
      final n = await build(
          s: session(start: base.subtract(const Duration(hours: 1))));
      expect(n.state.skillReminder, isNull);
      n.dispose();
    });

    test('below the 3-minute review floor nothing is offered', () async {
      final n = await build(
          s: session(start: base.add(const Duration(minutes: 2))));
      expect(n.state.skillReminder, isNull);
      n.dispose();
    });

    test('dismiss clears and holds for this run; the planner todo stays',
        () async {
      final planner = _FakePlanner();
      final n = await build(planner: planner);
      expect(n.state.skillReminder, isNotNull);
      n.dismissSkillReminder();
      expect(n.state.skillReminder, isNull);
      await n.refresh();
      expect(n.state.skillReminder, isNull,
          reason: 'the X holds for the app run');
      expect(planner.reminders, ['s1-skill-review']);
      n.dispose();
    });
  });

  group('SkillPlayerPage completion feeds the ledger', () {
    const skill = SkillLessonInfo(
      skillRef: 'maths.factorisation',
      cardId: 'card_f',
      subject: 'Maths',
      status: 'evaluated',
      name: 'Factorisation techniques',
    );

    testWidgets('finishing the review (recap-only content) fires once',
        (tester) async {
      var completed = 0;
      await tester.pumpWidget(MaterialApp(
        home: SkillPlayerPage(
          skill: skill,
          content: const SkillReviewContent(
            skillRef: 'maths.factorisation',
            recap: 'The method, compressed.',
          ),
          onReviewCompleted: () => completed++,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(completed, 1);
    });

    testWidgets('acing the diagnostic ("you\'re ready") also counts',
        (tester) async {
      var completed = 0;
      await tester.pumpWidget(MaterialApp(
        home: SkillPlayerPage(
          skill: skill,
          content: const SkillReviewContent(
            skillRef: 'maths.factorisation',
            diagnostic: [
              McqQuestion(
                id: 'd1',
                prompt: 'Factor x^2-1',
                options: ['(x-1)(x+1)', 'x(x-1)'],
                correctIndex: 0,
              ),
            ],
            recap: 'The method, compressed.',
          ),
          onReviewCompleted: () => completed++,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('(x-1)(x+1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton)); // Next
      await tester.pumpAndSettle();
      expect(completed, 1);
    });
  });
}

class _MemStore implements ScheduleStore {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Future<Map<String, dynamic>?> get(String collection, String key) async =>
      _data['$collection/$key'];

  @override
  Future<void> put(
          String collection, String key, Map<String, dynamic> value) async =>
      _data['$collection/$key'] = value;
}

class _FakeSchedule implements SessionScheduleSource {
  final List<ScheduledSession> sessions;
  _FakeSchedule(this.sessions);

  @override
  Future<List<ScheduledSession>> upcoming() async => sessions;
}

class _FakeSkills implements SkillLessonSource {
  final Map<String, SkillLessonInfo> byRef;
  _FakeSkills(this.byRef);

  @override
  Future<SkillLessonInfo?> lookup(String skillRef) async => byRef[skillRef];

  @override
  Future<List<SkillLessonInfo>> available() async => byRef.values.toList();
}

class _FakePlanner implements StudyPlanner {
  final List<String> reminders = [];

  @override
  Future<void> scheduleSessionReminder(
          {required String sessionId,
          required String title,
          required DateTime startTime}) async =>
      reminders.add(sessionId);

  @override
  Future<void> recordSkip(
      {required String sessionId,
      required DateTime sessionStart,
      required int scorePercent}) async {}

  @override
  Future<void> recordAttendanceConfirmation(
      {required String sessionId, required DateTime sessionStart}) async {}
}
