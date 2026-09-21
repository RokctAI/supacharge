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

// TelemetryClient's error lane: the logError delivery contract and its
// one-shot control-role fallback (an app can be pointed at a control-role
// site, whose gateway only resolves `control:`-prefixed cmds — the app's
// errors then land locally at control via the log_frontend_error twin,
// never in the tenant->control backend-error lane).

import 'dart:convert';

import 'package:base_sdk/src/services/telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    // The transport seam is app-global; never let one test's wiring leak.
    TelemetryClient.configure(transport: null);
  });

  group('logError delivery', () {
    test('sends the wire contract under the tenant cmd', () async {
      final delivered = <Map<String, dynamic>>[];
      TelemetryClient.configure(transport: (cmd, payload) async {
        delivered.add({'cmd': cmd, ...payload});
      });

      await TelemetryClient.I.logError(
        type: 'unit_test_error',
        sessionId: 's-1',
        context: {'detail': 'value'},
      );

      expect(delivered, hasLength(1));
      expect(delivered.single['cmd'], TelemetryClient.cmd);
      expect(delivered.single['error_message'], 'unit_test_error');
      final context =
          jsonDecode(delivered.single['context'] as String) as Map;
      expect(context['type'], 'unit_test_error');
      expect(context['session_id'], 's-1');
      expect(context['context']['detail'], 'value');
    });

    test('control-role fallback: a rejected tenant cmd retries once with '
        'the control: prefix', () async {
      final cmds = <String>[];
      TelemetryClient.configure(transport: (cmd, payload) async {
        cmds.add(cmd);
        // A control-role gateway rejects the unprefixed tenant cmd; the
        // control-role key is accepted.
        if (cmd == TelemetryClient.cmd) {
          throw Exception('control gateway: unknown cmd');
        }
      });

      await TelemetryClient.I.logError(type: 'unit_test_error');

      expect(cmds, [TelemetryClient.cmd, TelemetryClient.controlCmd]);
    });

    test('a fully failed delivery is swallowed (never breaks the app)',
        () async {
      var attempts = 0;
      TelemetryClient.configure(transport: (cmd, payload) async {
        attempts++;
        throw Exception('offline');
      });

      // Must not throw: telemetry never breaks the app.
      await TelemetryClient.I.logError(type: 'unit_test_error');

      // Two attempts per failed send: the tenant cmd, then the one-shot
      // control-role fallback.
      expect(attempts, 2);
    });
  });
}
