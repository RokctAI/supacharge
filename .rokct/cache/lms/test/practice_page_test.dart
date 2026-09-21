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

/// Fake repository for the adaptive practice flow: serves a fixed queue in
/// a fixed order (standing in for the SERVER's selection — the client must
/// render whatever order arrives) and captures every recorded attempt.
class _FakePracticeRepo extends Fake implements LmsRepository {
  final List<PracticeItem> items;
  final List<Map<String, Object?>> attempts = [];
  int queueRequests = 0;

  _FakePracticeRepo(this.items);

  @override
  Future<PracticeQueue> practiceQueue({String? subject, String? lesson}) async {
    queueRequests++;
    return PracticeQueue(items: items, generatedAt: 'now');
  }

  @override
  Future<void> recordPracticeAttempt({
    required String itemId,
    required McqOutcome outcome,
    String? subtopicRef,
    int? selectedIndex,
  }) async {
    attempts.add({
      'itemId': itemId,
      'outcome': outcome,
      'subtopicRef': subtopicRef,
      'selectedIndex': selectedIndex,
    });
  }
}

const _items = [
  PracticeItem(
    id: 'p1',
    subject: 'Mathematics',
    subtopicRef: 'algebra.factorising',
    prompt: 'Factorise: x^2 + 5x + 6',
    options: ['(x+2)(x+3)', '(x+1)(x+6)', '(x-2)(x-3)'],
    correctIndex: 0,
  ),
  PracticeItem(
    id: 'p2',
    subject: 'Mathematics',
    subtopicRef: 'algebra.exponents',
    prompt: 'Simplify: 2^3 x 2^4',
    options: ['2^12', '2^7'],
    correctIndex: 1,
  ),
];

Future<void> _pump(WidgetTester tester, LmsRepository repo) async {
  await tester.pumpWidget(MaterialApp(home: PracticePage(repository: repo)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the server queue in order and records the answer',
      (tester) async {
    final repo = _FakePracticeRepo(_items);
    await _pump(tester, repo);

    // Server order respected: p1 first.
    expect(find.text('Factorise: x^2 + 5x + 6'), findsOneWidget);
    expect(find.text('Question 1 of 2'), findsOneWidget);

    // Wrong pick: attempt recorded verbatim (incorrect + the picked index),
    // never converted to a skip.
    await tester.tap(find.text('(x+1)(x+6)'));
    await tester.pumpAndSettle();
    expect(repo.attempts, hasLength(1));
    expect(repo.attempts.single['itemId'], 'p1');
    expect(repo.attempts.single['outcome'], McqOutcome.incorrect);
    expect(repo.attempts.single['selectedIndex'], 1);
    expect(repo.attempts.single['subtopicRef'], 'algebra.factorising');

    // Options lock after answering — a second tap must not double-record.
    await tester.tap(find.text('(x-2)(x-3)'));
    await tester.pumpAndSettle();
    expect(repo.attempts, hasLength(1));

    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();
    expect(find.text('Question 2 of 2'), findsOneWidget);
  });

  testWidgets('a skip is recorded as a skip and the summary sums honestly',
      (tester) async {
    final repo = _FakePracticeRepo(_items);
    await _pump(tester, repo);

    // Answer Q1 correctly.
    await tester.tap(find.text('(x+2)(x+3)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();

    // Skip Q2: outcome skipped, no selected index (no forcing).
    await tester.tap(find.text('Skip this one'));
    await tester.pumpAndSettle();
    expect(repo.attempts, hasLength(2));
    expect(repo.attempts.last['outcome'], McqOutcome.skipped);
    expect(repo.attempts.last['selectedIndex'], isNull);

    // Summary: 1 of 2 correct, 1 skipped.
    expect(find.text('Practice done'), findsOneWidget);
    expect(find.text('1 of 2 correct — 1 skipped'), findsOneWidget);

    // "Practice more" asks the SERVER again — a fresh selection, not a
    // client-side reshuffle.
    await tester.tap(find.text('Practice more'));
    await tester.pumpAndSettle();
    expect(repo.queueRequests, 2);
    expect(find.text('Question 1 of 2'), findsOneWidget);
  });

  testWidgets('an empty queue shows the calm empty state, never an error',
      (tester) async {
    final repo = _FakePracticeRepo(const []);
    await _pump(tester, repo);
    expect(find.text('Nothing to practice yet'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  test('PracticeQueue.fromJson drops malformed items instead of rendering them',
      () {
    final queue = PracticeQueue.fromJson({
      'items': [
        {
          'id': 'ok',
          'subject': 'maths',
          'question': 'Q?',
          'options': ['a', 'b'],
          'correct_index': 1,
        },
        {'id': 'broken', 'question': 'no options', 'options': []},
        {
          'id': 'bad-index',
          'question': 'Q?',
          'options': ['a', 'b'],
          'correct_index': 7,
        },
      ],
      'generated_at': 't',
    });
    expect(queue.items, hasLength(1));
    expect(queue.items.single.id, 'ok');
    expect(queue.items.single.correctIndex, 1);
  });
}
