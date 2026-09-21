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

// Design strip section 47 on the runner's DERIVATION — the reading gate
// (47h), the optional step's Skip (47i) and the overnight clock (47c),
// pinned as plain Dart with an injected clock, like task_run_test.dart.
//
// What a later edit could quietly undo:
//   * a reading step is blocked by DATA — empty or out of spec — and the
//     refusal names the value in the frame's words;
//   * an out-of-spec reading opens only by re-testing or by a note that
//     says why; never by a flag;
//   * Skip completes an OPTIONAL step only; a required one has no Skip;
//   * the clock keeps running without the app: a step started at night
//     reads as run out the next morning from its timestamp alone;
//   * a plain step's map is exactly section 46's — the new keys are
//     written only when they say something — and freshCopy / Start over
//     strip what was recorded;
//   * a pull keeps the device-only step keys the server does not carry.

import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/application/run/task_run.dart';
import 'package:productivity_sdk/src/common/models/response/task_response.dart';

final DateTime night = DateTime(2026, 9, 4, 22, 0, 0);

Map<String, dynamic> reading(String label, {num? min, num? max, String? value}) =>
    ReadingSpec(label: label, unit: 'ppm', min: min, max: max, value: value)
        .toMap();

Map<String, dynamic> task(
  List<Map<String, dynamic>> steps, {
  bool sequential = true,
}) => <String, dynamic>{
  'id': 'task-1',
  'title': 'Service',
  'stepsAreSequential': sequential,
  'subtasks': steps,
};

Map<String, dynamic> readingStep({List<Map<String, dynamic>>? readings, String? note}) =>
    <String, dynamic>{
      'title': 'Readings',
      'isDone': false,
      'durationSeconds': 0,
      'kind': 'reading',
      'readings': readings ?? <Map<String, dynamic>>[reading('TDS — permeate', max: 50)],
      if (note != null) 'note': note,
    };

Map<String, dynamic> photoStep({bool optional = true}) => <String, dynamic>{
  'title': 'Photo & notes',
  'isDone': false,
  'durationSeconds': 0,
  'kind': 'photo',
  'optional': optional,
};

void main() {
  group('47h — the reading gate', () {
    test('an empty reading blocks: incomplete, not ready, and says which', () {
      final run = TaskRun.fromTask(task([readingStep()]));
      expect(run.gateAt(0, night), StepGate.incomplete);
      expect(run.canCompleteAt(0, night), isFalse);
      expect(run.steps[0].refusal, 'TDS — permeate has no value yet');
      expect(run.complete(0, night).isFinished, isFalse, reason: 'refused');
    });

    test('out of spec blocks, in the frame\'s words', () {
      final run = TaskRun.fromTask(task([readingStep()])).recordReading(0, 0, '212');
      expect(run.steps[0].readings[0].status, ReadingStatus.outOfSpec);
      expect(run.gateAt(0, night), StepGate.incomplete);
      expect(run.steps[0].refusal, 'TDS — permeate 212 ppm is outside ≤ 50 ppm');
    });

    test('in spec is ready, and Finish then completes it', () {
      final run = TaskRun.fromTask(task([readingStep()])).recordReading(0, 0, '40');
      expect(run.gateAt(0, night), StepGate.ready);
      expect(run.complete(0, night).isFinished, isTrue);
    });

    test('a note explaining an out-of-spec value is the route out', () {
      TaskRun run = TaskRun.fromTask(task([readingStep()])).recordReading(0, 0, '212');
      expect(run.gateAt(0, night), StepGate.incomplete);
      run = run.recordNote(0, 'Re-tested twice; brine tank was low.');
      expect(run.gateAt(0, night), StepGate.ready);
      expect(run.steps[0].refusal, isNull);
    });

    test('every reading must be present; the first unmet one is named', () {
      final run = TaskRun.fromTask(
        task([
          readingStep(readings: [
            reading('TDS — feed', max: 400, value: '175'),
            reading('Pressure — feed', min: 6.0, max: 10.0),
          ]),
        ]),
      );
      expect(run.steps[0].firstUnmetReading?.label, 'Pressure — feed');
      expect(run.recordReading(0, 1, '5.2').steps[0].refusal,
          'Pressure — feed 5.2 ppm is outside 6.0–10.0 ppm');
      expect(run.recordReading(0, 1, '8.4').gateAt(0, night), StepGate.ready);
    });

    test('the spec prints as the frame draws it', () {
      expect(const ReadingSpec(label: 'a', max: 400).specLabel, '≤ 400');
      expect(const ReadingSpec(label: 'a', max: 50).specLabel, '≤ 50');
      expect(const ReadingSpec(label: 'a', min: 6.0, max: 10.0).specLabel, '6.0–10.0');
      expect(const ReadingSpec(label: 'a', min: 1.0).specLabel, '≥ 1.0');
      expect(const ReadingSpec(label: 'a').specLabel, '');
    });

    test('a date reading is satisfied by a date and nothing else', () {
      const ReadingSpec spec = ReadingSpec(label: 'Installed on', isDate: true);
      expect(spec.status, ReadingStatus.empty);
      expect(spec.withValue('yesterday').status, ReadingStatus.empty);
      expect(spec.withValue('2026-03-14').status, ReadingStatus.inSpec);
      expect(spec.withValue('2026-03-14').date, DateTime(2026, 3, 14));
    });

    test('a value may be typed while the clock still blocks the step', () {
      final run = TaskRun.fromTask(
        task([
          <String, dynamic>{...readingStep(), 'durationSeconds': 120},
        ]),
      ).start(0, night).recordReading(0, 0, '40');
      expect(run.steps[0].readings[0].value, '40');
      expect(run.gateAt(0, night.add(const Duration(seconds: 30))), StepGate.running);
      expect(run.gateAt(0, night.add(const Duration(seconds: 120))), StepGate.ready);
    });

    test('a locked step takes no reading', () {
      final run = TaskRun.fromTask(
        task([<String, dynamic>{'title': 'First', 'isDone': false}, readingStep()]),
      );
      expect(run.recordReading(1, 0, '40').steps[1].readings[0].hasValue, isFalse);
    });
  });

  group('47i — the optional step and its Skip', () {
    test('an optional step can be skipped; Skip completes it as skipped', () {
      final run = TaskRun.fromTask(task([photoStep()]));
      expect(run.canSkipAt(0), isTrue);
      expect(run.gateAt(0, night), StepGate.ready, reason: 'a photo never blocks');
      final next = run.skip(0, night);
      expect(next.isFinished, isTrue);
      expect(next.steps[0].skipped, isTrue);
      expect(next.steps[0].completedAt, night);
    });

    test('Finish works on it without a photo, and is not a skip', () {
      final next = TaskRun.fromTask(task([photoStep()])).complete(0, night);
      expect(next.isFinished, isTrue);
      expect(next.steps[0].skipped, isFalse);
    });

    test('a required step has no Skip, and skip() refuses it', () {
      final run = TaskRun.fromTask(task([photoStep(optional: false)]));
      expect(run.canSkipAt(0), isFalse);
      expect(run.skip(0, night).isFinished, isFalse);
      final required = TaskRun.fromTask(task([readingStep()]));
      expect(required.canSkipAt(0), isFalse);
    });

    test('a locked optional step cannot be skipped ahead of its turn', () {
      final run = TaskRun.fromTask(
        task([<String, dynamic>{'title': 'First', 'isDone': false}, photoStep()]),
      );
      expect(run.canSkipAt(1), isFalse);
    });

    test('Back re-opens a skipped step as open, not skipped', () {
      final run = TaskRun.fromTask(
        task([photoStep(), <String, dynamic>{'title': 'After', 'isDone': false}]),
      ).skip(0, night);
      final back = run.back(1);
      expect(back.steps[0].isDone, isFalse);
      expect(back.steps[0].skipped, isFalse);
    });

    test('the photo is a path string, kept until removed', () {
      TaskRun run = TaskRun.fromTask(task([photoStep()]));
      run = run.recordValue(0, '/storage/pictures/vessel-head.jpg');
      expect(run.steps[0].value, '/storage/pictures/vessel-head.jpg');
      run = run.recordNote(0, 'Seal weeping slightly.');
      expect(run.steps[0].note, 'Seal weeping slightly.');
      expect(run.recordValue(0, null).steps[0].hasValue, isFalse);
    });
  });

  group('47c — the clock keeps running without the app', () {
    test('a step started at night has run out by morning, from its stamp alone', () {
      // Stabilization, 2 minutes, started 22:00; the app is killed.
      final run = TaskRun.fromTask(
        task([
          <String, dynamic>{
            'title': 'Stabilization',
            'isDone': false,
            'durationSeconds': 120,
            'startedAt': night.toIso8601String(),
          },
        ]),
      );
      final morning = DateTime(2026, 9, 5, 7, 0, 0);
      expect(run.gateAt(0, night.add(const Duration(seconds: 90))), StepGate.running);
      expect(run.gateAt(0, morning), StepGate.ready);
      expect(run.steps[0].remainingAt(morning), Duration.zero);
      expect(run.steps[0].elapsedAt(morning), const Duration(hours: 9));
      expect(run.hasRunningClockAt(morning), isFalse, reason: 'no ticker to arm');
      expect(run.canCompleteAt(0, morning), isTrue);
    });

    test('a thirty-minute rinse: blocked at 22:14, open at 22:30, open at dawn', () {
      final run = TaskRun.fromTask(
        task([
          <String, dynamic>{
            'title': 'Brine and Slow Rinse',
            'isDone': false,
            'durationSeconds': 1800,
            'startedAt': night.toIso8601String(),
          },
        ]),
      );
      final DateTime later = night.add(const Duration(minutes: 7, seconds: 46));
      expect(run.gateAt(0, later), StepGate.running);
      expect(formatRunClock(run.steps[0].remainingAt(later)), '22:14');
      expect(run.gateAt(0, night.add(const Duration(minutes: 30))), StepGate.ready);
      expect(run.gateAt(0, DateTime(2026, 9, 5, 6, 30)), StepGate.ready);
    });

    test('the run re-read from its maps lands on the same step, credit intact', () {
      final TaskRun before = TaskRun.fromTask(
        task([
          <String, dynamic>{'title': 'Initial Check', 'isDone': false},
          <String, dynamic>{'title': 'Stabilization', 'isDone': false, 'durationSeconds': 120},
        ]),
      ).complete(0, night).start(1, night.add(const Duration(minutes: 1)));
      final Map<String, dynamic> saved = before.applyTo(task(const []));
      final TaskRun after = TaskRun.fromTask(saved);
      final morning = DateTime(2026, 9, 5, 7, 0, 0);
      expect(after.currentIndex, 1);
      expect(after.positionLabel, 'Step 2 of 2');
      expect(after.gateAt(1, morning), StepGate.ready);
    });
  });

  group('the maps', () {
    test('a plain step writes exactly section 46\'s keys', () {
      final map = TaskRunStep.fromMap(<String, dynamic>{
        'title': 'Backwash',
        'durationSeconds': 600,
      }).toMap();
      expect(map.keys.toSet(), <String>{'title', 'isDone', 'durationSeconds'});
    });

    test('kind, optional, readings, value, note and skipped round-trip', () {
      final Map<String, dynamic> saved = TaskRun.fromTask(
        task([readingStep(), photoStep()]),
      )
          .recordReading(0, 0, '40')
          .recordNote(0, 'fine')
          .complete(0, night)
          .recordValue(1, '/p/vessel.jpg')
          .skip(1, night)
          .applyTo(task(const []));
      final TaskRun again = TaskRun.fromTask(saved);
      expect(again.steps[0].kind, StepKind.reading);
      expect(again.steps[0].readings[0].value, '40');
      expect(again.steps[0].readings[0].max, 50);
      expect(again.steps[0].note, 'fine');
      expect(again.steps[1].kind, StepKind.photo);
      expect(again.steps[1].optional, isTrue);
      expect(again.steps[1].value, '/p/vessel.jpg');
      expect(again.steps[1].skipped, isTrue);
      expect(again.isFinished, isTrue);
    });

    test('an unknown kind reads as plain', () {
      expect(TaskRunStep.fromMap(<String, dynamic>{'title': 'x', 'kind': 'video'}).kind,
          StepKind.plain);
    });

    test('freshCopy keeps the spec and strips what was recorded', () {
      final Map<String, dynamic> saved = TaskRun.fromTask(task([readingStep(), photoStep()]))
          .recordReading(0, 0, '212')
          .recordNote(0, 'why')
          .recordValue(1, '/p/x.jpg')
          .skip(1, night)
          .applyTo(task(const []));
      final List<Map<String, dynamic>> fresh = <Map<String, dynamic>>[
        for (final Object? row in saved['subtasks'] as List)
          TaskRunStep.freshCopy((row as Map).cast<String, dynamic>()),
      ];
      final TaskRunStep readings = TaskRunStep.fromMap(fresh[0]);
      final TaskRunStep photo = TaskRunStep.fromMap(fresh[1]);
      expect(readings.kind, StepKind.reading);
      expect(readings.readings[0].max, 50);
      expect(readings.readings[0].hasValue, isFalse);
      expect(readings.hasNote, isFalse);
      expect(photo.optional, isTrue);
      expect(photo.hasValue, isFalse);
      expect(photo.skipped, isFalse);
      expect(photo.isDone, isFalse);
    });

    test('Start over clears readings, photo, note and skipped', () {
      final TaskRun reset = TaskRun.fromTask(task([readingStep(), photoStep()]))
          .recordReading(0, 0, '40')
          .complete(0, night)
          .skip(1, night)
          .restart();
      expect(reset.isStarted, isFalse);
      expect(reset.steps[0].readings[0].hasValue, isFalse);
      expect(reset.steps[1].skipped, isFalse);
      expect(reset.steps[0].readings[0].max, 50, reason: 'the spec is procedure');
    });
  });

  group('a pull keeps the device-only step keys', () {
    test('same step by title at the same position: kind, readings, value survive', () {
      final Map<String, dynamic> device = TaskRun.fromTask(task([readingStep(), photoStep()]))
          .recordReading(0, 0, '40')
          .applyTo(task(const []));
      final TaskResponse pulled = TaskResponse.fromMap(<String, dynamic>{
        'name': 'TASK-1',
        'client_id': 'c-1',
        'subject': 'Service',
        'subtasks': <Map<String, dynamic>>[
          <String, dynamic>{'subject': 'Readings', 'is_done': 0, 'duration_seconds': 0},
          <String, dynamic>{'subject': 'Photo & notes', 'is_done': 0, 'duration_seconds': 0},
        ],
      });
      final Map<String, dynamic> merged = pulled.toTodo(existing: device);
      final TaskRun run = TaskRun.fromTask(merged);
      expect(run.steps[0].kind, StepKind.reading);
      expect(run.steps[0].readings[0].value, '40');
      expect(run.steps[1].optional, isTrue);
    });

    test('a different step at that position takes nothing from the device row', () {
      final Map<String, dynamic> device = TaskRun.fromTask(task([readingStep()]))
          .applyTo(task(const []));
      final TaskResponse pulled = TaskResponse.fromMap(<String, dynamic>{
        'name': 'TASK-1',
        'client_id': 'c-1',
        'subject': 'Service',
        'subtasks': <Map<String, dynamic>>[
          <String, dynamic>{'subject': 'Backwash', 'is_done': 0, 'duration_seconds': 600},
        ],
      });
      final TaskRun run = TaskRun.fromTask(pulled.toTodo(existing: device));
      expect(run.steps[0].kind, StepKind.plain);
      expect(run.steps[0].readings, isEmpty);
    });
  });
}
