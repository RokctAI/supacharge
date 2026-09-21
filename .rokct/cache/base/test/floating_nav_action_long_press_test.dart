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

// FloatingNavAction.onLongPress — the second, optional gesture on a control.
//
// Ray, 2026-09-20: "i think productivity plus should be in the floating nav
// when you in its page. floating nav already accept modes and buttons". The
// button that moves onto the bar is productivity's new-item plus, and it
// already carries a shortcut on its long press ("plus opens new but i think
// hlding it should give me option like tasks notes"). A FloatingActionButton
// has no long press of its own, which is why that page wrapped it in a
// GestureDetector; the bar's own controls always had one, so this exposes it
// to the caller rather than letting the shortcut be lost in the move.
//
//   * a tap runs onTap and a long press runs onLongPress, independently;
//   * saying nothing is exactly the control that shipped before — no long
//     press, and the tap untouched;
//   * an unpressable control (locked, or no onTap) is unpressable by EITHER
//     gesture;
//   * leading and trailing controls both honour it.

import 'package:base_sdk/base_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(FloatingNavMode mode) {
  return ProviderScope(
    child: ScreenUtilInit(
      designSize: const Size(800, 600),
      builder: (context, _) => MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FloatingBottomNav(mode: mode),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

FloatingNavControlsMode _controls({
  required FloatingNavAction action,
  bool leading = true,
}) {
  return FloatingNavControlsMode(
    actions: leading ? const <FloatingNavAction>[] : <FloatingNavAction>[action],
    leadingActions:
        leading ? <FloatingNavAction>[action] : const <FloatingNavAction>[],
  );
}

void main() {
  group('FloatingNavAction.onLongPress', () {
    testWidgets('a tap and a long press run their own callbacks',
        (tester) async {
      int taps = 0;
      int presses = 0;
      await tester.pumpWidget(_host(_controls(
        action: FloatingNavAction(
          icon: Icons.add,
          label: 'New',
          onTap: () => taps++,
          onLongPress: () => presses++,
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(presses, 0);

      await tester.longPress(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(presses, 1);
    });

    testWidgets('a trailing control honours it too', (tester) async {
      int presses = 0;
      await tester.pumpWidget(_host(_controls(
        leading: false,
        action: FloatingNavAction(
          icon: Icons.add,
          label: 'New',
          onTap: () {},
          onLongPress: () => presses++,
        ),
      )));
      await tester.pumpAndSettle();

      await tester.longPress(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(presses, 1);
    });

    testWidgets('saying nothing is the control that shipped before',
        (tester) async {
      int taps = 0;
      await tester.pumpWidget(_host(_controls(
        action: FloatingNavAction(
          icon: Icons.add,
          label: 'New',
          onTap: () => taps++,
        ),
      )));
      await tester.pumpAndSettle();

      // A long press on a control that declares none does nothing at all,
      // and does NOT fall through to the tap.
      await tester.longPress(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(taps, 0);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('an unpressable control is unpressable by either gesture',
        (tester) async {
      int presses = 0;
      // Locked: the control is visibly present and visibly off.
      await tester.pumpWidget(_host(_controls(
        action: FloatingNavAction(
          icon: Icons.add,
          label: 'New',
          locked: true,
          onTap: () {},
          onLongPress: () => presses++,
        ),
      )));
      await tester.pumpAndSettle();
      await tester.longPress(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(presses, 0);

      // No onTap at all is the other half of `enabled`.
      await tester.pumpWidget(_host(_controls(
        action: FloatingNavAction(
          icon: Icons.add,
          label: 'New',
          onLongPress: () => presses++,
        ),
      )));
      await tester.pumpAndSettle();
      await tester.longPress(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(presses, 0);
    });
  });
}
