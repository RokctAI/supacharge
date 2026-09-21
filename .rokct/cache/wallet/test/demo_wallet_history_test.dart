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

import 'package:wallet_sdk/src/common/infrastructure/repositories/demo_wallet_history.dart';

void main() {
  test('demo history is a small, newest-first, self-consistent ledger', () {
    final now = DateTime.utc(2026, 9, 4, 12);
    final rows = DemoWalletHistory.entries(now: now);

    expect(rows.length, inInclusiveRange(4, 5));

    final ids = rows.map((r) => r.id).toSet();
    expect(ids.length, rows.length, reason: 'ids must be unique');

    final types = rows.map((r) => r.type).toSet();
    expect(types, containsAll(['topup', 'payment', 'refund']));
    expect(rows.where((r) => r.type == 'payment').length, 2);

    final stamps = rows.map((r) => DateTime.parse(r.createdAt!)).toList();
    for (var i = 1; i < stamps.length; i++) {
      expect(stamps[i].isBefore(stamps[i - 1]), isTrue,
          reason: 'rows are newest first');
    }
    expect(stamps.first.isBefore(now), isTrue);

    for (final r in rows) {
      expect(r.price, greaterThan(0));
      expect(r.note, isNotEmpty);
      expect(r.status, isNotEmpty);
      // Plain ids: nothing on screen says "demo".
      expect('${r.uuid} ${r.note}'.toLowerCase(), isNot(contains('demo')));
    }

    num net = 0;
    for (final r in rows) {
      final credit = r.type == 'topup' || r.type == 'refund';
      net += credit ? r.price! : -r.price!;
    }
    expect(net, 793.0);
  });
}
