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

/// Usage reporting v1 (presence vs performance) — the model-side contract:
/// absent server data hides rather than inventing zeros, the left-early
/// marker and sittings ride the live-session entries, and the recorded
/// lessons carry their honest windowed/lifetime flag.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';

void main() {
  group('LiveSessionWatch', () {
    test('parses a full entry including the left-early marker', () {
      final w = LiveSessionWatch.fromJson({
        'title': 'Fractions',
        'minutes': 12,
        'sittings': 1,
        'left_early': true,
      });
      expect(w, isNotNull);
      expect(w!.title, 'Fractions');
      expect(w.minutes, 12);
      expect(w.sittings, 1);
      expect(w.leftEarly, true);
    });

    test('unknown sittings and left-early stay null — no claim invented', () {
      final w = LiveSessionWatch.fromJson({
        'title': 'Fractions',
        'minutes': 42,
        'sittings': null,
        'left_early': null,
      });
      expect(w!.sittings, isNull);
      expect(w.leftEarly, isNull);
    });

    test('a malformed entry answers null instead of a guessed row', () {
      expect(LiveSessionWatch.fromJson({'minutes': 12}), isNull);
      expect(LiveSessionWatch.fromJson({'title': 'X'}), isNull);
    });
  });

  group('RecordedLessonWatch.listFromJson', () {
    test('parses a list, dropping malformed entries', () {
      final lessons = RecordedLessonWatch.listFromJson([
        {'title': 'Algebra intro', 'minutes': 10},
        {'title': ''},
        'junk',
      ]);
      expect(lessons, hasLength(1));
      expect(lessons.single.title, 'Algebra intro');
      expect(lessons.single.minutes, 10);
    });

    test('a non-list (absent key on an old server) answers empty', () {
      expect(RecordedLessonWatch.listFromJson(null), isEmpty);
    });
  });

  group('PartnerReport usage fields', () {
    test('defaults hide everything — an old server changes nothing', () {
      final report =
          PartnerReport(studentName: 'Thabo', weekStart: DateTime(2026, 8, 23));
      expect(report.daysActiveInApp, isNull);
      expect(report.liveSessions, isEmpty);
      expect(report.recordedLessons, isEmpty);
      expect(report.recordedLessonsWindowed, true);
    });
  });

  group('TermReport usage fields', () {
    test('parses the presence block the server merged into the payload', () {
      final report = TermReport.fromJson({
        'term': {'number': 3, 'year': 2026, 'label': 'Term 3 2026'},
        'subjects': [],
        'days_active_in_app': 41,
        'recorded_lessons': [
          {'title': 'Geometry', 'minutes': 30},
        ],
        'recorded_lessons_windowed': false,
      });
      expect(report.daysActiveInApp, 41);
      expect(report.recordedLessons.single.title, 'Geometry');
      // False means lifetime totals — the page must not claim the term.
      expect(report.recordedLessonsWindowed, false);
    });

    test('absent keys (an old server) hide the block', () {
      final report = TermReport.fromJson({'subjects': []});
      expect(report.daysActiveInApp, isNull);
      expect(report.recordedLessons, isEmpty);
      expect(report.recordedLessonsWindowed, true);
    });
  });
}
