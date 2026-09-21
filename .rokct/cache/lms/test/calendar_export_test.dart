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


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';

class _MemStore implements ScheduleStore {
  final Map<String, Map<String, dynamic>> data = {};

  @override
  Future<Map<String, dynamic>?> get(String collection, String key) async =>
      data['$collection/$key'];

  @override
  Future<void> put(
          String collection, String key, Map<String, dynamic> value) async =>
      data['$collection/$key'] = value;
}

class _FakeSharer implements LessonCalendarSharer {
  final bool result;
  final List<String> sharedIcs = [];
  final List<String> filenames = [];

  _FakeSharer({this.result = true});

  @override
  Future<bool> shareLessonCalendar(
      {required String ics, required String filename}) async {
    sharedIcs.add(ics);
    filenames.add(filename);
    return result;
  }
}

void main() {
  final base = DateTime(2026, 8, 20, 15, 0);

  ScheduledSession session({
    String id = 's1',
    DateTime? start,
    int? durationSeconds,
    String? secondTutor,
  }) =>
      ScheduledSession(
        sessionId: id,
        subject: 'Mathematics',
        topic: 'Quadratic functions',
        tutorName: 'Sifiso Zulu',
        secondTutorName: secondTutor,
        startTime: start ?? base,
        durationSeconds: durationSeconds,
      );

  group('LessonCalendarPrefs', () {
    test('opt-in is off by default, persists, and opt-out clears the ledger',
        () async {
      final prefs = LessonCalendarPrefs(store: _MemStore());
      expect(await prefs.enabled(), isFalse);
      await prefs.setEnabled(true);
      expect(await prefs.enabled(), isTrue);
      await prefs.markExported(['a', 'b']);
      expect(await prefs.exportedIds(), {'a', 'b'});
      await prefs.setEnabled(false);
      expect(await prefs.enabled(), isFalse);
      // Re-opt-in starts fresh so everything upcoming is offered again.
      expect(await prefs.exportedIds(), isEmpty);
    });

    test('markExported accumulates across calls', () async {
      final prefs = LessonCalendarPrefs(store: _MemStore());
      await prefs.markExported(['a']);
      await prefs.markExported(['b', 'a']);
      expect(await prefs.exportedIds(), {'a', 'b'});
    });
  });

  group('pendingExports', () {
    test('keeps only confirmed, upcoming, unexported airings', () {
      final now = base.subtract(const Duration(hours: 2));
      final confirmed = session(id: 'up');
      final past = session(
          id: 'past', start: base.subtract(const Duration(days: 1)));
      final unconfirmed = session(id: 'uncf');
      final exported = session(id: 'done');
      final pending = LessonCalendarExport.pendingExports(
        sessions: [confirmed, past, unconfirmed, exported],
        attendance: {
          'up': AttendanceState.confirmed,
          'past': AttendanceState.confirmed,
          'uncf': AttendanceState.none,
          'done': AttendanceState.confirmed,
        },
        exported: {'done'},
        now: now,
      );
      expect(pending.map((s) => s.sessionId), ['up']);
    });
  });

  group('buildIcs', () {
    test('carries subject + lesson title, UTC times and default hour', () {
      final ics = LessonCalendarExport.buildIcs([session()],
          now: () => base.subtract(const Duration(hours: 2)));
      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('SUMMARY:Mathematics: Quadratic functions'));
      expect(ics, contains('DTSTART:${_utc(base)}'));
      expect(
          ics, contains('DTEND:${_utc(base.add(const Duration(hours: 1)))}'));
      expect(ics, contains('END:VCALENDAR'));
      // CRLF line endings per RFC 5545.
      expect(ics, contains('\r\n'));
    });

    test('uses the session duration when the data carries one', () {
      final ics =
          LessonCalendarExport.buildIcs([session(durationSeconds: 2700)]);
      expect(ics,
          contains('DTEND:${_utc(base.add(const Duration(minutes: 45)))}'));
    });

    test('friendly description names the duo, never internal ids', () {
      final ics = LessonCalendarExport.buildIcs(
          [session(id: 'sess_INTERNAL_99', secondTutor: 'John Petersen')]);
      expect(ics, contains('Sifiso Zulu & John Petersen'));
      expect(ics, isNot(contains('sess_INTERNAL_99')));
    });

    test('UID is stable across builds (idempotent re-import)', () {
      String uidOf(String ics) => RegExp(r'UID:(\S+)').firstMatch(ics)![1]!;
      final a = uidOf(LessonCalendarExport.buildIcs([session()]));
      final b = uidOf(LessonCalendarExport.buildIcs([session()]));
      expect(a, b);
    });

    test('escapes RFC 5545 special characters in text fields', () {
      final s = ScheduledSession(
        sessionId: 's1',
        subject: 'Maths; Lit',
        topic: 'Percentages, VAT',
        tutorName: 'Priya',
        startTime: base,
      );
      final ics = LessonCalendarExport.buildIcs([s]);
      expect(ics, contains(r'SUMMARY:Maths\; Lit: Percentages\, VAT'));
    });
  });

  group('CalendarExportBanner', () {
    Future<void> pump(WidgetTester tester,
        {required LessonCalendarPrefs prefs,
        required LessonCalendarSharer sharer,
        List<ScheduledSession>? sessions,
        Map<String, AttendanceState>? attendance}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CalendarExportBanner(
            sessions: sessions ?? [session()],
            attendance:
                attendance ?? const {'s1': AttendanceState.confirmed},
            sharer: sharer,
            prefs: prefs,
            now: () => base.subtract(const Duration(hours: 2)),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('hidden while the student has not opted in', (tester) async {
      final prefs = LessonCalendarPrefs(store: _MemStore());
      await pump(tester, prefs: prefs, sharer: _FakeSharer());
      expect(find.textContaining('calendar'), findsNothing);
    });

    testWidgets('opted in: offers pending lessons, shares, then goes quiet',
        (tester) async {
      final prefs = LessonCalendarPrefs(store: _MemStore());
      await prefs.setEnabled(true);
      final sharer = _FakeSharer();
      await pump(tester, prefs: prefs, sharer: sharer);
      expect(find.textContaining('into your calendar'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(sharer.sharedIcs, hasLength(1));
      expect(sharer.sharedIcs.single, contains('Quadratic functions'));
      expect(sharer.filenames.single, 'supacharge-lessons.ics');
      // Exported ledger keeps the refresh from re-offering the same airing.
      expect(await prefs.exportedIds(), {'s1'});
      expect(find.textContaining('into your calendar'), findsNothing);
    });

    testWidgets('a dismissed share sheet leaves the offer available',
        (tester) async {
      final prefs = LessonCalendarPrefs(store: _MemStore());
      await prefs.setEnabled(true);
      final sharer = _FakeSharer(result: false);
      await pump(tester, prefs: prefs, sharer: sharer);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(await prefs.exportedIds(), isEmpty);
      expect(find.textContaining('into your calendar'), findsOneWidget);
    });

    testWidgets('unconfirmed airings are never offered', (tester) async {
      final prefs = LessonCalendarPrefs(store: _MemStore());
      await prefs.setEnabled(true);
      await pump(tester,
          prefs: prefs,
          sharer: _FakeSharer(),
          attendance: const {'s1': AttendanceState.none});
      expect(find.textContaining('into your calendar'), findsNothing);
    });
  });
}

String _utc(DateTime t) {
  final u = t.toUtc();
  String p(int v) => v.toString().padLeft(2, '0');
  return '${u.year}${p(u.month)}${p(u.day)}T'
      '${p(u.hour)}${p(u.minute)}${p(u.second)}Z';
}
