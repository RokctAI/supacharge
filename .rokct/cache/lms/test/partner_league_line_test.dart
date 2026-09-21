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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';

/// Partner-side league visibility: a partner with several students sees
/// where each of THEIR OWN students stands in this week's league — tier and
/// rank per student, nothing about anyone else's cohort-mates. The card is
/// wired through an optional [PartnerLeagueSource] (null hides it, same
/// posture as billing/links), and a failed or empty league answer never
/// takes the dashboard down.
void main() {
  group('notifier', () {
    test('league standings load per linked student', () async {
      final n = PartnerDashboardNotifier(
        source: _TwoStudentSource(),
        access: _FixedAccess(AccessStatus.partner),
        league: _FakeLeague([
          const StudentLeagueStanding(
              studentId: 'thabo', tier: 'Gold', points: 45, rank: 3,
              cohortSize: 12),
          const StudentLeagueStanding(
              studentId: 'naledi', tier: 'Silver', points: 20, rank: 8,
              cohortSize: 20),
        ]),
      );
      await n.init();
      expect(n.state.leagueByStudent, hasLength(2));
      expect(n.state.leagueByStudent['thabo']?.tier, 'Gold');
      expect(n.state.leagueByStudent['thabo']?.rank, 3);
      expect(n.state.leagueByStudent['naledi']?.tier, 'Silver');
      n.dispose();
    });

    test('no league source wired -> empty map, dashboard unaffected',
        () async {
      final n = PartnerDashboardNotifier(
        source: _TwoStudentSource(),
        access: _FixedAccess(AccessStatus.partner),
      );
      await n.init();
      expect(n.state.leagueByStudent, isEmpty);
      expect(n.state.report, isNotNull);
      n.dispose();
    });

    test('league fetch failure is swallowed — the report still loads',
        () async {
      final n = PartnerDashboardNotifier(
        source: _TwoStudentSource(),
        access: _FixedAccess(AccessStatus.partner),
        league: _ThrowingLeague(),
      );
      await n.init();
      expect(n.state.leagueByStudent, isEmpty);
      expect(n.state.report?.studentName, 'Thabo');
      n.dispose();
    });
  });

  group('dashboard card', () {
    testWidgets('a league line per student — tier + rank, own students only',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: PartnerDashboardPage(
            deps: PartnerDashboardDeps(
              source: _TwoStudentSource(),
              access: _FixedAccess(AccessStatus.partner),
              league: _FakeLeague([
                const StudentLeagueStanding(
                    studentId: 'thabo', tier: 'Gold', points: 45, rank: 3,
                    cohortSize: 12),
                const StudentLeagueStanding(
                    studentId: 'naledi', tier: 'Silver', points: 20, rank: 8,
                    cohortSize: 20),
              ]),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Collapsed: the card leads with the SELECTED student's standing
      // (the summary and the expanded row both carry it — the collapse
      // animation keeps both in the tree).
      expect(find.text('League this week'), findsOneWidget);
      expect(find.text('Gold · 3rd of 12'), findsWidgets);

      // Expanded: one line per linked student, tier + rank each.
      await tester.tap(find.text('League this week'));
      await tester.pumpAndSettle();
      expect(find.text('Thabo'), findsWidgets);
      expect(find.text('Silver · 8th of 20'), findsOneWidget);
    });

    testWidgets('no league data -> no card', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: PartnerDashboardPage(
            deps: PartnerDashboardDeps(
              source: _TwoStudentSource(),
              access: _FixedAccess(AccessStatus.partner),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('League this week'), findsNothing);
    });
  });
}

class _FixedAccess implements AccessStatusSource {
  final AccessStatus status;

  _FixedAccess(this.status);

  @override
  Future<AccessStatus> current() async => status;
}

class _FakeLeague implements PartnerLeagueSource {
  final List<StudentLeagueStanding> standings;

  _FakeLeague(this.standings);

  @override
  Future<List<StudentLeagueStanding>> studentsLeague() async => standings;
}

class _ThrowingLeague implements PartnerLeagueSource {
  @override
  Future<List<StudentLeagueStanding>> studentsLeague() async =>
      throw Exception('offline');
}

class _TwoStudentSource implements PartnerReportSource {
  @override
  Future<List<LinkedStudent>> students() async => const [
        LinkedStudent(id: 'thabo', name: 'Thabo'),
        LinkedStudent(id: 'naledi', name: 'Naledi'),
      ];

  @override
  Future<PartnerReport> weeklyReport(DateTime weekStart,
          {String? studentId}) async =>
      PartnerReport(
        studentName: studentId == 'naledi' ? 'Naledi' : 'Thabo',
        weekStart: weekStart,
        sessionsScheduled: 4,
        sessionsAttended: 3,
        engagementRatePercent: studentId == 'naledi' ? 60 : 80,
      );

  @override
  Future<List<PartnerAlert>> alerts() async => const [];
}
