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

/// Server-configurable plans (owner instruction 2026-08-13): the app's
/// plan catalog is `rlms.api.billing.plans` — LMS Plan records — and this
/// pins the row -> [LessonPlanOption] mapping plus the kind semantics the
/// purchase flow keys off (recurring / one-off programme / per-lesson).
void main() {
  group('lessonPlanFromServer', () {
    test('maps a recurring catalog row verbatim — server is price authority',
        () {
      final plan = lessonPlanFromServer({
        'id': 'standard-monthly',
        'title': 'Full Access',
        'description': 'Every live lesson.',
        'kind': 'Recurring',
        'price': 299,
        'months': 1,
      });
      expect(plan.id, 'standard-monthly');
      expect(plan.title, 'Full Access');
      expect(plan.description, 'Every live lesson.');
      expect(plan.price, 299);
      expect(plan.months, 1);
      expect(plan.kind, PlanKind.recurring);
      expect(plan.isOneOff, isFalse);
      expect(plan.term, PlanTerm.monthly);
    });

    test('a yearly row keeps its own price — no client-side derivation', () {
      final plan = lessonPlanFromServer({
        'id': 'standard-yearly',
        'title': 'Full Access',
        'kind': 'Recurring',
        'price': 2990,
        'months': 12,
      });
      expect(plan.price, 2990);
      expect(plan.term, PlanTerm.yearly);
    });

    test('a one-off programme row carries kind, zero months and the window '
        'label', () {
      final plan = lessonPlanFromServer({
        'id': 'holiday-programme',
        'title': 'Holiday Programme',
        'kind': 'One-Off Programme',
        'price': 449,
        'months': 0,
        'window_label': 'December Holiday Programme',
      });
      expect(plan.kind, PlanKind.oneOffProgramme);
      expect(plan.isOneOff, isTrue);
      expect(plan.months, 0);
      expect(plan.windowLabel, 'December Holiday Programme');
    });

    test('a per-lesson row reads as perLesson', () {
      final plan = lessonPlanFromServer({
        'id': 'per-lesson',
        'title': 'Pay Per Lesson',
        'kind': 'Per Lesson',
        'price': 75,
        'months': 0,
      });
      expect(plan.kind, PlanKind.perLesson);
      expect(plan.isOneOff, isTrue);
    });

    test('holiday_access rides the row by record, not by term (#23)', () {
      // A yearly plan the owner narrowed to First Week must advertise
      // First Week — the record is the authority, never the term length.
      final narrowedYearly = lessonPlanFromServer({
        'id': 'standard-yearly',
        'title': 'Full Access',
        'kind': 'Recurring',
        'price': 2990,
        'months': 12,
        'holiday_access': 'First Week',
      });
      expect(narrowedYearly.holidayAccess, HolidayAccessLevel.firstWeek);
      expect(holidayPerkLevel(narrowedYearly), HolidayAccessLevel.firstWeek);

      final excluded = lessonPlanFromServer({
        'id': 'no-holiday',
        'title': 'Term Time Only',
        'kind': 'Recurring',
        'price': 199,
        'months': 1,
        'holiday_access': 'None',
      });
      expect(excluded.holidayAccess, HolidayAccessLevel.none);
      expect(holidayPerkLevel(excluded), HolidayAccessLevel.none);
    });

    test(
        'an old server that sends no holiday_access falls back to the term '
        'derivation', () {
      final monthly = lessonPlanFromServer({
        'id': 'standard-monthly',
        'title': 'Full Access',
        'kind': 'Recurring',
        'price': 299,
        'months': 1,
      });
      expect(monthly.holidayAccess, isNull);
      expect(holidayPerkLevel(monthly), HolidayAccessLevel.firstWeek);

      final yearly = lessonPlanFromServer({
        'id': 'standard-yearly',
        'title': 'Full Access',
        'kind': 'Recurring',
        'price': 2990,
        'months': 12,
      });
      expect(yearly.holidayAccess, isNull);
      expect(holidayPerkLevel(yearly), HolidayAccessLevel.full);
    });

    test('missing price renders as 0, never an invented number', () {
      // Decision #47: nothing client-side may substitute a price the
      // server did not state.
      final plan = lessonPlanFromServer({
        'id': 'mystery',
        'title': 'Mystery',
        'kind': 'Recurring',
        'months': 1,
      });
      expect(plan.price, 0);
    });
  });

  group('PlanKind.fromServer', () {
    test('matches the server kind strings', () {
      expect(PlanKind.fromServer('Recurring'), PlanKind.recurring);
      expect(
          PlanKind.fromServer('One-Off Programme'), PlanKind.oneOffProgramme);
      expect(PlanKind.fromServer('Per Lesson'), PlanKind.perLesson);
    });

    test('an unknown kind degrades to recurring so old clients still render',
        () {
      expect(PlanKind.fromServer(null), PlanKind.recurring);
      expect(PlanKind.fromServer(''), PlanKind.recurring);
      expect(PlanKind.fromServer('Timeshare'), PlanKind.recurring);
    });
  });

  group('LessonPlanCatalogSnapshot', () {
    test('defaults are empty and rate-less — the honest unavailable state',
        () {
      const snapshot = LessonPlanCatalogSnapshot();
      expect(snapshot.plans, isEmpty);
      expect(snapshot.partnerMonthlyRate, isNull);
    });
  });
}
