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
// Data: the harness activates a demo session (DemoSession.instance.activate)
// and the SDKs register their REAL Http repositories; base_sdk's
// DemoGatewayInterceptor answers every platform cmd from the SDKs' own
// `<cmd>.json` fixtures. No build flag is needed.
//
// Run:  flutter test test/render/render_screen_test.dart
//       RENDER_SUFFIX=_draft flutter test test/render/render_screen_test.dart

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
// The offline seam google_fonts documents for tests: `httpClient` is
// @visibleForTesting, so the harness can serve the faces committed beside
// this file instead of reaching fonts.gstatic.com.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_base;
import 'package:http/http.dart' as http;
import 'package:replay_sdk/replay_sdk.dart' show AssetPreloadScheduler;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auth_sdk/auth_sdk.dart' show AuthSdkDependencies;
// ignore: implementation_imports
import 'package:auth_sdk/src/common/services/session_profile.dart'
    show sessionProfileOf;
import 'package:base_sdk/base_sdk.dart'
    show
        BaseSdkDependencies,
        DemoFixtures,
        DemoSession,
        LocalStorage,
        ProfileSectionRegistry;
// Deep imports into base_sdk's src/ are expected in a harness (the kit's
// template says so): the harness is deliberately coupled to the shipped code
// rather than to a public facade, and neither the theme seam nor the auth
// facade is on the base_sdk barrel.
import 'package:base_sdk/src/domain/interface/auth.dart'
    show AuthRepositoryFacade;
// ApiResult's `when` is an extension declared in its freezed part, so the
// library that declares it has to be imported for the pattern to be in scope.
import 'package:base_sdk/src/handlers/api_result.dart';
import 'package:base_sdk/src/presentation/pages/profile/widgets/profile_theme_toggle.dart'
    show ProfileThemeToggle;
import 'package:base_sdk/src/presentation/theme/app_style.dart' show AppStyle;
import 'package:lms_sdk/lms_sdk.dart'
    show
        LmsArcsDetailCard,
        LmsAttendanceDetailCard,
        LmsCalendarExportCard,
        LmsSchoolCard,
        LmsSdkDependencies,
        LmsSettingCard,
        LmsStudentStatsRow,
        ServerClock;
import 'package:users_sdk/users_sdk.dart' show UsersSdkDependencies;
// The bundled English copy main.dart's boot hooks register. Without it
// every key the backend would serve rendered humanized ("Matric prep title").
// ignore: implementation_imports
import 'package:auth_sdk/src/translations/auth_en_translations.dart'
    show kAuthEnTranslations;
// ignore: implementation_imports
import 'package:base_sdk/src/services/bundled_translations.dart'
    show BundledTranslations;
// ignore: implementation_imports
import 'package:lms_sdk/src/translations/lms_en_translations.dart'
    show kLmsEnTranslations;

// The shell's own composed glue. This is the point of rendering a SHELL
// rather than an SDK: the sections, hooks, ordering and gates below are the
// ones the shipped app registers, not a reconstruction of them.
import 'package:supacharge/presentation/routes/lms_route_pages.dart'
    show
        DemoLibraryStore,
        DemoProfileStore,
        DemoScheduleSource,
        StudentProfileRouteView,
        SupachargeNav,
        registerSupachargeProfileSections,
        supachargeAnnouncementsAllowed,
        supachargeLessonReviewAllowed;
import 'render_screens.g.dart' show kGeneratedScreens;
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

/// Logical height of the phone viewport every screen is rendered in.
const double kPhoneHeight = 844;

/// Elements anchored to the VIEWPORT, not to the end of the content.
///
/// StudentProfileRouteView puts the floating nav in an Align(bottomCenter)
/// inside a Stack, so its rect bottom is always the bottom of whatever
/// viewport it is measured in. Feeding that into the shrink pass makes
/// contentBottom the probe height and the frame never shrinks - the render
/// came out 2600 logical px tall with ~1300 of dead space under the footer.
/// These keys are therefore excluded from the content height and their
/// measured height is reserved as bottom chrome instead, which is the same
/// thing minilauncher's harness does for its drawer handle.
const Set<String> kViewportAnchored = <String>{'lms.nav'};

/// The app's design size, straight from the composed app_widget: a 390px
/// frame is compact, so ScreenUtil resolves `.w/.h/.sp` against 375x812.
const Size kDesignSize = Size(375, 812);

/// TODO(harness) 2/8 - the SDK's own demo data. THIS IS THE MAIN PATH.
///
/// Registrations run in composed-app order (base first, then each feature
/// SDK), exactly as main.dart's generated sdk-di block does. Each SDK
/// registers its REAL Http repository and its own `<cmd>.json` fixture
/// directory; with the demo session active (primeAppState) base_sdk's
/// DemoGatewayInterceptor answers every platform call from those fixtures.
/// Nothing here is a fixture written for this render.
Future<void> registerDemoDependencies() async {
  assert(
      DemoSession.demoActive,
      'demo session not active: the real repositories would call a live '
      'backend and the render is of a broken, empty screen');
  final getIt = GetIt.I;
  // Same trap again, in Flutter itself: rootBundle caches each asset's
  // load Future, and a Future delivers its result through the zone it was
  // created in. The demo interceptor reads its fixtures through rootBundle,
  // so a fixture first loaded inside an earlier variant's fake-async zone
  // never answered a later variant: tutors, courses, library and schedule
  // were captured as a lone spinner. Empty the cache so each variant loads
  // its fixtures in its own zone, as a fresh app launch would.
  rootBundle.clear();
  // main.dart's translation boot hooks, in the same order.
  BundledTranslations.register('en', kAuthEnTranslations);
  BundledTranslations.register('en', kLmsEnTranslations);
  BaseSdkDependencies.register(getIt);
  AuthSdkDependencies.register(getIt);
  UsersSdkDependencies.register(getIt);
  // A fixed school-day "now" BEFORE lms_sdk registers its clock (its
  // registration stands aside for one already there). See kRenderNow.
  if (!getIt.isRegistered<ServerClock>()) {
    final clock = ServerClock(fetch: () async => kRenderNow().toUtc());
    await clock.sync();
    getIt.registerSingleton<ServerClock>(clock);
  }
  LmsSdkDependencies.register(getIt);

  // Prime the shell's two memoised operator gates (lesson review /
  // homework queue, announcements) HERE, on the real event loop this
  // function already runs on. The shell keeps each answer for the life of
  // the process - a real app has one profile lifetime - but this harness
  // renders two variants in one process: a Future first completed inside
  // the first variant's fake-async zone wakes its later awaiters in that
  // zone, which is gone by the second variant, so GenericProfilePage's
  // sequential gate walk stalled at 'lms.student.lesson_review' and every
  // section and header slot after it stayed unresolved in the light frame
  // (12 elements measured against the dark frame's 17). Primed on the real
  // loop, the memo wakes both variants. The answers are still the demo
  // repository's own.
  await Future.wait<bool>(<Future<bool>>[
    supachargeLessonReviewAllowed(),
    supachargeAnnouncementsAllowed(),
  ]);
  // The demo library and schedule seed their lesson assets once per launch
  // behind a static Future. Seed them here on the real loop too, or the
  // second variant of each waits on a Future from the first's dead zone.
  await DemoLibraryStore().load();
  await DemoProfileStore().attendance();
  await DemoScheduleSource().upcoming();
  seedConfirmedGrade();
}

/// The moment every screen is rendered at: today at 10:00 in the render's
/// local time zone, mid-morning of a school day.
///
/// The demo week (schedule, library, attendance) is laid out relative to the
/// app's [ServerClock], whose demo answer is the device's own clock. Taken
/// from the wall clock, a render made at 06:00 UTC listed the day's sessions
/// between about 05:00 and 09:00. Pinning the clock keeps the timetable in
/// school hours (roughly 08:00 to 15:00) whenever the render runs, and keeps
/// one live session in its door window, as the demo intends.
DateTime kRenderNow() {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day, 10);
}

/// The loader DemoFixtures had before the harness wrapped it, kept so the
/// wrap is applied once per process rather than once per variant.
Future<String?> Function(String key)? _baseFixtureLoader;

/// Demo state: the demo student has ALREADY confirmed this school year's
/// grade.
///
/// lms_sdk's `student_my_grade` fixture answers `needs_confirmation: true`
/// so the app's own tour can walk the January rollover gate. A render of the
/// Schedule tab is a render of the schedule, though, and with that answer it
/// captured the blocking "New school year - which grade are you in now"
/// gate instead of the timetable. The same fixture answer, with the
/// confirmation done (grade 12 - the gate's suggested grade - and nothing
/// left to confirm), is what the app holds after the student taps through.
/// Served through DemoFixtures' own loader seam; every other fixture is
/// untouched.
void seedConfirmedGrade() {
  final base = _baseFixtureLoader ??= DemoFixtures.loader;
  DemoFixtures.loader = (String key) async {
    final text = await base(key);
    if (text == null) return text;
    if (!key.endsWith('/api.lms.student_my_grade.json')) return text;
    final status = Map<String, dynamic>.from(jsonDecode(text) as Map);
    final suggested = status['suggested_grade'] ?? status['grade'];
    return jsonEncode(<String, dynamic>{
      ...status,
      'grade': suggested,
      'needs_confirmation': false,
    });
  };
}

/// TODO(harness) 3/8 - EXCEPTION: device history the demo mode cannot supply.
///
/// EMPTY. The profile's attendance ledger and library are device history,
/// but the app's own demo mode now fills them: the shell registers
/// lms_sdk's demo-aware DemoProfileStore and DemoLibraryStore, which seed a
/// believable month on a demo session's first read (see
/// registerDemoDependencies). Nothing is seeded here.
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
/// (hidden: the persona defaults to student), the shared nav clearance, and
/// the registry's onLogout affordance.
void registerScreen() {
  ProfileSectionRegistry.I.reset();
  registerSupachargeProfileSections();
}

// The other LMS screens come from the lms_sdk's own render fragment
// (templates/render/lms.render.yaml), merged into render_screens.g.dart by
// shared-workflows scripts/render/merge_render_fragments.py before this test
// runs (run_strip.sh). Each is the real route view; the in-app tutorial layer
// is never drawn - the render does not know about it and must not.

/// TODO(harness) 6/8 - the widget under test.
///
/// The real screen in the real wrapping: the app's ProviderScope,
/// ScreenUtilInit at the app's design size, and a MaterialApp carrying the
/// composed app_widget's ThemeData. GenericProfilePage is the host; every row
/// below the identity header comes from the registry.
Widget buildScreen({required bool dark, Widget? home}) {
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
        // The REAL host route, not a bare GenericProfilePage. The route is a
        // Stack of the profile host PLUS the floating pill nav
        // (SupachargeNav, Profile slot index 3); the section list ends in a
        // clearance spacer sized for exactly that nav. Pumping the page on its
        // own reserved the strip and drew nothing into it, so the frame was
        // missing chrome the shipped screen always has. Driving the app's own
        // composition is also what sets the profile persona, which
        // StudentProfileRouteView.build does on the way past.
        home: home ?? const StudentProfileRouteView(),
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
List<ElementSpec> elementSpecs({String screen = 'profile'}) {
  // Every other LMS screen is measured as ONE element, the real route view
  // itself. Per-element callouts for those screens are added as each one is
  // reviewed; the page is still a real render either way.
  final pageFinder = kGeneratedScreens[screen]?.finder;
  if (pageFinder != null) {
    return <ElementSpec>[
      ElementSpec(
        key: 'lms.$screen.page',
        label: 'LMS $screen screen - real route view',
        finder: pageFinder(),
      ),
    ];
  }
  return <ElementSpec>[
    ElementSpec(
      key: 'base.identity_header',
      label: 'Identity header - name, contact, role, edit/logout',
      finder: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_IdentityHeader'),
    ),
    ElementSpec(
      key: 'lms.student.header_stats',
      label: 'Stats row - attendance and average score',
      finder: find.byType(LmsStudentStatsRow),
    ),
    // The successor of the retired appearance row (number 19, burnt): the
    // light/dark toggle is base_sdk's ProfileThemeToggle in the host's top
    // controls row, above the identity header. A new key rather than the
    // old one, because the kit never re-issues a retired number.
    ElementSpec(
      key: 'base.theme_toggle',
      label: 'Theme toggle pill - light/dark (host top controls row)',
      finder: find.byType(ProfileThemeToggle),
    ),
    // The section-id specs come BEFORE the generic settings-row spec on
    // purpose. LmsSchoolCard RETURNS an LmsSettingCard, so both finders match
    // the same rect; the kit's de-duplication keeps whichever was measured
    // first, and the section id is the better key because it survives a
    // reworded row title. strip.json carries a number for both spellings so
    // the page numbers correctly either way.
    //
    // There is deliberately no appearance row here: lms_sdk retired it (see
    // LmsProfileSections' own doc comment - "the appearance settings row is
    // retired ... the host's top controls row owns the theme toggle now"), so
    // its numbers are parked in strip.json's `retired` map rather than
    // pointing at a widget that no longer exists.
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
    ElementSpec.each(
      keyOf: (i, w) => 'lms.setting_row.${(w as LmsSettingCard).title}',
      labelOf: (i, w) => 'Setting row - ${(w as LmsSettingCard).title}',
      finder: find.byType(LmsSettingCard),
    ),
    ElementSpec(
      key: 'lms.nav',
      label: 'Floating pill nav - Profile slot (index 3)',
      finder: find.byType(SupachargeNav),
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
// Where the files come from: they are COMMITTED under test/render/fonts/,
// named by the SHA-256 google_fonts checks each file against, and served back
// through google_fonts' own @visibleForTesting http seam. google_fonts then
// takes its normal path and verifies each file's length AND checksum before
// registering it, so the render is provably the real face rather than a
// lookalike, and no hash is hard-coded here.
//
// An earlier revision fetched the families from upstream at render time
// instead. That is fragile by design - a render test that needs the network is
// one outage away from red - and it is the last thing in the fleet still doing
// it, so this now matches paas_driver. A face nobody committed 404s through
// the offline client and fails the run loudly, naming the file.
//
// Set RENDER_FONT_DIR to point at a different directory of the same shape.
// ---------------------------------------------------------------------------

/// Directory holding the committed Google faces, named by the SHA-256
/// google_fonts checks each file against. `RENDER_FONT_DIR` points the harness
/// at a different directory for a local experiment.
String _fontDir() {
  final override = Platform.environment['RENDER_FONT_DIR'];
  if (override != null && override.isNotEmpty) return override;
  return '${Directory.current.path}/test/render/fonts';
}

/// Serves google_fonts' own font URLs from the committed faces.
///
/// google_fonts addresses every file as
/// `https://fonts.gstatic.com/s/a/<sha256>.ttf`, so the file name IS the
/// checksum: no hash is hard-coded in this harness, and a google_fonts bump
/// that moves to different faces surfaces as an honest 404 instead of a
/// silently wrong render.
class _OfflineGoogleFontsClient extends http.BaseClient {
  _OfflineGoogleFontsClient(this.fontsDir);

  final Directory fontsDir;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final file = File('${fontsDir.path}/${request.url.pathSegments.last}');
    if (!file.existsSync()) {
      return http.StreamedResponse(
        const Stream<List<int>>.empty(),
        404,
        request: request,
        reasonPhrase:
            'not committed under test/render/fonts - see its README to add it',
      );
    }
    final bytes = file.readAsBytesSync();
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      200,
      contentLength: bytes.length,
      request: request,
    );
  }
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

  final fontsDir = Directory(_fontDir());
  if (!fontsDir.existsSync()) {
    throw StateError(
      'no committed Google faces at ${fontsDir.path} - every glyph would fall '
      'back to the FlutterTest block font and the render would be worthless.',
    );
  }
  google_fonts_base.httpClient = _OfflineGoogleFontsClient(fontsDir);

  // Warm every face AppStyle asks google_fonts for BEFORE the first pump, and
  // wait for the registrations to land. google_fonts registers asynchronously,
  // so without this the first variant lays out with fallback metrics and only
  // re-measures once the faces arrive. Deterministic, and identical for both
  // variants.
  // Inline SVG art (the demo avatar's initials) names Helvetica / Arial /
  // sans-serif, none of which exists in a headless test: the initials drew
  // as FlutterTest blocks, a white bar across the avatar. Serve those
  // generic families from the committed Inter faces.
  final interFaces = <File>[
    File('${fontsDir.path}/ecdb53099b1a68cd24c6900ea5beeafec81bd3c8cb9d0f3c51b9986583ba3982.ttf'),
    File('${fontsDir.path}/d7ba633bab7f40576e539a7e934a1301d7618dceea59c743de477c2c493462fc.ttf'),
  ];
  for (final family in <String>['Helvetica', 'Arial', 'sans-serif']) {
    await load(family, interFaces);
  }

  await GoogleFonts.pendingFonts(<TextStyle>[
    // Inter - the body scale (interRegular / interNormal / interNoSemi /
    // interSemi + interBold).
    GoogleFonts.inter(fontWeight: FontWeight.w400),
    GoogleFonts.inter(fontWeight: FontWeight.w500),
    GoogleFonts.inter(fontWeight: FontWeight.w600),
    GoogleFonts.inter(fontWeight: FontWeight.w700),
    // Montserrat - the logo/motto scale, upright and italic.
    GoogleFonts.montserrat(fontWeight: FontWeight.w400),
    GoogleFonts.montserrat(fontWeight: FontWeight.w700),
    GoogleFonts.montserrat(fontWeight: FontWeight.w900),
    GoogleFonts.montserrat(
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
    ),
    GoogleFonts.montserrat(
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
    ),
    GoogleFonts.montserrat(
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
    ),
  ]);

  // Roboto is the one face google_fonts is never asked for: nothing in
  // AppStyle calls GoogleFonts.roboto, but a TextStyle naming no family
  // resolves to the platform default, which under `flutter test` is the
  // FlutterTest block font. Register it directly under the plain family name.
  final roboto = File(
    '${fontsDir.path}/'
    'd1d7c5f4500eeb1a09e051781906c3642015a3f6c9b69046b905c8bf34c6ad60.ttf',
  );
  if (!roboto.existsSync()) {
    throw StateError('Roboto 400 missing at ${roboto.path} - every bare '
        'TextStyle would render as the FlutterTest block font');
  }
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
  final remix = _findFile(Directory(pubCache),
      RegExp(r'remixicon-[^/\\]+[/\\]fonts[/\\]Remix\.ttf'));
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
  // Demo on: the mock preferences above start empty, so the persisted flag
  // is set again for each variant.
  await DemoSession.instance.activate();
  AppStyle.setBrightness(dark ? Brightness.dark : Brightness.light);
  // The app's brand palette, injected the way main.dart's brand hook does.
  applyAppBrandColors();
}

/// The demo persona this shell signs in as - a student account, which the
/// auth SDK's `api.user.login` fixture answers for any address it does not
/// map to another role.
const String kDemoStudentEmail = 'student@demo.rokct.ai';

/// Persists the demo persona the identity header reads.
///
/// Signs in the way the app does: through the REAL
/// `AuthRepositoryFacade.login`, whose `api.user.login` call the
/// DemoGatewayInterceptor answers from auth_sdk's own fixture. The account is
/// mapped with auth_sdk's `sessionProfileOf` and stored through the app's
/// real LocalStorage.setUser, which is exactly where GenericProfilePage's
/// identity header reads the user from.
///
/// The auth token is left EMPTY on purpose. base_sdk's
/// ProfileNotifier.fetchUser short-circuits without one; WITH one it reaches
/// for connectivity_plus, whose channel is unimplemented headlessly, and the
/// resulting unawaited async error would fail the render instead of showing
/// anything.
Future<void> persistDemoUser() async {
  final auth = GetIt.I<AuthRepositoryFacade>();
  final result = await auth.login(email: kDemoStudentEmail, password: 'demo');
  await result.when(
    success: (data) async {
      final user = data.data?.user;
      if (user == null) {
        throw StateError('the api.user.login fixture returned no user');
      }
      await LocalStorage.setUser(sessionProfileOf(user));
    },
    failure: (error, status) async {
      throw StateError('demo sign-in failed ($status): $error - is the demo '
          'session active and does auth_sdk ship an api.user.login fixture?');
    },
  );
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

/// The other channels this harness has to answer. All answer NULL - nothing is
/// simulated, the absent plugin is simply not allowed to throw an unhandled
/// MissingPluginException that aborts the render:
///
///  * `flutter_secure_storage` - LocalStorage's session write reaches for it,
///    so the app's REAL write can run unmodified.
///  * `connectivity_plus` - the app subscribes to the connectivity stream on
///    startup. `receiveBroadcastStream` activates the stream by sending
///    `listen` over a MethodChannel of the SAME name, so mocking the method
///    channel is what stops it; without this the dark variant (which runs
///    first) dies on an unhandled MissingPluginException before it can be
///    captured. Answering null leaves the app in its genuine headless state -
///    no connectivity events - which is what the frame should show.
void _mockAbsentPlugins() {
  const channels = <String>[
    'plugins.it_nomads.com/flutter_secure_storage',
    'dev.fluttercommunity.plus/connectivity',
    'dev.fluttercommunity.plus/connectivity_status',
  ];
  for (final name in channels) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(name), (call) async => null);
  }
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

/// Keeps draining real async work until no loading spinner is on screen, so
/// a screen whose demo data lands late is captured with its content instead
/// of a lone CircularProgressIndicator. Gives up after [timeout] and says so.
Future<void> _waitForLoaded(WidgetTester tester, String name,
    {Duration timeout = const Duration(seconds: 30)}) async {
  final loading = _loadingIndicators();
  final stopwatch = Stopwatch()..start();
  while (loading.evaluate().isNotEmpty && stopwatch.elapsed < timeout) {
    await _drain(tester, rounds: 2);
  }
  if (loading.evaluate().isNotEmpty) {
    // ignore: avoid_print
    print('[render] WARNING: $name still shows a loading indicator after '
        '${timeout.inSeconds}s - its demo data never arrived.');
  }
}

/// Spinners and skeleton shimmers: any of these on screen means the data has
/// not landed yet.
Finder _loadingIndicators() => find.byWidgetPredicate((w) =>
    w is CircularProgressIndicator ||
    w.runtimeType.toString().toLowerCase().contains('shimmer') ||
    w.runtimeType.toString().toLowerCase().contains('skeleton'));

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
  String screen = 'profile',
}) async {
  final outDir = Directory('${Directory.current.path}/out')
    ..createSync(recursive: true);

  _mockPathProvider(dbDir);
  _mockAbsentPlugins();

  await tester.runAsync(_loadRealFontsOnce);

  // Order matters. Exception stubs go into GetIt FIRST so the SDKs' guarded
  // registrations stand aside; then the SDKs register their real
  // repositories (answered by the demo interceptor); then any device history the demo mode cannot supply.
  registerExceptionStubs();
  await tester.runAsync(() => primeAppState(dark: dark));
  await tester.runAsync(registerDemoDependencies);
  await tester.runAsync(persistDemoUser);
  await seedDeviceHistory(tester);
  registerScreen();

  // Every screen renders in ONE fixed phone viewport (390x844), the frame a
  // store screenshot or marketing render is read in. The earlier
  // measure-then-shrink pass resized the viewport AFTER the data had loaded;
  // the resize rebuilt route views into a fresh load (the frame was captured
  // on its spinner) and, for a Scaffold whose leaves never settled, left the
  // frame at the 2600px probe height. A fixed viewport has neither failure.
  tester.view.physicalSize =
      Size(kLogicalWidth * kDevicePixelRatio, kPhoneHeight * kDevicePixelRatio);
  tester.view.devicePixelRatio = kDevicePixelRatio;
  addTearDown(tester.view.reset);
  const targetHeight = kPhoneHeight;

  final boundaryKey = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: boundaryKey,
    child: buildScreen(dark: dark, home: kGeneratedScreens[screen]?.build()),
  ));
  await _drain(tester);
  await _waitForLoaded(tester, name);
  // Let entrance animations and late setStates finish, then check again.
  await _drain(tester, rounds: 4);
  await _waitForLoaded(tester, name);
  expect(_loadingIndicators().evaluate(), isEmpty,
      reason: '$name is still loading - refusing to capture a spinner or '
          'shimmer frame');

  // Only what is on screen in the phone frame is annotated.
  final measured = _measure(tester, elementSpecs(screen: screen))
      .where((m) => m.rect.top < kPhoneHeight && m.rect.bottom > 0)
      .toList();
  expect(measured, isNotEmpty,
      reason: 'no elements matched - check elementSpecs() and the gates in '
          'registerScreen()');

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

  // The Library screen's demo seed registers the replay SDK, which starts a
  // 6-hour periodic asset-preload timer; a timer left pending fails the test
  // after the PNG is already written.
  if (GetIt.I.isRegistered<AssetPreloadScheduler>()) {
    GetIt.I.get<AssetPreloadScheduler>().stop();
  }
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
  // Fetching stays ON, but `loadRealFonts` swaps google_fonts' http client
  // for one that only ever answers from the faces committed under
  // test/render/fonts. Nothing reaches the network, the render is
  // reproducible offline, and google_fonts still checksums every face it
  // registers. Turning fetching OFF instead would make google_fonts throw
  // before it ever consulted the committed files.
  GoogleFonts.config.allowRuntimeFetching = true;

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

  for (final screen in kGeneratedScreens.keys) {
    for (final dark in <bool>[true, false]) {
      testWidgets('render lms $screen - ${dark ? 'dark' : 'light'}',
          (tester) async {
        await renderVariant(tester,
            dark: dark,
            name: '${screen}_${dark ? 'dark' : 'light'}$suffix',
            dbDir: dbDir,
            screen: screen);
      });
    }
  }
}
