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

void main() {
  // A Monday evening: the completed session was today's 17:00 airing.
  final done17 = DateTime(2026, 7, 20, 17, 0);
  final after = done17.add(const Duration(hours: 1)); // prompt at ~18:00

  ScheduledSession airing(
    String id, {
    String? lessonId,
    String subject = 'Maths',
    String topic = 'Quadratic equations',
    String tutor = 'Grandmaster',
    required DateTime start,
    List<String> requiresSkills = const [],
  }) =>
      ScheduledSession(
        sessionId: id,
        lessonId: lessonId,
        subject: subject,
        topic: topic,
        tutorName: tutor,
        startTime: start,
        requiresSkills: requiresSkills,
      );

  // Tomorrow's Maths lesson, three airings (one lesson : one day : three
  // airings), plus an earlier Physics lesson the student is eligible for.
  final tue = DateTime(2026, 7, 21);
  List<ScheduledSession> feed({List<String> requiresSkills = const []}) => [
        airing('m17', lessonId: 'L2', start: tue.add(const Duration(hours: 17)), requiresSkills: requiresSkills),
        airing('m1830',
            lessonId: 'L2',
            start: tue.add(const Duration(hours: 18, minutes: 30)),
            requiresSkills: requiresSkills),
        airing('m20', lessonId: 'L2', start: tue.add(const Duration(hours: 20)), requiresSkills: requiresSkills),
        airing('p17',
            lessonId: 'P1',
            subject: 'Physical Sciences',
            topic: 'Vectors',
            tutor: 'Big John',
            start: done17.add(const Duration(hours: 3))), // tonight, sooner
      ];

  group('NextLessonResolver', () {
    test('same subject wins even when an alternate subject airs sooner', () {
      final c = NextLessonResolver.resolve(feed(),
          subject: 'Maths', excludeSessionId: 'done', after: after);
      expect(c!.sameSubject, isTrue);
      expect(c.session.sessionId, 'm17', reason: 'earliest Maths airing');
    });

    test('falls back to an eligible alternate subject when none upcoming', () {
      final onlyPhysics =
          feed().where((s) => s.subject != 'Maths').toList();
      final c = NextLessonResolver.resolve(onlyPhysics,
          subject: 'Maths', excludeSessionId: 'done', after: after);
      expect(c!.sameSubject, isFalse);
      expect(c.session.sessionId, 'p17');
    });

    test('preferred slot picks that airing of the same lesson-day', () {
      final c = NextLessonResolver.resolve(feed(),
          subject: 'Maths',
          excludeSessionId: 'done',
          after: after,
          preferredSlot: '18:30');
      expect(c!.session.sessionId, 'm1830',
          reason: "the student's own slot, not the generic earliest");
    });

    test('unknown preference keeps the earliest airing', () {
      final c = NextLessonResolver.resolve(feed(),
          subject: 'Maths',
          excludeSessionId: 'done',
          after: after,
          preferredSlot: '19:15');
      expect(c!.session.sessionId, 'm17');
    });

    test('excludes the completed session, past airings, and skill lessons',
        () {
      final sessions = [
        airing('done', lessonId: 'L1', start: done17),
        ScheduledSession(
          sessionId: 'skill',
          subject: 'Maths',
          topic: 'Factorisation',
          tutorName: 'Grandmaster',
          startTime: after.add(const Duration(hours: 1)),
          isSkillLesson: true,
        ),
      ];
      expect(
          NextLessonResolver.resolve(sessions,
              subject: 'Maths', excludeSessionId: 'done', after: after),
          isNull);
    });
  });

  group('NextLessonPromptNotifier', () {
    final intents = <(String, bool)>[];
    NextLessonPromptNotifier build({
      List<ScheduledSession>? sessions,
      SkillLessonSource? skills,
      Future<bool> Function(String)? isSkillReviewed,
      SlotPreferenceStore? slotPreference,
    }) {
      intents.clear();
      return NextLessonPromptNotifier(NextLessonPromptDeps(
        sessionId: 'done',
        upcoming: () async => sessions ?? feed(),
        resolveSubject: () async => 'Maths',
        skills: skills,
        isSkillReviewed: isSkillReviewed,
        slotPreference: slotPreference,
        recordIntent: (id, will) async => intents.add((id, will)),
        now: () => after,
      ));
    }

    test('init resolves the candidate and asks', () async {
      final n = build(slotPreference: _FakeSlotPreference('20:00'));
      await n.init();
      expect(n.state.phase, NextLessonPromptPhase.asking);
      expect(n.state.candidate!.session.sessionId, 'm20');
      n.dispose();
    });

    test('yes surfaces unmet requires_skills (all unmet without a ledger)',
        () async {
      final n = build(
        sessions: feed(requiresSkills: const ['maths.factorisation']),
        skills: _FakeSkills({
          'maths.factorisation': _skill('maths.factorisation'),
        }),
      );
      await n.init();
      await n.confirmAttendance();
      expect(n.state.phase, NextLessonPromptPhase.confirmed);
      expect(n.state.studySkills.map((s) => s.skillRef),
          ['maths.factorisation']);
      n.dispose();
    });

    test('the reviewed-filter hook drops met skills from the study list',
        () async {
      final n = build(
        sessions: feed(
            requiresSkills: const ['maths.factorisation', 'maths.surds']),
        skills: _FakeSkills({
          'maths.factorisation': _skill('maths.factorisation'),
          'maths.surds': _skill('maths.surds'),
        }),
        isSkillReviewed: (ref) async => ref == 'maths.factorisation',
      );
      await n.init();
      await n.confirmAttendance();
      expect(n.state.studySkills.map((s) => s.skillRef), ['maths.surds']);
      n.dispose();
    });

    test('no skill prerequisites → nothing further to show', () async {
      final n = build(skills: _FakeSkills(const {}));
      await n.init();
      await n.confirmAttendance();
      expect(n.state.phase, NextLessonPromptPhase.confirmed);
      expect(n.state.studySkills, isEmpty);
      n.dispose();
    });

    test('yes records a confirmed intent for the candidate airing', () async {
      final n = build();
      await n.init();
      await n.confirmAttendance();
      expect(intents, [('m17', true)]);
      n.dispose();
    });

    test(
        '"can\'t make it" offers the other same-day airings BEFORE any '
        'skip (decision #11.4)', () async {
      final n = build();
      await n.init();
      await n.declinePreferredSlot();
      expect(n.state.phase, NextLessonPromptPhase.timeshift);
      expect(n.state.alternates.map((s) => s.sessionId), ['m1830', 'm20']);
      expect(intents, isEmpty, reason: 'nothing recorded until a choice');
      n.dispose();
    });

    test(
        'choosing a timeshift airing confirms THAT airing and surfaces its '
        'study-ahead skills', () async {
      final n = build(
        sessions: feed(requiresSkills: const ['maths.factorisation']),
        skills: _FakeSkills({
          'maths.factorisation': _skill('maths.factorisation'),
        }),
      );
      await n.init();
      await n.declinePreferredSlot();
      await n.chooseTimeshift(n.state.alternates.first);
      expect(n.state.phase, NextLessonPromptPhase.timeshifted);
      expect(n.state.alternates.single.sessionId, 'm1830');
      expect(intents, [('m1830', true)],
          reason: 'the reminder must target the chosen airing');
      expect(n.state.studySkills.map((s) => s.skillRef),
          ['maths.factorisation']);
      n.dispose();
    });

    test(
        'declining every airing records intent only — skip is last resort '
        'and the skip gate stays untouched', () async {
      final n = build();
      await n.init();
      await n.declinePreferredSlot();
      await n.declineAll();
      expect(n.state.phase, NextLessonPromptPhase.declined);
      expect(intents, [('m17', false)]);
      n.dispose();
    });

    test('no same-day alternates → decline falls straight through', () async {
      // Only one airing of the next lesson exists that day.
      final single = [feed().first];
      final n = build(sessions: single);
      await n.init();
      await n.declinePreferredSlot();
      expect(n.state.phase, NextLessonPromptPhase.declined);
      expect(intents, [('m17', false)]);
      n.dispose();
    });
  });
}

SkillLessonInfo _skill(String ref, {String status = 'evaluated'}) =>
    SkillLessonInfo(
      skillRef: ref,
      cardId: 'card_$ref',
      subject: 'Maths',
      status: status,
      name: ref.split('.').last,
    );

class _FakeSkills implements SkillLessonSource {
  final Map<String, SkillLessonInfo> byRef;
  _FakeSkills(this.byRef);

  @override
  Future<SkillLessonInfo?> lookup(String skillRef) async => byRef[skillRef];

  @override
  Future<List<SkillLessonInfo>> available() async => byRef.values.toList();
}

class _FakeSlotPreference implements SlotPreferenceStore {
  String? slot;
  final List<DateTime> attended = [];
  _FakeSlotPreference([this.slot]);

  @override
  Future<String?> preferred() async => slot;

  @override
  Future<void> recordAttendedAiring(DateTime airingStart) async =>
      attended.add(airingStart);
}
