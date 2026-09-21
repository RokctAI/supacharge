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


// The fleet audit that followed #242, in tests. Same defect, same shape:
// a widget that names a colour from AppStyle's app-wide isDark static and
// resolves nothing from its BuildContext registers no dependency, so a
// theme-mode change schedules no rebuild of it and it keeps the previous
// mode's ink until something else happens to rebuild it (Ray, 2026-09-19:
// "glance doesnt change test immediately untill you come back if you
// switched theme mode"; and "might be worth checking in all sdks if this
// is there not just in glance").
//
// Each case below mounts the widget behind a boundary the flip does NOT
// cross on its own account - a `const` child, whose widget instance is
// handed back identical so its element is not rebuilt - which is exactly
// how these two are mounted in the product. Only a dependency of the
// widget's own on the inherited theme restyles it here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:base_sdk/src/application/orders_list/orders_list_notifier.dart';
import 'package:base_sdk/src/application/orders_list/orders_list_provider.dart';
import 'package:base_sdk/src/application/profile/profile_host_capabilities.dart';
import 'package:base_sdk/src/domain/interface/orders.dart';
import 'package:base_sdk/src/models/data/order_active_model.dart';
import 'package:base_sdk/src/presentation/components/glance_card.dart';
import 'package:base_sdk/src/presentation/pages/profile/profile_host_scope.dart';
import 'package:base_sdk/src/presentation/pages/profile/widgets/base_profile_footer.dart';
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:base_sdk/src/services/local_storage.dart';

/// The host shape that matters: the theme mode flips app-wide and the
/// subject sits inside a `const` child, so the flip rebuilds everything
/// above it and nothing below.
class _ThemedHost extends StatefulWidget {
  const _ThemedHost({super.key, required this.child});

  final Widget child;

  @override
  State<_ThemedHost> createState() => _ThemedHostState();
}

class _ThemedHostState extends State<_ThemedHost> {
  bool dark = true;

  /// Mirrors AppNotifier.changeTheme: AppStyle's statics are synced and the
  /// Material themeMode flips, in that order.
  void flip() {
    AppStyle.setBrightness(dark ? Brightness.light : Brightness.dark);
    setState(() => dark = !dark);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(800, 600),
      builder: (context, _) => MaterialApp(
        theme: ThemeData(useMaterial3: false, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: false, brightness: Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(body: Center(child: widget.child)),
      ),
    );
  }
}

/// The profile footer's meta row, under the anonymous host scope so the
/// usage badge - which needs a signed-in user and an HttpService - stays
/// out of the row, as in base_profile_footer_demo_test.
class _MetaRowRegion extends StatelessWidget {
  const _MetaRowRegion();

  @override
  Widget build(BuildContext context) {
    return const ProfileHostScope(
      capabilities: ProfileHostCapabilities(
        hasAccount: false,
        hasShops: false,
        hasGallery: false,
      ),
      child: ProfileMetaRow(),
    );
  }
}

/// Stands in for the orders repository the notifier is constructed with.
/// Nothing is asked of it: the stub notifier below answers the one call the
/// card makes, so no method of this ever runs.
class _UnusedOrdersRepository implements OrdersRepositoryFacade {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('the active-order glance card asked the backend');
}

/// The card fetches on mount. This test is about the card's styling, not
/// its data, so the fetch is answered with nothing: no active order, so
/// the card renders its empty shape and asks no shop for a logo. What is
/// under test is whether a theme-mode change rebuilds the card at all.
class _NoOrdersNotifier extends OrdersListNotifier {
  _NoOrdersNotifier() : super(_UnusedOrdersRepository());

  @override
  Future<void> fetchActiveOrders(BuildContext context) async {}
}

class _GlanceRegion extends StatelessWidget {
  const _GlanceRegion();

  @override
  Widget build(BuildContext context) => const ActiveOrderGlanceCard();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bool wasDark = AppStyle.isDark;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  tearDown(() => AppStyle.isDark = wasDark);

  /// The separator dot's colour: the row's mode-resolving ink, and the one
  /// piece of the row that needs neither a backend nor a PackageInfo
  /// channel to render.
  Color? separatorInk(WidgetTester tester) => tester
      .widget<Icon>(find.byIcon(Remix.checkbox_blank_circle_fill))
      .color;

  testWidgets(
      'a theme-mode change restyles the profile meta row with the profile '
      'still on screen', (WidgetTester tester) async {
    AppStyle.setBrightness(Brightness.dark);

    final GlobalKey<_ThemedHostState> host = GlobalKey<_ThemedHostState>();
    await tester.pumpWidget(
      _ThemedHost(key: host, child: const _MetaRowRegion()),
    );
    await tester.pumpAndSettle();

    final Color darkInk = AppStyle.inkFor(Brightness.dark);
    final Color lightInk = AppStyle.inkFor(Brightness.light);
    expect(darkInk, isNot(lightInk));

    expect(separatorInk(tester), darkInk);

    // The toggle lives on this very page, so the flip happens with the row
    // mounted - it must not wait for a rebuild from somewhere else.
    host.currentState!.flip();
    await tester.pumpAndSettle();

    expect(separatorInk(tester), lightInk,
        reason: "the meta row kept the previous mode's ink");
  });

  /// The explicit-brightness ink seams, all three of the same shape as
  /// #242's inkFor: the value the mode-resolving getter would give, chosen
  /// by a brightness the caller got from the inherited theme instead of by
  /// the app-wide isDark static. No new colour values - each pair is the
  /// pair its getter already resolves between, which is what these
  /// assertions pin by flipping the static and comparing.
  void expectSeamMatchesGetter(
    String name,
    Color Function(Brightness) seam,
    Color Function() getter,
  ) {
    AppStyle.setBrightness(Brightness.dark);
    expect(seam(Brightness.dark), getter(), reason: '$name, dark');
    final Color light = seam(Brightness.light);
    AppStyle.setBrightness(Brightness.light);
    expect(light, getter(), reason: '$name, light');
    expect(seam(Brightness.dark), isNot(seam(Brightness.light)),
        reason: '$name resolves to one value for both modes');
  }

  test('faintFor names textDarkFaint\'s two values by brightness', () {
    expectSeamMatchesGetter(
        'faintFor', AppStyle.faintFor, () => AppStyle.textDarkFaint);
  });

  /// The SURFACE-ROLE seams the shared-component sweep added, each the
  /// same shape: the value its mode-resolving getter would give, chosen by
  /// a brightness the caller got from the inherited theme instead of by the
  /// app-wide isDark static. No new colour values.
  test('cardFor names cardDark\'s two values by brightness', () {
    expectSeamMatchesGetter(
        'cardFor', AppStyle.cardFor, () => AppStyle.cardDark);
  });

  test('cardAltFor names cardDarkAlt\'s two values by brightness', () {
    expectSeamMatchesGetter(
        'cardAltFor', AppStyle.cardAltFor, () => AppStyle.cardDarkAlt);
  });

  test('strokeFor names strokeDark\'s two values by brightness', () {
    expectSeamMatchesGetter(
        'strokeFor', AppStyle.strokeFor, () => AppStyle.strokeDark);
  });

  test('subtleStrokeFor names strokeDarkSubtle\'s two values by brightness',
      () {
    expectSeamMatchesGetter('subtleStrokeFor', AppStyle.subtleStrokeFor,
        () => AppStyle.strokeDarkSubtle);
  });

  /// And the two card roles are DISTINCT roles, not two names for one
  /// colour: the alt fill is what a panel uses to read as separate from the
  /// card it sits on, so if they ever collapsed the seam would be a lie.
  test('the card and card-alt seams are different fills in both modes', () {
    for (final Brightness b in Brightness.values) {
      expect(AppStyle.cardFor(b), isNot(AppStyle.cardAltFor(b)),
          reason: 'cardFor and cardAltFor collapsed in $b');
      expect(AppStyle.strokeFor(b), isNot(AppStyle.subtleStrokeFor(b)),
          reason: 'strokeFor and subtleStrokeFor collapsed in $b');
    }
  });

  test('surfaceFor names surfaceDark\'s two values by brightness', () {
    // And is not the polarity-pinned pair: those never resolve.
    expectSeamMatchesGetter(
        'surfaceFor', AppStyle.surfaceFor, () => AppStyle.surfaceDark);
    expect(AppStyle.surfaceFor(Brightness.dark), AppStyle.surfaceDarkRaw);
    expect(AppStyle.surfaceFor(Brightness.light), AppStyle.surfaceLightRaw);
  });

  test('secondaryInkFor names textDarkSecondary\'s two values by brightness',
      () {
    // The seam the active-order glance card's weather notice now asks for
    // its muted ink: the same two values AppStyle.textDarkSecondary
    // resolves between, chosen by an explicit brightness rather than by
    // the app-wide isDark static. No new colour.
    AppStyle.setBrightness(Brightness.dark);
    expect(AppStyle.secondaryInkFor(Brightness.dark), AppStyle.textDarkSecondary);
    final Color light = AppStyle.secondaryInkFor(Brightness.light);
    AppStyle.setBrightness(Brightness.light);
    expect(light, AppStyle.textDarkSecondary);
    expect(AppStyle.secondaryInkFor(Brightness.dark),
        isNot(AppStyle.secondaryInkFor(Brightness.light)));
  });

  testWidgets(
      'a theme-mode change rebuilds the active-order glance card in place',
      (WidgetTester tester) async {
    // The weather notice this card adds names a muted colour of ITS own,
    // which the shell #242 fixed deliberately leaves alone - so the shell's
    // theme dependency does nothing for it. The notice is built inside two
    // ValueListenableBuilders, which rebuild only when their notifier
    // fires, and the colour came from AppStyle's app-wide static. So a mode
    // change reached neither: nothing rebuilt this card's element and the
    // notice kept the previous mode's ink until an order or ETA tick
    // happened along.
    //
    // The card's data is not what is under test here (it needs a backend);
    // the rebuild is. Before the fix, build() ran once and the
    // ValueListenableBuilder it returns stayed the very same instance
    // across the flip - proof that the mode change did not reach the card.
    AppStyle.setBrightness(Brightness.dark);

    final GlobalKey<_ThemedHostState> host = GlobalKey<_ThemedHostState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ordersListProvider.overrideWith((Ref ref) => _NoOrdersNotifier()),
        ],
        child: _ThemedHost(key: host, child: const _GlanceRegion()),
      ),
    );
    await tester.pumpAndSettle();

    final Finder listener = find.descendant(
      of: find.byType(ActiveOrderGlanceCard),
      matching: find.byType(ValueListenableBuilder<OrderActiveModel?>),
    );
    final Widget before = tester.widget(listener);

    host.currentState!.flip();
    await tester.pumpAndSettle();

    expect(tester.widget(listener), isNot(same(before)),
        reason: 'the theme-mode change did not rebuild the card, so its '
            "weather notice keeps the previous mode's ink");
  });
}
