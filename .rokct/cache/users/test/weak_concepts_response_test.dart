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
import 'package:users_sdk/src/common/models/response/weak_concepts_response.dart';

/// JSON-parsing coverage for the `paas.api.user.get_weak_concepts` client
/// model. Fixtures mirror the server's api_response wrapper exactly as it
/// reaches `response.data` (Frappe's `message` envelope already stripped by
/// base_sdk's FrappeResponseInterceptor).
void main() {
  Map<String, dynamic> wrapped(Map<String, dynamic> payload) =>
      {'data': payload, 'status_code': 200};

  group('WeakConceptsResponse.fromJson', () {
    test('parses the full server payload, preserving score-desc order', () {
      final response = WeakConceptsResponse.fromJson(wrapped({
        'concepts': [
          {
            'subtopic_ref': 'quadratic_formula_derivation',
            'label': 'Quadratic Formula Derivation',
            'score': 1.42,
            'incorrect': 2,
            'skipped': 1,
            'correct': 4,
            'attempts': 7,
            'last_seen': '2026-08-01 10:00:00',
          },
          {
            'subtopic_ref': 'completing_the_square',
            'label': 'Completing The Square',
            'score': 0.8,
            'incorrect': 1,
            'skipped': 0,
            'correct': 3,
            'attempts': 4,
            'last_seen': '2026-07-20 09:30:00',
          },
        ],
        'total': 12,
        'limit': 20,
        'offset': 0,
        'days': 90,
        'source_available': true,
      }));

      expect(response.concepts, hasLength(2));
      expect(response.concepts.map((c) => c.subtopicRef).toList(), [
        'quadratic_formula_derivation',
        'completing_the_square',
      ]);
      final first = response.concepts.first;
      expect(first.label, 'Quadratic Formula Derivation');
      expect(first.score, 1.42);
      expect(first.incorrect, 2);
      expect(first.skipped, 1);
      expect(first.correct, 4);
      expect(first.attempts, 7);
      expect(first.lastSeen, '2026-08-01 10:00:00');
      expect(response.total, 12);
      expect(response.limit, 20);
      expect(response.offset, 0);
      expect(response.days, 90);
      expect(response.sourceAvailable, isTrue);
    });

    test(
        'source_available false with empty concepts is a valid state, '
        'not a parse failure', () {
      final response = WeakConceptsResponse.fromJson(wrapped({
        'concepts': [],
        'total': 0,
        'limit': 20,
        'offset': 0,
        'days': 90,
        'source_available': false,
      }));

      expect(response.sourceAvailable, isFalse);
      expect(response.concepts, isEmpty);
      expect(response.total, 0);
    });

    test('coerces Frappe-style loose types (int score, 0/1 bools, strings)',
        () {
      final response = WeakConceptsResponse.fromJson(wrapped({
        'concepts': [
          {
            'subtopic_ref': 'fractions',
            'label': 'Fractions',
            'score': 2, // int, not double
            'incorrect': '3', // stringified
            'skipped': 0,
            'correct': 0,
            'attempts': 3,
            // no last_seen key at all
          },
        ],
        'total': '1',
        'limit': 20.0,
        'offset': 0,
        'days': 90,
        'source_available': 1, // Frappe truthy int
      }));

      final concept = response.concepts.single;
      expect(concept.score, 2.0);
      expect(concept.incorrect, 3);
      expect(concept.lastSeen, isNull);
      expect(response.total, 1);
      expect(response.limit, 20);
      expect(response.sourceAvailable, isTrue);
    });

    test('degrades to safe defaults on missing/garbage payloads', () {
      for (final junk in [
        null,
        <String, dynamic>{},
        {'data': null},
        {'data': 'oops'},
        {
          'data': {
            'concepts': ['not-a-map', 42],
          },
        },
      ]) {
        final response = WeakConceptsResponse.fromJson(junk);
        expect(response.concepts, isEmpty, reason: 'payload: $junk');
        expect(response.sourceAvailable, isFalse, reason: 'payload: $junk');
        expect(response.limit, 20, reason: 'payload: $junk');
        expect(response.days, 90, reason: 'payload: $junk');
      }
    });

    test('accepts an already-unwrapped payload map (defensive)', () {
      final response = WeakConceptsResponse.fromJson({
        'concepts': [
          {'subtopic_ref': 'algebra_basics', 'label': 'Algebra Basics'},
        ],
        'total': 1,
        'limit': 5,
        'offset': 0,
        'days': 30,
        'source_available': true,
      });
      expect(response.concepts.single.subtopicRef, 'algebra_basics');
      expect(response.limit, 5);
      expect(response.days, 30);
    });

    test('toJson round-trips through fromJson', () {
      const original = WeakConceptsResponse(
        concepts: [
          WeakConcept(
            subtopicRef: 'trig_identities',
            label: 'Trig Identities',
            score: 1.1,
            incorrect: 1,
            skipped: 1,
            correct: 2,
            attempts: 4,
            lastSeen: '2026-08-10 08:00:00',
          ),
        ],
        total: 1,
        limit: 20,
        offset: 0,
        days: 90,
        sourceAvailable: true,
      );
      final round = WeakConceptsResponse.fromJson(original.toJson());
      expect(round.concepts.single.subtopicRef, 'trig_identities');
      expect(round.concepts.single.score, 1.1);
      expect(round.sourceAvailable, isTrue);
      expect(round.total, 1);
    });
  });
}
