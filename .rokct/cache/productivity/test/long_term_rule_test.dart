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

// Section 47m, second pass — the long-term band is DERIVED from the end
// date (Ray: "long term task is selected not automatically detected from
// end date"). This pins the rule that replaced the compose form's switch.
//
// Imports the application layer only, never the store, so the suite loads
// on a bare checkout — the rule for every test file in this package.
//
// What a later edit could quietly undo:
//   * the cut-off is ONE named constant. A second literal 30 anywhere
//     would let the form and the list mean different spans.
//   * no end date is NOT long term. Measuring an absent deadline against
//     a creation date would sweep every undated task into the band.
//   * the boundary is EXCLUSIVE: exactly the horizon is still the day's
//     work, and one day past it is not.

import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/application/tasks/long_term_rule.dart';

void main() {
  group('LongTermRule', () {
    final DateTime created = DateTime.utc(2026, 9, 18, 9);

    test('the cut-off is one named constant', () {
      expect(LongTermRule.horizonDays, 30);
    });

    test('a task with no end date is not long term', () {
      expect(
        LongTermRule.isLongTerm(endDate: null, createdAt: created),
        isFalse,
      );
    });

    test('an end date inside the horizon is the day\'s work', () {
      expect(
        LongTermRule.isLongTerm(
          endDate: created.add(const Duration(days: 7)),
          createdAt: created,
        ),
        isFalse,
      );
    });

    test('exactly the horizon is not yet long term', () {
      expect(
        LongTermRule.isLongTerm(
          endDate: created.add(
            const Duration(days: LongTermRule.horizonDays),
          ),
          createdAt: created,
        ),
        isFalse,
      );
    });

    test('one day past the horizon is long term', () {
      expect(
        LongTermRule.isLongTerm(
          endDate: created.add(
            const Duration(days: LongTermRule.horizonDays + 1),
          ),
          createdAt: created,
        ),
        isTrue,
      );
    });

    test('an end date before the start is not long term', () {
      expect(
        LongTermRule.isLongTerm(
          endDate: created.subtract(const Duration(days: 90)),
          createdAt: created,
        ),
        isFalse,
      );
    });

    test('a start date wins over the creation date when there is one', () {
      // The span is 40 days from creation but 5 from the start the task
      // carries, so it is the day's work.
      expect(
        LongTermRule.isLongTerm(
          endDate: created.add(const Duration(days: 40)),
          startDate: created.add(const Duration(days: 35)),
          createdAt: created,
        ),
        isFalse,
      );
    });

    test('with neither a start nor a creation date there is nothing to '
        'measure', () {
      expect(
        LongTermRule.isLongTerm(endDate: created.add(const Duration(days: 90))),
        isFalse,
      );
    });
  });

  group('LongTermRule.forTodo', () {
    test('reads the task map the surface actually writes', () {
      final Map<String, dynamic> todo = <String, dynamic>{
        'title': 'Rebuild the RO skid',
        'createdAt': DateTime.utc(2026, 9, 18).toIso8601String(),
        'deadline': DateTime.utc(2026, 12, 1).toIso8601String(),
      };

      expect(LongTermRule.forTodo(todo), isTrue);
    });

    test('a near deadline on the same map is not long term', () {
      final Map<String, dynamic> todo = <String, dynamic>{
        'createdAt': DateTime.utc(2026, 9, 18).toIso8601String(),
        'deadline': DateTime.utc(2026, 9, 25).toIso8601String(),
      };

      expect(LongTermRule.forTodo(todo), isFalse);
    });

    test('an unparseable deadline is false, never a throw', () {
      final Map<String, dynamic> todo = <String, dynamic>{
        'createdAt': DateTime.utc(2026, 9, 18).toIso8601String(),
        'deadline': 'whenever',
      };

      expect(LongTermRule.forTodo(todo), isFalse);
    });

    test('a DateTime on the map reads the same as its string', () {
      final DateTime created = DateTime.utc(2026, 9, 18);
      final Map<String, dynamic> todo = <String, dynamic>{
        'createdAt': created,
        'deadline': created.add(const Duration(days: 45)),
      };

      expect(LongTermRule.forTodo(todo), isTrue);
    });

    test('a pulled task measures from its own start date', () {
      final Map<String, dynamic> todo = <String, dynamic>{
        'createdAt': DateTime.utc(2026, 9, 18).toIso8601String(),
        'startDate': DateTime.utc(2026, 11, 1).toIso8601String(),
        'deadline': DateTime.utc(2026, 11, 10).toIso8601String(),
      };

      expect(LongTermRule.forTodo(todo), isFalse);
    });
  });
}
