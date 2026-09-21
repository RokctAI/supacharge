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

// Design strip section 46 — the guided run's DERIVATION, pinned as plain
// Dart. No widget tree, no store, no clock but the one each test hands
// in: every number the runner draws is recomputed from the four step
// fields, and these tests are the proof that the recomputation is right.
//
// What a later edit could quietly undo:
//   * the current step is DERIVED (first not complete), never stored;
//   * remaining time comes from `startedAt` and the wall clock, so a run
//     resumes after a kill with its credit intact;
//   * a blocked step (a running clock) cannot be completed — ruling one;
//   * a confirm-only step (duration 0) is live at once and never
//     auto-completes;
//   * `startedAt` is written once and never rewritten (no pause in v1);
//   * Back re-opens ONE step and keeps its start; Start over is the one
//     destructive act.

import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/application/run/task_run.dart';

final DateTime t0 = DateTime(2026, 9, 2, 8, 0, 0);

DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

Map<String, dynamic> step(
  String title, {
  int seconds = 0,
  bool done = false,
  String? instruction,
  DateTime? started,
  DateTime? completed,
}) => <String, dynamic>{
  'title': title,
  'isDone': done,
  'durationSeconds': seconds,
  if (instruction != null) 'instruction': instruction,
  if (started != null) 'startedAt': started.toIso8601String(),
  if (completed != null) 'completedAt': completed.toIso8601String(),
};

Map<String, dynamic> task(
  List<Map<String, dynamic>> steps, {
  bool sequential = false,
}) => <String, dynamic>{
  'id': 'task-1',
  'title': 'Nine step job',
  'stepsAreSequential': sequential,
  'subtasks': steps,
};

void main() {
  group('the current step is derived, never stored', () {
    test('it is the first step not complete', () {
      final run = TaskRun.fromTask(
        task([step('a', done: true), step('b'), step('c')]),
      );
      expect(run.currentIndex, 1);
      expect(run.currentNumber, 2);
      expect(run.doneCount, 1);
      expect(run.leftCount, 2);
      expect(run.isFinished, isFalse);
    });

    test('a gap counts: an earlier open step is current even after later ones', () {
      final run = TaskRun.fromTask(
        task([step('a'), step('b', done: true), step('c', done: true)]),
      );
      expect(run.currentIndex, 0);
    });

    test('finished when every step is done, and null then', () {
      final run = TaskRun.fromTask(
        task([step('a', done: true), step('b', done: true)]),
      );
      expect(run.isFinished, isTrue);
      expect(run.currentIndex, isNull);
      expect(run.positionLabel, isNull);
    });

    test('an empty task has no run', () {
      final run = TaskRun.fromTask(task(const []));
      expect(run.hasSteps, isFalse);
      expect(run.isFinished, isFalse);
      expect(run.currentIndex, isNull);
    });

    test('"Step N of M" once the run has been touched, and only then', () {
      expect(TaskRun.fromTask(task([step('a'), step('b')])).positionLabel, isNull);
      expect(
        TaskRun.fromTask(task([step('a', done: true), step('b')])).positionLabel,
        'Step 2 of 2',
      );
      expect(
        TaskRun.fromTask(
          task([step('a', seconds: 60, started: t0), step('b')]),
        ).positionLabel,
        'Step 1 of 2',
      );
    });

    test('in progress means touched and not finished — the 859 badge case', () {
      expect(TaskRun.fromTask(task([step('a')])).isInProgress, isFalse);
      expect(TaskRun.fromTask(task([step('a', done: true), step('b')])).isInProgress, isTrue);
      expect(TaskRun.fromTask(task([step('a', done: true)])).isInProgress, isFalse);
    });
  });

  group('the unlock gate', () {
    test('any order: every open step is unlocked', () {
      final run = TaskRun.fromTask(task([step('a'), step('b'), step('c')]));
      expect(run.isUnlocked(0), isTrue);
      expect(run.isUnlocked(2), isTrue);
      expect(run.gateAt(2, t0), StepGate.ready);
    });

    test('in order: only the current step is unlocked', () {
      final run = TaskRun.fromTask(
        task([step('a', done: true), step('b'), step('c')], sequential: true),
      );
      expect(run.isUnlocked(1), isTrue);
      expect(run.isUnlocked(2), isFalse);
      expect(run.gateAt(2, t0), StepGate.locked);
    });

    test('a locked step cannot be started or completed', () {
      final run = TaskRun.fromTask(
        task([step('a'), step('b', seconds: 60)], sequential: true),
      );
      expect(run.canStartAt(1, t0), isFalse);
      expect(run.complete(1, t0).steps[1].isDone, isFalse);
      expect(run.start(1, t0).steps[1].isStarted, isFalse);
    });

    test('a done step is never unlocked, in either mode', () {
      expect(TaskRun.fromTask(task([step('a', done: true)])).isUnlocked(0), isFalse);
      expect(
        TaskRun.fromTask(task([step('a', done: true)], sequential: true)).isUnlocked(0),
        isFalse,
      );
    });

    test('a sequential run has no skip; an any-order run skips to the next open step', () {
      final ordered = TaskRun.fromTask(task([step('a'), step('b')], sequential: true));
      expect(ordered.skipTargetFrom(0), isNull);
      final loose = TaskRun.fromTask(task([step('a'), step('b', done: true), step('c')]));
      expect(loose.skipTargetFrom(0), 2);
      expect(loose.skipTargetFrom(2), isNull);
    });
  });

  group('remaining time comes from timestamps, not a counter', () {
    test('before Start the clock reads the full duration', () {
      final run = TaskRun.fromTask(task([step('wait', seconds: 1800)]));
      expect(run.steps[0].remainingAt(t0), const Duration(minutes: 30));
      expect(run.gateAt(0, t0), StepGate.notStarted);
    });

    test('while running it counts down from startedAt on every read', () {
      final run = TaskRun.fromTask(
        task([step('wait', seconds: 1800, started: t0)]),
      );
      expect(run.steps[0].remainingAt(at(466)), const Duration(seconds: 1334));
      expect(run.gateAt(0, at(466)), StepGate.running);
      expect(run.hasRunningClockAt(at(466)), isTrue);
    });

    test('once the clock has run out Continue is live', () {
      final run = TaskRun.fromTask(
        task([step('wait', seconds: 1800, started: t0)]),
      );
      expect(run.steps[0].remainingAt(at(1800)), Duration.zero);
      expect(run.gateAt(0, at(1800)), StepGate.ready);
      expect(run.gateAt(0, at(99999)), StepGate.ready);
      expect(run.hasRunningClockAt(at(1800)), isFalse);
    });

    test('a step started in the future reads zero elapsed, never negative', () {
      final run = TaskRun.fromTask(
        task([step('wait', seconds: 60, started: at(30))]),
      );
      expect(run.steps[0].elapsedAt(t0), Duration.zero);
      expect(run.steps[0].remainingAt(t0), const Duration(seconds: 60));
    });

    test('RESUME AFTER A KILL: the position and the credit both survive', () {
      // The app was closed with step 2's 30-minute clock started at t0 and
      // step 1 done. Reopened 40 minutes later, from the same map.
      final run = TaskRun.fromTask(
        task([
          step('prepare', done: true, started: at(-60), completed: t0),
          step('wait', seconds: 1800, started: t0),
          step('confirm', seconds: 0),
        ]),
      );
      final later = at(40 * 60);
      expect(run.currentIndex, 1, reason: 'position kept');
      expect(run.steps[1].remainingAt(later), Duration.zero,
          reason: 'the clock ran without the app');
      expect(run.gateAt(1, later), StepGate.ready);
      expect(run.lastTouched, t0);
    });

    test('a reopened step keeps its start, so its credit is not lost', () {
      final run = TaskRun.fromTask(
        task([
          step('wait', seconds: 60, done: true, started: t0, completed: at(60)),
          step('next'),
        ]),
      );
      final reopened = run.back(1);
      expect(reopened.steps[0].isDone, isFalse);
      expect(reopened.steps[0].completedAt, isNull);
      expect(reopened.steps[0].startedAt, t0, reason: 'startedAt is written once');
      expect(reopened.gateAt(0, at(60)), StepGate.ready);
    });
  });

  group('ruling one: a blocked step cannot be skipped', () {
    test('complete() refuses while the clock runs and the step stays open', () {
      final run = TaskRun.fromTask(
        task([step('wait', seconds: 1800, started: t0), step('next')]),
      );
      final attempt = run.complete(0, at(10));
      expect(attempt.steps[0].isDone, isFalse);
      expect(attempt.steps[0].completedAt, isNull);
      expect(identical(attempt, run), isTrue);
    });

    test('and accepts the moment it has run out', () {
      final run = TaskRun.fromTask(
        task([step('wait', seconds: 1800, started: t0), step('next')]),
      );
      final done = run.complete(0, at(1800));
      expect(done.steps[0].isDone, isTrue);
      expect(done.steps[0].completedAt, at(1800));
      expect(done.currentIndex, 1);
    });
  });

  group('the confirm-only step', () {
    test('duration 0 has no clock: Continue is live at once', () {
      final run = TaskRun.fromTask(task([step('confirm')]));
      expect(run.steps[0].isTimed, isFalse);
      expect(run.gateAt(0, t0), StepGate.ready);
      expect(run.canStartAt(0, t0), isFalse, reason: 'nothing to start');
      expect(run.canCompleteAt(0, t0), isTrue);
    });

    test('it NEVER auto-completes — only a complete() call completes it', () {
      final run = TaskRun.fromTask(task([step('confirm')]));
      expect(run.steps[0].isDone, isFalse);
      expect(run.steps[0].clockElapsedAt(at(999999)), isTrue);
      expect(run.gateAt(0, at(999999)), StepGate.ready);
      expect(run.isFinished, isFalse);
      expect(run.currentIndex, 0, reason: 'still the current step, however long it waits');
      final done = run.complete(0, at(5));
      expect(done.steps[0].isDone, isTrue);
      expect(done.steps[0].startedAt, at(5), reason: 'stamped as started when confirmed');
      expect(done.steps[0].completedAt, at(5));
      expect(done.isFinished, isTrue);
    });

    test('a timed step never auto-completes either: the clock running out is not done', () {
      final run = TaskRun.fromTask(task([step('wait', seconds: 60, started: t0)]));
      expect(run.steps[0].clockElapsedAt(at(60)), isTrue);
      expect(run.steps[0].isDone, isFalse);
      expect(run.isFinished, isFalse);
    });
  });

  group('startedAt is written once — no pause in v1', () {
    test('start() on a started step changes nothing', () {
      final run = TaskRun.fromTask(task([step('wait', seconds: 60, started: t0)]));
      final again = run.start(0, at(30));
      expect(again.steps[0].startedAt, t0);
    });

    test('start() on an unstarted timed step stamps it and nothing else', () {
      final run = TaskRun.fromTask(task([step('wait', seconds: 60), step('b')]));
      final started = run.start(0, at(5));
      expect(started.steps[0].startedAt, at(5));
      expect(started.steps[0].isDone, isFalse);
      expect(started.steps[1].startedAt, isNull);
      expect(started.isStarted, isTrue);
    });
  });

  group('Back moves one step; Start over is the one destructive act', () {
    test('back re-opens the most recently completed step before the focus', () {
      final run = TaskRun.fromTask(
        task([
          step('a', done: true, completed: at(1)),
          step('b', done: true, completed: at(2)),
          step('c'),
        ]),
      );
      final back = run.back(2);
      expect(back.steps[1].isDone, isFalse);
      expect(back.steps[0].isDone, isTrue, reason: 'ONE step, not all');
      expect(back.currentIndex, 1);
      expect(run.back(0), same(run), reason: 'nothing before the first step');
    });

    test('restart clears progress and keeps the procedure', () {
      final run = TaskRun.fromTask(
        task([
          step('a', seconds: 60, instruction: 'Do a.', done: true, started: t0, completed: at(60)),
          step('b', seconds: 30, started: at(60)),
        ], sequential: true),
      );
      final fresh = run.restart();
      expect(fresh.isStarted, isFalse);
      expect(fresh.sequential, isTrue);
      expect(fresh.steps[0].instruction, 'Do a.');
      expect(fresh.steps[0].durationSeconds, 60);
      expect(fresh.steps[0].startedAt, isNull);
      expect(fresh.steps[0].completedAt, isNull);
      expect(fresh.steps[1].startedAt, isNull);
    });

    test('freshCopy strips a subtask map of its progress only', () {
      final copy = TaskRunStep.freshCopy(
        step('a', seconds: 60, instruction: 'Do a.', done: true, started: t0, completed: at(60)),
      );
      expect(copy['isDone'], isFalse);
      expect(copy.containsKey('startedAt'), isFalse);
      expect(copy.containsKey('completedAt'), isFalse);
      expect(copy['instruction'], 'Do a.');
      expect(copy['durationSeconds'], 60);
    });
  });

  group('focus after a move', () {
    test('nextOpenFrom lands on the next open step, else the first open one', () {
      final run = TaskRun.fromTask(
        task([step('a'), step('b', done: true), step('c'), step('d', done: true)]),
      );
      expect(run.nextOpenFrom(1), 2);
      expect(run.nextOpenFrom(3), 0);
      expect(TaskRun.fromTask(task([step('a', done: true)])).nextOpenFrom(0), isNull);
    });

    test('previousDoneBefore finds the nearest completed step behind', () {
      final run = TaskRun.fromTask(
        task([step('a', done: true), step('b'), step('c', done: true), step('d')]),
      );
      expect(run.previousDoneBefore(3), 2);
      expect(run.previousDoneBefore(1), 0);
      expect(run.previousDoneBefore(0), isNull);
    });
  });

  group('the map round trip', () {
    test('both vocabularies read, one is written', () {
      final fromServer = TaskRunStep.fromMap(<String, dynamic>{
        'subject': 'Wait',
        'is_done': 1,
        'instruction': 'Slowly.',
        'duration_seconds': '90',
        'started_at': '2026-09-02 08:00:00',
        'completed_at': '2026-09-02 08:01:30',
      });
      expect(fromServer.title, 'Wait');
      expect(fromServer.isDone, isTrue);
      expect(fromServer.durationSeconds, 90);
      expect(fromServer.startedAt, DateTime(2026, 9, 2, 8, 0, 0));
      final map = fromServer.toMap();
      expect(map['title'], 'Wait');
      expect(map['isDone'], isTrue);
      expect(map['durationSeconds'], 90);
      expect(map['instruction'], 'Slowly.');
      expect(map['startedAt'], DateTime(2026, 9, 2, 8, 0, 0).toIso8601String());
      expect(map.containsKey('subject'), isFalse);
    });

    test('absent timestamps stay absent, not null', () {
      final map = TaskRunStep.fromMap(step('a')).toMap();
      expect(map.containsKey('startedAt'), isFalse);
      expect(map.containsKey('completedAt'), isFalse);
      expect(map.containsKey('instruction'), isFalse);
      expect(map['durationSeconds'], 0);
    });

    test('bad values degrade: negative or unreadable duration is 0, bad dates are null', () {
      final s = TaskRunStep.fromMap(<String, dynamic>{
        'title': 'x',
        'durationSeconds': -5,
        'startedAt': 'not a date',
      });
      expect(s.durationSeconds, 0);
      expect(s.startedAt, isNull);
      expect(TaskRunStep.fromMap(<String, dynamic>{'title': 'x', 'durationSeconds': 'abc'}).durationSeconds, 0);
    });

    test('applyTo writes the steps back onto the task and touches nothing else', () {
      final source = task([step('a'), step('b')])..['priority'] = 'High';
      final run = TaskRun.fromTask(source).complete(0, t0);
      final out = run.applyTo(source);
      expect(out['priority'], 'High');
      expect(out['id'], 'task-1');
      expect((out['subtasks'] as List).length, 2);
      expect((out['subtasks'] as List)[0]['isDone'], isTrue);
      expect(source['subtasks'][0]['isDone'], isFalse, reason: 'the source map is not mutated');
    });

    test('the sequential flag reads in either vocabulary', () {
      expect(TaskRun.fromTask(<String, dynamic>{'steps_are_sequential': 1, 'subtasks': []}).sequential, isTrue);
      expect(TaskRun.fromTask(<String, dynamic>{'stepsAreSequential': true, 'subtasks': []}).sequential, isTrue);
      expect(TaskRun.fromTask(<String, dynamic>{'subtasks': []}).sequential, isFalse);
    });
  });

  group('the clock strings', () {
    test('m:ss below an hour, h:mm:ss from an hour', () {
      expect(formatRunClock(const Duration(seconds: 1334)), '22:14');
      expect(formatRunClock(const Duration(seconds: 5)), '0:05');
      expect(formatRunClock(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
      expect(formatRunClock(const Duration(seconds: -4)), '0:00');
    });

    test('durations read as people say them', () {
      expect(formatRunDuration(const Duration(seconds: 45)), '45 s');
      expect(formatRunDuration(const Duration(minutes: 30)), '30 min');
      expect(formatRunDuration(const Duration(hours: 1)), '1 h');
      expect(formatRunDuration(const Duration(hours: 1, minutes: 30)), '1 h 30 min');
    });
  });
}
