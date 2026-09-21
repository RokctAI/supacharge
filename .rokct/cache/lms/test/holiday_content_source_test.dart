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

/// BackendHolidayContentSource.parseLessons — the row-mapping half of the
/// adapter over `replay.api.get_produced_sessions` (holiday brief item 1),
/// pinned against the Frappe response shapes the backend actually sends:
/// the `message` envelope, bare lists, and partially-broken rows that must
/// be skipped, never crash the shelf.
void main() {
  Map<String, dynamic> row({
    Object? sessionId = 'sess-101',
    Object? subject = 'mathematics',
    Object? grade = 12,
    Object? topic = 'Trigonometric identities',
    Object? scheduledAt = '2026-03-04 10:00:00',
  }) =>
      {
        'session_id': sessionId,
        'subject': subject,
        'grade': grade,
        'topic': topic,
        'scheduled_at': scheduledAt,
      };

  group('BackendHolidayContentSource.parseLessons', () {
    test('parses rows inside the Frappe message envelope', () {
      final lessons = BackendHolidayContentSource.parseLessons({
        'message': [row(), row(sessionId: 'sess-102', grade: 11)],
      });
      expect(lessons, hasLength(2));
      expect(lessons.first.sessionId, 'sess-101');
      expect(lessons.first.subject, 'mathematics');
      expect(lessons.first.grade, 12);
      expect(lessons.first.topic, 'Trigonometric identities');
      expect(lessons.first.originallyAt, DateTime(2026, 3, 4, 10));
      expect(lessons.last.grade, 11);
    });

    test('parses a bare list (no envelope) and a data envelope', () {
      expect(BackendHolidayContentSource.parseLessons([row()]), hasLength(1));
      expect(
        BackendHolidayContentSource.parseLessons({
          'data': [row()],
        }),
        hasLength(1),
      );
    });

    test('accepts a string grade (defensive: Int field over the wire)', () {
      final lessons =
          BackendHolidayContentSource.parseLessons([row(grade: '10')]);
      expect(lessons.single.grade, 10);
    });

    test('skips malformed rows but keeps the good ones', () {
      final lessons = BackendHolidayContentSource.parseLessons([
        row(),
        row(sessionId: null), // missing id
        row(sessionId: ''), // empty id
        row(topic: null), // missing topic
        row(grade: 'twelve'), // unparseable grade
        'not-a-map',
        row(sessionId: 'sess-103'),
      ]);
      expect(lessons.map((l) => l.sessionId), ['sess-101', 'sess-103']);
    });

    test('a missing or unparseable scheduled_at yields null originallyAt,'
        ' not a skipped row', () {
      final lessons = BackendHolidayContentSource.parseLessons([
        row(scheduledAt: null),
        row(sessionId: 'sess-102', scheduledAt: 'not a date'),
      ]);
      expect(lessons, hasLength(2));
      expect(lessons.first.originallyAt, isNull);
      expect(lessons.last.originallyAt, isNull);
    });

    test('non-list payloads degrade to an empty shelf', () {
      expect(BackendHolidayContentSource.parseLessons(null), isEmpty);
      expect(BackendHolidayContentSource.parseLessons('oops'), isEmpty);
      expect(BackendHolidayContentSource.parseLessons({'message': 'down'}),
          isEmpty);
      expect(BackendHolidayContentSource.parseLessons({}), isEmpty);
    });
  });
}
