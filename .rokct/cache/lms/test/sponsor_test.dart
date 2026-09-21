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
// Direct src imports (not the lms_sdk barrel): the barrel exports the
// presentation pages, whose TrKeys getters only exist after SDK-install-time
// injection from manifest.json — so barrel-importing tests cannot compile
// standalone. Same pattern as skills_wiring_test.dart.
import 'package:lms_sdk/src/common/application/sponsor/sponsor_dashboard_notifier.dart';
import 'package:lms_sdk/src/common/application/sponsor/sponsor_report_source.dart';
import 'package:lms_sdk/src/common/domain/interface/access_status_source.dart';
import 'package:lms_sdk/src/common/domain/models/access_policy.dart';
import 'package:lms_sdk/src/common/domain/models/sponsor_models.dart';

/// #42 item 3 — the sponsor/CSI dashboard notifier over the demo/local
/// source: the cohort rollup loads, switching the period refetches the
/// packaged report with the newly computed bounds, and the shareable text
/// carries the report's key numbers. Style of partner_test.dart.
void main() {
  test('sponsor dashboard loads the cohort rollup and the default report',
      () async {
    final source = _RecordingSource();
    final n = SponsorDashboardNotifier(
      source: source,
      access: _FixedAccess(AccessStatus.partner),
      now: () => DateTime(2026, 8, 13),
    );
    await n.init();

    expect(n.state.accessDenied, isFalse);
    expect(n.state.loading, isFalse);
    expect(n.state.summary?.studentsFunded, 24);
    expect(n.state.summary?.attendance.attendanceRatePercent, 83);
    // The default report is the CSI-framed last 90 days.
    expect(n.state.selectedPeriod, SponsorReportPeriod.last90Days);
    expect(n.state.report, isNotNull);
    expect(source.requestedStarts.single, DateTime(2026, 5, 15));
    expect(source.requestedEnds.single, DateTime(2026, 8, 13));
    n.dispose();
  });

  test('a non-partner account is denied, aggregates never load', () async {
    final source = _RecordingSource();
    final n = SponsorDashboardNotifier(
      source: source,
      access: _FixedAccess(
          const AccessStatus(subscription: SubscriptionState.active)),
    );
    await n.init();
    expect(n.state.accessDenied, isTrue);
    expect(n.state.summary, isNull);
    expect(source.requestedStarts, isEmpty);
    n.dispose();
  });

  test('switching the period refetches the report with the new bounds',
      () async {
    final source = _RecordingSource();
    final n = SponsorDashboardNotifier(
      source: source,
      access: _FixedAccess(AccessStatus.partner),
      now: () => DateTime(2026, 8, 13),
    );
    await n.init();

    await n.selectPeriod(SponsorReportPeriod.lastQuarter);
    expect(n.state.selectedPeriod, SponsorReportPeriod.lastQuarter);
    // Q3 2026 starts 1 July, so last quarter is 1 April - 30 June.
    expect(source.requestedStarts.last, DateTime(2026, 4, 1));
    expect(source.requestedEnds.last, DateTime(2026, 6, 30));
    expect(n.state.report?.periodStart, DateTime(2026, 4, 1));

    await n.selectPeriod(SponsorReportPeriod.last12Months);
    expect(source.requestedStarts.last, DateTime(2025, 8, 13));
    expect(source.requestedEnds.last, DateTime(2026, 8, 13));

    // Re-selecting the already-loaded period does not refetch.
    final calls = source.requestedStarts.length;
    await n.selectPeriod(SponsorReportPeriod.last12Months);
    expect(source.requestedStarts.length, calls);
    n.dispose();
  });

  test('period bounds: this quarter anchors at the calendar quarter start',
      () {
    final b = sponsorPeriodBounds(
        SponsorReportPeriod.thisQuarter, DateTime(2026, 8, 13, 17, 30));
    expect(b.start, DateTime(2026, 7, 1));
    expect(b.end, DateTime(2026, 8, 13));
  });

  test('share text packages the report: key numbers, no learner names',
      () async {
    final source = _RecordingSource();
    final n = SponsorDashboardNotifier(
      source: source,
      access: _FixedAccess(AccessStatus.partner),
      now: () => DateTime(2026, 8, 13),
    );
    await n.init();

    final text = n.buildShareText();
    expect(text, contains('Learners funded: 24'));
    expect(text, contains('R17928'));
    expect(text, contains('1180/1440'));
    expect(text, contains('82%'));
    expect(text, contains('Mathematics 68%'));
    expect(text, contains('engagement +8 points'));
    // The privacy rule, asserted on the exported artifact itself: the demo
    // roster names from the partner surface must never appear here.
    expect(text.contains('Amahle'), isFalse);
    expect(text.contains('Sipho'), isFalse);
    n.dispose();
  });
}

/// The demo source, recording every requested period so tests can assert
/// the notifier passed the bounds it computed.
class _RecordingSource extends DemoSponsorReportSource {
  final requestedStarts = <DateTime>[];
  final requestedEnds = <DateTime>[];

  @override
  Future<SponsorOutcomeReport> outcomeReport(
      {DateTime? start, DateTime? end}) {
    if (start != null) requestedStarts.add(start);
    if (end != null) requestedEnds.add(end);
    return super.outcomeReport(start: start, end: end);
  }
}

class _FixedAccess implements AccessStatusSource {
  final AccessStatus status;
  _FixedAccess(this.status);

  @override
  Future<AccessStatus> current() async => status;
}
