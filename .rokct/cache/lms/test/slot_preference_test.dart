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
  // Monday's three airings of one lesson (broadcast model: one lesson :
  // one day : three airings at 17:00, 18:30, 20:00).
  final mon = DateTime(2026, 7, 20);
  DateTime at(int h, [int m = 0]) => mon.add(Duration(hours: h, minutes: m));

  group('KvSlotPreferenceStore (inferred from attendance)', () {
    test('nothing attended yet → no preference', () async {
      final store = KvSlotPreferenceStore(kv: _MemStore(), now: () => at(21));
      expect(await store.preferred(), isNull);
    });

    test('the most-attended slot wins', () async {
      final store = KvSlotPreferenceStore(kv: _MemStore(), now: () => at(21));
      await store.recordAttendedAiring(at(17));
      await store.recordAttendedAiring(at(18, 30));
      await store.recordAttendedAiring(at(18, 30));
      expect(await store.preferred(), '18:30');
    });

    test('ties break toward the most recently attended slot', () async {
      var t = at(21);
      final store = KvSlotPreferenceStore(kv: _MemStore(), now: () => t);
      await store.recordAttendedAiring(at(17));
      t = t.add(const Duration(days: 1));
      await store.recordAttendedAiring(at(20));
      expect(await store.preferred(), '20:00',
          reason: 'seeded by the just-attended airing on a fresh history');
    });

    test('persists across store instances (KV round-trip)', () async {
      final kv = _MemStore();
      await KvSlotPreferenceStore(kv: kv, now: () => at(21))
          .recordAttendedAiring(at(17));
      expect(
          await KvSlotPreferenceStore(kv: kv, now: () => at(22)).preferred(),
          '17:00');
    });
  });

  group('timeshift options (decision #11.4)', () {
    ScheduledSession airing(String id, DateTime start, {String? lessonId}) =>
        ScheduledSession(
          sessionId: id,
          lessonId: lessonId ?? 'L1',
          subject: 'Maths',
          topic: 'Quadratic equations',
          tutorName: 'Grandmaster',
          startTime: start,
        );

    test('offers the OTHER same-day airings of the same lesson, in order',
        () {
      final sessions = [
        airing('a17', at(17)),
        airing('a20', at(20)),
        airing('a1830', at(18, 30)),
        airing('other-day', at(17).add(const Duration(days: 7))),
        airing('other-lesson', at(18, 30), lessonId: 'L2'),
      ];
      final alts = NextLessonResolver.sameDayAlternates(
          sessions, sessions.first, at(16));
      expect(alts.map((s) => s.sessionId), ['a1830', 'a20']);
    });

    test('an airing already past is not offered', () {
      final sessions = [
        airing('a17', at(17)),
        airing('a1830', at(18, 30)),
        airing('a20', at(20)),
      ];
      final alts = NextLessonResolver.sameDayAlternates(
          sessions, sessions.first, at(19));
      expect(alts.map((s) => s.sessionId), ['a20']);
    });

    test('no lessonId to match airings on → no timeshift offer', () {
      final s = ScheduledSession(
        sessionId: 'x',
        subject: 'Maths',
        topic: 'T',
        tutorName: 'G',
        startTime: at(17),
      );
      expect(NextLessonResolver.sameDayAlternates([s, s], s, at(16)), isEmpty);
    });
  });

  group('AttendanceIntentStore', () {
    test('yes lands as a confirmed stance the schedule reads', () async {
      final kv = _MemStore();
      await AttendanceIntentStore(kv: kv).record('s1', willAttend: true);
      final row = await kv.get(ScheduleNotifier.attendanceCollection, 's1');
      expect(row?['state'], AttendanceState.confirmed.name);
    });

    test('no records a decline INTENT only — never a skip stance', () async {
      final kv = _MemStore();
      final store = AttendanceIntentStore(kv: kv);
      await store.record('s1', willAttend: false);
      expect(await store.declined('s1'), isTrue);
      // The attendance collection is untouched: the §3 skip gate still
      // applies at door time exactly as before.
      expect(
          await kv.get(ScheduleNotifier.attendanceCollection, 's1'), isNull);
    });
  });

  test('recordJoin feeds the attended airing into the slot preference',
      () async {
    final slots = _FakeSlotPreference();
    final session = ScheduledSession(
      sessionId: 's1',
      subject: 'Maths',
      topic: 'Quadratic equations',
      tutorName: 'Grandmaster',
      startTime: at(18, 30),
    );
    final n = ScheduleNotifier(
      schedule: _FakeSchedule([session]),
      store: _MemStore(),
      slotPreference: slots,
      now: () => at(18, 30),
    );
    await n.init();
    await n.recordJoin(session);
    await Future<void>.delayed(Duration.zero);
    expect(slots.attended, [at(18, 30)]);
    n.dispose();
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

class _FakeSlotPreference implements SlotPreferenceStore {
  final List<DateTime> attended = [];

  @override
  Future<String?> preferred() async => null;

  @override
  Future<void> recordAttendedAiring(DateTime airingStart) async =>
      attended.add(airingStart);
}
