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
  final base = DateTime(2026, 7, 20, 15, 0);
  ScheduledSession session({String id = 's1', DateTime? start}) =>
      ScheduledSession(
        sessionId: id,
        subject: 'Maths',
        topic: 'Quadratic equations',
        tutorName: 'Grandmaster',
        startTime: start ?? base,
        doorCloseSeconds: 300,
      );

  const q = McqQuestion(
      id: 'q1', prompt: 'x?', options: ['a', 'b'], correctIndex: 0);

  ScheduleNotifier build({
    DateTime Function()? now,
    List<McqQuestion> questions = const [q],
    _FakePlanner? planner,
    _MemStore? store,
    ScheduledSession? s,
    _FakeRepo? repository,
  }) {
    return ScheduleNotifier(
      schedule: _FakeSchedule([s ?? session()]),
      questions: _FakeQuestions(questions),
      planner: planner,
      store: store ?? _MemStore(),
      repository: repository,
      now: now ?? () => base.subtract(const Duration(hours: 2)),
    );
  }

  test('door policy: before-open, grace window, locked', () {
    final s = session();
    expect(s.doorStateAt(base.subtract(const Duration(minutes: 1))),
        DoorState.beforeOpen);
    expect(s.doorStateAt(base.add(const Duration(minutes: 4))),
        DoorState.graceOpen);
    expect(s.doorStateAt(base.add(const Duration(minutes: 6))),
        DoorState.locked);
  });

  test('confirming attendance hands out the pre-study assignment (one action)',
      () async {
    final planner = _FakePlanner();
    final n = build(planner: planner);
    await n.init();
    await n.confirmAttendance(n.state.sessions.single);
    expect(n.state.attendance['s1'], AttendanceState.confirmed);
    expect(n.state.assignment, isNotNull);
    expect(n.state.assignment!.questions, hasLength(1));
    await Future<void>.delayed(Duration.zero);
    expect(planner.confirmations, ['s1']);
    n.dispose();
  });

  test('pre-session assessment from the assignment records a baseline score',
      () async {
    final n = build();
    await n.init();
    await n.confirmAttendance(n.state.sessions.single);
    n.startPreAssessment();
    expect(n.state.skipCheck?.purpose,
        KnowledgeCheckPurpose.preSessionAssessment);
    n.answerCheck(0); // correct
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(n.state.skipCheck, isNull);
    expect(n.state.baselineScores['s1'], 100);
    // Optional pre-work never locks anything.
    expect(n.state.appLocked, isFalse);
    n.dispose();
  });

  test('skip gate: answering completes the skip, records score, clears lock',
      () async {
    final planner = _FakePlanner();
    final n = build(planner: planner);
    await n.init();
    await n.requestSkip(n.state.sessions.single);
    expect(n.state.appLocked, isTrue, reason: 'lock registers immediately');
    n.answerCheck(1); // incorrect — still an answer
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(n.state.skipCheck, isNull);
    expect(n.state.appLocked, isFalse);
    expect(n.state.attendance['s1'], AttendanceState.skipped);
    await Future<void>.delayed(Duration.zero);
    expect(planner.skips.single.$1, 's1');
    expect(planner.skips.single.$2, 0); // 0% of answered correct
    n.dispose();
  });

  test('abandoning the skip gate keeps the lock, and it survives restart',
      () async {
    final store = _MemStore();
    final n = build(store: store);
    await n.init();
    await n.requestSkip(n.state.sessions.single);
    n.abandonCheck();
    expect(n.state.skipCheck, isNull);
    expect(n.state.appLocked, isTrue, reason: 'abandoning does not unlock');
    n.dispose();

    // "Restart": a fresh notifier over the same store restores the lock.
    final n2 = build(store: store);
    await n2.init();
    expect(n2.state.appLocked, isTrue);
    n2.dispose();
  });

  test('lock releases automatically once the session time passes', () async {
    final store = _MemStore();
    final n = build(store: store);
    await n.init();
    await n.requestSkip(n.state.sessions.single);
    n.abandonCheck();
    n.dispose();

    // Clock past the session start → restore drops the expired lock.
    final n2 = build(
        store: store, now: () => base.add(const Duration(minutes: 1)));
    await n2.init();
    expect(n2.state.appLocked, isFalse);
    n2.dispose();
  });

  test('skip with no authored questions records freely (nothing to prove)',
      () async {
    final planner = _FakePlanner();
    final n = build(questions: const [], planner: planner);
    await n.init();
    await n.requestSkip(n.state.sessions.single);
    expect(n.state.appLocked, isFalse);
    expect(n.state.attendance['s1'], AttendanceState.skipped);
    n.dispose();
  });

  test(
      'P3.2 backend sync: join syncs Attended, a completed skip gate syncs '
      'the answered/unanswered split the partner report reads', () async {
    final repo = _FakeRepo();
    final n = build(repository: repo);
    await n.init();

    await n.recordJoin(n.state.sessions.single);
    await Future<void>.delayed(Duration.zero);
    expect(repo.events, [('s1', AttendanceEventOutcome.attended)]);

    // Answered skip (wrong answer still counts as answered).
    await n.requestSkip(n.state.sessions.single);
    n.answerCheck(1);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(repo.events.last, ('s1', AttendanceEventOutcome.skippedAnswered));
    n.dispose();
  });

  test(
      'wired ServerClock: the door state a spoofed device clock would flip '
      'stays put; only real elapsed time moves it', () async {
    // Session opens 4 min after true server time.
    final s = session(start: base.add(const Duration(minutes: 4)));
    var wall = base.add(const Duration(hours: 3)); // device clock is spoofed
    var mono = const Duration(seconds: 500);
    final clock = ServerClock(
      fetch: () async => base.toUtc(), // "server" says the true time
      elapsed: () => mono,
      wallClock: () => wall,
    );
    final n = ScheduleNotifier(
      schedule: _FakeSchedule([s]),
      questions: _FakeQuestions(const [q]),
      store: _MemStore(),
      clock: clock, // no `now` → notifier gates on the corrected clock
    );
    await n.init(); // syncs the clock, then computes doors

    expect(n.state.doors['s1'], DoorState.beforeOpen);

    // Spoof the device clock 2h forward and recompute — door must not open.
    wall = wall.add(const Duration(hours: 2));
    await n.refresh();
    expect(n.state.doors['s1'], DoorState.beforeOpen,
        reason: 'device-clock spoof must not open the door');

    // Real monotonic time reaches the window → door opens honestly.
    mono += const Duration(minutes: 4, seconds: 30);
    await n.refresh();
    expect(n.state.doors['s1'], DoorState.graceOpen);
    n.dispose();
  });

  test('P3.2 backend sync: an expired unanswered lock syncs skippedUnanswered',
      () async {
    final store = _MemStore();
    final n = build(store: store);
    await n.init();
    await n.requestSkip(n.state.sessions.single);
    n.abandonCheck();
    n.dispose();

    // Clock past the session start → the released lock is the
    // skipped-without-answering row, synced to the backend.
    final repo = _FakeRepo();
    final n2 = build(
        store: store,
        repository: repo,
        now: () => base.add(const Duration(minutes: 1)));
    await n2.init();
    await Future<void>.delayed(Duration.zero);
    expect(
        repo.events, [('s1', AttendanceEventOutcome.skippedUnanswered)]);
    n2.dispose();
  });
}

/// Captures P3.2 attendance-event syncs; every other LmsRepository member
/// throws if touched (Fake), which is the point — the schedule flow must
/// only ever hit the sync endpoint.
class _FakeRepo extends Fake implements LmsRepository {
  final List<(String, AttendanceEventOutcome)> events = [];

  @override
  Future<void> recordAttendanceEvent({
    required String sessionId,
    required AttendanceEventOutcome outcome,
    double dataUsedMb = 0,
    int? secondsWatched,
    String? sittingId,
  }) async {
    events.add((sessionId, outcome));
  }
}

class _FakeSchedule implements SessionScheduleSource {
  final List<ScheduledSession> sessions;
  _FakeSchedule(this.sessions);

  @override
  Future<List<ScheduledSession>> upcoming() async => sessions;
}

class _FakeQuestions implements SessionQuestionSource {
  final List<McqQuestion> qs;
  _FakeQuestions(this.qs);

  @override
  Future<List<McqQuestion>> questionsForSession(String sessionId) async => qs;
}

class _FakePlanner implements StudyPlanner {
  final List<String> reminders = [];
  final List<String> confirmations = [];
  final List<(String, int)> skips = [];

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
          required int scorePercent}) async =>
      skips.add((sessionId, scorePercent));

  @override
  Future<void> recordAttendanceConfirmation(
          {required String sessionId, required DateTime sessionStart}) async =>
      confirmations.add(sessionId);
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
