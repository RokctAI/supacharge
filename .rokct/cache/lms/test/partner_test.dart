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
import 'package:lms_sdk/src/common/application/schedule/schedule_notifier.dart'
    show ScheduleStore;

void main() {
  group('§1 hard boundary: a partner CANNOT control the student account', () {
    // This is the structural guarantee, not a UI omission: AccessPolicy
    // denies a partner every learning and control capability by construction.
    const partner = AccessStatus.partner;

    test('partner is denied every student capability', () {
      for (final cap in LessonCapability.values) {
        final allowed = AccessPolicy.allows(partner, cap);
        if (cap == LessonCapability.partnerDashboard ||
            cap == LessonCapability.weeklyReports) {
          expect(allowed, isTrue, reason: 'partner may view $cap');
        } else {
          expect(allowed, isFalse,
              reason: 'partner must NOT be able to $cap');
        }
      }
    });

    test('the control capabilities are specifically denied', () {
      // The actions the doc names: attend, lock/force, control the account.
      expect(AccessPolicy.allows(partner, LessonCapability.attendSession),
          isFalse);
      expect(AccessPolicy.allows(partner, LessonCapability.lockOrForceSession),
          isFalse);
      expect(
          AccessPolicy.allows(partner, LessonCapability.controlStudentAccount),
          isFalse);
      // A student holds those over their own account — proving the denial is
      // role-based, not a blanket false that would also break the student.
      const student = AccessStatus(subscription: SubscriptionState.active);
      expect(AccessPolicy.allows(student, LessonCapability.attendSession),
          isTrue);
      expect(
          AccessPolicy.allows(student, LessonCapability.controlStudentAccount),
          isTrue);
    });
  });

  test('partner dashboard loads for a partner, is denied to a student',
      () async {
    final source = _FakeReportSource();

    final partnerN = PartnerDashboardNotifier(
      source: source,
      access: _FixedAccess(AccessStatus.partner),
    );
    await partnerN.init();
    expect(partnerN.state.accessDenied, isFalse);
    expect(partnerN.state.report?.studentName, 'Thabo');
    partnerN.dispose();

    final studentN = PartnerDashboardNotifier(
      source: source,
      access: _FixedAccess(
          const AccessStatus(subscription: SubscriptionState.active)),
    );
    await studentN.init();
    expect(studentN.state.accessDenied, isTrue);
    expect(studentN.state.report, isNull);
    studentN.dispose();
  });

  test('§1 weekly report composes from the §5 ledgers + behavior streak',
      () async {
    final kv = _MemStore();
    final profile = ProfileStore(kv: kv);
    final library = LibraryStore(kv: kv);
    final weekStart = DateTime(2026, 7, 12); // a Sunday

    // A week of §5 attendance + engagement + a library score.
    await profile.recordAttendance(AttendanceRecord(
        sessionId: 's1',
        at: weekStart.add(const Duration(days: 1)),
        outcome: AttendanceOutcome.attendedOnTime));
    await profile.recordAttendance(AttendanceRecord(
        sessionId: 's2',
        at: weekStart.add(const Duration(days: 2)),
        outcome: AttendanceOutcome.skippedWithAssessment));
    await profile.recordEngagement(answered: 8, skipped: 2);
    await library.recordAttended(LibraryEntry(
      sessionId: 's1',
      subject: 'Maths',
      topic: 'Quadratics',
      tutorName: 'Grandmaster',
      attendedAt: weekStart.add(const Duration(days: 1)),
      recordingAvailableAt: LibraryEntry.defaultRecordingUnlock(weekStart),
      postScore: 80,
    ));

    final composer = LocalPartnerReportComposer(
      behavior: _FakeBehavior(streak: 5),
      studentName: 'Thabo',
      profile: profile,
      library: library,
      alertStore: PartnerAlertStore(kv: kv),
    );
    final report = await composer.weeklyReport(weekStart);

    expect(report.studentName, 'Thabo');
    expect(report.sessionsScheduled, 2);
    expect(report.sessionsAttended, 1);
    expect(report.sessionsSkippedAnswered, 1);
    expect(report.engagementRatePercent, 80);
    expect(report.performanceScores['Quadratics'], 80);
    expect(report.currentStreak, 5); // from the reused behavior signal
  });

  test(
      'invite: success marks sent, carries the P3.2 pairing code, and fires '
      'the partner-added hook', () async {
    var added = false;
    final n = PartnerInviteNotifier(
      sender: _FakeSender(PartnerInviteOutcome.sent),
      onPartnerAdded: () async => added = true,
    );
    n.setContact('0821234567');
    await n.send();
    expect(n.state.sent, isTrue);
    // The success screen shows the code so it can be shared in person too.
    expect(n.state.pairingCode, '123456');
    expect(n.state.codeExpiresAt, DateTime(2026, 7, 17));
    expect(added, isTrue);
    n.dispose();
  });

  test('invite: backend rejection surfaces a retryable error', () async {
    final n =
        PartnerInviteNotifier(sender: _FakeSender(PartnerInviteOutcome.failed));
    n.setContact('bad');
    await n.send();
    expect(n.state.sent, isFalse);
    expect(n.state.error, 'send-failed');
    n.dispose();
  });

  test('alert store round-trips newest-first', () async {
    final store = PartnerAlertStore(kv: _MemStore());
    await store.record(PartnerAlert(
        type: PartnerAlertType.sessionSkipped,
        message: 'Skipped Maths.',
        at: DateTime(2026, 7, 13)));
    await store.record(PartnerAlert(
        type: PartnerAlertType.milestoneReached,
        message: '90% on Quadratics!',
        at: DateTime(2026, 7, 14)));
    final alerts = await store.recent();
    expect(alerts.first.type, PartnerAlertType.milestoneReached);
    expect(alerts, hasLength(2));
  });

  test('most-recent-Sunday anchors the weekly window', () {
    // Wed 2026-07-15 -> Sun 2026-07-12.
    expect(mostRecentSunday(DateTime(2026, 7, 15)), DateTime(2026, 7, 12));
    // On a Sunday, it's that day.
    expect(mostRecentSunday(DateTime(2026, 7, 12)), DateTime(2026, 7, 12));
  });
}

class _FixedAccess implements AccessStatusSource {
  final AccessStatus status;
  _FixedAccess(this.status);
  @override
  Future<AccessStatus> current() async => status;
}

class _FakeReportSource implements PartnerReportSource {
  @override
  Future<List<LinkedStudent>> students() async =>
      const [LinkedStudent(id: 'thabo', name: 'Thabo')];
  @override
  Future<PartnerReport> weeklyReport(DateTime weekStart,
          {String? studentId}) async =>
      PartnerReport(studentName: 'Thabo', weekStart: weekStart);
  @override
  Future<List<PartnerAlert>> alerts() async => const [];
}

class _FakeBehavior implements StudyBehaviorSignal {
  final int streak;
  _FakeBehavior({this.streak = 0});
  @override
  Future<void> recordAttendance({required DateTime at}) async {}
  @override
  Future<void> recordSkip({required DateTime at, required bool answered}) async {}
  @override
  Future<void> recordSkipUrge(
      {required DateTime at, required bool attended}) async {}
  @override
  Future<StudyBehaviorSummary> weeklySummary(DateTime weekStart) async =>
      StudyBehaviorSummary(currentStreak: streak);
}

class _FakeSender implements PartnerInviteSender {
  final PartnerInviteOutcome outcome;
  _FakeSender(this.outcome);
  @override
  Future<PartnerInviteResult> send(PartnerInvite invite) async =>
      outcome == PartnerInviteOutcome.sent
          ? PartnerInviteResult(outcome,
              pairingCode: '123456',
              expiresAt: DateTime(2026, 7, 17))
          : PartnerInviteResult.failed;
}

class _MemStore implements ScheduleStore {
  final Map<String, Map<String, dynamic>> _data = {};
  @override
  Future<Map<String, dynamic>?> get(String collection, String key) async =>
      _data['$collection/$key'];
  @override
  Future<void> put(
          String collection, String key, Map<String, dynamic> value) async =>
      _data['$collection/$key'] = value;
}
