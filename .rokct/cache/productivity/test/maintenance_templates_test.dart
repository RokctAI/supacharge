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

// Design strip section 47 — the RO plant's service runs as ordinary task
// maps (47a), the timed brine rinse as a clock-gated step (47b), the
// first-run setup gate and the plant record it writes (47d), and where
// the readings and photo steps sit (47h / 47i). Plain Dart: the
// templates are data, the store is handed an in-memory map.
//
// What a later edit could quietly undo:
//   * the stage lists are paas_pos's, in its order, with its durations —
//     nine for a softener, seven for a megaChar, the first four shared;
//   * every duration comes from the ONE map; none is typed twice;
//   * the readings step is REQUIRED and last but one; the photo step is
//     OPTIONAL and last;
//   * nothing but the setup is offered until the plant is described;
//   * due dates are the install date plus the interval, and the vessel
//     service repeats weekly through the task's own recurrence.

import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/application/run/maintenance_plant.dart';
import 'package:productivity_sdk/src/common/application/run/maintenance_templates.dart';
import 'package:productivity_sdk/src/common/application/run/task_run.dart';

final DateTime now = DateTime(2026, 9, 5, 9, 30);

const PlantRecord plant = PlantRecord(
  megaCharVessels: 1,
  softenerVessels: 1,
  membranes: 2,
);

List<String> titles(List<Map<String, dynamic>> steps) =>
    <String>[for (final Map<String, dynamic> s in steps) '${s['title']}'];

Map<String, dynamic> setupTask() => MaintenanceTemplates.build(
  MaintenanceTemplate.plantSetup,
  now: now,
)..['id'] = 'setup-1';

/// A setup run with every required reading filled and completed, the
/// water spec left as [waterSpec] says.
Map<String, dynamic> finishedSetup({bool skipWaterSpec = true, String? permeateTdsMax}) {
  TaskRun run = TaskRun.fromTask(setupTask());
  run = run
      .recordReading(0, 0, '1')
      .recordReading(0, 1, '1')
      .recordReading(0, 2, '2026-03-14')
      .complete(0, now)
      .recordReading(1, 0, '2026-08-20')
      .recordReading(1, 1, '2026-06-01')
      .recordReading(1, 2, '2026-06-01')
      .complete(1, now)
      .recordReading(2, 0, '2')
      .recordReading(2, 1, '2026-01-10')
      .complete(2, now);
  if (skipWaterSpec) {
    run = run.skip(3, now);
  } else {
    if (permeateTdsMax != null) run = run.recordReading(3, 1, permeateTdsMax);
    run = run.complete(3, now);
  }
  return run.applyTo(setupTask());
}

void main() {
  group('47a — the softener regeneration', () {
    final List<Map<String, dynamic>> steps =
        MaintenanceTemplates.steps(MaintenanceTemplate.softenerMaintenance);

    test('eleven steps: the nine stages, then Readings, then Photo & notes', () {
      expect(titles(steps), <String>[
        'Initial Check',
        'Pressure Release',
        'Backwash',
        'Settling',
        'Brine and Slow Rinse',
        'Fast Rinse',
        'Brine Refill',
        'Stabilization',
        'Return to Service',
        'Readings',
        'Photo & notes',
      ]);
    });

    test('every stage carries the one map\'s duration and its instruction', () {
      for (final String stage in kSoftenerStages) {
        final Map<String, dynamic> step =
            steps.firstWhere((Map<String, dynamic> s) => s['title'] == stage);
        expect(step['durationSeconds'], kMaintenanceStageSeconds[stage], reason: stage);
        expect(step['instruction'], kMaintenanceStageInstructions[stage], reason: stage);
      }
      expect(kMaintenanceStageSeconds['Brine and Slow Rinse'], 1800);
      expect(kMaintenanceStageSeconds['Backwash'], 600);
      expect(kMaintenanceStageSeconds['Brine Refill'], 300);
      expect(kMaintenanceStageSeconds['Return to Service'], 0);
      expect(kMaintenanceStageSeconds['Initial Check'], 0);
    });

    test('47b — the brine rinse is a clock-gated step: blocked until it runs out', () {
      final TaskRun run = TaskRun.fromTask(<String, dynamic>{
        'stepsAreSequential': true,
        'subtasks': steps,
      });
      TaskRun r = run;
      for (int i = 0; i < 4; i++) {
        r = r.start(i, now).complete(i, now.add(Duration(seconds: r.steps[i].durationSeconds)));
      }
      expect(r.currentIndex, 4);
      expect(r.steps[4].title, 'Brine and Slow Rinse');
      expect(r.gateAt(4, now), StepGate.notStarted);
      r = r.start(4, now);
      expect(r.gateAt(4, now.add(const Duration(minutes: 7, seconds: 46))), StepGate.running);
      expect(r.complete(4, now.add(const Duration(minutes: 29))).steps[4].isDone, isFalse);
      expect(r.gateAt(4, now.add(const Duration(minutes: 30))), StepGate.ready);
    });

    test('47h — the readings step is required, last but one, four readings', () {
      final TaskRunStep readings = TaskRunStep.fromMap(steps[9]);
      expect(readings.kind, StepKind.reading);
      expect(readings.optional, isFalse);
      expect(readings.isTimed, isFalse);
      expect(
        <String>[for (final ReadingSpec r in readings.readings) r.label],
        <String>['TDS — feed', 'TDS — permeate', 'Pressure — feed', 'Pressure — permeate'],
      );
      expect(readings.readings[0].specWithUnit, '≤ 400 ppm');
      expect(readings.readings[1].specWithUnit, '≤ 50 ppm');
      expect(readings.readings[2].specWithUnit, '6.0–10.0 bar');
      expect(readings.readings[3].specWithUnit, '≥ 1.0 bar');
      expect(readings.instruction, 'Take TDS and pressure before returning to service.');
    });

    test('47i — the photo step is optional and last', () {
      final TaskRunStep photo = TaskRunStep.fromMap(steps.last);
      expect(photo.kind, StepKind.photo);
      expect(photo.optional, isTrue);
      expect(photo.instruction, 'Optional. Skipping does not hold up the run.');
    });

    test('the run is an ordinary task: sequential, weekly, reminded, due today', () {
      final Map<String, dynamic> task = MaintenanceTemplates.build(
        MaintenanceTemplate.softenerMaintenance,
        now: now,
        plant: plant,
      );
      expect(task['title'], 'Softener Maintenance');
      expect(task['template'], 'softener_maintenance');
      expect(task['stepsAreSequential'], isTrue);
      expect(task['recurrence'], 'Weekly');
      expect(task['reminder'], isTrue);
      expect(task['deadline'], DateTime(2026, 9, 5).toIso8601String());
      expect(task['isDone'], isFalse);
      expect(task.containsKey('id'), isFalse, reason: 'the page mints ids');
      expect(kVesselServiceDays, 7, reason: 'the interval Weekly encodes');
    });
  });

  group('the megaChar backwash', () {
    final List<Map<String, dynamic>> steps =
        MaintenanceTemplates.steps(MaintenanceTemplate.megaCharMaintenance);

    test('nine steps: seven stages sharing the softener\'s first four', () {
      expect(titles(steps), <String>[
        'Initial Check',
        'Pressure Release',
        'Backwash',
        'Settling',
        'Fast Wash',
        'Stabilization',
        'Return to Filter',
        'Readings',
        'Photo & notes',
      ]);
      expect(kMegaCharStages.sublist(0, 4), kSoftenerStages.sublist(0, 4));
    });

    test('durations from the one map', () {
      for (final String stage in kMegaCharStages) {
        final Map<String, dynamic> step =
            steps.firstWhere((Map<String, dynamic> s) => s['title'] == stage);
        expect(step['durationSeconds'], kMaintenanceStageSeconds[stage], reason: stage);
      }
      expect(kMaintenanceStageSeconds['Fast Wash'], 600);
      expect(kMaintenanceStageSeconds['Return to Filter'], 0);
    });

    test('every stage either list names is in both maps', () {
      for (final String stage in <String>{...kSoftenerStages, ...kMegaCharStages}) {
        expect(kMaintenanceStageSeconds.containsKey(stage), isTrue, reason: stage);
        expect(kMaintenanceStageInstructions.containsKey(stage), isTrue, reason: stage);
      }
      expect(kMaintenanceStageSeconds.length, 11);
    });
  });

  group('47d — the plant has to be described before it can be serviced', () {
    test('without a record only the setup is offered; with one, everything', () {
      for (final MaintenanceTemplate template in MaintenanceTemplates.all) {
        expect(
          MaintenanceTemplates.isOffered(template, null),
          template == MaintenanceTemplate.plantSetup,
          reason: template.name,
        );
        expect(MaintenanceTemplates.isOffered(template, plant), isTrue);
      }
      expect(MaintenanceTemplates.all.first, MaintenanceTemplate.plantSetup);
    });

    test('the setup run: three required reading steps and an optional water spec', () {
      final List<Map<String, dynamic>> steps =
          MaintenanceTemplates.steps(MaintenanceTemplate.plantSetup);
      expect(titles(steps), <String>['Vessels', 'Filters', 'RO membranes', 'Water spec']);
      for (int i = 0; i < 3; i++) {
        final TaskRunStep step = TaskRunStep.fromMap(steps[i]);
        expect(step.kind, StepKind.reading, reason: step.title);
        expect(step.optional, isFalse, reason: step.title);
      }
      final TaskRunStep water = TaskRunStep.fromMap(steps[3]);
      expect(water.optional, isTrue);
      expect(water.isSatisfied, isTrue, reason: 'pre-filled with the frame\'s limits');
      final TaskRunStep vessels = TaskRunStep.fromMap(steps[0]);
      expect(vessels.readings[0].label, 'MegaChar vessels');
      expect(vessels.readings[0].min, 1);
      expect(vessels.readings[2].isDate, isTrue);
      final Map<String, dynamic> task = MaintenanceTemplates.build(
        MaintenanceTemplate.plantSetup,
        now: now,
      );
      expect(task['template'], 'plant_setup');
      expect(task['stepsAreSequential'], isTrue);
      expect(task['deadline'], isNull);
      expect(task['reminder'], isFalse);
    });

    test('a vessels step with no megaChar cannot finish: the gate is the old one', () {
      final TaskRun run = TaskRun.fromTask(setupTask())
          .recordReading(0, 0, '0')
          .recordReading(0, 1, '1')
          .recordReading(0, 2, '2026-03-14');
      expect(run.steps[0].refusal, 'MegaChar vessels 0 is outside ≥ 1');
      expect(run.gateAt(0, now), StepGate.incomplete);
    });

    test('a finished setup run reads as a plant record', () {
      final PlantRecord? record = MaintenanceSetup.recordFrom(finishedSetup(), now: now);
      expect(record, isNotNull);
      expect(record!.megaCharVessels, 1);
      expect(record.softenerVessels, 1);
      expect(record.vesselsInstalledOn, DateTime(2026, 3, 14));
      expect(record.preFilterInstalledOn, DateTime(2026, 8, 20));
      expect(record.roFilterInstalledOn, DateTime(2026, 6, 1));
      expect(record.postFilterInstalledOn, DateTime(2026, 6, 1));
      expect(record.membranes, 2);
      expect(record.membranesInstalledOn, DateTime(2026, 1, 10));
      expect(record.spec.permeateTdsMax, 50, reason: 'skipped spec keeps the defaults');
      expect(record.recordedAt, now);
    });

    test('a setup run still open reads as no plant', () {
      final Map<String, dynamic> open = TaskRun.fromTask(setupTask())
          .recordReading(0, 0, '1')
          .recordReading(0, 1, '1')
          .recordReading(0, 2, '2026-03-14')
          .complete(0, now)
          .applyTo(setupTask());
      expect(MaintenanceSetup.recordFrom(open), isNull);
      expect(MaintenanceSetup.recordFrom(<String, dynamic>{'title': 'x'}), isNull);
    });

    test('a water spec that was filled in flows into the readings step', () {
      final PlantRecord? record = MaintenanceSetup.recordFrom(
        finishedSetup(skipWaterSpec: false, permeateTdsMax: '60'),
      );
      expect(record!.spec.permeateTdsMax, 60);
      expect(record.spec.feedTdsMax, 400);
      final TaskRunStep readings = MaintenanceTemplates.readingsStep(record.spec);
      expect(readings.readings[1].max, 60);
      final TaskRun run = TaskRun.fromTask(
        MaintenanceTemplates.build(
          MaintenanceTemplate.softenerMaintenance,
          now: now,
          plant: record,
        ),
      );
      expect(run.steps[9].readings[1].specWithUnit, '≤ 60 ppm');
    });

    test('the record round-trips through its map', () {
      final PlantRecord record = MaintenanceSetup.recordFrom(finishedSetup(), now: now)!;
      final PlantRecord again = PlantRecord.fromMap(record.toMap());
      expect(again.toMap(), record.toMap());
      expect(again.preFilterInstalledOn, DateTime(2026, 8, 20));
    });
  });

  group('due dates from the plant record', () {
    final PlantRecord described = MaintenanceSetup.recordFrom(finishedSetup(), now: now)!;

    test('a replacement is due its interval after the install date', () {
      expect(
        MaintenanceTemplates.dueOn(MaintenanceTemplate.preFilterReplacement,
            now: now, plant: described),
        DateTime(2026, 9, 19),
        reason: '2026-08-20 + $kPreFilterDays days',
      );
      expect(
        MaintenanceTemplates.dueOn(MaintenanceTemplate.roFilterReplacement,
            now: now, plant: described),
        DateTime(2026, 6, 1).add(const Duration(days: kRoFilterDays)),
      );
      expect(
        MaintenanceTemplates.dueOn(MaintenanceTemplate.membraneReplacement,
            now: now, plant: described),
        DateTime(2027, 1, 10),
        reason: '2026-01-10 + $kMembraneDays days',
      );
      expect(kPreFilterDays, 30);
      expect(kRoFilterDays, 180);
      expect(kMembraneDays, 365);
    });

    test('a replacement task is an ordinary reminder with no step list', () {
      final Map<String, dynamic> task = MaintenanceTemplates.build(
        MaintenanceTemplate.membraneReplacement,
        now: now,
        plant: described,
      );
      expect(task['title'], 'RO membrane replacement');
      expect(task['subtasks'], isEmpty);
      expect(task['stepsAreSequential'], isFalse);
      expect(task['reminder'], isTrue);
      expect(task['deadline'], DateTime(2027, 1, 10).toIso8601String());
      expect(MaintenanceTemplates.recurrence(MaintenanceTemplate.preFilterReplacement), 'Monthly');
      expect(MaintenanceTemplates.recurrence(MaintenanceTemplate.membraneReplacement), 'None');
    });

    test('with no date on the record the replacement is due today, not never', () {
      expect(
        MaintenanceTemplates.dueOn(MaintenanceTemplate.roFilterReplacement,
            now: now, plant: plant),
        DateTime(2026, 9, 5),
      );
    });
  });

  group('the store', () {
    test('reads null until saved, then the record; capture writes only the setup', () async {
      Map<String, dynamic>? held;
      final MaintenancePlantStore store = MaintenancePlantStore(
        read: () => held,
        write: (Map<String, dynamic>? value) async => held = value,
      );
      expect(store.current(), isNull);
      expect(
        await store.captureFromRun(
          MaintenanceTemplates.build(MaintenanceTemplate.softenerMaintenance, now: now),
        ),
        isNull,
      );
      expect(held, isNull, reason: 'a service run never writes the plant');
      final PlantRecord? captured = await store.captureFromRun(finishedSetup(), now: now);
      expect(captured, isNotNull);
      expect(store.current()!.membranes, 2);
      expect(held!['version'], PlantRecord.version);
    });

    test('a half-described plant reads as none, so setup is offered again', () {
      final MaintenancePlantStore store = MaintenancePlantStore(
        read: () => <String, dynamic>{'megaCharVessels': 1, 'softenerVessels': 0, 'membranes': 2},
        write: (_) async {},
      );
      expect(store.current(), isNull);
    });

    test('templates resolve by key, and a hand-made task has none', () {
      expect(MaintenanceTemplates.byKey('megachar_maintenance'),
          MaintenanceTemplate.megaCharMaintenance);
      expect(MaintenanceTemplates.byKey(null), isNull);
      expect(MaintenanceTemplates.byKey('weekend job'), isNull);
    });
  });
}
