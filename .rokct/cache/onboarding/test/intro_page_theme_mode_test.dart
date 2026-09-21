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

// Every step of first-run setup restyles itself the moment the theme mode
// changes, with the step still mounted (Ray, 2026-09-19: "glance doesnt
// change test immediately untill you come back if you switched theme mode" —
// the same defect, found here by the fleet audit that followed).
//
// The whole page tree decided its surface, its cards, its hairlines and its
// ink from AppStyle.surfaceDark / cardDark / cardDarkAlt / strokeDark /
// textDarkSecondary / textPrimary — mode-resolving statics, not inherited
// widgets. Nothing in here read anything from the BuildContext that a
// theme-mode flip touches: the scaffold's only context read was
// MediaQuery.sizeOf (through base_sdk's windowSizeOf), which answers to the
// WINDOW and not the mode, and the introProvider notifier IntroPage watches
// is a feature notifier a theme-mode change never notifies. So the flip
// scheduled no rebuild of any element in here and the previous mode's
// colours stayed on screen for the whole of first-run setup.
//
// ThemeFlipHost captures the page once and hands the identical instance back
// on every rebuild, so a parent rebuild provably cannot deliver the flip —
// which is also how the product mounts it (see the note in
// theme_flip_host.dart). Only a dependency of each step's own on the
// inherited theme restyles it here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:onboarding_sdk/onboarding_sdk.dart';

import 'theme_flip_host.dart';

void main() {
  /// The step card's own subtree. On the phone fold the compact rail sits
  /// OUTSIDE the card's scroll view, so this separates the card's copy from
  /// the rail's copy of the same step title.
  Finder inCard(Finder matching) => find.descendant(
      of: find.byType(SingleChildScrollView), matching: matching);

  /// Two host slides that draw the shell's own Back/Continue pair, so the
  /// run can be walked step by step.
  IntroDeps twoSlides() => IntroDeps(
        slides: [
          OnboardingSlide(
              content: const Text('slide a'),
              data: const {'id': 'a'},
              title: 'Your school',
              shellActions: true),
          OnboardingSlide(
              content: const Text('slide b'),
              data: const {'id': 'b'},
              title: 'Your grade',
              shellActions: true),
        ],
        store: InMemoryOnboardingProgressStore(),
      );

  /// A required slide that never reports done, so the shell draws the
  /// blocked-Continue reason under it.
  IntroDeps oneRequiredSlide() => IntroDeps(
        slides: [
          OnboardingSlide(
              content: const Text('slide a'),
              data: const {'id': 'a'},
              title: 'Your school',
              required: true,
              shellActions: true),
        ],
        store: InMemoryOnboardingProgressStore(),
      );

  /// No host slides at all: welcome, the role choice, then the closing step.
  IntroDeps noSlides() =>
      IntroDeps(slides: const [], store: InMemoryOnboardingProgressStore());

  Future<void> toRole(WidgetTester tester) async {
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
  }

  Future<void> toFirstSlide(WidgetTester tester) async {
    await toRole(tester);
    await tester.tap(find.text("I'm the student"));
    await tester.pumpAndSettle();
  }

  Future<void> toSecondSlide(WidgetTester tester) async {
    await toFirstSlide(tester);
    await tester.tap(find.byKey(const Key('onboarding.continue')));
    await tester.pumpAndSettle();
  }

  Future<void> toDone(WidgetTester tester) async {
    await toRole(tester);
    await tester.tap(find.text("I'm the student"));
    await tester.pumpAndSettle();
  }

  tearDown(() => AppStyle.setBrightness(Brightness.dark));

  group('the shared frame', () {
    testWidgets('_OnboardingScaffold — the branded page surface follows the flip',
        (tester) async {
      phoneWindow(tester);
      await expectRestylesOnFlip(
        tester,
        child: IntroPage(deps: noSlides()),
        read: (t) => t.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        expected: AppStyle.surfaceFor,
      );
    });

    testWidgets('_OnboardingScaffold — the optional/required step label follows',
        (tester) async {
      phoneWindow(tester);
      await expectRestylesOnFlip(
        tester,
        child: IntroPage(deps: twoSlides()),
        settle: toFirstSlide,
        read: (t) =>
            textInk(t, find.byKey(const Key('onboarding.step_label'))),
        expected: AppStyle.secondaryInkFor,
      );
    });

    testWidgets('_OnboardingCard — fill and hairline follow the flip',
        (tester) async {
      phoneWindow(tester);
      final Finder card = decoratedAround(find.text('JUVO')).first;
      await expectRestylesOnFlip(
        tester,
        child: IntroPage(deps: noSlides()),
        read: (t) => <Color?>[containerFill(t, card), containerStroke(t, card)],
        expected: (b) => <Color?>[AppStyle.cardFor(b), AppStyle.strokeFor(b)],
      );
    });
  });

  group('the steps', () {
    testWidgets('_WelcomeCard — the app name and its motto follow the flip',
        (tester) async {
      phoneWindow(tester);
      await expectRestylesOnFlip(
        tester,
        child: IntroPage(deps: noSlides()),
        read: (t) => <Color?>[
          textInk(t, find.text('JUVO')),
          textInk(t, find.text('Motto')),
        ],
        expected: (b) =>
            <Color?>[AppStyle.inkFor(b), AppStyle.secondaryInkFor(b)],
      );
    });

    testWidgets('_RoleChoice — headline and subcopy follow the flip',
        (tester) async {
      phoneWindow(tester);
      await expectRestylesOnFlip(
        tester,
        child: IntroPage(deps: noSlides()),
        settle: toRole,
        read: (t) => <Color?>[
          textInk(t, inCard(find.text('Who is setting this up?'))),
          textInk(
              t,
              inCard(find.text(
                  'So we can tailor the experience to the right person.'))),
        ],
        expected: (b) =>
            <Color?>[AppStyle.inkFor(b), AppStyle.secondaryInkFor(b)],
      );
    });

    testWidgets('_RoleCard — fill, hairline, label, subtitle and chevron follow',
        (tester) async {
      phoneWindow(tester);
      final Finder row = decoratedAround(find.text("I'm the student")).first;
      await expectRestylesOnFlip(
        tester,
        child: IntroPage(deps: noSlides()),
        settle: toRole,
        read: (t) => <Color?>[
          containerFill(t, row),
          containerStroke(t, row),
          textInk(t, find.text("I'm the student")),
          textInk(t, find.text('This account is for me')),
          iconInk(t, find.byIcon(Icons.chevron_right).first),
        ],
        expected: (b) => <Color?>[
          AppStyle.cardAltFor(b),
          AppStyle.strokeFor(b),
          AppStyle.inkFor(b),
          AppStyle.secondaryInkFor(b),
          AppStyle.secondaryInkFor(b),
        ],
      );
    });

    testWidgets('_StepFooter — the Back button follows the flip',
        (tester) async {
      phoneWindow(tester);
      await expectRestylesOnFlip(
        tester,
        child: IntroPage(deps: twoSlides()),
        settle: toSecondSlide,
        read: (t) {
          final ButtonStyle? style =
              t.widget<OutlinedButton>(find.byType(OutlinedButton)).style;
          return <Color?>[
            buttonColor(style?.foregroundColor),
            buttonSide(style),
            buttonColor(style?.backgroundColor),
          ];
        },
        expected: (b) => <Color?>[
          AppStyle.inkFor(b),
          AppStyle.strokeFor(b),
          AppStyle.cardAltFor(b),
        ],
      );
    });

    testWidgets('_StepFooter — the blocked-Continue reason follows the flip',
        (tester) async {
      phoneWindow(tester);
      await expectRestylesOnFlip(
        tester,
        child: IntroPage(deps: oneRequiredSlide()),
        settle: toFirstSlide,
        read: (t) => textInk(t, find.byKey(const Key('onboarding.blocked'))),
        expected: AppStyle.secondaryInkFor,
      );
    });

    testWidgets('_Done — the closing headline and caption follow the flip',
        (tester) async {
      phoneWindow(tester);
      await expectRestylesOnFlip(
        tester,
        child: IntroPage(deps: noSlides()),
        settle: toDone,
        read: (t) => <Color?>[
          textInk(t, find.text("You're all set!")),
          textInk(
              t,
              find.text(
                  "Your lessons are ready — jump into today's class.")),
        ],
        expected: (b) =>
            <Color?>[AppStyle.inkFor(b), AppStyle.secondaryInkFor(b)],
      );
    });
  });

  group('the position rail', () {
    testWidgets('_RailHeader — "N left" and the pending segments follow',
        (tester) async {
      phoneWindow(tester);
      final Finder segments =
          decoratedUnder(find.byKey(const Key('onboarding.rail.compact')));
      await expectRestylesOnFlip(
        tester,
        child: IntroPage(deps: twoSlides()),
        read: (t) => <Color?>[
          textInk(t, find.byKey(const Key('onboarding.rail.left'))),
          containerFill(t, segments.at(1)),
        ],
        expected: (b) => <Color?>[
          AppStyle.secondaryInkFor(b),
          AppStyle.inkFor(b).withValues(alpha: 0.15),
        ],
      );
    });

    testWidgets('_CompactRail — the current-step card follows the flip',
        (tester) async {
      phoneWindow(tester);
      final Finder stepCard =
          decoratedUnder(find.byKey(const Key('onboarding.rail.compact'))).last;
      await expectRestylesOnFlip(
        tester,
        child: IntroPage(deps: twoSlides()),
        read: (t) => <Color?>[
          containerFill(t, stepCard),
          containerStroke(t, stepCard),
          textInk(t, find.text('Welcome')),
          textInk(t, find.text('next · Who is setting this up?')),
        ],
        expected: (b) => <Color?>[
          AppStyle.cardFor(b),
          AppStyle.strokeFor(b),
          AppStyle.inkFor(b),
          AppStyle.secondaryInkFor(b),
        ],
      );
    });

    testWidgets('_FullRail — the "First run" title follows the flip',
        (tester) async {
      tabletWindow(tester);
      await expectRestylesOnFlip(
        tester,
        child: IntroPage(deps: twoSlides()),
        designSize: const Size(1280, 800),
        read: (t) => textInk(t, find.text('First run')),
        expected: AppStyle.inkFor,
      );
    });

    testWidgets('_RailRow — current, pending and the pending number follow',
        (tester) async {
      tabletWindow(tester);
      final Finder pendingCircle = decoratedAround(find.text('4')).first;
      await expectRestylesOnFlip(
        tester,
        child: IntroPage(deps: twoSlides()),
        designSize: const Size(1280, 800),
        read: (t) => <Color?>[
          textInk(t, find.text('Welcome')),
          textInk(t, find.text('Your grade')),
          textInk(t, find.text('4')),
          containerStroke(t, pendingCircle),
        ],
        expected: (b) => <Color?>[
          AppStyle.inkFor(b),
          AppStyle.secondaryInkFor(b),
          AppStyle.secondaryInkFor(b),
          AppStyle.strokeFor(b),
        ],
      );
    });
  });
}
