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

/// Supercharge Holiday Programme (business doc §2 + holiday brief):
/// three-way access, mode selection, weak-topic catch-up, planner.
void main() {
  group('AccessPolicy: holiday programme three-way model', () {
    const cap = LessonCapability.holidayProgramme;

    test('standalone purchase works with NO subscription at all', () {
      // The genuinely new case: a non-subscriber who bought Holiday
      // Programme on its own — top-of-funnel acquisition.
      const standalone = AccessStatus(
          subscription: SubscriptionState.none,
          holiday: HolidayAccess.standalone);
      expect(AccessPolicy.allows(standalone, cap), isTrue);
      // ...and holiday access grants NOTHING else: not live sessions, not
      // the library, not Mandy.
      expect(
          AccessPolicy.allows(standalone, LessonCapability.liveSessions),
          isFalse);
      expect(AccessPolicy.allows(standalone, LessonCapability.libraryNew),
          isFalse);
      expect(AccessPolicy.allows(standalone, LessonCapability.assistant), isFalse);
    });

    test('bundled access rides on the subscription and lapses with it', () {
      const bundledActive = AccessStatus(
          subscription: SubscriptionState.active,
          holiday: HolidayAccess.bundled);
      const bundledLapsed = AccessStatus(
          subscription: SubscriptionState.lapsed,
          holiday: HolidayAccess.bundled);
      expect(AccessPolicy.allows(bundledActive, cap), isTrue);
      expect(AccessPolicy.allows(bundledLapsed, cap), isFalse);
    });

    test('a paid add-on is a completed purchase — survives lapsing', () {
      const addOnLapsed = AccessStatus(
          subscription: SubscriptionState.lapsed, holiday: HolidayAccess.addOn);
      expect(AccessPolicy.allows(addOnLapsed, cap), isTrue);
    });

    test('no holiday access means no holiday content, however subscribed',
        () {
      const activeNoHoliday =
          AccessStatus(subscription: SubscriptionState.active);
      expect(AccessPolicy.allows(activeNoHoliday, cap), isFalse);
      expect(AccessPolicy.allows(AccessStatus.guest, cap), isFalse);
    });

    test('an earned grant stands on its own, whatever the subscription', () {
      // Participation-earned temporary access (badge-driven, not a
      // purchase): survives lapsing — "keep what you earned" — and grants
      // ONLY holiday content, nothing else.
      for (final sub in SubscriptionState.values) {
        final earned = AccessStatus(subscription: sub, holiday: HolidayAccess.earned);
        expect(AccessPolicy.allows(earned, cap), isTrue, reason: '$sub');
      }
      const earnedLapsed = AccessStatus(
          subscription: SubscriptionState.lapsed, holiday: HolidayAccess.earned);
      expect(AccessPolicy.allows(earnedLapsed, LessonCapability.liveSessions),
          isFalse);
      expect(AccessPolicy.allows(earnedLapsed, LessonCapability.assistant), isFalse);
    });

    test('EarnedHolidayGrant window: inclusive start, exclusive end', () {
      final grant = EarnedHolidayGrant(
        validFrom: DateTime(2026, 6, 29),
        validUntil: DateTime(2026, 7, 6),
        reason: 'Perfect attendance — Term 2',
      );
      expect(grant.isActiveAt(DateTime(2026, 6, 28, 23, 59)), isFalse);
      expect(grant.isActiveAt(DateTime(2026, 6, 29)), isTrue);
      expect(grant.isActiveAt(DateTime(2026, 7, 5, 23, 59)), isTrue);
      expect(grant.isActiveAt(DateTime(2026, 7, 6)), isFalse);
    });

    test('partner accounts stay reporting-only', () {
      expect(AccessPolicy.allows(AccessStatus.partner, cap), isFalse);
    });

    test('sessionCapability routes holiday sessions to the holiday gate', () {
      expect(AccessPolicy.sessionCapability(holidaySession: true),
          LessonCapability.holidayProgramme);
      expect(AccessPolicy.sessionCapability(holidaySession: false),
          LessonCapability.liveSessions);
    });
  });

  group('resolveHolidayContentMode', () {
    test('December is next-grade preview for every plan', () {
      for (final personalized in [true, false]) {
        expect(
            resolveHolidayContentMode(
                holiday: SchoolHoliday.yearEnd,
                personalizedCatchUp: personalized),
            HolidayContentMode.nextGradePreview);
      }
    });

    test('mid-year splits on the personalized-catch-up entitlement', () {
      for (final h in [
        SchoolHoliday.term1Break,
        SchoolHoliday.term2Break,
        SchoolHoliday.term3Break,
      ]) {
        expect(
            resolveHolidayContentMode(holiday: h, personalizedCatchUp: false),
            HolidayContentMode.termRevision);
        expect(
            resolveHolidayContentMode(holiday: h, personalizedCatchUp: true),
            HolidayContentMode.weakTopicCatchUp);
      }
    });
  });

  group('selectWeakTopics', () {
    AttendanceRecord record(String topic, AttendanceOutcome outcome,
            {String subject = 'maths'}) =>
        AttendanceRecord(
          sessionId: 's-$topic-${outcome.name}',
          subject: subject,
          topic: topic,
          at: DateTime(2026, 4, 1),
          outcome: outcome,
        );

    test('low scores and missed sessions qualify; good scores do not', () {
      final topics = selectWeakTopics(
        arcs: const [
          PerformanceArc(
              subject: 'maths', topic: 'Gradients', inSessionPercent: 40),
          PerformanceArc(
              subject: 'maths', topic: 'Trigonometry', inSessionPercent: 85),
        ],
        attendance: [
          record('Probability', AttendanceOutcome.lockedOut),
          record('Probability', AttendanceOutcome.skippedWithoutAnswering),
          // Attended rows never count as missed.
          record('Trigonometry', AttendanceOutcome.attendedOnTime),
          // Skipping WITH a passed assessment is proving you know it.
          record('Sequences', AttendanceOutcome.skippedWithAssessment),
        ],
      );

      expect(topics.map((t) => t.topic),
          isNot(contains('Trigonometry'))); // scored well
      expect(topics.map((t) => t.topic), isNot(contains('Sequences')));
      // Two missed sessions outrank one 40% score (missed lessons never
      // happened at all).
      expect(topics.first.topic, 'Probability');
      expect(topics.first.missedSessions, 2);
      expect(topics.first.latestScorePercent, isNull);
      expect(topics[1].topic, 'Gradients');
      expect(topics[1].latestScorePercent, 40);
    });

    test('the latest evidence wins: a rewatch that fixed the topic clears it',
        () {
      final topics = selectWeakTopics(
        arcs: const [
          PerformanceArc(
              subject: 'maths',
              topic: 'Gradients',
              baselinePercent: 30,
              inSessionPercent: 40,
              revisionPercent: 80),
        ],
        attendance: const [],
      );
      expect(topics, isEmpty);
    });

    test('subject filter scopes the selection', () {
      final topics = selectWeakTopics(
        subject: 'maths',
        arcs: const [
          PerformanceArc(
              subject: 'science', topic: 'Forces', inSessionPercent: 20),
          PerformanceArc(
              subject: 'maths', topic: 'Gradients', inSessionPercent: 20),
        ],
        attendance: const [],
      );
      expect(topics, hasLength(1));
      expect(topics.single.topic, 'Gradients');
    });

    test('limit caps the list worst-first', () {
      final topics = selectWeakTopics(
        limit: 2,
        arcs: const [
          PerformanceArc(subject: 'm', topic: 'A', inSessionPercent: 45),
          PerformanceArc(subject: 'm', topic: 'B', inSessionPercent: 10),
          PerformanceArc(subject: 'm', topic: 'C', inSessionPercent: 30),
        ],
        attendance: const [],
      );
      expect(topics.map((t) => t.topic), ['B', 'C']);
    });

    test('no evidence means no topics — never invent weakness', () {
      expect(selectWeakTopics(arcs: const [], attendance: const []), isEmpty);
    });
  });

  group('HolidayProgrammePlanner', () {
    final termLessons = [
      const HolidayLessonRef(
          sessionId: 'g11-grad',
          subject: 'maths',
          grade: 11,
          topic: 'Gradients'),
      const HolidayLessonRef(
          sessionId: 'g11-trig',
          subject: 'maths',
          grade: 11,
          topic: 'Trigonometry'),
    ];
    final nextGrade = [
      const HolidayLessonRef(
          sessionId: 'g12-calc', subject: 'maths', grade: 12, topic: 'Calculus'),
    ];

    Future<HolidayAssignment> planWith(
      _FakeContent content, {
      SchoolHoliday holiday = SchoolHoliday.term2Break,
      bool personalized = false,
      List<PerformanceArc> arcs = const [],
    }) =>
        HolidayProgrammePlanner(content: content).plan(
          holiday: holiday,
          personalizedCatchUp: personalized,
          subject: 'maths',
          grade: 11,
          termStart: DateTime(2026, 4, 8),
          termEnd: DateTime(2026, 6, 27),
          arcs: arcs,
        );

    test('year-end preview asks for next-grade content', () async {
      final content = _FakeContent(nextGrade: nextGrade, term: termLessons);
      final a = await planWith(content, holiday: SchoolHoliday.yearEnd);
      expect(a.mode, HolidayContentMode.nextGradePreview);
      expect(a.lessons.single.grade, 12);
      expect(content.lastCurrentGrade, 11);
    });

    test('mid-year revision serves the whole term window', () async {
      final content = _FakeContent(term: termLessons);
      final a = await planWith(content);
      expect(a.mode, HolidayContentMode.termRevision);
      expect(a.lessons, hasLength(2));
      expect(content.lastFrom, DateTime(2026, 4, 8));
    });

    test('catch-up narrows term content to the weak topics, with evidence',
        () async {
      final content = _FakeContent(term: termLessons);
      final a = await planWith(content, personalized: true, arcs: const [
        PerformanceArc(
            subject: 'maths', topic: 'Gradients', inSessionPercent: 35),
        PerformanceArc(
            subject: 'maths', topic: 'Trigonometry', inSessionPercent: 90),
      ]);
      expect(a.mode, HolidayContentMode.weakTopicCatchUp);
      expect(a.lessons.single.topic, 'Gradients');
      expect(a.weakTopics.single.latestScorePercent, 35);
    });

    test('a personalized student with no weak evidence gets term revision',
        () async {
      final content = _FakeContent(term: termLessons);
      final a = await planWith(content, personalized: true);
      expect(a.mode, HolidayContentMode.termRevision);
      expect(a.lessons, hasLength(2));
    });

    test('a failing content source degrades to an empty shelf, keeping the '
        'weak topics', () async {
      final content = _FakeContent(throws: true);
      final a = await planWith(content, personalized: true, arcs: const [
        PerformanceArc(
            subject: 'maths', topic: 'Gradients', inSessionPercent: 35),
      ]);
      expect(a.lessons, isEmpty);
      expect(a.weakTopics, hasLength(1));
    });
  });

  group('plan-scoped holiday access (owner 2026-08-14)', () {
    List<HolidayLessonRef> shelf(int count) => [
          for (var i = 0; i < count; i++)
            HolidayLessonRef(
                sessionId: 's$i', subject: 'maths', grade: 11, topic: 't$i'),
        ];

    test('parse maps the server levels and fails OPEN to full', () {
      expect(HolidayAccessLevel.parse('Full'), HolidayAccessLevel.full);
      expect(
          HolidayAccessLevel.parse('First Week'), HolidayAccessLevel.firstWeek);
      expect(HolidayAccessLevel.parse('None'), HolidayAccessLevel.none);
      // Missing field, old server, or a level this build doesn't know —
      // the whole window stays open rather than narrowing on bad data.
      for (final weird in [null, '', 'Fortnight', 0, 1]) {
        expect(HolidayAccessLevel.parse(weird), HolidayAccessLevel.full,
            reason: '$weird');
      }
    });

    test('full keeps the whole shelf', () {
      final lessons = shelf(12);
      expect(lessonsForHolidayAccess(lessons, HolidayAccessLevel.full),
          same(lessons));
    });

    test('first week keeps the first seven days of a day-paced shelf', () {
      final kept =
          lessonsForHolidayAccess(shelf(12), HolidayAccessLevel.firstWeek);
      expect(kept, hasLength(7));
      expect([for (final l in kept) l.sessionId],
          ['s0', 's1', 's2', 's3', 's4', 's5', 's6']);
    });

    test('a shelf shorter than a week is untouched by first-week access',
        () {
      expect(
          lessonsForHolidayAccess(shelf(3), HolidayAccessLevel.firstWeek),
          hasLength(3));
      expect(lessonsForHolidayAccess(const [], HolidayAccessLevel.firstWeek),
          isEmpty);
    });

    test('none keeps nothing', () {
      expect(
          lessonsForHolidayAccess(shelf(5), HolidayAccessLevel.none), isEmpty);
    });
  });
}

class _FakeContent implements HolidayContentSource {
  final List<HolidayLessonRef> nextGrade;
  final List<HolidayLessonRef> term;
  final bool throws;

  int? lastCurrentGrade;
  DateTime? lastFrom;

  _FakeContent(
      {this.nextGrade = const [], this.term = const [], this.throws = false});

  @override
  Future<List<HolidayLessonRef>> nextGradeLessons(
      {required String subject, required int currentGrade}) async {
    if (throws) throw StateError('backend gap');
    lastCurrentGrade = currentGrade;
    return nextGrade;
  }

  @override
  Future<List<HolidayLessonRef>> termLessons(
      {required String subject,
      required int grade,
      required DateTime from,
      required DateTime to}) async {
    if (throws) throw StateError('backend gap');
    lastFrom = from;
    return term;
  }
}
