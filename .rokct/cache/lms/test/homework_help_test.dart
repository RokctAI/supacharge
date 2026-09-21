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
// Direct src imports (the skills_wiring_test schedule_notifier precedent),
// deliberately NOT the lms_sdk barrel: in the standalone workspace the
// barrel drags in pages whose compose-time-injected TrKeys members don't
// exist yet, and every barrel-importing suite fails to LOAD before it can
// run. The homework surface itself has no such dependency, so importing it
// directly keeps this suite runnable standalone AND composed.
import 'package:lms_sdk/src/common/domain/interface/access_status_source.dart';
import 'package:lms_sdk/src/common/domain/interface/homework_help.dart';
import 'package:lms_sdk/src/common/domain/models/access_policy.dart';
import 'package:lms_sdk/src/common/domain/models/homework_models.dart';
import 'package:lms_sdk/src/common/domain/models/lesson_models.dart';
import 'package:lms_sdk/src/common/presentation/pages/homework/homework_help_page.dart';

/// Async homework help wiring (product log #42 item 1: #4 send-and-wait +
/// #1 guide-don't-solve). The JSON fixtures below pin `rlms.api.homework`'s
/// actual `_student_view` / `answer_homework_mcq` shapes — the same
/// pin-the-real-contract posture as skills_wiring_test.dart.
const _readyQuestionJson = '''
{
  "id": "hw-001",
  "subject": "Mathematics",
  "grade": 11,
  "question_text": "Solve for x: 2x + 6 = 14",
  "status": "Ready",
  "submitted_at": "2026-08-13 09:30:00",
  "attachments": [],
  "decline_reason": null,
  "answered_index": null,
  "answer_outcome": null,
  "answered_at": null,
  "mcq": {
    "question": "You need x on its own. Which value satisfies 2x + 6 = 14?",
    "options": ["x = 4", "x = 10", "x = 7", "x = -4"]
  }
}
''';

const _declinedQuestionJson = '''
{
  "id": "hw-002",
  "subject": "English",
  "grade": 11,
  "question_text": "Write an essay on the causes of World War 1",
  "status": "Declined",
  "submitted_at": "2026-08-13 10:00:00",
  "decline_reason": "This needs your own written argument — a quick check can't stand in for an essay.",
  "answered_index": null,
  "answer_outcome": null,
  "answered_at": null
}
''';

/// A freshly submitted question carrying photo refs — `_student_view`'s
/// `attachments` list (parsed from the stored `attachment_refs` JSON).
const _submittedWithPhotosJson = '''
{
  "id": "hw-003",
  "subject": "Physics",
  "grade": 11,
  "question_text": "Why does the ball curve? See my diagram.",
  "status": "Submitted",
  "submitted_at": "2026-08-14 08:00:00",
  "attachments": ["/private/files/hw-diagram-1.jpg", "/private/files/hw-diagram-2.jpg"],
  "decline_reason": null,
  "answered_index": null,
  "answer_outcome": null,
  "answered_at": null
}
''';

const _revealJson = '''
{
  "correct": false,
  "selected_index": 1,
  "correct_index": 0,
  "correct_option": "x = 4",
  "explanation": "Subtract 6 from both sides (2x = 8), then divide by 2."
}
''';

HomeworkQuestion _ready() => HomeworkQuestion.fromJson(
    jsonDecode(_readyQuestionJson) as Map<String, dynamic>);

void main() {
  group('rlms.api.homework contract', () {
    test('parses the Ready student view — options WITHOUT the answer', () {
      final q = _ready();
      expect(q.id, 'hw-001');
      expect(q.subject, 'Mathematics');
      expect(q.grade, 11);
      expect(q.status, HomeworkStatus.ready);
      expect(q.submittedAt, isNotNull);
      expect(q.mcq, isNotNull);
      expect(q.mcq!.options, hasLength(4));
      // The guide-don't-solve invariant, structurally: the pre-attempt MCQ
      // model has no correct-index or explanation to leak — the truth only
      // exists on HomeworkReveal, which the server returns AFTER the
      // attempt is recorded.
      expect(q.reveal, isNull);
    });

    test('parses the essay decline with its student-visible reason', () {
      final q = HomeworkQuestion.fromJson(
          jsonDecode(_declinedQuestionJson) as Map<String, dynamic>);
      expect(q.status, HomeworkStatus.declined);
      expect(q.declineReason, contains('essay'));
      expect(q.mcq, isNull);
    });

    test('parses the post-attempt reveal ("wrong, A is correct")', () {
      final reveal = HomeworkReveal.fromJson(
          jsonDecode(_revealJson) as Map<String, dynamic>);
      expect(reveal.correct, isFalse);
      expect(reveal.selectedIndex, 1);
      expect(reveal.correctIndex, 0);
      expect(reveal.correctOption, 'x = 4');
      expect(reveal.explanation, contains('Subtract 6'));
    });

    test('parses photo attachment refs; absent means empty, never null', () {
      final withPhotos = HomeworkQuestion.fromJson(
          jsonDecode(_submittedWithPhotosJson) as Map<String, dynamic>);
      expect(withPhotos.attachments, [
        '/private/files/hw-diagram-1.jpg',
        '/private/files/hw-diagram-2.jpg',
      ]);
      // Fixtures without the key (older server) and with an empty list
      // both read as no photos.
      expect(_ready().attachments, isEmpty);
      final declined = HomeworkQuestion.fromJson(
          jsonDecode(_declinedQuestionJson) as Map<String, dynamic>);
      expect(declined.attachments, isEmpty);
    });

    test('status strings map exactly to the doctype Select options', () {
      expect(HomeworkStatus.parse('Submitted'), HomeworkStatus.submitted);
      expect(HomeworkStatus.parse('In Review'), HomeworkStatus.inReview);
      expect(HomeworkStatus.parse('Ready'), HomeworkStatus.ready);
      expect(HomeworkStatus.parse('Declined'), HomeworkStatus.declined);
      expect(HomeworkStatus.parse('Completed'), HomeworkStatus.completed);
      expect(HomeworkStatus.parse('???'), HomeworkStatus.unknown);
    });
  });

  group('HomeworkHelpPage', () {
    testWidgets('attempt-then-reveal: the answer only appears after lock-in',
        (tester) async {
      // A tall surface so the expanded card (intro + submit form + guided
      // check) fits without scroll gymnastics.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeHomeworkRepository([_ready()]);
      await tester.pumpWidget(MaterialApp(
        home: HomeworkHelpPage(
          repository: repo,
          assistant: assistantPersonaForGrade(11),
        ),
      ));
      await tester.pumpAndSettle();

      // Grade 11's host fronts the page (decision #40 — never hard-coded).
      expect(find.textContaining('Bianca'), findsWidgets);

      // Open the question card; the guided check shows options, no verdict.
      await tester.tap(find.textContaining('Solve for x'));
      await tester.pumpAndSettle();
      expect(find.text('x = 4'), findsOneWidget);
      expect(repo.answered, isEmpty);

      // Pick the WRONG option and lock it in (scrolling each control into
      // view first — the expanded card outgrows the test viewport).
      await tester.ensureVisible(find.text('x = 10'));
      await tester.tap(find.text('x = 10'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Lock in'));
      await tester.tap(find.textContaining('Lock in'));
      await tester.pumpAndSettle();

      // The attempt was recorded first; the reveal names the correction.
      expect(repo.answered, [('hw-001', 1)]);
      expect(find.textContaining('x = 4'), findsWidgets);
      expect(find.textContaining('Subtract 6'), findsOneWidget);
    });

    testWidgets('declined questions show the reason, not an MCQ',
        (tester) async {
      final declined = HomeworkQuestion.fromJson(
          jsonDecode(_declinedQuestionJson) as Map<String, dynamic>);
      await tester.pumpWidget(MaterialApp(
        home: HomeworkHelpPage(
          repository: _FakeHomeworkRepository([declined]),
          assistant: assistantPersonaForGrade(12),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Write an essay'));
      await tester.pumpAndSettle();
      expect(find.textContaining('your own written argument'), findsOneWidget);
      expect(find.textContaining('Lock in'), findsNothing);
    });

    testWidgets('homeworkTool capability gates the page (lapsed is blocked)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: HomeworkHelpPage(
          repository: _FakeHomeworkRepository(const []),
          assistant: assistantPersonaForGrade(10),
          accessSource: _FixedAccess(
              const AccessStatus(subscription: SubscriptionState.lapsed)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('subscription'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('photos upload first, then their refs ride the submit',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeHomeworkRepository(const []);
      var picks = 0;
      await tester.pumpWidget(MaterialApp(
        home: HomeworkHelpPage(
          repository: repo,
          assistant: assistantPersonaForGrade(11),
          pickPhoto: (source) async => '/no-such-dir/pick-${++picks}.jpg',
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField).at(1), 'Why does the ball curve?');
      await tester.tap(find.byKey(const Key('homework-attach-camera')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('homework-attach-gallery')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('homework-photo-0')), findsOneWidget);
      expect(find.byKey(const Key('homework-photo-1')), findsOneWidget);
      expect(find.text('2/${HomeworkHelpPage.maxPhotos}'), findsOneWidget);
      // Nothing uploads at pick time — only on send.
      expect(repo.uploaded, isEmpty);

      await tester.tap(find.text('Send question'));
      await tester.pumpAndSettle();

      expect(repo.uploaded,
          ['/no-such-dir/pick-1.jpg', '/no-such-dir/pick-2.jpg']);
      expect(repo.submitted, hasLength(1));
      expect(repo.submitted.single.$1, 'Why does the ball curve?');
      expect(repo.submitted.single.$2,
          ['/private/files/pick-1.jpg', '/private/files/pick-2.jpg']);
      // The draft cleared, thumbnails included.
      expect(find.byKey(const Key('homework-photo-0')), findsNothing);
    });

    testWidgets('a removed thumbnail never uploads; cap stops at 3',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeHomeworkRepository(const []);
      var picks = 0;
      await tester.pumpWidget(MaterialApp(
        home: HomeworkHelpPage(
          repository: repo,
          assistant: assistantPersonaForGrade(11),
          pickPhoto: (source) async => '/no-such-dir/pick-${++picks}.jpg',
        ),
      ));
      await tester.pumpAndSettle();

      final camera = find.byKey(const Key('homework-attach-camera'));
      for (var i = 0; i < 4; i++) {
        await tester.tap(camera);
        await tester.pumpAndSettle();
      }
      // The 4th tap was a no-op: the affordance disables at the cap.
      expect(picks, HomeworkHelpPage.maxPhotos);
      expect(find.byKey(const Key('homework-photo-2')), findsOneWidget);
      expect(find.byKey(const Key('homework-photo-3')), findsNothing);

      // Remove the middle photo, then send: only the remaining two upload.
      await tester.tap(find.byKey(const Key('homework-photo-remove-1')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField).at(1), 'Solve for x: 2x + 6 = 14');
      await tester.tap(find.text('Send question'));
      await tester.pumpAndSettle();
      expect(repo.uploaded,
          ['/no-such-dir/pick-1.jpg', '/no-such-dir/pick-3.jpg']);
    });

    testWidgets(
        'upload failure: friendly line only, draft kept, nothing submitted',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeHomeworkRepository(const [], failUploads: true);
      await tester.pumpWidget(MaterialApp(
        home: HomeworkHelpPage(
          repository: repo,
          assistant: assistantPersonaForGrade(11),
          pickPhoto: (source) async => '/no-such-dir/pick.jpg',
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField).at(1), 'Why does the ball curve?');
      await tester.tap(find.byKey(const Key('homework-attach-camera')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send question'));
      await tester.pumpAndSettle();

      // Ray's rule (PR #99): one friendly line for the student; the real
      // detail goes to telemetry, and the server-flavoured message from
      // the repository never reaches the screen.
      expect(find.textContaining('Could not send your photos'),
          findsOneWidget);
      expect(find.textContaining('storage quota'), findsNothing);
      expect(find.textContaining('DioException'), findsNothing);
      // Nothing was submitted, and the draft survives for a retry.
      expect(repo.submitted, isEmpty);
      expect(find.text('Why does the ball curve?'), findsOneWidget);
      expect(find.byKey(const Key('homework-photo-0')), findsOneWidget);
    });

    testWidgets('a question with photo refs shows the attachment count',
        (tester) async {
      final withPhotos = HomeworkQuestion.fromJson(
          jsonDecode(_submittedWithPhotosJson) as Map<String, dynamic>);
      await tester.pumpWidget(MaterialApp(
        home: HomeworkHelpPage(
          repository: _FakeHomeworkRepository([withPhotos]),
          assistant: assistantPersonaForGrade(11),
        ),
      ));
      await tester.pumpAndSettle();
      // 'photos_attached' falls back to "Photos attached" untranslated.
      expect(find.textContaining('Photos attached'), findsOneWidget);
    });

    testWidgets(
        'submit refusal: the server\'s own student-facing words, verbatim',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeHomeworkRepository(
        const [],
        failSubmitWith: const HomeworkHelpException.refusal(
            'That question is too long (5000 characters, max 4000). '
            'Send the specific problem you are stuck on.'),
      );
      await tester.pumpWidget(MaterialApp(
        home: HomeworkHelpPage(
          repository: repo,
          assistant: assistantPersonaForGrade(11),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField).at(1), 'A very long question');
      await tester.tap(find.text('Send question'));
      await tester.pumpAndSettle();

      // A recognized refusal is the server's student-crafted copy — it
      // stays meaningful, shown in the server's own words.
      expect(find.textContaining('That question is too long'), findsOneWidget);
    });

    testWidgets(
        'submit technical failure: friendly line only, never the detail',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeHomeworkRepository(
        const [],
        failSubmitWith: const HomeworkHelpException(
            'Unexpected submit_homework_question response shape: '
            '{traceback: pymysql.err.OperationalError on db-tenant-4}'),
      );
      await tester.pumpWidget(MaterialApp(
        home: HomeworkHelpPage(
          repository: repo,
          assistant: assistantPersonaForGrade(11),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField).at(1), 'Solve for x: 2x + 6 = 14');
      await tester.tap(find.text('Send question'));
      await tester.pumpAndSettle();

      // Ray's rule (PR #99): admin/server detail never reaches a student.
      // The student sees one friendly line; the detail goes to telemetry.
      expect(find.textContaining('Could not send your question'),
          findsOneWidget);
      expect(find.textContaining('pymysql'), findsNothing);
      expect(find.textContaining('response shape'), findsNothing);
      // The draft survives for a retry.
      expect(find.text('Solve for x: 2x + 6 = 14'), findsOneWidget);
    });

    testWidgets(
        'lock-in technical failure: friendly line only, never the detail',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeHomeworkRepository(
        [_ready()],
        failAnswerWith: const HomeworkHelpException(
            'Unexpected answer_homework_mcq response shape: '
            '<html>502 Bad Gateway nginx/1.24</html>'),
      );
      await tester.pumpWidget(MaterialApp(
        home: HomeworkHelpPage(
          repository: repo,
          assistant: assistantPersonaForGrade(11),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Solve for x'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('x = 10'));
      await tester.tap(find.text('x = 10'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Lock in'));
      await tester.tap(find.textContaining('Lock in'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not check your answer'),
          findsOneWidget);
      expect(find.textContaining('Bad Gateway'), findsNothing);
      expect(find.textContaining('response shape'), findsNothing);
    });

    testWidgets(
        'lock-in refusal: the server\'s one-attempt refusal stays verbatim',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeHomeworkRepository(
        [_ready()],
        failAnswerWith: const HomeworkHelpException.refusal(
            'This question is not ready to answer (status: Completed).'),
      );
      await tester.pumpWidget(MaterialApp(
        home: HomeworkHelpPage(
          repository: repo,
          assistant: assistantPersonaForGrade(11),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Solve for x'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('x = 10'));
      await tester.tap(find.text('x = 10'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Lock in'));
      await tester.tap(find.textContaining('Lock in'));
      await tester.pumpAndSettle();

      expect(find.textContaining('not ready to answer'), findsOneWidget);
    });
  });
}

class _FakeHomeworkRepository implements HomeworkHelpRepository {
  final List<HomeworkQuestion> questions;
  final List<(String, int)> answered = [];
  final List<String> uploaded = [];
  final List<(String, List<String>?)> submitted = [];

  /// When true, [uploadAttachment] refuses with server-flavoured detail —
  /// the page must show a friendly line, never these words.
  final bool failUploads;

  /// When set, [submitQuestion] / [answer] throw it — marked refusals must
  /// surface verbatim, unmarked technical detail must never hit the screen.
  final HomeworkHelpException? failSubmitWith;
  final HomeworkHelpException? failAnswerWith;

  _FakeHomeworkRepository(
    this.questions, {
    this.failUploads = false,
    this.failSubmitWith,
    this.failAnswerWith,
  });

  @override
  Future<HomeworkSubmitReceipt> submitQuestion({
    required String questionText,
    String? subject,
    int? grade,
    List<String>? attachments,
  }) async {
    final failure = failSubmitWith;
    if (failure != null) throw failure;
    submitted.add((questionText, attachments));
    return const HomeworkSubmitReceipt(
        id: 'hw-new', status: HomeworkStatus.submitted);
  }

  @override
  Future<String> uploadAttachment(String localFilePath) async {
    if (failUploads) {
      throw const HomeworkHelpException(
          'DioException 507: tenant storage quota exceeded on shard 4');
    }
    uploaded.add(localFilePath);
    return '/private/files/${localFilePath.split('/').last}';
  }

  @override
  Future<List<HomeworkQuestion>> myQuestions() async => questions;

  @override
  Future<HomeworkQuestion?> question(String id) async =>
      questions.where((q) => q.id == id).firstOrNull;

  @override
  Future<HomeworkReveal> answer({
    required String id,
    required int selectedIndex,
  }) async {
    final failure = failAnswerWith;
    if (failure != null) throw failure;
    answered.add((id, selectedIndex));
    return HomeworkReveal.fromJson(
        jsonDecode(_revealJson) as Map<String, dynamic>);
  }
}

class _FixedAccess implements AccessStatusSource {
  final AccessStatus status;
  _FixedAccess(this.status);
  @override
  Future<AccessStatus> current() async => status;
}
