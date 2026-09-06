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

// Render harness for the shared review-strip kit (RokctAI/shared-workflows
// scripts/render/README.md, templates/render-harness/render_screen_test.dart).
//
// Screen: the lms STUDENT PROFILE — base_sdk's GenericProfilePage hosting the
// sections this shell's own installed glue registers
// (registerSupachargeProfileSections in lib/presentation/routes/
// lms_route_pages.dart). It is the screen the kit was proved on, and the one
// screen in this shell that renders from demo fixtures with no stubbing at
// all: the harness names the screen and calls the app's real registration.
//
// Everything below the "proven mechanism" banner is the kit's, unchanged: the
// fixed-point height measurement, the real-event-loop drain, the
// RepaintBoundary capture and the rect sidecar are what make the output
// composable by scripts/render/compose_strip.py.
//
// This runs against the COMPOSED shell — `lib/` and the SDK caches only exist
// after `.rokct` compose, so the imports below resolve on a composed tree
// only. .github/workflows/render-strip.yml composes before it runs this.
//
// Run:  flutter test --dart-define=IS_DEMO=true test/render/render_screen_test.dart
//       RENDER_SUFFIX=_draft flutter test --dart-define=IS_DEMO=true \
//           test/render/render_screen_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auth_sdk/auth_sdk.dart' show AuthSdkDependencies;
import 'package:base_sdk/base_sdk.dart'
    show
        AppConstants,
        BaseSdkDependencies,
        GenericProfilePage,
        LocalStorage,
        ProfileData,
        ProfileSectionRegistry;
// Deep imports into base_sdk's src/ are expected in a harness (the kit's
// template says so): the harness is deliberately coupled to the shipped code
// rather than to a public facade, and neither the theme seam nor the auth
// facade is on the base_sdk barrel.
import 'package:base_sdk/src/domain/interface/auth.dart'
    show AuthRepositoryFacade;
import 'package:base_sdk/src/presentation/theme/app_style.dart' show AppStyle;
import 'package:lms_sdk/lms_sdk.dart'
    show
        LmsAppearanceCard,
        LmsArcsDetailCard,
        LmsAttendanceDetailCard,
        LmsCalendarExportCard,
        LmsSchoolCard,
        LmsSdkDependencies,
        LmsSettingCard,
        LmsStudentStatsCard;
import 'package:users_sdk/users_sdk.dart' show UsersSdkDependencies;

// The shell's own composed glue. This is the point of rendering a SHELL
// rather than an SDK: the sections, hooks, ordering and gates below are the
// ones the shipped app registers, not a reconstruction of them.
import 'package:supacharge/presentation/routes/lms_route_pages.dart'
    show registerSupachargeProfileSections;
import 'package:supacharge/presentation/theme/theme.dart'
    show applyAppBrandColors;

// ---------------------------------------------------------------------------
// Render settings - phone size the reviews are judged at. Only change these
// if the whole review is moving to a different device class.
// ---------------------------------------------------------------------------

/// Logical width of the frame (iPhone-class phone). The strip composer scales
/// the PNG to the bezel, so this only affects LAYOUT, not output resolution.
const double kLogicalWidth = 390;

/// Device pixel ratio the PNG is captured at (3 = @3x, crisp on any display).
const double kDevicePixelRatio = 3.0;

/// Tall probe viewport for the first pass. Must exceed the tallest screen; the
/// second pass shrinks to the measured content height.
const double kProbeHeight = 2600;

/// Slack below the last element in the final frame, in logical pixels.
const double kBottomPadding = 20;

/// The app's design size, straight from the composed app_widget: a 390px
/// frame is compact, so ScreenUtil resolves `.w/.h/.sp` against 375x812.
const Size kDesignSize = Size(375, 812);

/// TODO(harness) 2/8 - the SDK's own demo data. THIS IS THE MAIN PATH.
///
/// Registrations run in composed-app order (base first, then each feature
/// SDK), exactly as main.dart's generated sdk-di block does. With
/// `--dart-define=IS_DEMO=true` each SDK swaps in its OWN demo fixtures:
/// lms gets DemoLmsRepository + SeededTutorCatalog, auth gets
/// MockAuthRepository, users gets MockAddressRepository. Nothing here is a
/// fixture written for this render.
Future<void> registerDemoDependencies() async {
  assert(
      AppConstants.isDemo,
      'run with --dart-define=IS_DEMO=true, or the SDKs register their real '
      'HTTP repositories and the render is of a broken, empty screen');
  final getIt = GetIt.I;
  BaseSdkDependencies.register(getIt);
  AuthSdkDependencies.register(getIt);
  UsersSdkDependencies.register(getIt);
  LmsSdkDependencies.register(getIt);
}

/// TODO(harness) 3/8 - EXCEPTION: device history the demo mode cannot supply.
///
/// DELIBERATELY EMPTY for this screen. The profile's attendance ledger and
/// library are stores the device accumulates through use, and demo mode does
/// not pre-fill them (DemoLmsRepository.recordAttendanceEvent is a no-op);
/// seeding them through the real store API is the kit's documented exception,
/// not its default. This first adoption takes the default path, so the
/// attendance and per-topic cards render their genuine empty-history state -
/// which is itself a truthful frame of what a fresh device shows. The strip
/// config's notes say so, so no reviewer mistakes it for a bug.
Future<void> seedDeviceHistory(WidgetTester tester) async {}

/// TODO(harness) 4/8 - EXCEPTION: stub a service with no demo implementation.
///
/// EMPTY. This shell needs none: registerSupachargeProfileSections() already
/// installs the app's own throwing stand-ins for the two marketplace-side
/// facades base_sdk's profileProvider resolves eagerly
/// (ShopsRepositoryFacade, GalleryRepositoryFacade), so the harness has
/// nothing left to fake. The one platform channel faked at all is
/// path_provider, below, and that is the kit's own mechanism.
void registerExceptionStubs() {}

/// TODO(harness) 5/8 - register sections / routes / gates.
///
/// One call: the shell's real, installed profile registration - the same
/// function main.dart's generated di-hooks block invokes at boot. It brings
/// the student sections with their real hooks and gates, the partner sections
/// (hidden: the persona defaults to student), the shared appearance row and
/// nav clearance, and the registry's onLogout affordance.
void registerScreen() {
  ProfileSectionRegistry.I.reset();
  registerSupachargeProfileSections();
}

/// TODO(harness) 6/8 - the widget under test.
///
/// The real screen in the real wrapping: the app's ProviderScope,
/// ScreenUtilInit at the app's design size, and a MaterialApp carrying the
/// composed app_widget's ThemeData. GenericProfilePage is the host; every row
/// below the identity header comes from the registry.
Widget buildScreen({required bool dark}) {
  return ProviderScope(
    child: ScreenUtilInit(
      useInheritedMediaQuery: false,
      designSize: kDesignSize,
      builder: (context, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          useMaterial3: false,
        ),
        home: const GenericProfilePage(),
      ),
    ),
  );
}

/// TODO(harness) 7/8 - the elements the review points at.
///
/// `key` is the stable identity the composer binds a number to for the life
/// of the page; the committed map lives in test/render/strip.json. Section
/// ids are used verbatim where one exists, so a key means the same thing here
/// and in lms_profile_sections.dart. The two private host widgets have no
/// importable type and are matched by runtime type NAME, which the kit's
/// template documents as the supported way.
List<ElementSpec> elementSpecs() {
  return <ElementSpec>[
    ElementSpec(
      key: 'base.identity_header',
      label: 'Identity header - name, contact, role, edit/logout',
      finder: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_IdentityHeader'),
    ),
    ElementSpec(
      key: 'lms.student.header_stats',
      label: 'Stats card - grade badge, attendance, average score',
      finder: find.byType(LmsStudentStatsCard),
    ),
    // The section-id specs come BEFORE the generic settings-row spec on
    // purpose. LmsSchoolCard and LmsAppearanceCard RETURN an LmsSettingCard,
    // so both finders match the same rect; the kit's de-duplication keeps
    // whichever was measured first, and the section id is the better key
    // because it survives a reworded row title. strip.json carries a number
    // for both spellings so the page numbers correctly either way.
    ElementSpec(
      key: 'lms.student.school',
      label: 'School card - school name, curriculum chip',
      finder: find.byType(LmsSchoolCard),
    ),
    ElementSpec(
      key: 'lms.student.calendar_export',
      label: 'Calendar export row - add lessons to calendar (switch)',
      finder: find.byType(LmsCalendarExportCard),
    ),
    ElementSpec(
      key: 'lms.student.attendance_detail',
      label: 'Attendance - expandable breakdown',
      finder: find.byType(LmsAttendanceDetailCard),
    ),
    ElementSpec(
      key: 'lms.student.arcs_detail',
      label: 'Performance per topic - expandable',
      finder: find.byType(LmsArcsDetailCard),
    ),
    ElementSpec(
      key: 'lms.appearance',
      label: 'Appearance row - light/dark toggle',
      finder: find.byType(LmsAppearanceCard),
    ),
    ElementSpec.each(
      keyOf: (i, w) => 'lms.setting_row.${(w as LmsSettingCard).title}',
      labelOf: (i, w) => 'Setting row - ${(w as LmsSettingCard).title}',
      finder: find.byType(LmsSettingCard),
    ),
    ElementSpec(
      key: 'base.footer',
      label: 'base.footer - app name, version, online dot, usage badge',
      finder: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'BaseProfileFooter'),
    ),
  ];
}

// ---------------------------------------------------------------------------
// TODO(harness) 8/8 - real fonts.
//
// Without real faces every glyph renders as the Ahem/FlutterTest block font
// and the PNG is worthless, so a missing face is a HARD FAILURE here, never a
// silent fallback.
//
// Where the files come from is the one place this shell had to depart from the
// kit's template. The template loads `<pkg>/fonts/*.ttf` from a THROWAWAY
// harness package a human drops font files into; a harness committed to a
// shell repo has no such directory, and this repo ships no font assets at all
// (the app's type is google_fonts, fetched at runtime on a real device). The
// choice was to commit ~2.3 MB of TTFs into a repo whose `lib/` is not even
// committed, or to fetch the two upstream families once per run. This fetches
// them, into an ignored cache under .dart_tool/, from pinned Google Fonts
// upstream paths - and fails loudly if it cannot.
//
// Set RENDER_FONT_DIR to a directory holding these files to run fully offline.
// ---------------------------------------------------------------------------

/// Upstream file for each family, by cache filename. Variable fonts: one file
/// per family, instanced per weight by the text shaper.
const Map<String, String> kFontSources = <String, String>{
  'Inter.ttf': 'https://raw.githubusercontent.com/google/fonts/main/ofl/inter/'
      'Inter%5Bopsz%2Cwght%5D.ttf',
  'Montserrat.ttf':
      'https://raw.githubusercontent.com/google/fonts/main/ofl/montserrat/'
          'Montserrat%5Bwght%5D.ttf',
  'Roboto.ttf': 'https://raw.githubusercontent.com/google/fonts/main/ofl/'
      'roboto/Roboto%5Bwdth%2Cwght%5D.ttf',
};

/// google_fonts resolves a family PLUS its variant name, so every weight the
/// app asks for needs a registered family alias. AppStyle uses 400/500/600/
/// 700/800 across Inter and Montserrat.
const List<String> kFontVariants = <String>[
  'regular',
  '500',
  '600',
  '700',
  '800',
];

String _fontDir() {
  final override = Platform.environment['RENDER_FONT_DIR'];
  if (override != null && override.isNotEmpty) return override;
  return '${Directory.current.path}/.dart_tool/render_fonts';
}

Future<File> _fontFile(String name) async {
  final dir = Directory(_fontDir())..createSync(recursive: true);
  final file = File('${dir.path}/$name');
  if (file.existsSync() && file.lengthSync() > 0) return file;

  final url = kFontSources[name]!;
  // flutter_test installs an HttpOverrides that answers every request with a
  // 400, which is the right default for a test and the wrong one for this one
  // fetch. Restore the real client for the duration, then put it back.
  final saved = HttpOverrides.current;
  HttpOverrides.global = null;
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw StateError('font fetch for $name returned '
          'HTTP ${response.statusCode} from $url');
    }
    final bytes = await consolidateHttpClientResponseBytes(response);
    file.writeAsBytesSync(bytes);
    client.close();
  } finally {
    HttpOverrides.global = saved;
  }
  return file;
}

/// First match for [pattern] under [root], or null. Used to find the icon
/// fonts that ship inside the pub cache, whose paths carry a version.
File? _findFile(Directory root, RegExp pattern) {
  if (!root.existsSync()) return null;
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is File && pattern.hasMatch(entity.path)) return entity;
  }
  return null;
}

Future<void> loadRealFonts() async {
  Future<void> load(String family, List<File> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = file.readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  final inter = await _fontFile('Inter.ttf');
  final montserrat = await _fontFile('Montserrat.ttf');
  final roboto = await _fontFile('Roboto.ttf');

  for (final family in <String, File>{
    'Inter': inter,
    'Montserrat': montserrat,
  }.entries) {
    for (final variant in kFontVariants) {
      await load('${family.key}_$variant', <File>[family.value]);
    }
    // fontFamilyFallback lands on the plain family name.
    await load(family.key, <File>[family.value]);
  }

  // Bare TextStyles with no family fall back to the platform default.
  await load('Roboto', <File>[roboto]);

  // MaterialIcons ships inside the Flutter SDK cache.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null || flutterRoot.isEmpty) {
    throw StateError('FLUTTER_ROOT is unset, so MaterialIcons cannot be '
        'registered and every icon would render as a blank box');
  }
  await load('MaterialIcons', <File>[
    File('$flutterRoot/bin/cache/artifacts/material_fonts/'
        'MaterialIcons-Regular.otf')
  ]);

  // Package icon fonts live in the pub cache under a package-scoped family
  // name. Remix is the icon set every profile row uses.
  final pubCache = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final remix = _findFile(
      Directory(pubCache), RegExp(r'remixicon-[^/\\]+[/\\]fonts[/\\]Remix\.ttf'));
  if (remix == null) {
    throw StateError('Remix.ttf not found under $pubCache - every Remix icon '
        'on the page would render as a blank box');
  }
  await load('packages/remixicon/Remix', <File>[remix]);
}

/// App-wide state the screen reads before it builds - persisted settings,
/// theme mode and the brightness seam - in main.dart's own order: storage
/// first, brand palette next, SDK registrations after.
Future<void> primeAppState({required bool dark}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await LocalStorage.init();
  await LocalStorage.setAppThemeMode(dark);
  AppStyle.setBrightness(dark ? Brightness.dark : Brightness.light);
  // The app's brand palette, injected the way main.dart's brand hook does.
  applyAppBrandColors();
}

/// Persists the demo persona the identity header reads.
///
/// It is the SDK's OWN demo fixture, not one written here: in demo mode the
/// auth facade is MockAuthRepository, and `forgotPasswordConfirm` is the one
/// method on the facade that hands its demo persona back as a ProfileData -
/// a pure in-memory answer, no backend. It is then stored through the app's
/// real LocalStorage.setUser, which is exactly where
/// GenericProfilePage's identity header reads the user from.
///
/// The auth token is left EMPTY on purpose. base_sdk's
/// ProfileNotifier.fetchUser short-circuits without one; WITH one it reaches
/// for connectivity_plus, whose channel is unimplemented headlessly, and the
/// resulting unawaited async error would fail the render instead of showing
/// anything. A demo build has no backend to answer getProfileDetails()
/// either way, so the persisted user is the shipped demo path here.
Future<void> persistDemoUser() async {
  final auth = GetIt.I<AuthRepositoryFacade>();
  final result = await auth.forgotPasswordConfirm(
    verifyCode: '123456',
    email: 'demo@example.com',
  );
  ProfileData? user;
  result.when(
    success: (data) => user = data.user,
    failure: (error, status) => user = null,
  );
  if (user == null) {
    throw StateError('the auth SDK returned no demo profile - is '
        'IS_DEMO=true set, so MockAuthRepository is the registered facade?');
  }
  await LocalStorage.setUser(user);
}

// ===========================================================================
// Below here is the proven mechanism (kit template). Leave it alone.
// ===========================================================================

/// One numbered point: a finder, a stable key, and a human label.
class ElementSpec {
  ElementSpec({
    required this.key,
    required this.label,
    required this.finder,
  })  : keyOf = null,
        labelOf = null;

  /// A finder that matches SEVERAL widgets (e.g. every settings row); key and
  /// label are derived per match, so the numbering stays per-row.
  ElementSpec.each({
    required this.keyOf,
    required this.labelOf,
    required this.finder,
  })  : key = '',
        label = '';

  final String key;
  final String label;
  final Finder finder;
  final String Function(int index, Widget widget)? keyOf;
  final String Function(int index, Widget widget)? labelOf;
}

class _Measured {
  _Measured(this.key, this.label, this.rect);

  final String key;
  final String label;
  final Rect rect;
}

/// Mocks the path_provider channel so real drift/sqlite stores can open a
/// database in a temp dir. This is the ONLY platform channel the harness
/// fakes - everything else runs its real code path.
void _mockPathProvider(String dir) {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => dir);
}

/// Lets REAL async work (drift isolate, futures, file IO) complete, then pumps
/// frames so the resulting setStates land.
///
/// `pumpAndSettle` cannot do this: widget-test fake-async never runs the real
/// event loop, so a screen that waits on a real Future settles as empty.
Future<void> _drain(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump(const Duration(milliseconds: 250));
  }
}

List<_Measured> _measure(WidgetTester tester, List<ElementSpec> specs) {
  final measured = <_Measured>[];
  for (final spec in specs) {
    final elements = spec.finder.evaluate().toList();
    for (var i = 0; i < elements.length; i++) {
      try {
        final widget = elements[i].widget;
        measured.add(_Measured(
          spec.keyOf?.call(i, widget) ?? spec.key,
          spec.labelOf?.call(i, widget) ?? spec.label,
          tester.getRect(spec.finder.at(i)),
        ));
      } catch (_) {
        // Off-stage or unlaid-out matches are skipped rather than failing the
        // render: a section hidden by a gate is a legitimate outcome.
      }
    }
  }

  // Top-to-bottom, then drop wrappers that share a rect with a more specific
  // match (a decorated card whose child is the row we already measured).
  measured.sort((a, b) => a.rect.top.compareTo(b.rect.top));
  final deduped = <_Measured>[];
  for (final item in measured) {
    final clash = deduped.any((kept) =>
        (kept.rect.top - item.rect.top).abs() < 2 &&
        (kept.rect.height - item.rect.height).abs() < 4);
    if (!clash) deduped.add(item);
  }
  return deduped;
}

/// Renders one variant end to end and writes out/<name>.png + out/<name>.json.
Future<void> renderVariant(
  WidgetTester tester, {
  required bool dark,
  required String name,
  required String dbDir,
}) async {
  final outDir = Directory('${Directory.current.path}/out')
    ..createSync(recursive: true);

  _mockPathProvider(dbDir);

  await tester.runAsync(_loadRealFontsOnce);

  // Order matters. Exception stubs go into GetIt FIRST so the SDKs' guarded
  // registrations stand aside; then the SDKs register their own demo
  // implementations; then any device history the demo mode cannot supply.
  registerExceptionStubs();
  await tester.runAsync(() => primeAppState(dark: dark));
  await tester.runAsync(registerDemoDependencies);
  await tester.runAsync(persistDemoUser);
  await seedDeviceHistory(tester);
  registerScreen();

  tester.view.physicalSize =
      Size(kLogicalWidth * kDevicePixelRatio, kProbeHeight * kDevicePixelRatio);
  tester.view.devicePixelRatio = kDevicePixelRatio;
  addTearDown(tester.view.reset);

  final boundaryKey = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: boundaryKey,
    child: buildScreen(dark: dark),
  ));
  await _drain(tester);

  // Pass 1 measures the real content height in the tall probe viewport; pass 2
  // re-renders at exactly that height so the PNG is a full-length strip with
  // no dead space. Two passes are REQUIRED, not an optimisation: screenutil
  // `.h` sizes scale with the viewport, so the height converges to a fixed
  // point rather than being known up front.
  var measured = _measure(tester, elementSpecs());
  expect(measured, isNotEmpty,
      reason: 'no elements matched - check elementSpecs() and the gates in '
          'registerScreen()');

  final contentBottom =
      measured.map((m) => m.rect.bottom).reduce((a, b) => a > b ? a : b);
  final targetHeight =
      (contentBottom + kBottomPadding).clamp(400.0, kProbeHeight);

  tester.view.physicalSize =
      Size(kLogicalWidth * kDevicePixelRatio, targetHeight * kDevicePixelRatio);
  await tester.pump(const Duration(milliseconds: 50));
  await _drain(tester, rounds: 4);
  measured = _measure(tester, elementSpecs());

  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: kDevicePixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${outDir.path}/$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());

    // Sidecar consumed by scripts/render/compose_strip.py. `number` is a
    // convenience only - the composer re-derives stable global numbers from
    // `key`, so a new element never renumbers the ones already reviewed.
    final sidecar = <String, Object?>{
      'variant': name,
      'logicalWidth': kLogicalWidth,
      'logicalHeight': targetHeight,
      'devicePixelRatio': kDevicePixelRatio,
      'elements': <Object>[
        for (var i = 0; i < measured.length; i++)
          <String, Object?>{
            'number': i + 1,
            'key': measured[i].key,
            'label': measured[i].label,
            'x': measured[i].rect.left,
            'y': measured[i].rect.top,
            'w': measured[i].rect.width,
            'h': measured[i].rect.height,
          }
      ],
    };
    File('${outDir.path}/$name.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(sidecar));
  });
}

bool _fontsLoaded = false;
Future<void> _loadRealFontsOnce() async {
  if (_fontsLoaded) return;
  await loadRealFonts();
  _fontsLoaded = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Never let a test reach out for a webfont: the render must be reproducible
  // offline, and a silent fetch failure is a silent Ahem fallback. The faces
  // are registered from files by loadRealFonts() instead.
  GoogleFonts.config.allowRuntimeFetching = false;

  final dbDir = Directory.systemTemp.createTempSync('render_harness_db').path;

  // RENDER_SUFFIX distinguishes runs of the SAME harness against different
  // checkouts (e.g. `_draft` for the PR heads, empty for main), so both sets
  // of outputs can sit in one out/ dir and be composed into one page.
  final suffix = Platform.environment['RENDER_SUFFIX'] ?? '';

  testWidgets('render lms student profile - dark (app default)',
      (tester) async {
    await renderVariant(tester,
        dark: true, name: 'lms_student_profile_dark$suffix', dbDir: dbDir);
  });

  testWidgets('render lms student profile - light', (tester) async {
    await renderVariant(tester,
        dark: false, name: 'lms_student_profile_light$suffix', dbDir: dbDir);
  });
}
