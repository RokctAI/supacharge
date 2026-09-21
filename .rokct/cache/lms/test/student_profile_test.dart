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
import 'package:lms_sdk/src/common/application/schedule/schedule_notifier.dart'
    show ScheduleStore;

void main() {
  final july = DateTime(2026, 7, 1);

  AttendanceRecord rec(String id, AttendanceOutcome o,
          {int day = 5, List<String> parts = const []}) =>
      AttendanceRecord(
        sessionId: id,
        at: DateTime(2026, 7, day, 15),
        outcome: o,
        partsAttended: parts,
      );

  test('§5 monthly breakdown table math', () {
    final records = [
      for (var i = 0; i < 8; i++)
        rec('on$i', AttendanceOutcome.attendedOnTime, day: i + 1),
      rec('g1', AttendanceOutcome.attendedWithinGrace, day: 9),
      rec('s1', AttendanceOutcome.skippedWithAssessment, day: 10),
      rec('s2', AttendanceOutcome.skippedWithAssessment, day: 11),
      rec('l1', AttendanceOutcome.lockedOut, day: 12),
      // Outside the window: ignored.
      rec('old', AttendanceOutcome.attendedOnTime, day: 5)
          .copyWithAt(DateTime(2026, 6, 5)),
    ];
    final s = AttendanceSummary.over(records, july, DateTime(2026, 8, 1));
    expect(s.scheduled, 12);
    expect(s.attended, 9);
    expect(s.attendedOnTime, 8);
    expect(s.attendedWithinGrace, 1);
    expect(s.skippedWithAssessment, 2);
    expect(s.skippedWithoutAnswering, 0);
    expect(s.lockedOut, 1);
    expect(s.attendanceRatePercent, 75); // the doc's exact table
  });

  test('attendance merge: parts accumulate, attendance never downgrades',
      () async {
    final store = ProfileStore(kv: _MemStore());
    await store.recordAttendance(rec('s1',
        AttendanceOutcome.attendedOnTime, parts: ['Grandmaster']));
    // Second tutor part of the same lesson: Present (Both).
    await store.recordAttendance(rec('s1',
        AttendanceOutcome.attendedWithinGrace, parts: ['Big John']));
    var records = await store.attendance();
    expect(records.single.partsAttended.toSet(), {'Grandmaster', 'Big John'});
    expect(records.single.outcome, AttendanceOutcome.attendedOnTime,
        reason: 'attended outcome kept over the later grace record');
    // A skip record after attendance never downgrades it.
    await store
        .recordAttendance(rec('s1', AttendanceOutcome.skippedWithAssessment));
    records = await store.attendance();
    expect(records.single.outcome, AttendanceOutcome.attendedOnTime);
  });

  test('data usage estimate: ~1KB/s of sync traffic, TikTok comparison', () {
    // A 30-minute session ≈ 1.76mb — the "local assets are free" story.
    final mb = DataUsageRecord.estimateMb(1800);
    expect(mb, closeTo(1.76, 0.01));
    expect(mb < DataUsageRecord.tiktokVideoMb, isTrue);
  });

  test('profile composes from existing ledgers without re-tracking',
      () async {
    final kv = _MemStore();
    final store = ProfileStore(kv: kv);
    final library = LibraryStore(kv: kv);

    // Everything is pinned inside July 2026 and the notifier's clock is
    // injected below, so the month-window math cannot depend on the wall
    // clock of the machine running the tests.
    await store.recordAttendance(rec('s1', AttendanceOutcome.attendedOnTime));
    await store.recordDataUsage(DataUsageRecord(
        sessionId: 's1', at: DateTime(2026, 7, 15), megabytes: 4.2));
    await store.recordReaction(ReactionEvent(
        emoji: kLessonReactionEmojis.first, at: DateTime(2026, 7, 15)));
    final attendedAt = DateTime(2026, 7, 18, 15);
    await library.recordAttended(LibraryEntry(
      sessionId: 's1',
      subject: 'Maths',
      topic: 'Quadratics',
      tutorName: 'Grandmaster',
      attendedAt: attendedAt,
      recordingAvailableAt: LibraryEntry.defaultRecordingUnlock(attendedAt),
      baselineScore: 40,
      postScore: 80,
    ));

    final n = ProfileNotifier(
        store: store, library: library, now: () => DateTime(2026, 7, 20));
    await n.init();
    expect(n.state.summary.attendedOnTime, 1);
    expect(n.state.monthUsageMb, closeTo(4.2, 0.001));
    expect(n.state.monthSessionCount, 1);
    expect(n.state.reactionCounts[kLessonReactionEmojis.first], 1);
    final arc = n.state.arcs.single;
    expect(arc.baselinePercent, 40);
    expect(arc.inSessionPercent, 80);
    expect(arc.improved, isTrue);
    n.dispose();
  });

  test('engagement tally counts answers and reactions', () {
    const tally = EngagementTally(answers: 8, reactions: 3);
    expect(tally.total, 11);
  });
}

extension on AttendanceRecord {
  AttendanceRecord copyWithAt(DateTime newAt) => AttendanceRecord(
        sessionId: sessionId,
        lessonId: lessonId,
        subject: subject,
        topic: topic,
        at: newAt,
        outcome: outcome,
        partsAttended: partsAttended,
      );
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
