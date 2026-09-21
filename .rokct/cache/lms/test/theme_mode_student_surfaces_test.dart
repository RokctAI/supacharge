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


// A theme-mode flip must restyle these student-facing surfaces WITHOUT
// remounting them.
//
// Three of them are pages the route pins (an auto_route page holds the
// instance its route view made, so no ancestor rebuild reaches it), and the
// rest are widgets whose only host is one of those pages - which is the same
// pin one level down: the page never rebuilds on a flip, so neither does
// anything it built.
import 'dart:io';

import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/src/common/domain/interface/access_status_source.dart';
import 'package:lms_sdk/src/common/domain/interface/engagement_source.dart';
import 'package:lms_sdk/src/common/domain/interface/holiday_content_source.dart';
import 'package:lms_sdk/src/common/domain/interface/lms_repository.dart';
import 'package:lms_sdk/src/common/application/holiday/holiday_programme_planner.dart';
import 'package:lms_sdk/src/common/domain/models/access_policy.dart';
import 'package:lms_sdk/src/common/domain/models/engagement_models.dart';
import 'package:lms_sdk/src/common/domain/models/holiday_models.dart';
import 'package:lms_sdk/src/common/domain/models/lesson_models.dart';
import 'package:lms_sdk/src/common/domain/models/practice_models.dart';
import 'package:lms_sdk/src/common/infrastructure/sync/lms_upload_queue.dart';
import 'package:lms_sdk/src/common/presentation/pages/engagement/league_page.dart';
import 'package:lms_sdk/src/common/presentation/pages/holiday/holiday_programme_page.dart';
import 'package:lms_sdk/src/common/presentation/pages/lesson/widgets/mcq_overlay.dart';
import 'package:lms_sdk/src/common/presentation/pages/lesson/widgets/speaker_bubble.dart';
import 'package:lms_sdk/src/common/presentation/pages/practice/practice_page.dart';
import 'package:lms_sdk/src/common/presentation/widgets/page_dots.dart';
import 'package:lms_sdk/src/common/presentation/widgets/pending_sync_notice.dart';

import 'theme_flip_host.dart';

class _OfflineAccess implements AccessStatusSource {
  @override
  Future<AccessStatus> current() async => throw Exception('offline');
}

class _ActiveAccess implements AccessStatusSource {
  @override
  Future<AccessStatus> current() async =>
      const AccessStatus(subscription: SubscriptionState.active);
}

class _UnusedContent extends Fake implements HolidayContentSource {}

class _EmptyPracticeRepository extends Fake implements LmsRepository {
  @override
  Future<PracticeQueue> practiceQueue({String? subject, String? lesson}) async =>
      PracticeQueue.empty;
}

/// A settled engagement read: a streak, and no league week (which is the
/// _LeagueUnavailableCard path - no animation left running).
class _QuietEngagement implements EngagementSource {
  @override
  Future<StreakStatus> myStreak() async =>
      const StreakStatus(current: 3, best: 5);

  @override
  Future<LeagueWeek?> leagueWeek() async => null;
}

/// Two ops already waiting, so the notice has something to paint. Only the
/// members the notice's queue actually reaches are implemented.
class _WaitingOutbox extends Fake implements LmsUploadOutbox {
  @override
  Future<void> enqueueOrReplace({
    required String opType,
    required String dedupeKey,
    required Map<String, dynamic> payload,
  }) async {}

  @override
  Future<LmsUploadStatus> counts() async =>
      const LmsUploadStatus(pending: 2);

  @override
  Future<void> kick() async {}
}

HolidayProgrammeDeps _deps(AccessStatusSource access) => HolidayProgrammeDeps(
      access: access,
      planner: HolidayProgrammePlanner(content: _UnusedContent()),
      holiday: SchoolHoliday.values.first,
      termStart: DateTime(2026, 7, 1),
      termEnd: DateTime(2026, 9, 30),
      grade: () async => null,
      subjects: () async => const <String>[],
    );

const McqQuestion _question = McqQuestion(
  id: 'q1',
  prompt: 'Which value of x satisfies 2x + 6 = 14?',
  options: <String>['x = 4', 'x = 10'],
  correctIndex: 0,
  timeLimitSeconds: 20,
);

const TutorPersona _tutor = TutorPersona(id: 't1', displayName: 'Ms Dlamini');

/// A colour's channels without its alpha, so an ink read through an opacity
/// can still be compared against the ink itself.
String _rgb(Color color) => '${color.r},${color.g},${color.b}';

void main() {
  testWidgets('HolidayProgrammePage restyles its surface on a flip',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _HolidayHost(offline: true),
      read: (tester) => scaffoldFill(tester, HolidayProgrammePage),
      expected: AppStyle.surfaceFor,
    );
  });

  testWidgets("the holiday notice restyles on a flip although it is mounted "
      'const', (tester) async {
    // The set-your-grade notice is the `const _Notice`, so the page's own
    // rebuild cannot restyle it - it carries its own theme dependency.
    await expectRestylesOnFlip(
      tester,
      child: const _HolidayHost(offline: false),
      read: (tester) => textInkContaining(tester, 'Set your grade'),
      expected: AppStyle.inkFor,
    );
  });

  testWidgets('PracticePage restyles its surface on a flip', (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _PracticeHost(),
      read: (tester) => scaffoldFill(tester, PracticePage),
      expected: AppStyle.surfaceFor,
    );
  });

  testWidgets("PracticePage's empty state restyles on a flip", (tester) async {
    // _emptyState is a helper the build calls, so this covers the brightness
    // handed down to it.
    await expectRestylesOnFlip(
      tester,
      child: const _PracticeHost(),
      read: (tester) => textInk(tester, 'Nothing to practice yet'),
      expected: AppStyle.inkFor,
    );
  });

  testWidgets('LeaguePage restyles its surface on a flip', (tester) async {
    // A ConsumerWidget is no defence: its ref.watch is on engagementProvider,
    // which fires on league data, never on the theme mode.
    await expectRestylesOnFlip(
      tester,
      child: const _LeagueHost(),
      read: (tester) => scaffoldFill(tester, LeaguePage),
      expected: AppStyle.surfaceFor,
    );
  });

  testWidgets("LeaguePage's app bar ink restyles on a flip", (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _LeagueHost(),
      read: (tester) => textInk(tester, 'Streak & League'),
      expected: AppStyle.inkFor,
    );
  });

  testWidgets('PageDots restyles its inactive dots on a flip', (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const PageDots(count: 3, index: 0),
      // The dot is the ink at a quarter alpha, so compare the ink channels
      // and leave the alpha out of it.
      read: (tester) {
        final AnimatedContainer dot =
            tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
                .elementAt(1);
        final Color? fill = (dot.decoration as BoxDecoration?)?.color;
        return fill == null ? null : _rgb(fill);
      },
      expected: (Brightness brightness) => _rgb(AppStyle.inkFor(brightness)),
      wrapInScaffold: true,
    );
  });

  testWidgets('McqOverlay restyles its header on a flip', (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const _McqHost(),
      read: (tester) => textInk(tester, 'Quick check'),
      expected: AppStyle.secondaryInkFor,
      wrapInScaffold: true,
    );
  });

  testWidgets('SpeakerBubble restyles its drag handle on a flip',
      (tester) async {
    await expectRestylesOnFlip(
      tester,
      child: const SpeakerBubble(tutor: _tutor, speaking: false),
      read: (tester) => textInk(tester, '•••'),
      expected: AppStyle.secondaryInkFor,
      wrapInScaffold: true,
    );
  });

  testWidgets('PendingSyncNotice restyles its card on a flip', (tester) async {
    final LmsUploadQueue queue = LmsUploadQueue(outbox: _WaitingOutbox());
    await queue.queueSaveProgress('L1');
    await expectRestylesOnFlip(
      tester,
      child: PendingSyncNotice(queue: queue),
      read: (tester) => textInkContaining(tester, 'waiting to sync'),
      expected: AppStyle.inkFor,
      wrapInScaffold: true,
    );
  });

  // CalendarExportBanner is a source guard rather than a widget test: it only
  // paints once its LessonCalendarPrefs reports the profile switch on AND
  // LessonCalendarExport still has un-exported airings, and LessonCalendarPrefs
  // is a concrete KV-backed class with no injectable seam for the first of
  // those. The guard asserts the two properties the fix is made of.
  test('CalendarExportBanner takes its mode from the inherited theme', () {
    final String source = File('lib/src/common/presentation/pages/schedule/'
            'widgets/calendar_export_banner.dart')
        .readAsStringSync();
    expect(source, contains('Theme.of(context).brightness'),
        reason: 'the banner must depend on the inherited theme, or a '
            'theme-mode flip schedules nothing for it');
    expect(
        RegExp(r'AppStyle\.(isDark|surfaceDark|cardDark|cardDarkAlt|strokeDark'
                r'|strokeDarkSubtle|textDarkSecondary|textDarkFaint'
                r'|textPrimary)\b')
            .hasMatch(source),
        isFalse,
        reason: 'no mode-resolving AppStyle static may decide a colour here');
  });
}

class _HolidayHost extends StatelessWidget {
  const _HolidayHost({required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) => HolidayProgrammePage(
        deps: _deps(offline ? _OfflineAccess() : _ActiveAccess()),
      );
}

class _PracticeHost extends StatelessWidget {
  const _PracticeHost();

  @override
  Widget build(BuildContext context) =>
      PracticePage(repository: _EmptyPracticeRepository());
}

class _LeagueHost extends StatelessWidget {
  const _LeagueHost();

  @override
  Widget build(BuildContext context) => ProviderScope(
        child: LeaguePage(source: _QuietEngagement()),
      );
}

class _McqHost extends StatelessWidget {
  const _McqHost();

  @override
  Widget build(BuildContext context) => McqOverlay(
        question: _question,
        remainingSeconds: 20,
        onSelect: (_) {},
        asPanel: true,
      );
}
