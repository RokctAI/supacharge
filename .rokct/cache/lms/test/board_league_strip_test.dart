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

/// The Board carries the student's OWN weekly-league standing as a compact
/// strip (tier, points, rank) with a tap-through to the full Streak &
/// League surface. The Board's per-topic map stays deliberately unranked —
/// the strip is personal only, never a leaderboard, and it disappears
/// entirely when no engagement source is wired (tests, hosts without the
/// surface) or the league answer is unavailable.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    EngagementSource? engagement,
    VoidCallback? onOpenLeague,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: TheBoardPage(
          term: BoardTerm.demo(),
          engagement: engagement,
          onOpenLeague: onOpenLeague,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('board shows the personal league strip and taps through',
      (tester) async {
    var opened = 0;
    await pump(
      tester,
      engagement: _FakeEngagement(const LeagueWeek(
          tier: 'Gold', points: 45, rank: 3, cohortSize: 12)),
      onOpenLeague: () => opened++,
    );

    expect(find.text('GOLD LEAGUE'), findsOneWidget);
    expect(find.text('45 pts · 3rd of 12 this week'), findsOneWidget);

    await tester.tap(find.text('GOLD LEAGUE'));
    await tester.pump();
    expect(opened, 1,
        reason: 'the strip is plain navigation into the league surface — '
            'one tap, one push of the host\'s LeagueRoute');
  });

  testWidgets('empty cohort: points only, no invented rank', (tester) async {
    await pump(
      tester,
      engagement: _FakeEngagement(
          const LeagueWeek(tier: 'Bronze', points: 10, cohortSize: 0)),
    );
    expect(find.text('BRONZE LEAGUE'), findsOneWidget);
    expect(find.text('10 pts this week'), findsOneWidget);
    expect(find.textContaining('pts ·'), findsNothing);
  });

  testWidgets('no engagement source wired -> no strip at all',
      (tester) async {
    await pump(tester);
    expect(find.textContaining('LEAGUE'), findsNothing);
  });

  testWidgets('league unavailable (null answer) -> no strip', (tester) async {
    await pump(tester, engagement: _FakeEngagement(null));
    expect(find.textContaining('LEAGUE'), findsNothing);
  });
}

class _FakeEngagement implements EngagementSource {
  final LeagueWeek? week;

  _FakeEngagement(this.week);

  @override
  Future<StreakStatus> myStreak() async => const StreakStatus(current: 2);

  @override
  Future<LeagueWeek?> leagueWeek() async => week;
}
