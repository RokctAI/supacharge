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
// WHAT THE LAUNCHER GLANCE SHOWS (Ray, 2026-09-19: "in home the glance has 3
// items, task, plan on a page, personal mastery. all these are  productivity.
// having a productivity button in floating nav is better and the glance show
// what need attention").
//
// The rule is pure and reads ONLY fields these models already carry:
//   * tasks    -> TaskModel.dueDate + TaskModel.status
//   * plan     -> PlanBoard.objectives / .kpis (via kpisOf) + .kpisRead
//   * mastery  -> MasteryTodo.date + MasteryTodo.status, under a goal whose
//                 rows were sent (MasteryGoal.todos)
//
// Nothing needing attention selects nothing at all - the whole quiet case,
// because base_sdk's GlanceCard collapses on an empty item list.

import 'dart:io';

// Narrow imports, not the barrel: the barrel pulls the drift-generated
// entities, which a bare checkout has not generated (the same reason the
// sync tests already import by path).
import 'package:base_sdk/src/domain/interface/processing_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/application/glance/productivity_attention.dart';
import 'package:productivity_sdk/src/common/models/data/objective_data.dart';
import 'package:productivity_sdk/src/common/models/data/task_data.dart';
import 'package:productivity_sdk/src/common/models/data/vision_data.dart';

final DateTime now = DateTime(2026, 9, 19, 14, 30);

TaskModel task(
  String title, {
  DateTime? dueDate,
  ProcessingState status = ProcessingState.active,
}) {
  return TaskModel(
    id: title,
    title: title,
    status: status,
    dueDate: dueDate,
  );
}

StrategicObjective objective(String name, String title) =>
    StrategicObjective(name: name, title: title);

Kpi kpi(String name, String objectiveName) =>
    Kpi(name: name, title: name, strategicObjective: objectiveName);

MasteryGoal goal(String title, {List<MasteryTodo>? todos}) =>
    MasteryGoal(name: title, title: title, todos: todos);

MasteryTodo todo(
  String description, {
  DateTime? date,
  String status = 'Open',
}) =>
    MasteryTodo(description: description, date: date, status: status);

void main() {
  group('tasks - dueDate and status, nothing else', () {
    test('overdue and due-today tasks need attention, soonest first', () {
      final List<ProductivityAttentionLine> lines =
          ProductivityAttention.tasksNeedingAttention(
        <TaskModel>[
          task('due today', dueDate: DateTime(2026, 9, 19, 9)),
          task('overdue', dueDate: DateTime(2026, 9, 17)),
        ],
        now: now,
      );
      expect(
        lines.map((ProductivityAttentionLine l) => l.text).toList(),
        <String>['Overdue - overdue', 'Due today - due today'],
      );
      expect(
        lines.every((ProductivityAttentionLine l) =>
            l.source == ProductivityAttentionSource.tasks &&
            l.routePath == ProductivityAttention.tasksPath),
        isTrue,
      );
    });

    test('a task due later today still needs attention', () {
      // Compared by DAY: due at 09:00 and it is 14:30 is still today's work,
      // and due at 23:00 today is too.
      expect(
        ProductivityAttention.tasksNeedingAttention(
          <TaskModel>[task('tonight', dueDate: DateTime(2026, 9, 19, 23))],
          now: now,
        ),
        hasLength(1),
      );
    });

    test('tomorrow, no due date, completed and cancelled all say nothing', () {
      expect(
        ProductivityAttention.tasksNeedingAttention(
          <TaskModel>[
            task('tomorrow', dueDate: DateTime(2026, 9, 20)),
            task('undated'),
            task('done',
                dueDate: DateTime(2026, 9, 17),
                status: ProcessingState.completed),
            task('dropped',
                dueDate: DateTime(2026, 9, 17),
                status: ProcessingState.cancelled),
          ],
          now: now,
        ),
        isEmpty,
      );
    });

    test('a glance is a glance: at most three lines from one surface', () {
      expect(
        ProductivityAttention.tasksNeedingAttention(
          <TaskModel>[
            for (int day = 11; day <= 18; day++)
              task('late $day', dueDate: DateTime(2026, 9, day)),
          ],
          now: now,
        ),
        hasLength(ProductivityAttention.maxLinesPerSource),
      );
    });
  });

  group('plan on a page - an objective nothing measures', () {
    test('an objective with no KPI needs attention; a measured one does not',
        () {
      final PlanBoard plan = PlanBoard(
        objectives: <StrategicObjective>[
          objective('obj-1', 'Grow the route'),
          objective('obj-2', 'Measured already'),
        ],
        kpis: <Kpi>[kpi('kpi-1', 'obj-2')],
      );
      final List<ProductivityAttentionLine> lines =
          ProductivityAttention.planNeedingAttention(plan);
      expect(
        lines.map((ProductivityAttentionLine l) => l.text).toList(),
        <String>['Nothing measures - Grow the route'],
      );
      expect(lines.single.routePath, ProductivityAttention.planPath);
    });

    test('an unreadable KPI list claims nothing at all', () {
      // The board itself refuses to draw "0 KPIs" over a failed read, and
      // this refuses to call it attention for the same reason.
      final PlanBoard plan = PlanBoard(
        objectives: <StrategicObjective>[objective('obj-1', 'Grow the route')],
        kpisRead: false,
      );
      expect(ProductivityAttention.planNeedingAttention(plan), isEmpty);
    });

    test('no plan read at all says nothing', () {
      expect(ProductivityAttention.planNeedingAttention(null), isEmpty);
    });
  });

  group('personal mastery - an open to-do whose date has arrived', () {
    test('open, dated today or earlier, named under its goal', () {
      final List<ProductivityAttentionLine> lines =
          ProductivityAttention.masteryNeedingAttention(
        <MasteryGoal>[
          goal('Finish the course', todos: <MasteryTodo>[
            todo('Module three', date: DateTime(2026, 9, 18)),
            todo('Module four', date: DateTime(2026, 9, 25)),
          ]),
        ],
        now: now,
      );
      expect(
        lines.map((ProductivityAttentionLine l) => l.text).toList(),
        <String>['Finish the course - Module three'],
      );
      expect(lines.single.routePath, ProductivityAttention.masteryPath);
    });

    test('closed, cancelled, undated and unsent rows all say nothing', () {
      expect(
        ProductivityAttention.masteryNeedingAttention(
          <MasteryGoal>[
            goal('Closed', todos: <MasteryTodo>[
              todo('done', date: DateTime(2026, 9, 1), status: 'Closed'),
              todo('dropped',
                  date: DateTime(2026, 9, 1), status: 'Cancelled'),
              todo('no date'),
            ]),
            // todos null: get_personal_mastery_goals returned the parent's
            // own columns only, so there is nothing to read - not "0 of 0".
            goal('Rows not sent'),
          ],
          now: now,
        ),
        isEmpty,
      );
    });
  });

  group('the whole glance', () {
    test('tasks, then plan, then mastery - the order the doors were in', () {
      final List<ProductivityAttentionLine> lines =
          ProductivityAttention.select(
        tasks: <TaskModel>[task('overdue', dueDate: DateTime(2026, 9, 17))],
        plan: PlanBoard(
          objectives: <StrategicObjective>[objective('obj-1', 'Unmeasured')],
        ),
        masteryGoals: <MasteryGoal>[
          goal('Course', todos: <MasteryTodo>[
            todo('Module three', date: DateTime(2026, 9, 18)),
          ]),
        ],
        now: now,
      );
      expect(
        lines.map((ProductivityAttentionLine l) => l.source).toList(),
        <ProductivityAttentionSource>[
          ProductivityAttentionSource.tasks,
          ProductivityAttentionSource.plan,
          ProductivityAttentionSource.mastery,
        ],
      );
    });

    test('nothing needing attention selects nothing - the quiet case', () {
      expect(
        ProductivityAttention.select(
          tasks: <TaskModel>[
            task('undated'),
            task('tomorrow', dueDate: DateTime(2026, 9, 20)),
          ],
          plan: PlanBoard(
            objectives: <StrategicObjective>[objective('obj-1', 'Measured')],
            kpis: <Kpi>[kpi('kpi-1', 'obj-1')],
          ),
          masteryGoals: <MasteryGoal>[goal('Rows not sent')],
          now: now,
        ),
        isEmpty,
      );
      // And with no sources at all.
      expect(ProductivityAttention.select(now: now), isEmpty);
    });
  });

  group('the manifest wires the glance as one widget, not three doors', () {
    test('both markers are claimed, and no fixed GlanceCardItem is left', () {
      final String manifest = File('manifest.json').readAsStringSync();
      expect(manifest, contains('NeedsAttentionGlance('));
      expect(manifest, contains('"placeholder": "// @launcher-glance-imports"'));
      expect(
        manifest,
        contains('"placeholder": "            // @launcher-glance"'),
      );
      // The three permanent doors are gone from the injection. The three
      // ROUTES are untouched - they are where the one Productivity entry and
      // these attention lines both go.
      expect(manifest, isNot(contains("text: 'Tasks - plan your day'")));
      expect(manifest, isNot(contains("text: 'Personal mastery - your goals'")));
      expect(manifest, contains('"path": "/vision/mastery"'));
    });
  });
}
