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


import 'package:base_sdk/base_sdk.dart' show ProfileSectionRegistry;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';

/// The student-facing doorway into /league (decision #42 gap 4): a
/// settings-style profile row, exactly like the other pushed account
/// surfaces (My plan, Billing history). The row lives in
/// [LmsProfileSections.registerStudentSections] as the
/// `lms.student.streak_league` section of base_sdk's generic profile host;
/// the host wires the [LmsProfileNavHook] to
/// `context.router.push(const LeagueRoute())` — lms_sdk only renders the
/// row. A null hook skips the section's registration entirely, the
/// section-host expression of the old null-hides contract every optional
/// profile row carries.
void main() {
  const sectionId = 'lms.student.streak_league';

  setUp(ProfileSectionRegistry.I.reset);
  tearDown(ProfileSectionRegistry.I.reset);

  void register({LmsProfileNavHook? onOpenStreakLeague}) {
    LmsProfileSections.registerStudentSections(
      visible: () async => true,
      defaultCurriculum: 'CAPS',
      onOpenStreakLeague: onOpenStreakLeague,
    );
  }

  testWidgets('profile shows the Streak & league row and taps through',
      (tester) async {
    var opened = 0;
    register(onOpenStreakLeague: (_) => opened++);

    final matches = ProfileSectionRegistry.I.sections
        .where((s) => s.id == sectionId)
        .toList();
    expect(matches, hasLength(1),
        reason: 'a wired hook registers the row with the profile host');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: matches.single.builder)),
    ));

    expect(find.text('Streak & league'), findsOneWidget);
    expect(
        find.text('Your attendance streak and weekly league'), findsOneWidget);

    await tester.tap(find.text('Streak & league'));
    await tester.pump();
    expect(opened, 1, reason: 'the row is plain navigation — one tap, '
        'one push of the host\'s LeagueRoute');
  });

  testWidgets('no callback wired -> no row (same as the other optional rows)',
      (tester) async {
    register();
    expect(
      ProfileSectionRegistry.I.sections.any((s) => s.id == sectionId),
      isFalse,
      reason: 'a null hook never registers the section — the same rows the '
          'old page hid stay unregistered on the host',
    );
  });
}
