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


import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/services/connectivity_service.dart';

void main() {
  final service = ConnectivityService.I;

  var probeCalls = 0;
  var drainCalls = 0;
  var probeAnswer = true;

  setUp(() async {
    // stop() resets the pessimistic _wasOnline baseline between tests.
    await service.stop();
    probeCalls = 0;
    drainCalls = 0;
    probeAnswer = true;
    service.backendProbe = () async {
      probeCalls++;
      return probeAnswer;
    };
    service.onBackendRegained = () async {
      drainCalls++;
    };
  });

  test('regain with backend answering kicks the drain', () async {
    await service.handleConnectivityChange([ConnectivityResult.wifi]);
    expect(probeCalls, 1);
    expect(drainCalls, 1);
  });

  test('regain with backend unreachable does NOT kick the drain', () async {
    probeAnswer = false;
    await service.handleConnectivityChange([ConnectivityResult.wifi]);
    expect(probeCalls, 1);
    expect(drainCalls, 0);
  });

  test('staying online never re-probes or re-kicks', () async {
    await service.handleConnectivityChange([ConnectivityResult.wifi]);
    await service.handleConnectivityChange([ConnectivityResult.wifi]);
    await service.handleConnectivityChange([ConnectivityResult.mobile]);
    expect(probeCalls, 1);
    expect(drainCalls, 1);
  });

  test('going offline is silent; the NEXT regain probes again', () async {
    await service.handleConnectivityChange([ConnectivityResult.wifi]);
    await service.handleConnectivityChange([ConnectivityResult.none]);
    expect(probeCalls, 1);
    await service.handleConnectivityChange([ConnectivityResult.ethernet]);
    expect(probeCalls, 2);
    expect(drainCalls, 2);
  });

  test('a none result never probes or kicks', () async {
    await service.handleConnectivityChange([ConnectivityResult.none]);
    expect(probeCalls, 0);
    expect(drainCalls, 0);
  });

  test('a transport the old whitelist omitted is a regain like any other',
      () async {
    // This case used to sit in the test above, asserting that bluetooth was
    // offline. It is not: connectivity_plus names a transport at all only for
    // a network that HAS internet capability - `none` is its answer for one
    // that does not - so bluetooth tethering, a VPN and the unnamed `other`
    // are every bit as online as wifi (AppConnectivity.isOnline). The drain
    // must not wait for a wifi/mobile/ethernet answer that a VPN-connected
    // phone never gives.
    await service.handleConnectivityChange([ConnectivityResult.bluetooth]);
    expect(probeCalls, 1);
    expect(drainCalls, 1);
  });

  test('vpn and other are regains too', () async {
    await service.handleConnectivityChange([ConnectivityResult.vpn]);
    expect(drainCalls, 1);
    await service.handleConnectivityChange([ConnectivityResult.none]);
    await service.handleConnectivityChange([ConnectivityResult.other]);
    expect(drainCalls, 2);
  });
}
