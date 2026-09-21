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

// QuickFlowPage (the section-42 settings surface) pumped DIRECTLY from
// templates/ — the page carries no ${package} import precisely so this
// harness can compile it standalone (the analyzer excludes templates/, so
// this test IS the template's compile gate). RUN WITH
// `flutter test --dart-define=IS_DEMO=true`: demo mode serves the
// section-42 seed shop from MockQuickFlowRepository via the DI gate.
//
// Covers the three switches and what each one says about itself (the LIVE
// badge on the one real field, the hand-over warning on the one that
// completes orders nobody hands over), the preset grid's counter and its
// filled/empty slots, and the widths: 3-up plus the wide-read extras at
// plane width, 1-up without them on the phone.

import 'package:base_sdk/src/models/data/currency_data.dart';
import 'package:base_sdk/src/services/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:merchants_sdk/src/manager/application/quick_flow/quick_flow_provider.dart';
import 'package:merchants_sdk/src/manager/di/manager_merchants_di.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../templates/pages/manager/quick_flow/quick_flow_page.dart';

Widget _host(Widget child, Size designSize) => ProviderScope(
      child: ScreenUtilInit(
        designSize: designSize,
        builder: (context, _) => MaterialApp(home: child),
      ),
    );

/// Pumps the page at a real logical size. The design size tracks the
/// viewport so ScreenUtil scales 1:1 — these tests are about WHICH
/// elements a width grants, not about type scaling.
Future<void> _pump(WidgetTester tester, {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_host(const QuickFlowPage(), size));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await LocalStorage.setSelectedCurrency(
      CurrencyData(id: 'ZAR', symbol: 'R', position: 'before', rate: 1),
    );
    ManagerMerchantsDependencies.register(GetIt.instance);
  });

  group('QuickFlowPage — the three switches', () {
    testWidgets('names all three and badges the one that is already live',
        (tester) async {
      await _pump(tester, size: const Size(1280, 3200));
      expect(find.text('Quick flow'), findsWidgets);
      expect(find.text('Auto-accept incoming orders'), findsOneWidget);
      expect(find.text('Auto-complete at Ready'), findsOneWidget);
      expect(find.text('Keypad autodial'), findsOneWidget);
      // Only the auto-accept row is bound to a field that already existed.
      expect(find.text('LIVE · SERVER'), findsOneWidget);
    });

    testWidgets('auto-complete says out loud what it costs', (tester) async {
      await _pump(tester, size: const Size(1280, 3200));
      expect(
        find.textContaining('without anyone handing them over'),
        findsOneWidget,
      );
    });

    testWidgets('the platform gate line is a WIDE read only', (tester) async {
      await _pump(tester, size: const Size(1280, 3200));
      expect(
        find.textContaining('Auto Approve All Orders'),
        findsOneWidget,
      );
      await _pump(tester, size: const Size(412, 3200));
      expect(find.textContaining('Auto Approve All Orders'), findsNothing);
    });

    testWidgets('a switch writes through to the shop', (tester) async {
      await _pump(tester, size: const Size(1280, 3200));
      final element = tester.element(find.byType(QuickFlowPage));
      final container = ProviderScope.containerOf(element, listen: false);
      expect(
        container.read(quickFlowProvider).settings.autoCompleteAtReady,
        isFalse,
      );
      await container
          .read(quickFlowProvider.notifier)
          .setAutoCompleteAtReady(true);
      await tester.pumpAndSettle();
      expect(
        container.read(quickFlowProvider).settings.autoCompleteAtReady,
        isTrue,
      );
    });
  });

  group('QuickFlowPage — the digit-preset grid', () {
    testWidgets('counts what is set and draws all nine slots',
        (tester) async {
      await _pump(tester, size: const Size(1280, 3200));
      expect(find.text('5 of 9 set'), findsOneWidget);
      for (var digit = 1; digit <= 9; digit++) {
        expect(find.byKey(Key('quickFlowPreset$digit')), findsOneWidget);
      }
      // Five filled (clearable), four inert.
      expect(
        find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith(
                    'quickFlowPresetClear',
                  ),
        ),
        findsNWidgets(5),
      );
      expect(find.text('Add item'), findsNWidgets(4));
    });

    testWidgets('a filled slot shows its item over its price',
        (tester) async {
      await _pump(tester, size: const Size(1280, 3200));
      expect(find.text('20 L refill'), findsOneWidget);
      expect(find.text('R35.00'), findsOneWidget);
    });

    testWidgets('clearing a key returns it to Add item', (tester) async {
      await _pump(tester, size: const Size(1280, 3200));
      await tester.tap(find.byKey(const Key('quickFlowPresetClear3')));
      await tester.pumpAndSettle();
      expect(find.text('20 L refill'), findsNothing);
      expect(find.text('4 of 9 set'), findsOneWidget);
      expect(find.text('Add item'), findsNWidgets(5));
    });

    testWidgets('an empty slot opens the picker', (tester) async {
      await _pump(tester, size: const Size(1280, 3200));
      await tester.tap(find.byKey(const Key('quickFlowPreset7')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Choose an item for key'), findsOneWidget);
      expect(find.byKey(const Key('quickFlowPresetSearch')), findsOneWidget);
    });
  });

  group('QuickFlowPage — the fold', () {
    testWidgets('the flow strip is a wide read and drops on the phone',
        (tester) async {
      await _pump(tester, size: const Size(1280, 3200));
      expect(find.text('Money in'), findsOneWidget);
      expect(find.text('No per-order taps'), findsOneWidget);
      await _pump(tester, size: const Size(412, 3200));
      expect(find.text('Money in'), findsNothing);
    });

    testWidgets('the sections rail is granted at plane widths only',
        (tester) async {
      await _pump(tester, size: const Size(1280, 3200));
      expect(find.text('Sections'), findsOneWidget);
      // Quick flow reads twice on the rail-plus-detail layout: the lit
      // rail row and the detail's own title.
      expect(find.text('Quick flow'), findsNWidgets(2));
      await _pump(tester, size: const Size(412, 3200));
      expect(find.text('Sections'), findsNothing);
      expect(find.text('Quick flow'), findsOneWidget);
    });
  });
}
