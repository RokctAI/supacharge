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


import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_sdk/lms_sdk.dart';
// Transitive via base_sdk; test-only use to seed the translation bundle.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

// Decision #23 behaviour: student-tier plans render as ONE card with
// monthly/yearly TERM TABS; the holiday-programme perk is driven by term;
// a partner viewer sees "Add your student(s)", not a discount tier.

const _monthly = LessonPlanOption(
  id: 'std_m',
  title: 'Standard',
  description: 'Live lessons',
  price: 299,
  months: 1,
);
const _yearly = LessonPlanOption(
  id: 'std_y',
  title: 'Standard',
  description: 'Live lessons',
  price: 2990,
  months: 12,
);
const _partnerPlan = LessonPlanOption(
  id: 'partner',
  title: 'Partner',
  price: 249,
  months: 1,
  tier: PlanTier.partner,
);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(() async {
    // The sheet's copy goes through AppHelpers.getTranslation, which reads
    // the translation bundle a composed app downloads at runtime. The
    // standalone harness has no bundle, so getTranslation would fall back to
    // Title-casing the raw key ('month' -> 'Month') and the copy-sensitive
    // finders below would miss. Seed only the strings these assertions rely
    // on, exactly as the host app would serve them.
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const {});
    await LocalStorage.init();
    await LocalStorage.setTranslations({
      'month': 'month',
      'year': 'year',
      'add_your_students': 'Add your student(s)',
    });
  });

  test('term is derived from months, not the title', () {
    expect(_monthly.term, PlanTerm.monthly);
    expect(_yearly.term, PlanTerm.yearly);
  });

  testWidgets('student plans: one family, monthly/yearly tabs, term-driven '
      'perk', (tester) async {
    await tester.pumpWidget(_host(PlansSheet(
      loading: false,
      plans: const [_monthly, _yearly, _partnerPlan],
      purchasing: false,
      plansAvailable: true,
      onPurchase: (_) {},
      onDismiss: () {},
    )));
    await tester.pumpAndSettle();

    // Partner-tier plan is filtered out of the student view: exactly one
    // family card (no swipe dots), with both term tabs.
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    // Defaults to monthly: monthly price + one-free-week perk.
    expect(find.text('R299/month'), findsOneWidget);
    expect(find.textContaining('One free week'), findsOneWidget);
    expect(find.textContaining('full holiday programme'), findsNothing);

    // Switch to yearly: price and perk both follow the term.
    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();
    expect(find.text('R2990/year'), findsOneWidget);
    expect(find.textContaining('full holiday programme'), findsOneWidget);
    expect(find.textContaining('One free week'), findsNothing);
  });

  testWidgets('a partner who has not linked a student sees the add-student '
      'panel, not plans', (tester) async {
    var added = false;
    await tester.pumpWidget(_host(PlansSheet(
      loading: false,
      plans: const [_monthly, _yearly],
      purchasing: false,
      plansAvailable: true,
      viewerTier: PlanTier.partner,
      hasLinkedStudent: false,
      onAddStudent: () => added = true,
      onPurchase: (_) {},
      onDismiss: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Add your student(s)'), findsWidgets);
    expect(find.text('Monthly'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Add your student(s)'));
    expect(added, isTrue);
  });

  testWidgets('a partner who already linked a student falls through to plans',
      (tester) async {
    await tester.pumpWidget(_host(PlansSheet(
      loading: false,
      plans: const [_monthly, _yearly],
      purchasing: false,
      plansAvailable: true,
      viewerTier: PlanTier.partner,
      hasLinkedStudent: true,
      onPurchase: (_) {},
      onDismiss: () {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Add your student(s)'), findsNothing);
  });
}
