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


// Copyright (c) 2026 ROKCT INTELLIGENCE (PTY) LTD
// For license information, please see license.txt

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Direct src imports (the homework_help_test precedent), deliberately NOT
// the lms_sdk barrel, so the suite loads standalone AND composed.
import 'package:lms_sdk/src/common/domain/interface/homework_fulfilment.dart';
import 'package:lms_sdk/src/common/presentation/pages/admin/homework_fulfilment_page.dart';

/// The operator fulfilment surface + AI drafting wiring. The JSON fixtures
/// pin `rlms.api.homework`'s actual `homework_pending_requests` /
/// `draft_homework_mcq` shapes — the pin-the-real-contract posture of
/// homework_help_test.dart.
const _pendingJson = '''
{
  "name": "hw-101",
  "member": "student@example.com",
  "subject": "Mathematics",
  "grade": 8,
  "question_text": "Solve for x: 2x + 6 = 14",
  "status": "Submitted",
  "submitted_at": "2026-08-14 08:00:00"
}
''';

/// The `mcq` half of a `draft_homework_mcq` response — already passed
/// through the server's `validate_mcq_payload`, so the same shape publish
/// accepts.
const _draftJson = '''
{
  "question": "Which value of x satisfies 2x + 6 = 14?",
  "options": ["x = 4", "x = 10", "x = 7", "x = -4"],
  "correct_index": 0,
  "explanation": "Subtract 6 from both sides (2x = 8), then divide by 2."
}
''';

HomeworkPendingRequest _pending() => HomeworkPendingRequest.fromJson(
    jsonDecode(_pendingJson) as Map<String, dynamic>);

HomeworkMcqDraft _draft() =>
    HomeworkMcqDraft.fromJson(jsonDecode(_draftJson) as Map<String, dynamic>);

void main() {
  group('HomeworkMcqDraft.fromJson', () {
    test('parses the draft endpoint shape', () {
      final draft = _draft();
      expect(draft.question, 'Which value of x satisfies 2x + 6 = 14?');
      expect(draft.options, hasLength(4));
      expect(draft.correctIndex, 0);
      expect(draft.explanation, contains('Subtract 6'));
    });

    test('round-trips into the publish wire shape', () {
      final json = _draft().toJson();
      expect(json['question'], 'Which value of x satisfies 2x + 6 = 14?');
      expect(json['options'], hasLength(4));
      expect(json['correct_index'], 0);
      expect(json['explanation'], isNotEmpty);
    });
  });

  group('Publish dialog AI drafting', () {
    Future<void> openDialog(WidgetTester tester, _FakeFulfilmentRepo repo) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: HomeworkFulfilmentPage(repository: repo),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publish MCQ'));
      await tester.pumpAndSettle();
    }

    testWidgets('Draft with AI pre-fills the form for the operator to edit',
        (tester) async {
      final repo = _FakeFulfilmentRepo([_pending()], draft: _draft());
      await openDialog(tester, repo);

      // The dialog opens hand-written-first: question prefilled with the
      // student's words, empty options.
      expect(find.text('Draft with AI'), findsOneWidget);
      expect(find.text('x = 4'), findsNothing);

      await tester.tap(find.text('Draft with AI'));
      await tester.pumpAndSettle();

      // Every field pre-filled from the draft, ready to edit.
      expect(repo.draftedIds, ['hw-101']);
      expect(
          find.text('Which value of x satisfies 2x + 6 = 14?'), findsOneWidget);
      for (final option in ['x = 4', 'x = 10', 'x = 7', 'x = -4']) {
        expect(find.text(option), findsOneWidget);
      }
      expect(find.text('Subtract 6 from both sides (2x = 8), then divide by 2.'),
          findsOneWidget);

      // Drafting is NOT publishing: nothing was sent, the human decides.
      expect(repo.published, isEmpty);

      // The operator approves — only now does the publish call happen,
      // carrying the (possibly edited) draft.
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(repo.published, hasLength(1));
      expect(repo.published.single.correctIndex, 0);
      expect(repo.published.single.options, hasLength(4));
    });

    testWidgets('draft failure shows a friendly line and keeps the form',
        (tester) async {
      final repo = _FakeFulfilmentRepo(
        [_pending()],
        draftError:
            const HomeworkFulfilmentException("AI drafting isn't configured yet."),
      );
      await openDialog(tester, repo);

      await tester.tap(find.text('Draft with AI'));
      await tester.pumpAndSettle();

      // The server's own friendly line, inside the dialog — the operator
      // can still write the set by hand and publish.
      expect(find.text("AI drafting isn't configured yet."), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
      expect(repo.published, isEmpty);
    });
  });
}

class _FakeFulfilmentRepo implements HomeworkFulfilmentRepository {
  final List<HomeworkPendingRequest> pending;
  final HomeworkMcqDraft? draft;
  final HomeworkFulfilmentException? draftError;

  final List<String> draftedIds = [];
  final List<HomeworkMcqDraft> published = [];
  final List<String> declined = [];

  _FakeFulfilmentRepo(this.pending, {this.draft, this.draftError});

  @override
  Future<List<HomeworkPendingRequest>> pendingRequests() async => pending;

  @override
  Future<HomeworkMcqDraft> draftMcq({required String id}) async {
    draftedIds.add(id);
    if (draftError != null) throw draftError!;
    return draft!;
  }

  @override
  Future<void> publishMcq(
      {required String id, required HomeworkMcqDraft mcq}) async {
    published.add(mcq);
  }

  @override
  Future<void> decline({required String id, required String reason}) async {
    declined.add(id);
  }
}
