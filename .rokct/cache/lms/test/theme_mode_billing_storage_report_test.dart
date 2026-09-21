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


// A theme-mode flip must restyle these four surfaces WITHOUT remounting
// them. Each is an auto_route page: the route holds the instance its builder
// made, so no ancestor rebuild reaches the page, and a page whose only mode
// input was a mode-resolving AppStyle static (surfaceDark, textPrimary, ...)
// kept the previous mode's colours until something else happened to rebuild
// it. Every subject here is pumped as the host's `const` child, which pins
// its element exactly the way the route does.
//
// The child assertions are the other half of the same story: the cards and
// retry states inside these pages still read the statics, and that is
// correct - the page constructs them NON-`const` from its own build, so the
// page's rebuild hands each one a fresh instance and the statics resolve
// against the mode the flip already set.
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/src/common/domain/interface/billing_account.dart';
import 'package:lms_sdk/src/common/domain/interface/lesson_storage.dart';
import 'package:lms_sdk/src/common/domain/models/billing_models.dart';
import 'package:lms_sdk/src/common/presentation/pages/billing/billing_history_page.dart';
import 'package:lms_sdk/src/common/presentation/pages/billing/entitlements_page.dart';
import 'package:lms_sdk/src/common/presentation/pages/reports/term_report_page.dart';
import 'package:lms_sdk/src/common/presentation/pages/storage/storage_manager_page.dart';

import 'theme_flip_host.dart';

class _FailingHistory implements BillingHistorySource {
  @override
  Future<List<BillingRecordEntry>> history() async =>
      throw Exception('offline');
}

class _FailingEntitlements implements EntitlementsSource {
  @override
  Future<EntitlementSummary> summary() async => throw Exception('offline');
}

class _StubInventory implements LessonStorageInventory {
  _StubInventory(this.lessons);

  final List<StoredLesson> lessons;

  @override
  Future<List<StoredLesson>> listDownloads() async => lessons;

  @override
  Future<void> deleteDownload(String sessionId) async {}

  @override
  Future<void> redownload(String sessionId) async {}
}

void main() {
  testWidgets('BillingHistoryPage restyles its surface on a theme-mode flip',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _BillingHistoryHost(),
      read: (tester) => scaffoldFill(tester, BillingHistoryPage),
      expected: AppStyle.surfaceFor,
    );
  });

  testWidgets('BillingHistoryPage restyles its app bar ink on a flip',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _BillingHistoryHost(),
      read: (tester) => textInk(tester, 'Billing history'),
      expected: AppStyle.inkFor,
    );
  });

  testWidgets(
      'the retry state inside BillingHistoryPage rides the page rebuild',
      (tester) async {
    // The reachability half: _RetryState still reads the statics and is
    // deliberately untouched, because the page builds it non-`const`.
    await expectRestylesOnFlip(
      tester,
      child: const _BillingHistoryHost(),
      read: (tester) =>
          textInk(tester, "Your billing history isn't available right now."),
      expected: AppStyle.inkFor,
    );
  });

  testWidgets('EntitlementsPage restyles its surface on a theme-mode flip',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _EntitlementsHost(),
      read: (tester) => scaffoldFill(tester, EntitlementsPage),
      expected: AppStyle.surfaceFor,
    );
  });

  testWidgets('EntitlementsPage restyles its app bar ink on a flip',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _EntitlementsHost(),
      read: (tester) => textInk(tester, 'My plan'),
      expected: AppStyle.inkFor,
    );
  });

  testWidgets('the retry state inside EntitlementsPage rides the page rebuild',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _EntitlementsHost(),
      read: (tester) =>
          textInk(tester, "Your plan details aren't available right now."),
      expected: AppStyle.inkFor,
    );
  });

  testWidgets('StorageManagerPage restyles its surface on a theme-mode flip',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _StorageHost(lessons: <StoredLesson>[]),
      read: (tester) => scaffoldFill(tester, StorageManagerPage),
      expected: AppStyle.surfaceFor,
    );
  });

  testWidgets('the empty-downloads note restyles on a flip although it is '
      'mounted const', (tester) async {
    // _CenteredNote is built `const` on the empty path, so the page's own
    // rebuild cannot restyle it - it carries its own theme dependency.
    await expectRestylesOnFlip(
      tester,
      child: const _StorageHost(lessons: <StoredLesson>[]),
      read: (tester) => textInkContaining(tester, 'No downloaded lessons yet'),
      expected: AppStyle.secondaryInkFor,
    );
  });

  testWidgets('the downloads total line restyles on a flip', (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: _StorageHost(lessons: <StoredLesson>[_lesson()]),
      read: (tester) => textInkContaining(tester, 'on this device'),
      expected: AppStyle.secondaryInkFor,
    );
  });

  testWidgets('a lesson row inside StorageManagerPage rides the page rebuild',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: _StorageHost(lessons: <StoredLesson>[_lesson()]),
      read: (tester) => textInk(tester, 'Mathematics'),
      expected: AppStyle.inkFor,
    );
  });

  testWidgets('TermReportPage restyles its surface on a theme-mode flip',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _TermReportHost(),
      read: (tester) => scaffoldFill(tester, TermReportPage),
      expected: AppStyle.surfaceFor,
    );
  });

  testWidgets("TermReportPage's friendly message restyles on a flip",
      (tester) async {
    // The message comes from a helper the build calls, so this also covers
    // the brightness handed down to _message.
    await expectRestylesOnFlip(
      tester,
      child: const _TermReportHost(),
      read: (tester) => textInkContaining(tester, "Couldn't load the term"),
      expected: AppStyle.secondaryInkFor,
    );
  });
}

StoredLesson _lesson() => StoredLesson(
      sessionId: 's1',
      sizeBytes: 5 * 1024 * 1024,
      subject: 'Mathematics',
      scheduledAt: DateTime(2026, 8, 10),
    );

// Each subject gets a `const` wrapper so the host's child is const even
// though the page itself needs a source: the wrapper's element is what the
// flip cannot rebuild, and it hands the page the identical instance in turn.
class _BillingHistoryHost extends StatelessWidget {
  const _BillingHistoryHost();

  @override
  Widget build(BuildContext context) =>
      BillingHistoryPage(source: _FailingHistory());
}

class _EntitlementsHost extends StatelessWidget {
  const _EntitlementsHost();

  @override
  Widget build(BuildContext context) =>
      EntitlementsPage(source: _FailingEntitlements());
}

class _StorageHost extends StatelessWidget {
  const _StorageHost({required this.lessons});

  final List<StoredLesson> lessons;

  @override
  Widget build(BuildContext context) =>
      StorageManagerPage(inventory: _StubInventory(lessons));
}

class _TermReportHost extends StatelessWidget {
  const _TermReportHost();

  @override
  Widget build(BuildContext context) =>
      TermReportPage(load: () async => null);
}
