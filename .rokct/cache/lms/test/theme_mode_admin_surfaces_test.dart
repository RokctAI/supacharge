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


// A theme-mode flip must restyle the three operator surfaces - the
// announcements desk, the homework queue and the lesson review desk -
// WITHOUT remounting them, and the two dialogs they open with them.
//
// Each page is an auto_route page, so the route holds the instance its
// builder made and no ancestor rebuild reaches it. Each dialog is the
// content a showDialog builder made, and the dialog route holds THAT
// instance the same way. Every subject here is pumped (or opened) as a
// pinned element, exactly as in the product.
import 'dart:convert';

import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/src/common/domain/interface/announcement_admin.dart';
import 'package:lms_sdk/src/common/domain/interface/homework_fulfilment.dart';
import 'package:lms_sdk/src/common/domain/interface/lesson_review_playback.dart';
import 'package:lms_sdk/src/common/domain/interface/lms_repository.dart';
import 'package:lms_sdk/src/common/domain/models/announcement_models.dart';
import 'package:lms_sdk/src/common/presentation/pages/admin/announcements_admin_page.dart';
import 'package:lms_sdk/src/common/presentation/pages/admin/homework_fulfilment_page.dart';
import 'package:lms_sdk/src/common/presentation/pages/admin/lesson_review_page.dart';

import 'theme_flip_host.dart';

const String _pendingJson = '''
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

class _EmptyAnnouncementAdmin implements AnnouncementAdmin {
  @override
  Future<bool> canManage() async => true;

  @override
  Future<List<Announcement>> listAll() async => const <Announcement>[];

  @override
  Future<Announcement> create({
    required String title,
    required String body,
    String? subject,
    int? grade,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async =>
      Announcement(id: 'a1', title: title, body: body);

  @override
  Future<void> retire(String id) async {}
}

class _QueueRepo implements HomeworkFulfilmentRepository {
  @override
  Future<List<HomeworkPendingRequest>> pendingRequests() async =>
      <HomeworkPendingRequest>[
        HomeworkPendingRequest.fromJson(
            jsonDecode(_pendingJson) as Map<String, dynamic>),
      ];

  @override
  Future<HomeworkMcqDraft> draftMcq({required String id}) async =>
      throw UnimplementedError();

  @override
  Future<void> publishMcq(
      {required String id, required HomeworkMcqDraft mcq}) async {}

  @override
  Future<void> decline({required String id, required String reason}) async {}
}

class _UnusedRepository extends Fake implements LmsRepository {}

class _UnusedPlayback extends Fake implements LessonReviewPlayback {}

void main() {
  testWidgets('AnnouncementsAdminPage restyles its surface on a flip',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _AnnouncementsHost(),
      read: (tester) => scaffoldFill(tester, AnnouncementsAdminPage),
      expected: AppStyle.surfaceFor,
    );
  });

  testWidgets('AnnouncementsAdminPage restyles its app bar ink on a flip',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _AnnouncementsHost(),
      read: (tester) => textInk(tester, 'Announcements'),
      expected: AppStyle.inkFor,
    );
  });

  testWidgets('the empty-queue line inside AnnouncementsAdminPage restyles',
      (tester) async {
    // _buildList is a helper the build calls, so this covers the brightness
    // handed down to it.
    await expectRestylesOnFlip(
      tester,
      child: const _AnnouncementsHost(),
      read: (tester) => textInkContaining(tester, 'Nothing posted yet'),
      expected: AppStyle.secondaryInkFor,
    );
  });

  testWidgets('the compose dialog rides the dialog route rebuild',
      (tester) async {
    // The reachability half for a dialog: _ComposeDialog still reads the
    // statics and is deliberately untouched. showDialog's content is built
    // by a builder the route re-invokes - a Navigator update calls
    // Route.changedExternalState, which clears ModalRoute's cached page -
    // so the flip hands the dialog a fresh instance and the statics resolve
    // against the mode it has already set. This passes on origin/main too,
    // which is the point: it pins the rejection.
    await expectRestylesOnFlip(
      tester,
      child: const _AnnouncementsHost(),
      afterPump: (tester) => tester.tap(find.text('New announcement')),
      read: dialogFill,
      expected: AppStyle.cardFor,
    );
  });

  testWidgets('HomeworkFulfilmentPage restyles its surface on a flip',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _QueueHost(),
      read: (tester) => scaffoldFill(tester, HomeworkFulfilmentPage),
      expected: AppStyle.surfaceFor,
    );
  });

  testWidgets('HomeworkFulfilmentPage restyles its app bar ink on a flip',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _QueueHost(),
      read: (tester) => textInk(tester, 'Homework queue'),
      expected: AppStyle.inkFor,
    );
  });

  testWidgets('the queue count line restyles on a flip', (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _QueueHost(),
      read: (tester) => textInkContaining(tester, 'awaiting an answer set'),
      expected: AppStyle.secondaryInkFor,
    );
  });

  testWidgets('the publish dialog rides the dialog route rebuild',
      (tester) async {
    // Same rejection as the compose dialog above, on the queue side.
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await expectRestylesOnFlip(
      tester,
      child: const _QueueHost(),
      afterPump: (tester) => tester.tap(find.text('Publish MCQ')),
      read: dialogFill,
      expected: AppStyle.cardFor,
    );
  });

  testWidgets('LessonReviewPage restyles its surface on a flip',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _LessonReviewHost(),
      read: (tester) => scaffoldFill(tester, LessonReviewPage),
      expected: AppStyle.surfaceFor,
    );
  });

  testWidgets('LessonReviewPage restyles its app bar ink on a flip',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _LessonReviewHost(),
      read: (tester) => textInk(tester, 'Lesson review'),
      expected: AppStyle.inkFor,
    );
  });

  testWidgets('the retry state inside LessonReviewPage rides the page rebuild',
      (tester) async {
    // The reachability half: _RetryState still reads the statics and is
    // deliberately untouched, because the page builds it non-`const`.
    await expectRestylesOnFlip(
      tester,
      child: const _LessonReviewHost(),
      read: (tester) =>
          textInk(tester, "The lesson index isn't available right now."),
      expected: AppStyle.inkFor,
    );
  });
}

// Each subject gets a wrapper whose instance the host holds across the
// flip, so nothing above the subject can rebuild it.
class _AnnouncementsHost extends StatelessWidget {
  const _AnnouncementsHost();

  @override
  Widget build(BuildContext context) =>
      AnnouncementsAdminPage(admin: _EmptyAnnouncementAdmin());
}

class _QueueHost extends StatelessWidget {
  const _QueueHost();

  @override
  Widget build(BuildContext context) =>
      HomeworkFulfilmentPage(repository: _QueueRepo());
}

class _LessonReviewHost extends StatelessWidget {
  const _LessonReviewHost();

  @override
  Widget build(BuildContext context) => LessonReviewPage(
        repository: _UnusedRepository(),
        playback: _UnusedPlayback(),
        fetchIndex: () async => throw Exception('index unavailable'),
      );
}
