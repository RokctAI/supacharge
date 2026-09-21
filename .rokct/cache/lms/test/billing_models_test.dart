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
// Direct model import (not the lms_sdk.dart barrel): the barrel pulls in
// presentation pages whose TrKeys members only exist after the composer
// injects the manifest tr_keys into base_sdk, so this file would not even
// load standalone through it. The models have no such gate.
import 'package:lms_sdk/src/common/domain/models/billing_models.dart';
import 'package:lms_sdk/src/common/domain/models/holiday_models.dart';

/// Billing/entitlement model parsing pins the backend's REAL answer shapes
/// (rlms.api.billing.my_billing_history rows and
/// rlms.api.student.my_entitlements) — the fixtures below mirror what those
/// endpoints actually emit (frappe.get_all field lists / isoformat dates),
/// not an invented shape.
void main() {
  group('BillingRecordEntry', () {
    test('parses a my_billing_history record row', () {
      final entry = BillingRecordEntry.fromJson(const {
        'student': 'student@example.com',
        'amount': 249.0,
        'rate_kind': 'Partner',
        'months': 3,
        'period_start': '2026-05-01',
        'period_end': '2026-07-31',
        'charged_at': '2026-05-01 09:30:00',
      });
      expect(entry.student, 'student@example.com');
      expect(entry.amount, 249.0);
      expect(entry.rateKind, 'Partner');
      expect(entry.months, 3);
      expect(entry.periodStart, DateTime(2026, 5, 1));
      expect(entry.periodEnd, DateTime(2026, 7, 31));
      expect(entry.chargedAt, DateTime(2026, 5, 1, 9, 30));
    });

    test('tolerates missing optionals without inventing values', () {
      final entry = BillingRecordEntry.fromJson(const {
        'student': 's@example.com',
        'amount': 299,
      });
      expect(entry.amount, 299.0);
      expect(entry.rateKind, isNull);
      expect(entry.months, 1);
      expect(entry.periodStart, isNull);
      expect(entry.periodEnd, isNull);
      expect(entry.chargedAt, isNull);
    });
  });

  group('EntitlementSummary', () {
    test('parses the my_entitlements shape, newest period first', () {
      final summary = EntitlementSummary.fromJson(const {
        'active': true,
        'periods': [
          {'start': '2025-01-01', 'end': '2025-03-31'},
          {'start': '2026-05-01', 'end': null},
        ],
      });
      expect(summary.active, isTrue);
      expect(summary.periods, hasLength(2));
      // Sorted most-recent-first for display.
      expect(summary.periods.first.start, DateTime(2026, 5, 1));
      expect(summary.periods.first.end, isNull);
      expect(summary.periods.last.end, DateTime(2025, 3, 31));
    });

    test('assistant_chat parses fail-OPEN: only an explicit off disables',
        () {
      // Old servers don't send the field — allowed.
      expect(
        EntitlementSummary.fromJson(const {'active': true, 'periods': []})
            .assistantChat,
        isTrue,
      );
      for (final off in [false, 0]) {
        expect(
          EntitlementSummary.fromJson({
            'active': true,
            'periods': const [],
            'assistant_chat': off,
          }).assistantChat,
          isFalse,
        );
      }
      for (final on in [true, 1]) {
        expect(
          EntitlementSummary.fromJson({
            'active': true,
            'periods': const [],
            'assistant_chat': on,
          }).assistantChat,
          isTrue,
        );
      }
    });

    test('holiday_access parses fail-OPEN: unknown levels read as Full', () {
      // Old servers don't send the field — the whole window stays open.
      expect(
        EntitlementSummary.fromJson(const {'active': true, 'periods': []})
            .holidayAccess,
        HolidayAccessLevel.full,
      );
      expect(
        EntitlementSummary.fromJson(const {
          'active': true,
          'periods': [],
          'holiday_access': 'First Week',
        }).holidayAccess,
        HolidayAccessLevel.firstWeek,
      );
      expect(
        EntitlementSummary.fromJson(const {
          'active': true,
          'periods': [],
          'holiday_access': 'None',
        }).holidayAccess,
        HolidayAccessLevel.none,
      );
      for (final weird in ['Fortnight', '', 1, null]) {
        expect(
          EntitlementSummary.fromJson({
            'active': true,
            'periods': const [],
            'holiday_access': weird,
          }).holidayAccess,
          HolidayAccessLevel.full,
          reason: '$weird',
        );
      }
    });

    test('inactive summary with no periods stays honestly empty', () {
      final summary = EntitlementSummary.fromJson(const {
        'active': false,
        'periods': [],
      });
      expect(summary.active, isFalse);
      expect(summary.periods, isEmpty);
    });

    test('drops malformed period rows instead of crashing', () {
      final summary = EntitlementSummary.fromJson(const {
        'active': 1,
        'periods': [
          {'start': 'not-a-date'},
          {'end': '2026-01-01'},
          {'start': '2026-02-01', 'end': '2026-02-28'},
        ],
      });
      expect(summary.active, isTrue);
      expect(summary.periods, hasLength(1));
    });

    test('period containment matches the library coverage rule', () {
      final closed = EntitlementPeriod(
        start: DateTime(2026, 5, 1),
        end: DateTime(2026, 7, 31),
      );
      expect(closed.covers(DateTime(2026, 4, 30)), isFalse);
      expect(closed.covers(DateTime(2026, 5, 1)), isTrue);
      expect(closed.covers(DateTime(2026, 7, 31, 23, 59)), isTrue);
      expect(closed.covers(DateTime(2026, 8, 1)), isFalse);

      final open = EntitlementPeriod(start: DateTime(2026, 5, 1));
      expect(open.covers(DateTime(2030, 1, 1)), isTrue);
    });
  });
}
