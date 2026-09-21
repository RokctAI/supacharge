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
// Direct imports (same as skill_review_source_test) so this test also
// compiles standalone, where the barrel's presentation exports need the
// manifest-injected TrKeys of a composed host app.
import 'package:lms_sdk/src/common/infrastructure/repositories/http_leaderboard_source.dart';

/// §7 weekly badge over the rlms league endpoints (decision #42 gap 4).
///
/// The fixture below is the REAL `league_standings` answer shape from
/// `agent/lms/frappe/src/rlms/api/engagement.py` — display names already
/// privacy-reduced server-side (first name + last initial), standings
/// ordered highest points first with rank 1 at the top. These tests pin
/// that contract: the badge is the server's top row, verbatim — nothing
/// is recomputed, re-sorted, or adjusted on device.
const _standingsAnswer = {
  'week_start': '2026-08-10',
  'tier': 'Silver',
  'cohort': '1',
  'promote_top': 10,
  'demote_bottom': 5,
  'standings': [
    {'display_name': 'Thabo M.', 'points': 45, 'rank': 1, 'is_me': false},
    {'display_name': 'Naledi K.', 'points': 30, 'rank': 2, 'is_me': true},
    {'display_name': 'Sipho D.', 'points': 30, 'rank': 2, 'is_me': false},
    {'display_name': 'Lerato P.', 'points': 10, 'rank': 4, 'is_me': false},
  ],
};

void main() {
  group('HttpLeaderboardSource.weeklyBadgeFromStandings', () {
    test('answers the server-ranked top row verbatim', () {
      final badge = HttpLeaderboardSource.weeklyBadgeFromStandings(
          Map<String, dynamic>.from(_standingsAnswer));
      expect(badge, isNotNull);
      expect(badge!.displayName, 'Thabo M.');
      expect(badge.score, 45, reason: 'server points, never recomputed');
      expect(badge.activityLabel, HttpLeaderboardSource.weeklyActivityLabel);
    });

    test('empty standings (cohort still filling) -> null, never a zero-score'
        ' badge', () {
      final badge = HttpLeaderboardSource.weeklyBadgeFromStandings(
          {'week_start': '2026-08-10', 'standings': <dynamic>[]});
      expect(badge, isNull);
    });

    test('missing or malformed standings -> null, never a throw', () {
      expect(HttpLeaderboardSource.weeklyBadgeFromStandings({}), isNull);
      expect(
          HttpLeaderboardSource.weeklyBadgeFromStandings(
              {'standings': 'oops'}),
          isNull);
      expect(
          HttpLeaderboardSource.weeklyBadgeFromStandings({
            'standings': ['not-a-map'],
          }),
          isNull);
    });

    test('a top row without a display name -> null (no anonymous badge)', () {
      final badge = HttpLeaderboardSource.weeklyBadgeFromStandings({
        'standings': [
          {'points': 45, 'rank': 1},
        ],
      });
      expect(badge, isNull);
    });
  });

  group('HttpLeaderboardSource over the wire', () {
    test('backend unavailable -> weeklyBadge answers null, never throws',
        () async {
      // No HttpService is registered in a test env, so the client lookup
      // throws inside the source's guard — exactly the production failure
      // it must degrade through (callers fall back to the student's own
      // tally; the cause goes to telemetry, not the student).
      final source = HttpLeaderboardSource();
      expect(await source.weeklyBadge(), isNull);
    });

    test('topToday answers null — no per-session daily surface exists yet',
        () async {
      final source = HttpLeaderboardSource();
      expect(await source.topToday('session-1'), isNull);
    });
  });
}
