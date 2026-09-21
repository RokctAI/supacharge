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

// Tour run 34040758271, still 10 (productivity_task_compose), phone and
// tablet: the compose lane scrolled under PlaneHost's corner Back pill,
// so the Long term switch (phone) and Save task (tablet) sat under it.
//
// The installed template (templates/pages/tasks/tasks_page.dart) cannot
// be pumped here — it imports comms_sdk and opens the app database — so
// this pumps the frame it now uses, PlaneBackClearance around the pane's
// list inside a real PlaneHost with a real FloatingBackPill, and pins the
// rule the fix rests on: NO control of the form may sit under the pill at
// ANY scroll offset, and the list still reaches its last control without
// overflow. Padding inside the list (the previous 88.h) only ever cleared
// the pill at the end of the scroll; the stills are taken at the top.

import 'dart:math' as math;

import 'package:base_sdk/src/presentation/adaptive/planes.dart';
import 'package:base_sdk/src/presentation/components/floating_nav/floating_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_sdk/src/common/presentation/plane_back_clearance.dart';

const Key _longTerm = Key('compose-long-term');
const Key _save = Key('compose-save');

/// The compose pane's frame as the template builds it: a Scaffold, its
/// SafeArea, the clearance band, the 16-wide gutter, and the list — with
/// the form's kinds of control in the template's order, enough of them
/// that the list scrolls on both sizes.
Widget _composePane(BuildContext context) {
  return Scaffold(
    body: SafeArea(
      child: PlaneBackClearance(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: ListView(
            padding: EdgeInsets.only(top: 12.h, bottom: 12.h),
            children: <Widget>[
              const Text('New task'),
              // Template chips, title, priority, deadline, category,
              // repeats, remind me: enough above the switch that it can
              // reach the viewport's foot on both sizes, as on the still.
              for (int i = 0; i < 14; i++) ...<Widget>[
                14.verticalSpace,
                TextField(key: ValueKey<String>('field-$i')),
              ],
              14.verticalSpace,
              Row(
                children: <Widget>[
                  const Expanded(child: Text('Long term')),
                  Switch(key: _longTerm, value: false, onChanged: (_) {}),
                ],
              ),
              for (int i = 0; i < 12; i++) ...<Widget>[
                8.verticalSpace,
                Row(
                  children: <Widget>[
                    Checkbox(value: false, onChanged: (_) {}),
                    Expanded(child: Text('Step ${i + 1}')),
                  ],
                ),
              ],
              20.verticalSpace,
              ElevatedButton(
                key: _save,
                onPressed: () {},
                child: const Text('Save task'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: size,
      builder: (BuildContext context, _) => MaterialApp(
        home: PlaneHost(
          back: FloatingNavBack(
            icon: Icons.arrow_back,
            label: 'Back',
            onTap: () {},
          ),
          stack: <PlanePage>[
            PlanePage(
              name: 'list',
              span: PlaneSpan.two,
              builder: (_) => const Scaffold(body: Text('Tasks')),
            ),
            PlanePage(name: 'list-detail-compose', builder: _composePane),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

Rect _pill(WidgetTester tester) =>
    tester.getRect(find.byType(FloatingBackPill));

/// The part of every form control that is on screen right now: the list
/// clips at its viewport, so a control laid out past the band's edge is
/// not drawn there.
Iterable<Rect> _visibleControls(WidgetTester tester) {
  final Rect viewport = tester.getRect(find.byType(ListView));
  return <Finder>[
    find.byType(TextField),
    find.byType(Switch),
    find.byType(Checkbox),
    find.byType(ElevatedButton),
  ]
      .expand((Finder f) => f.evaluate())
      .map((Element e) =>
          tester.getRect(find.byWidget(e.widget)).intersect(viewport))
      .where((Rect r) => !r.isEmpty);
}

/// The form's own scroll position — the list's, not a text field's.
ScrollPosition _list(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

/// Scrolls so [key]'s widget sits at the very bottom of its viewport —
/// the worst case for the corner pill. The list builds lazily, so it is
/// walked until the control exists.
Future<void> _alignToBottom(WidgetTester tester, Key key) async {
  final ScrollPosition list = _list(tester);
  while (find.byKey(key).evaluate().isEmpty &&
      list.pixels < list.maxScrollExtent) {
    list.jumpTo(math.min(list.pixels + 100, list.maxScrollExtent));
    await tester.pump();
  }
  await Scrollable.ensureVisible(
    tester.element(find.byKey(key)),
    alignment: 1.0,
  );
  await tester.pump();
}

void _expectClear(WidgetTester tester, String when) {
  final Rect pill = _pill(tester);
  for (final Rect control in _visibleControls(tester)) {
    expect(
      control.overlaps(pill),
      isFalse,
      reason: '$when: control $control sits under the pill $pill',
    );
  }
  expect(tester.takeException(), isNull, reason: '$when: overflow');
}

void main() {
  testWidgets('the clearance is the pill\'s own figures plus the frames\' gap',
      (
    WidgetTester tester,
  ) async {
    // The design size matches the window, so ScreenUtil scales by one.
    await _pump(tester, const Size(390, 844));
    expect(planeBackPillInset, 16);
    expect(planeBackPillHeight(), 60);
    expect(planeBackClearance(), 60 + 16 + 12);
    expect(_pill(tester).height, planeBackPillHeight());
    expect(_pill(tester).bottom, 844 - planeBackPillInset);
  });

  for (final (String name, Size size) in <(String, Size)>[
    ('phone 390x844', const Size(390, 844)),
    ('tablet 1280x800', const Size(1280, 800)),
  ]) {
    group(name, () {
      testWidgets('the pill is drawn, and nothing sits under it at the top', (
        WidgetTester tester,
      ) async {
        await _pump(tester, size);
        expect(find.byType(FloatingBackPill), findsOneWidget);
        expect(find.text('New task'), findsOneWidget);
        _expectClear(tester, 'at the top');
      });

      testWidgets('the Long term switch clears the pill at the viewport foot', (
        WidgetTester tester,
      ) async {
        await _pump(tester, size);
        await _alignToBottom(tester, _longTerm);
        final Rect pill = _pill(tester);
        final Rect toggle = tester.getRect(find.byKey(_longTerm));
        expect(toggle.bottom, lessThanOrEqualTo(pill.top));
        _expectClear(tester, 'Long term at the foot');
      });

      testWidgets('Save task clears the pill at the viewport foot', (
        WidgetTester tester,
      ) async {
        await _pump(tester, size);
        await _alignToBottom(tester, _save);
        final Rect pill = _pill(tester);
        final Rect save = tester.getRect(find.byKey(_save));
        expect(save.bottom, lessThanOrEqualTo(pill.top));
        expect(
            save.bottom, lessThanOrEqualTo(size.height - planeBackClearance()));
        _expectClear(tester, 'Save task at the end');
      });

      testWidgets('no control sits under the pill at any scroll offset', (
        WidgetTester tester,
      ) async {
        await _pump(tester, size);
        final ScrollPosition list = _list(tester);
        final double max = list.maxScrollExtent;
        expect(max, greaterThan(0), reason: 'the form must scroll');
        for (double offset = 0; offset <= max; offset += 40) {
          list.jumpTo(offset);
          await tester.pump();
          _expectClear(tester, 'offset $offset');
        }
      });
    });
  }
}
