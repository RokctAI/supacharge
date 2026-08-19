// Copyright (c) 2026 RokctAI
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// Guided-tour runner for the demo build (--dart-define=IS_DEMO=true).
//
// Steps come from tour_steps.g.dart, which CI regenerates from
// tour/app.tour.yaml plus the tour fragments shipped by the composed SDKs
// (see RokctAI/shared-workflows scripts/tour/README.md). Per step the runner
// performs the step's action, lets the screen settle, prints a
// `TOUR_SHOT:<key>` marker to logcat and holds the frame still - the
// host-side capture script answers each marker with
// `adb exec-out screencap -p`.
//
// This file only imports stable entrypoints: `package:supacharge/main.dart`
// exists in every composition (lib/ is composed at CI time from base_sdk's
// templates) and the generated steps file is committed alongside this
// runner.

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:supacharge/main.dart' as app;

import 'tour_steps.g.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'guided tour',
    (WidgetTester tester) async {
      await tourSetup();

      app.main();
      // Let the splash flow (backend status, translations, auth check) play
      // out before the first step runs.
      await _settle(tester, 10000);

      for (final TourStep step in tourSteps) {
        try {
          await step
              .action(tester, _rootRouter(tester))
              .timeout(const Duration(seconds: 90));
        } catch (error) {
          // A single broken step must not sink the whole tour - the marker
          // is reported so CI can annotate it, and the run moves on.
          debugPrint('TOUR_ACTION_ERROR:${step.key}:$error');
        }
        await _settle(tester, step.settleMs);
        if (step.screenshot) {
          debugPrint('TOUR_SHOT:${step.key}');
          // Hold the frame still so the host screencap catches a stable
          // screen (the capture script answers the marker within this
          // window).
          await _hold(3500);
          debugPrint('TOUR_STEP_DONE:${step.key}');
        }
      }

      debugPrint('TOUR_COMPLETE:${tourSteps.length}');
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}

/// The root router, resolved from the root navigator's context. Works from
/// any screen because every page sits under the root RouterScope.
StackRouter _rootRouter(WidgetTester tester) {
  final Element element = tester.element(find.byType(Navigator).first);
  return AutoRouter.of(element);
}

/// Pump until animations settle (best-effort - looping animations are fine
/// for a still), then keep pumping real frames until [ms] has elapsed.
Future<void> _settle(WidgetTester tester, int ms) async {
  final DateTime end = DateTime.now().add(Duration(milliseconds: ms));
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
  } catch (_) {
    // pumpAndSettle times out on screens with looping animations - the
    // wall-clock loop below still gives the screen time to render.
  }
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// Real wall-clock pause that leaves the last rendered frame on screen.
Future<void> _hold(int ms) async {
  final DateTime end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
