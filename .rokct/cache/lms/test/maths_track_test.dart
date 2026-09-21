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

/// Maths-track wiring (decision #29): the subscribe-time picker preselects
/// and locks from the server (`student_my_maths_track`) instead of only the
/// device KV. These pin the client side of that contract — the slug
/// vocabulary shared with rlms' maths_track module and the response shapes
/// my_maths_track actually returns.
void main() {
  group('MathsTrack.slug (rlms maths_track vocabulary)', () {
    test('matches the server/factory content slugs exactly', () {
      // CORE = 'maths', LITERACY = 'mathematical_literacy' — what
      // student_set_maths_track normalises to and my_maths_track returns.
      expect(MathsTrack.mathematics.slug, 'maths');
      expect(MathsTrack.mathematicalLiteracy.slug, 'mathematical_literacy');
    });

    test('round-trips through the tolerant parser', () {
      for (final t in MathsTrack.values) {
        expect(MathsTrack.fromSubject(t.slug), t);
      }
    });
  });

  group('MathsTrackStatus (rlms.api.student.my_maths_track contract)', () {
    test('explicit choice: track + chosen + locked', () {
      final s = MathsTrackStatus.fromJson(
          {'track': 'maths', 'chosen': 'maths', 'locked': true});
      expect(s.track, MathsTrack.mathematics);
      expect(s.chosen, MathsTrack.mathematics);
      expect(s.locked, isTrue);
    });

    test('literacy slug maps to the literacy track', () {
      final s = MathsTrackStatus.fromJson({
        'track': 'mathematical_literacy',
        'chosen': 'mathematical_literacy',
        'locked': true,
      });
      expect(s.track, MathsTrack.mathematicalLiteracy);
      expect(s.chosen, MathsTrack.mathematicalLiteracy);
    });

    test('derived from an enrolment: held but never explicitly chosen', () {
      // A student enrolled before the picker existed still holds a track:
      // the server derives it (locked), but chosen stays null.
      final s = MathsTrackStatus.fromJson(
          {'track': 'maths', 'chosen': null, 'locked': true});
      expect(s.track, MathsTrack.mathematics);
      expect(s.chosen, isNull);
      expect(s.locked, isTrue);
    });

    test('no track yet: all null, unlocked', () {
      final s = MathsTrackStatus.fromJson(
          {'track': null, 'chosen': null, 'locked': false});
      expect(s.track, isNull);
      expect(s.chosen, isNull);
      expect(s.locked, isFalse);
    });

    test('missing keys degrade the same as nulls', () {
      final s = MathsTrackStatus.fromJson(const {});
      expect(s.track, isNull);
      expect(s.chosen, isNull);
      expect(s.locked, isFalse);
    });

    test('unknown slug degrades to null rather than throwing', () {
      final s = MathsTrackStatus.fromJson(
          {'track': 'physical_sciences', 'chosen': 'nonsense', 'locked': true});
      expect(s.track, isNull);
      expect(s.chosen, isNull);
      // locked passes through untouched — the server said the pick is
      // settled even if the client can't name the track.
      expect(s.locked, isTrue);
    });
  });
}
