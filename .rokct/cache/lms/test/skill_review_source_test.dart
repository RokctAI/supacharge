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


import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
// Direct import (same as skills_wiring_test's notifier import) so this
// test also compiles standalone, where the barrel's presentation exports
// need the manifest-injected TrKeys of a composed host app.
import 'package:lms_sdk/src/common/domain/interface/skill_review_source.dart';

/// The CAPS review sets riding the published skills_index (factory Level-3
/// form: diagnostic / recap / exit_check, per-skill files under
/// `factory/lessons/curriculum/CAPS/{subject}/skills/`). The fixture below
/// is a published-index entry carrying the REAL review fields from the
/// factory repo's `CAPS/maths/skills/grade10/factorisation_techniques.json`,
/// verbatim — these tests pin the actual contract, not an invented shape.
/// SkillLessonIndex.parse keeps only the lookup fields, which is exactly
/// why BackendSkillReviewSource reads the raw `skills` map instead.
const _publishedIndexWithReviews = r'''
{
  "skills": {
    "maths.factorisation_techniques": {
      "card_id": "maths.factorisation_techniques",
      "subject": "Mathematics",
      "grade": 10,
      "topic": "Skills",
      "subtopic": "Factorisation techniques",
      "lesson_name": "Factorisation techniques",
      "status": "evaluated",
      "diagnostic": [
        {
          "id": "diag_1",
          "prompt": "Factorised fully, 6x² − 7x − 3 equals:",
          "options": [
            "(2x − 3)(3x + 1)",
            "(2x + 3)(3x − 1)",
            "(6x − 1)(x + 3)",
            "(3x − 3)(2x + 1)"
          ],
          "correct_index": 0,
          "time_limit_seconds": 30
        },
        {
          "id": "diag_2",
          "prompt": "Factorised fully, x³ + 8 equals:",
          "options": [
            "(x + 2)(x² − 2x + 4)",
            "(x + 2)(x² + 2x + 4)",
            "(x − 2)(x² + 2x + 4)",
            "(x + 2)³"
          ],
          "correct_index": 0,
          "time_limit_seconds": 30
        }
      ],
      "recap": "Factorising reverses expanding: it breaks an expression into the brackets whose product it is. Run the same decision tree every time. First, always: take out any common factor across all terms. Then count the terms - the count picks the tool. Two terms: difference of squares, or sum/difference of cubes. Three terms: the trinomial method. Four terms: grouping in pairs. Finally, check every bracket in your answer for further factorising - \"fully\" is a contract.\n\nTrinomials ax² + bx + c: hunt two numbers whose product is a × c and whose sum is b. For 6x² − 7x − 3: product 6 × (−3) = −18, sum −7. Read the signs first - negative product means opposite signs; negative sum means the bigger number is negative. The pair is −9 and +2. Split the middle term: 6x² − 9x + 2x − 3; group in pairs: 3x(2x − 3) + 1(2x − 3); the matching brackets are the built-in check - if they differ, the split or a sign is wrong. Factor the bracket out: (2x − 3)(3x + 1).\n\nCubes: recognise perfect cubes (1, 8, 27, 64, 125, 216; x³; y⁶). The identities share one pattern - a short bracket of the two cube roots, and a long bracket built square-the-first, multiply-the-pair, square-the-last - with signs by SOAP: Same as the original, Opposite for the middle term, Always Positive last. So x³ + 8 = (x + 2)(x² − 2x + 4). The middle term is a × b (2x), not a square (never 4x), and the long bracket NEVER factorises further - stopping there is correct.\n\nGrouping in pairs, for four terms: 2ax + 2ay − bx − by. Pair as they stand, factor each pair - and when a pair leads with a minus, take out a NEGATIVE factor so the bracket's signs flip into a match: 2a(x + y) − b(x + y). Then factor out the common bracket: (x + y)(2a − b). If pairs share nothing, rearrange kin together first.\n\nVerify everything the same way: expand your answer and confirm the original returns. Thirty seconds, and the answer is proven rather than hoped.",
      "exit_check": [
        {
          "id": "exit_1",
          "prompt": "For 6x² − 7x − 3, the split numbers must satisfy:",
          "options": [
            "Product −18 and sum −7",
            "Product −3 and sum −7",
            "Product 18 and sum 7",
            "Product −21 and sum −3"
          ],
          "correct_index": 0,
          "time_limit_seconds": 30
        },
        {
          "id": "exit_2",
          "prompt": "In SOAP for the cubes identities, the letters give:",
          "options": [
            "Same, Opposite, Always Positive - the three signs",
            "Square, Order, Add, Product",
            "Sum Of All Powers",
            "Simplify, Organise, Apply, Prove"
          ],
          "correct_index": 0,
          "time_limit_seconds": 30
        },
        {
          "id": "exit_3",
          "prompt": "Grouping −bx − by requires factoring out:",
          "options": [
            "−b, leaving (x + y)",
            "+b, leaving (x + y)",
            "−x, leaving (b + y)",
            "+b, leaving (−x + y)"
          ],
          "correct_index": 0,
          "time_limit_seconds": 30
        },
        {
          "id": "exit_4",
          "prompt": "The reliable check for any factorisation is:",
          "options": [
            "Expand the answer and confirm the original expression returns",
            "Substitute x = 0 only",
            "Compare bracket lengths",
            "Repeat the factorisation"
          ],
          "correct_index": 0,
          "time_limit_seconds": 30
        }
      ]
    }
  }
}
''';

Map<String, dynamic> _entry() {
  final index =
      jsonDecode(_publishedIndexWithReviews) as Map<String, dynamic>;
  final skills = index['skills'] as Map<String, dynamic>;
  return Map<String, dynamic>.from(
      skills['maths.factorisation_techniques'] as Map);
}

void main() {
  group('SkillReviewContent.fromCapsJson (published-index entry form)', () {
    test('parses the real CAPS review fields', () {
      final content = SkillReviewContent.fromCapsJson(_entry(),
          skillRef: 'maths.factorisation_techniques');

      expect(content.skillRef, 'maths.factorisation_techniques');
      expect(content.hasContent, isTrue);

      // Diagnostic: 1-2 skip-ahead questions, McqQuestion field names
      // (correct_index / time_limit_seconds) exactly as authored.
      expect(content.diagnostic, hasLength(2));
      expect(content.diagnostic.first.id, 'diag_1');
      expect(content.diagnostic.first.correctIndex, 0);
      expect(content.diagnostic.first.timeLimitSeconds, 30);
      expect(content.diagnostic.first.options, hasLength(4));

      // Recap: plain text with \n\n paragraph breaks, decoded to real
      // newlines by jsonDecode.
      expect(content.recap, contains('SOAP'));
      expect(content.recap, contains('\n\n'));

      // Exit check: 2-5 MCQs.
      expect(content.exitCheck, hasLength(4));
      expect(content.exitCheck.map((q) => q.id),
          ['exit_1', 'exit_2', 'exit_3', 'exit_4']);
      expect(content.exitCheck.last.prompt,
          contains('reliable check for any factorisation'));
    });

    test('index-era entry (no review keys) has no content — the source '
        'contract requires null for those, never an empty review', () {
      final entry = _entry()
        ..remove('diagnostic')
        ..remove('recap')
        ..remove('exit_check');
      final content = SkillReviewContent.fromCapsJson(entry,
          skillRef: 'maths.factorisation_techniques');
      expect(content.hasContent, isFalse);
      expect(content.diagnostic, isEmpty);
      expect(content.recap, isEmpty);
      expect(content.exitCheck, isEmpty);
    });

    test('malformed question entries are dropped, never thrown on', () {
      final content = SkillReviewContent.fromCapsJson({
        'diagnostic': [
          null,
          'not-a-question',
          {
            'id': 'ok',
            'prompt': 'x?',
            'options': ['a', 'b'],
            'correct_index': 1,
          },
        ],
        'recap': '',
        'exit_check': 'not-a-list',
      }, skillRef: 'maths.factorisation_techniques');
      expect(content.diagnostic.map((q) => q.id), ['ok']);
      expect(content.diagnostic.single.correctIndex, 1);
      expect(content.exitCheck, isEmpty);
      expect(content.hasContent, isTrue);
    });

    test('per-skill CAPS file form: skill_ref read from the json itself',
        () {
      final content = SkillReviewContent.fromCapsJson({
        'skill_ref': 'maths.factorisation_techniques',
        'recap': 'HCF first, every time.',
      });
      expect(content.skillRef, 'maths.factorisation_techniques');
      expect(content.hasContent, isTrue);
    });
  });
}
