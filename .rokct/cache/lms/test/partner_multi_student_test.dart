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

/// P3.1: multi-student partner accounts, partner-first signup, and
/// partner-as-payer (delegated billing). Extends — never weakens — P3's
/// structural boundary: partner_test.dart proves a partner is denied every
/// student capability; these tests prove that stays true across multiple
/// linked students, both link directions, and billing assumption.
void main() {
  group('P3.1 one partner, many students', () {
    test('dashboard loads every linked student, report per student',
        () async {
      final source = _MultiStudentSource();
      final n = PartnerDashboardNotifier(
        source: source,
        access: _FixedAccess(AccessStatus.partner),
      );
      await n.init();

      expect(n.state.accessDenied, isFalse);
      expect(n.state.students, hasLength(2));
      // First linked student is selected by default, and the report shown
      // is THAT student's — not an aggregate, not the other kid's.
      expect(n.state.selectedStudentId, 'thabo');
      expect(n.state.report?.studentName, 'Thabo');
      expect(n.state.report?.sessionsAttended, 3);

      await n.selectStudent('naledi');
      expect(n.state.report?.studentName, 'Naledi');
      expect(n.state.report?.sessionsAttended, 1);
      // The selected student's report is fetched on init and again on
      // selection (first and last ids); the middle pair is init()'s cohort
      // ranking/rollup scan, which deliberately fetches one report per
      // linked student (see PartnerDashboardNotifier._scanCohort).
      expect(source.requestedStudentIds,
          ['thabo', 'thabo', 'naledi', 'naledi']);
      n.dispose();
    });

    test('alerts resolve per student; legacy alerts (no id) show for all',
        () async {
      final source = _MultiStudentSource();
      final n = PartnerDashboardNotifier(
        source: source,
        access: _FixedAccess(AccessStatus.partner),
      );
      await n.init();

      // Selected: thabo -> thabo's alert + the legacy alert, never naledi's.
      expect(
        n.state.alertsForSelected.map((a) => a.message),
        ['Thabo skipped Maths.', 'Legacy alert.'],
      );
      await n.selectStudent('naledi');
      expect(
        n.state.alertsForSelected.map((a) => a.message),
        ['Naledi hit 90%!', 'Legacy alert.'],
      );
      n.dispose();
    });

    test('per-student alert survives the store round-trip', () async {
      final store = PartnerAlertStore(kv: _MemStore());
      await store.record(PartnerAlert(
        type: PartnerAlertType.sessionSkipped,
        message: 'Skipped.',
        at: DateTime(2026, 7, 13),
        studentId: 'thabo',
      ));
      final alerts = await store.recent();
      expect(alerts.single.studentId, 'thabo');
    });

    test('same-device composer stays the single-student path', () async {
      final composer = LocalPartnerReportComposer(
        behavior: _FakeBehavior(),
        studentName: 'Thabo',
        profile: ProfileStore(kv: _MemStore()),
        library: LibraryStore(kv: _MemStore()),
        alertStore: PartnerAlertStore(kv: _MemStore()),
      );
      final students = await composer.students();
      expect(students.single.name, 'Thabo');
    });

    test(
        '§1 boundary is per-role, not per-link: a partner with many students '
        'is still denied every control capability', () {
      // AccessPolicy answers from the ROLE — the number of linked students
      // (and which side initiated each link) cannot widen it, structurally.
      const partner = AccessStatus.partner;
      for (final cap in LessonCapability.values) {
        final allowed = AccessPolicy.allows(partner, cap);
        expect(
          allowed,
          cap == LessonCapability.partnerDashboard ||
              cap == LessonCapability.weeklyReports,
          reason: 'partner scope must not change with student count: $cap',
        );
      }
    });
  });

  group('P3.1 partner-first signup (reversed invite)', () {
    test('add-student invite: success marks sent with the P3.2 pairing code',
        () async {
      final sender = _FakeStudentSender(PartnerInviteOutcome.sent);
      final n = AddStudentNotifier(sender: sender);
      n.setRelationship(PartnerRelationship.parent);
      n.setContact('0821234567');
      await n.send();
      expect(n.state.sent, isTrue);
      expect(n.state.pairingCode, '654321');
      expect(sender.sent.single.contact, '0821234567');
      n.dispose();
    });

    test('add-student invite: rejection surfaces a retryable error',
        () async {
      final n = AddStudentNotifier(
          sender: _FakeStudentSender(PartnerInviteOutcome.failed));
      n.setContact('bad');
      await n.send();
      expect(n.state.sent, isFalse);
      expect(n.state.error, 'send-failed');
      n.dispose();
    });

    test('student-side redeem: success links and fires the hook', () async {
      var linked = false;
      final n = RedeemPartnerCodeNotifier(
        redeemer: _FakeRedeemer({'good-code': RedeemOutcome.linked}),
        onLinked: () async => linked = true,
      );
      n.setCode('good-code');
      await n.redeem();
      expect(n.state.linked, isTrue);
      expect(linked, isTrue);
      n.dispose();
    });

    test('student-side redeem: specific rejections surface as themselves',
        () async {
      for (final entry in {
        'used-code': RedeemOutcome.invalidCode,
        'second-partner': RedeemOutcome.alreadyPartnered,
      }.entries) {
        final n = RedeemPartnerCodeNotifier(
            redeemer: _FakeRedeemer({entry.key: entry.value}));
        n.setCode(entry.key);
        await n.redeem();
        expect(n.state.linked, isFalse);
        expect(n.state.error, entry.value);
        n.dispose();
      }
    });
  });

  group('P3.1 partner-as-payer (delegated billing)', () {
    test('assuming billing flips only the selected student', () async {
      final billing = _FakeBilling();
      final n = PartnerDashboardNotifier(
        source: _MultiStudentSource(),
        access: _FixedAccess(AccessStatus.partner),
        billing: billing,
      );
      await n.init();
      await n.setPaysForSelected(true);

      expect(billing.assumed, ['thabo']);
      expect(
          n.state.students.firstWhere((s) => s.id == 'thabo').paidByPartner,
          isTrue);
      expect(
          n.state.students.firstWhere((s) => s.id == 'naledi').paidByPartner,
          isFalse);

      // ...and releasing hands it back.
      await n.setPaysForSelected(false);
      expect(billing.released, ['thabo']);
      expect(
          n.state.students.firstWhere((s) => s.id == 'thabo').paidByPartner,
          isFalse);
      n.dispose();
    });

    test('billing failure surfaces an error and changes nothing', () async {
      final n = PartnerDashboardNotifier(
        source: _MultiStudentSource(),
        access: _FixedAccess(AccessStatus.partner),
        billing: _FakeBilling(outcome: PartnerBillingOutcome.failed),
      );
      await n.init();
      await n.setPaysForSelected(true);
      expect(n.state.billingError, 'billing-failed');
      expect(n.state.students.first.paidByPartner, isFalse);
      n.dispose();
    });

    test('billing is a partner-own-account action: no new student capability',
        () {
      // The deliberate design point of delegated billing: nothing about the
      // §1 capability table changed. A partner who pays still cannot touch
      // the student account.
      const partner = AccessStatus.partner;
      expect(AccessPolicy.allows(partner, LessonCapability.attendSession),
          isFalse);
      expect(
          AccessPolicy.allows(
              partner, LessonCapability.controlStudentAccount),
          isFalse);
      expect(
          AccessPolicy.allows(partner, LessonCapability.lockOrForceSession),
          isFalse);
    });
  });
}

class _FixedAccess implements AccessStatusSource {
  final AccessStatus status;
  _FixedAccess(this.status);
  @override
  Future<AccessStatus> current() async => status;
}

/// One partner, two students — the parent-with-two-kids case.
class _MultiStudentSource implements PartnerReportSource {
  final requestedStudentIds = <String?>[];

  @override
  Future<List<LinkedStudent>> students() async => const [
        LinkedStudent(id: 'thabo', name: 'Thabo'),
        LinkedStudent(
            id: 'naledi',
            name: 'Naledi',
            relationship: PartnerRelationship.parent),
      ];

  @override
  Future<PartnerReport> weeklyReport(DateTime weekStart,
      {String? studentId}) async {
    requestedStudentIds.add(studentId);
    return switch (studentId) {
      'naledi' => PartnerReport(
          studentName: 'Naledi', weekStart: weekStart, sessionsAttended: 1),
      _ => PartnerReport(
          studentName: 'Thabo', weekStart: weekStart, sessionsAttended: 3),
    };
  }

  @override
  Future<List<PartnerAlert>> alerts() async => [
        PartnerAlert(
            type: PartnerAlertType.sessionSkipped,
            message: 'Thabo skipped Maths.',
            at: DateTime(2026, 7, 14),
            studentId: 'thabo'),
        PartnerAlert(
            type: PartnerAlertType.milestoneReached,
            message: 'Naledi hit 90%!',
            at: DateTime(2026, 7, 13),
            studentId: 'naledi'),
        PartnerAlert(
            type: PartnerAlertType.appLocked,
            message: 'Legacy alert.',
            at: DateTime(2026, 7, 12)),
      ];
}

class _FakeStudentSender implements StudentInviteSender {
  final PartnerInviteOutcome outcome;
  final sent = <PartnerInvite>[];
  _FakeStudentSender(this.outcome);
  @override
  Future<PartnerInviteResult> send(PartnerInvite invite) async {
    sent.add(invite);
    return outcome == PartnerInviteOutcome.sent
        ? PartnerInviteResult(outcome, pairingCode: '654321')
        : PartnerInviteResult.failed;
  }
}

class _FakeRedeemer implements PartnerLinkRedeemer {
  final Map<String, RedeemOutcome> outcomes;
  _FakeRedeemer(this.outcomes);
  @override
  Future<RedeemOutcome> redeem(String code) async =>
      outcomes[code] ?? RedeemOutcome.invalidCode;
}

class _FakeBilling implements PartnerBilling {
  final PartnerBillingOutcome outcome;
  final assumed = <String>[];
  final released = <String>[];
  _FakeBilling({this.outcome = PartnerBillingOutcome.updated});
  @override
  Future<PartnerBillingOutcome> assumeBilling(String studentId) async {
    if (outcome == PartnerBillingOutcome.updated) assumed.add(studentId);
    return outcome;
  }

  @override
  Future<PartnerBillingOutcome> releaseBilling(String studentId) async {
    if (outcome == PartnerBillingOutcome.updated) released.add(studentId);
    return outcome;
  }
}

class _FakeBehavior implements StudyBehaviorSignal {
  @override
  Future<void> recordAttendance({required DateTime at}) async {}
  @override
  Future<void> recordSkip(
      {required DateTime at, required bool answered}) async {}
  @override
  Future<void> recordSkipUrge(
      {required DateTime at, required bool attended}) async {}
  @override
  Future<StudyBehaviorSummary> weeklySummary(DateTime weekStart) async =>
      const StudyBehaviorSummary(currentStreak: 0);
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
