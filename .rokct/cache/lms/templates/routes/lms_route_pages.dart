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


// Host-side route shell + cross-SDK adapters for lms_sdk's lesson player.
//
// This file is HOST glue (installed into the app shell), which is the one
// place allowed to import multiple feature SDKs: lms_sdk owns the lesson
// experience and its interfaces; replay_sdk owns headless playback. The
// adapters below satisfy lms_sdk's LessonPlaybackEngine with replay_sdk's
// gatekeeper/audio-sync, and replay_sdk's ManimRenderSink with lms_sdk's
// WhiteboardPlayer (ADR-005: consumer-owned interfaces, host-owned adapters).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:auto_route/auto_route.dart';
import 'package:${package}/presentation/routes/app_router.dart';
// Bundled demo lesson (real evaluated content triple): the seeded asset ids
// back the demo schedule's joinable sessions and the tutor-card sample.
// `show`-restricted — demo_lesson.dart's own demo classes predate this
// file's and would otherwise collide.
import 'package:${package}/presentation/routes/demo_lesson.dart'
    show kDemoLessonSessionId, demoWeekMockSessionIds, seedDemoLessonAssets;
import 'package:base_sdk/base_sdk.dart';
// Chained partner login after guest accept/signup (the backend returns
// {email} only, no session) — the same facade the login screen exchanges
// credentials through, resolved from GetIt like every other service here.
import 'package:base_sdk/src/domain/interface/auth.dart'
    show AuthRepositoryFacade;
// Unwired-facade stand-ins for the generic profile host: base_sdk's
// profileProvider eagerly resolves these two marketplace-side facades this
// app never composes a provider for (see registerSupachargeProfileSections).
import 'package:base_sdk/src/domain/interface/gallery.dart'
    show GalleryRepositoryFacade;
import 'package:base_sdk/src/domain/interface/shops.dart'
    show ShopsRepositoryFacade;
import 'package:base_sdk/src/presentation/theme/app_style.dart';
// Device-local notification scheduling (Remind Me tasks + the no-opt-in
// session-start alerts) — the same comms_sdk primitive productivity's
// tasks page schedules its own reminders through.
import 'package:comms_sdk/comms_sdk.dart' show LocalNotifications;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
// Second, prefixed import of services on purpose (additive — the `show
// rootBundle` line above is shared with other in-flight work): the
// Readiness share sheet needs Clipboard.
import 'package:flutter/services.dart' as services;
import 'package:get_it/get_it.dart';
import 'package:lms_sdk/lms_sdk.dart';
// Opt-in lesson calendar export: the generated .ics travels through the
// platform share sheet (both packages are host-pubspec dependencies).
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:productivity_sdk/productivity_sdk.dart' as prod;
import 'package:remixicon/remixicon.dart';
import 'package:replay_sdk/replay_sdk.dart';
import 'package:share_plus/share_plus.dart';
// Office-hours weak concepts: users_sdk's cross-session aggregate endpoint
// (Users PR #17). Concrete-class import on purpose — getWeakConcepts is not
// on base_sdk's UserRepositoryFacade (that facade lives in the core repo);
// host glue is the one place allowed to couple SDKs like this (ADR-005).
import 'package:users_sdk/src/common/infrastructure/repositories/user_repository.dart'
    show UserRepository;
// Shared wallet card config: wallet_sdk registers the 'wallet.card'
// profile section itself (its own di_hook); this host only sets the
// section's static seam (see registerSupachargeProfileSections). Host glue
// is the one place allowed to couple SDKs like this (ADR-005).
import 'package:wallet_sdk/wallet_sdk.dart' show WalletCardSection;

/// The universal platform gateway entry point: every backend call in this
/// file is a POST here with a `{"cmd", "payload"}` JSON body, where cmd is
/// the old dotted endpoint with its leading app segment dropped
/// (`paas.api.lms.*` -> `api.lms.*`, `paas.api.replay.*` -> `api.replay.*`).
/// Kept on the raw [HttpService] client (rather than base_sdk's
/// [PlatformGateway]) because several sites below read the response's
/// status code, which the gateway helper does not surface.
const String _kGatewayPath = '/api/v1/method/rokct.platform.api';

/// The curriculum Supacharge teaches, as the fallback when a student has no
/// stored choice. A host-owned constant, not a base_sdk or lms_sdk concern:
/// all CONTENT is CAPS-only today — CAPS exists in content only as the
/// factory's structure. Per-student curriculum (school-capture brief) is
/// read through [resolveStudentCurriculum] below, never this constant
/// directly.
const String kSupachargeCurriculum = 'CAPS';

/// The student's curriculum, resolved: their stored choice (school-capture
/// brief — derived from the school they picked, or their confirmed
/// fallback, kept in the 'lms_curriculum' KV alongside `lms_school`) when
/// present, else [kSupachargeCurriculum]. The ONE read path for per-student
/// curriculum — the school-capture flow and [resolveContentCurriculumLabel]
/// both resolve through here rather than reading the constant or the KV
/// directly. This is the student's STORED answer: it is not by itself a
/// claim about the content they are served. See
/// [resolveContentCurriculumLabel] for the badge.
Future<String> resolveStudentCurriculum() async {
  try {
    final row = await AppDbScheduleStore().get('lms_curriculum', 'value');
    final c = row?['curriculum'];
    if (c is String && c.trim().isNotEmpty) return c.trim();
  } catch (_) {/* fall through to the app constant */}
  return kSupachargeCurriculum;
}

/// Curricula whose lessons the app actually serves today.
///
/// The published lesson indexes carry CAPS rows only — the index builders
/// read the CAPS curriculum root and `lms_course` has no curriculum
/// dimension — so CAPS is the one value a badge can truthfully name. Add a
/// curriculum here when its content actually reaches students, and the
/// badge starts appearing for it on its own.
const Set<String> kServedCurricula = {kSupachargeCurriculum};

/// The curriculum to LABEL content with, or null when the student's stored
/// curriculum is not one the served content honours. The badge asserts
/// "these lessons are <X>" — it may only appear when that is true.
///
/// Distinct from [resolveStudentCurriculum], which keeps returning the
/// stored value for everything that legitimately needs it (the
/// school-capture pools, the suggestion buckets). Only the badge goes
/// through here.
Future<String?> resolveContentCurriculumLabel() async {
  final c = await resolveStudentCurriculum();
  return kServedCurricula.contains(c) ? c : null;
}

/// Shared suggestion pools for the school-capture flow (used by the
/// onboarding school slide and the profile school row): the compiled seed
/// list, then the bundled DBE EMIS masterlist asset — the demo/offline
/// nationwide pool; its canonical copy lives in the agent repo at
/// lms/frappe/src/rlms/data/known_schools.json and is copied into
/// assets/known_schools.json (assets/ is not versioned here) — then the
/// accumulated pool: schools other students entered under a curriculum,
/// fetched from the backend (`student_known_schools`) via
/// [_fetchAccumulatedSchools].
final CombinedSchoolSuggester supachargeSchoolSuggester =
    CombinedSchoolSuggester(
  sources: [
    const SeedListSchoolSuggestionSource(),
    LoadedPoolSchoolSuggestionSource(_loadMasterlistSchoolPools),
    AccumulatedSchoolSuggestionSource.remote(_fetchAccumulatedSchools),
  ],
);

/// Backend fetch for the accumulated school pool
/// (`LmsRepository.knownSchools` → rlms `student_known_schools`). Failures
/// stay silent — suggestions are decoration, never an error surface: the
/// source degrades a throw to no suggestions and retries on a later
/// keystroke.
Future<List<String>> _fetchAccumulatedSchools(String curriculum) {
  final getIt = GetIt.instance;
  if (!getIt.isRegistered<LmsRepository>()) {
    LmsSdkDependencies.register(getIt);
  }
  return getIt.get<LmsRepository>().knownSchools(curriculum);
}

/// Parses the bundled masterlist into per-curriculum name pools, keeping
/// only phases a grade 8-12 student can attend (secondary / combined /
/// intermediate) so suggestions aren't drowned in primary schools. Names
/// stay verbatim from the masterlist — never edited — so a later backend
/// sync dedupes cleanly. A missing or malformed asset degrades to no
/// suggestions from this pool.
Future<Map<String, List<String>>> _loadMasterlistSchoolPools() async {
  try {
    final raw = await rootBundle.loadString('assets/known_schools.json');
    final decoded = jsonDecode(raw);
    final curricula =
        decoded is Map<String, dynamic> ? decoded['curricula'] : null;
    if (curricula is! Map<String, dynamic>) return const {};
    const phases = {'secondary', 'combined', 'intermediate'};
    return {
      for (final e in curricula.entries)
        e.key: [
          for (final s in (e.value as List? ?? const []))
            if (s is Map && phases.contains(s['phase'])) '${s['name']}',
        ],
    };
  } catch (e) {
    debugPrint('==> school masterlist asset load failed: $e');
    return const {};
  }
}

/// Wraps lms_sdk's `LmsRepository.setGrade()` behind [StudentGradeCapture]
/// (ADR-005: consumer-owned interface, host-owned adapter) — backing the
/// onboarding grade slide lms_sdk's manifest injects into the onboarding
/// shell via its `onboarding_slides` entry.
class LmsGradeCaptureAdapter implements StudentGradeCapture {
  LmsRepository get _repository {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<LmsRepository>()) {
      LmsSdkDependencies.register(getIt);
    }
    return getIt.get<LmsRepository>();
  }

  @override
  Future<void> submitGrade(int grade) async {
    // Offline-first: persist to the shared KV the profile reads back, so the
    // grade captured here survives even when the backend is unavailable
    // (dev/demo). The backend write is best-effort on top.
    try {
      await AppDbScheduleStore().put('lms_grade', 'value', {'grade': grade});
    } catch (_) {/* best-effort local cache */}
    await _repository.setGrade(grade);
  }
}

/// Wraps the offline-first school + curriculum KVs behind lms_sdk's
/// [StudentSchoolCapture] (school-capture brief + curriculum refinement),
/// mirroring [LmsGradeCaptureAdapter]'s storage path exactly: the shared KV
/// the profile reads back is written first, then the backend write
/// (`LmsRepository.setSchool()` → the rlms student record's school +
/// curriculum fields) rides best-effort on top — the school slide swallows
/// a throw, so a backend hiccup never blocks onboarding. The stored
/// curriculum is read back through [resolveStudentCurriculum] above.
class LmsSchoolCaptureAdapter implements StudentSchoolCapture {
  LmsRepository get _repository {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<LmsRepository>()) {
      LmsSdkDependencies.register(getIt);
    }
    return getIt.get<LmsRepository>();
  }

  @override
  Future<void> submitSchool(String school,
      {required String curriculum}) async {
    // Offline-first: persist to the shared KV the profile reads back, so the
    // school captured here survives even when the backend is unavailable
    // (dev/demo). The backend write is best-effort on top.
    try {
      final kv = AppDbScheduleStore();
      await kv.put('lms_school', 'value', {'school': school});
      await kv.put('lms_curriculum', 'value', {'curriculum': curriculum});
    } catch (_) {/* best-effort local cache */}
    await _repository.setSchool(school, curriculum);
  }
}

/// Access Control Matrix source over the subscription state subscriptions_sdk
/// caches in the shared AppDatabase KV store ('user_subscriptions' row per
/// user: active flag + expiryDate). Offline-friendly by construction — it
/// reads the last-known-good cache, never the network.
class KvAccessStatusSource implements AccessStatusSource {
  @override
  Future<AccessStatus> current() async {
    final user = LocalStorage.getUser();
    // A partner login is reporting-only regardless of any subscription row.
    if (user?.role == 'partner') return AccessStatus.partner;
    // A demo session has no backend subscription row, so treat the student
    // as fully subscribed — every subscription gate (library recordings,
    // live lessons, skills) drops app-wide. Read per call, so a marked
    // account signing in after boot is answered on the very next read.
    if (DemoSession.demoActive) {
      return const AccessStatus(subscription: SubscriptionState.active);
    }
    final userId = user?.id?.toString();
    if (userId == null || userId.isEmpty) return AccessStatus.guest;
    final row = await AppDatabase().getItem('user_subscriptions', userId);
    if (row == null) return AccessStatus.guest;
    final active = row['active'] == true;
    final expiryRaw = row['expiryDate'];
    final expiry =
        expiryRaw is String ? DateTime.tryParse(expiryRaw) : null;
    final unexpired = expiry == null || expiry.isAfter(DateTime.now());
    return AccessStatus(
      subscription: (active && unexpired)
          ? SubscriptionState.active
          : SubscriptionState.lapsed,
      hasPartner: await hasAccountabilityPartner(userId),
    );
  }
}

/// The host-resolved [LmsPlanSnapshot] behind the profile header's plan
/// row: the subscription state subscriptions_sdk caches in the shared
/// 'user_subscriptions' KV row (title + active + expiryDate +
/// allowedSubjects) — the same offline-friendly last-known-good read as
/// [KvAccessStatusSource], never the network, and never a
/// subscriptions_sdk import (ADR-005: lms-side code only reads the shared
/// KV). Demo composes the same cast as /my-plan: the Full Access plan
/// [DemoLessonPlans] sells, active per [_DemoEntitlementsSource]'s
/// summary, its monthly renewal running to the first of next month (the
/// open demo coverage stretch starts on a 1st).
Future<LmsPlanSnapshot?> _studentPlanSnapshot() async {
  if (DemoSession.demoActive) {
    final plans = await DemoLessonPlans().getPlans();
    final summary = await _DemoEntitlementsSource().summary();
    final now = DateTime.now();
    return LmsPlanSnapshot(
      title: plans.first.title,
      active: summary.active,
      expiresAt: DateTime(now.year, now.month + 1, 1),
    );
  }
  final userId = LocalStorage.getUser()?.id?.toString();
  if (userId == null || userId.isEmpty) return null;
  final row = await AppDatabase().getItem('user_subscriptions', userId);
  if (row == null) return null;
  final title = row['title'];
  final expiryRaw = row['expiryDate'];
  final subjectsRaw = row['allowedSubjects'];
  var subjects = const <String>[];
  if (subjectsRaw is String && subjectsRaw.isNotEmpty) {
    try {
      final decoded = jsonDecode(subjectsRaw);
      if (decoded is List) {
        subjects = [
          for (final s in decoded)
            if (s != null) '$s',
        ];
      }
    } catch (_) {/* tolerate a malformed cached list */}
  }
  return LmsPlanSnapshot(
    title:
        title is String && title.trim().isNotEmpty ? title.trim() : null,
    active: row['active'] == true,
    expiresAt: expiryRaw is String ? DateTime.tryParse(expiryRaw) : null,
    allowedSubjects: subjects,
  );
}

/// Whether the student has an active accountability partner link
/// (rlms.api.partner.my_status) — offline-friendly by the same last-known-
/// good pattern as the subscription row: refresh over the network when
/// reachable, cache the result into the same 'user_subscriptions' KV row,
/// fall back to the cached value (default false) when offline.
Future<bool> hasAccountabilityPartner(String userId) async {
  final db = AppDatabase();
  try {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<HttpService>()) throw StateError('offline');
    final res = await getIt.get<HttpService>().client(requireAuth: true).post(
          _kGatewayPath,
          data: {'cmd': 'api.lms.partner_my_status'},
        );
    final message = res.data is Map ? res.data['message'] : res.data;
    final hasPartner = message is Map && message['has_partner'] == true;
    final row = await db.getItem('user_subscriptions', userId) ?? {};
    await db.putItem('user_subscriptions', userId, {
      ...row,
      'hasPartner': hasPartner,
    });
    return hasPartner;
  } catch (e) {
    debugPrint('==> hasAccountabilityPartner: using cached value ($e)');
    final row = await db.getItem('user_subscriptions', userId);
    return row?['hasPartner'] == true;
  }
}

/// The student's own grade, last-known-good (student-grade brief): refresh
/// from rlms.api.student.my_grade when reachable, cache into the same
/// 'user_subscriptions' KV row the subscription/partner state rides, fall
/// back to the cached value (null = never captured) when offline. This is
/// the single host-side grade source the catalog filter and Holiday
/// Programme wiring read — lms_sdk models never carry it.
Future<int?> studentGrade() async {
  final userId = LocalStorage.getUser()?.id?.toString();
  if (userId == null || userId.isEmpty) {
    // Demo runs logged-out; the demo repository reads the onboarding KV
    // grade directly, so the grade badge/filtering still work.
    if (!DemoSession.demoActive) return null;
    try {
      final getIt = GetIt.instance;
      if (!getIt.isRegistered<LmsRepository>()) {
        LmsSdkDependencies.register(getIt);
      }
      return (await getIt.get<LmsRepository>().myGrade()).grade;
    } catch (_) {
      return null;
    }
  }
  final db = AppDatabase();
  try {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<LmsRepository>()) {
      LmsSdkDependencies.register(getIt);
    }
    final status = await getIt.get<LmsRepository>().myGrade();
    await _cacheStudentGrade(userId, status.grade);
    return status.grade;
  } catch (e) {
    debugPrint('==> studentGrade: using cached value ($e)');
    final row = await db.getItem('user_subscriptions', userId);
    return (row?['grade'] as num?)?.toInt();
  }
}

Future<void> _cacheStudentGrade(String userId, int? grade) async {
  try {
    final db = AppDatabase();
    final row = await db.getItem('user_subscriptions', userId) ?? {};
    await db.putItem('user_subscriptions', userId, {...row, 'grade': grade});
  } catch (e) {
    debugPrint('==> studentGrade cache write failed: $e');
  }
}

/// replay_sdk's consumer-owned render slice, delegating to lms_sdk's player.
class ManimSinkAdapter implements ManimRenderSink {
  final WhiteboardPlayer player;

  ManimSinkAdapter(this.player);

  @override
  void pauseRendering() => player.pauseRendering();

  @override
  void resumeRendering() => player.resumeRendering();

  @override
  void clearCanvas() => player.clearCanvas();
}

/// lms_sdk's consumer-owned playback slice, implemented over replay_sdk.
///
/// Translates replay's manifest track events (schema per
/// docs/supacharge-product.md: profile / subtopic_start / subtopic_end /
/// stretch_break / break_start / signoff) into lms_sdk's typed
/// [LessonPlaybackEvent] vocabulary.
class ReplayLessonEngine implements LessonPlaybackEngine {
  final WhiteboardPlayer player;
  final _events = StreamController<LessonPlaybackEvent>.broadcast();

  AudioSync? _audioSync;
  StreamSubscription<TrackEvent>? _trackSub;
  String? _sessionId;

  /// Raw manifest JSON, kept alongside the parsed model so subtopic_end
  /// events whose `exercise` lists question IDs can be resolved against a
  /// manifest-level `questions` bank when the content pipeline ships one.
  Map<String, dynamic>? _rawManifestJson;

  /// Whiteboard animation feed: the session's animations.json primitives,
  /// scheduled against the real audio clock. replay_sdk's ManimRenderSink
  /// deliberately carries only pause/resume/clear — primitive scheduling is
  /// host glue (ADR-005: replay_sdk cannot know lms_sdk's ManimPrimitive),
  /// so the engine keeps its own handle on the audio source and feeds
  /// [WhiteboardPlayer.renderPrimitive] with catch-up semantics each tick.
  AudioplayersLessonAudioSource? _lessonAudio;

  /// Decision #39: the app, not the factory, picks `intro/new` vs
  /// `intro/returning` for the opening block — it is the side that knows
  /// the attendance history.
  final AssistantIntroSelector _introSelector = AssistantIntroSelector();

  /// Bundle key -> spilled temp file for the standing clips already
  /// resolved this session (see [_loadStandingClipPath]).
  final Map<String, String> _clipPathCache = {};

  /// The host's opening beat, once an `assistant_opening` has fired. A
  /// `handover` that states its position as `after: "assistant_opening"`
  /// (factory #133) waits on this instead of firing at its own `time: 0`,
  /// which is what stops decision #39's opening block ending in the same
  /// tick it began. Null until an opening arrives — a manifest with no
  /// host, or a mid-session join past t=0 — and a handover then fires
  /// straight away, exactly as it does today.
  Future<bool>? _openingBeat;

  Timer? _animTicker;
  List<ManimPrimitive> _animPrimitives = const [];
  bool _hasClearEvents = false;
  bool _hasCameraEvents = false;
  int _nextAnimIndex = 0;

  /// True only for the engine instance that claimed this session in
  /// [ActiveSessionRegistry] — a duplicate engine (stacked route) must not
  /// release a claim it never owned when its route pops.
  bool _ownsSession = false;

  Timer? _netWatch;
  bool _online = true;

  // Telemetry state (base_sdk TelemetryClient): each failure class logs
  // once per session at the transition where it is already detected.
  bool _animStallLogged = false;
  int _stallTicks = 0;
  Timer? _pauseWatchdog;

  /// Audio time at which the second-part tutor "enters the room" — one
  /// minute before the Mandy bridge, computed from the manifest (they join
  /// near the END of part one and stay silent until their part).
  double? _tutor2JoinTime;
  bool _tutor2Announced = false;

  ReplayLessonEngine({required this.player});

  @override
  Future<LessonReadiness> prepare(String sessionId) async {
    _sessionId = sessionId;
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<SessionGatekeeper>()) {
      ReplaySdkDependencies.register(getIt);
    }
    final readiness =
        await getIt.get<SessionGatekeeper>().verifySessionReady(sessionId);
    if (!readiness.isReady) {
      // Check 5: gatekeeper verification failure (missing/corrupt
      // manifest, audio or animations file) at session start.
      unawaited(TelemetryClient.I.logError(
        type: 'session_assets_missing',
        sessionId: sessionId,
        context: {'missing': readiness.missingDescription},
      ));
    }
    return LessonReadiness(
      isReady: readiness.isReady,
      missingDescription: readiness.missingDescription,
    );
  }

  Future<String?> _loadAudioPath() async {
    final sessionId = _sessionId;
    if (sessionId == null) return null;
    try {
      final assetStore = GetIt.instance.get<AssetStore>();
      final root = await assetStore.assetsRoot();
      return assetStore.audioPath(root, sessionId);
    } catch (e) {
      debugPrint('==> ReplayLessonEngine: audio path lookup failed: $e');
      return null;
    }
  }

  /// Local file for a standing clip's recorded audio, or null when there
  /// is none to play.
  ///
  /// Standing clips are APP-BUNDLED team assets (`assets/team/...`,
  /// vendored from the agent repo's `lms/team/`), not per-session assets,
  /// so they resolve out of the asset bundle rather than the AssetStore.
  /// [LessonAudioSource.load] wants a file path, so the bundled bytes are
  /// spilled to a temp file once per clip and reused after.
  ///
  /// Null is the ORDINARY answer today: the manifest's clip table ships
  /// text-first and the one-time standing-clip recording session is still
  /// blocked on the voice-engine decision, so most clips name a script and
  /// no audio. AudioSync skips the beat on a null.
  Future<String?> _loadStandingClipPath(StandingClip clip) async {
    final audio = clip.audio;
    if (audio == null || audio.isEmpty) return null;
    final key = 'assets/team/$audio';
    final cached = _clipPathCache[key];
    if (cached != null) return cached;
    try {
      final bytes = await rootBundle.load(key);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}'
          '${key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}');
      if (!await file.exists()) {
        await file.writeAsBytes(bytes.buffer
            .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      }
      _clipPathCache[key] = file.path;
      return file.path;
    } catch (e) {
      // A named-but-unbundled clip is expected while the recordings do not
      // exist — a debug line, not telemetry, and never a thrown beat.
      debugPrint('==> ReplayLessonEngine: standing clip $key unavailable: $e');
      return null;
    }
  }


  /// Fires one standing-clip beat, if there is anything to fire. A null or
  /// empty ref, no AudioSync, or a ref the manifest cannot resolve to audio
  /// all mean the same thing: skip the beat and leave playback alone.
  void _playStandingClip(String? ref) {
    if (ref == null || ref.isEmpty) return;
    final sync = _audioSync;
    if (sync == null) return;
    unawaited(sync.playStandingClip(ref).catchError((Object e) {
      debugPrint('==> ReplayLessonEngine: standing clip $ref failed: $e');
      return false;
    }));
  }

  /// A timekeeping call and, when the manifest assigned one, the tutor's
  /// answer to it — strictly in that order, the second only if the first
  /// actually played. A warning with no recorded audio takes its
  /// acknowledgement with it: a tutor answering a call nobody heard is
  /// worse than a silent call.
  Future<void> _playInterjection(String? clip, String? ack) async {
    if (clip == null || clip.isEmpty) return;
    final sync = _audioSync;
    if (sync == null) return;
    final played = await sync.playStandingClip(clip).catchError((Object e) {
      debugPrint('==> ReplayLessonEngine: interjection $clip failed: $e');
      return false;
    });
    if (!played || ack == null || ack.isEmpty) return;
    _playStandingClip(ack);
  }

  /// The host's opening block. Returns the beat, so a `handover` that says
  /// it comes after the opening can wait on it.
  ///
  /// The queue slot is claimed SYNCHRONOUSLY, with the ref still being
  /// resolved: the pick costs an attendance-ledger read, and the tutor's
  /// greeting sits on the same `time: 0` and has its ref in hand, so an
  /// opening that waited for its pick before queueing would be greeted
  /// over. AudioSync bounds the wait like any other beat.
  Future<bool> _playOpeningBeat(Map<String, String> variants) {
    final sync = _audioSync;
    if (sync == null || variants.isEmpty) return Future<bool>.value(false);
    return sync
        .playStandingClip(_openingClipRef(variants))
        .catchError((Object e) {
      debugPrint('==> ReplayLessonEngine: opening clip failed: $e');
      return false;
    });
  }

  /// The app picks `new` vs `returning` off the on-device attendance
  /// ledger (decision #39). Falls back to `new` when the event offers only
  /// one — a first-time welcome never mis-greets, a mistaken "welcome
  /// back" would.
  Future<String?> _openingClipRef(Map<String, String> variants) async {
    final sessionId = _sessionId;
    var key = 'new';
    if (sessionId != null) {
      try {
        final variant = await _introSelector.variantForSession(sessionId);
        key = variant == IntroVariant.returning ? 'returning' : 'new';
      } catch (e) {
        debugPrint('==> ReplayLessonEngine: intro variant lookup failed: $e');
      }
    }
    return variants[key] ?? variants['new'] ?? variants.values.first;
  }

  /// Holds [event] back until [beat] is done, then emits it — the ordering
  /// a track event states with `after` instead of with a time.
  Future<void> _emitAfter(Future<bool> beat, LessonPlaybackEvent event) async {
    try {
      await beat;
    } catch (e) {
      debugPrint('==> ReplayLessonEngine: waiting on the opening beat '
          'failed: $e');
    }
    _emit(event);
  }

  Future<ReplayManifest?> _loadManifest() async {
    final sessionId = _sessionId;
    if (sessionId == null) return null;
    try {
      final assetStore = GetIt.instance.get<AssetStore>();
      final root = await assetStore.assetsRoot();
      final raw =
          await File(assetStore.manifestPath(root, sessionId)).readAsString();
      _rawManifestJson = jsonDecode(raw) as Map<String, dynamic>;
      final parsed = ManifestParser().parse(raw);
      // Second-part tutor enters near the END of part one: a minute before
      // the Mandy bridge (silent until their part — the notifier handles
      // speaking attribution).
      final tracks = (_rawManifestJson?['tracks'] as List?) ?? const [];
      for (final t in tracks) {
        if (t is Map &&
            (t['type'] == 'break_start' || t['type'] == 'stretch_break')) {
          final at = (t['time'] as num?)?.toDouble();
          if (at != null) {
            _tutor2JoinTime = (at - 60).clamp(0, double.infinity);
          }
          break;
        }
      }
      return parsed;
    } catch (e) {
      debugPrint('==> ReplayLessonEngine: manifest load failed: $e');
      // Check 6: a manifest failing real parsing/reading at load time
      // should be impossible post-CI-gate — log it when it happens anyway.
      unawaited(TelemetryClient.I.logError(
        type: 'manifest_parse_failed',
        sessionId: sessionId,
        context: {'error': e.toString()},
      ));
      return null;
    }
  }

  @override
  Future<void> start() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    // Idempotence + duplicate guard. A second start() on this instance, or
    // a stacked duplicate of the same session (double-tapped join button),
    // must not spin up another audio clock: concurrent AudioSyncs all
    // stomp the one shared WhiteboardPlayer canvas and double the audio.
    if (_audioSync != null) return;
    if (ActiveSessionRegistry.isActive(sessionId)) {
      debugPrint('==> ReplayLessonEngine: $sessionId is already playing — '
          'refusing duplicate start.');
      // Check 4: the triple-tap stacked-session bug's guard actually
      // firing — recurrence stays visible without catching it live.
      unawaited(TelemetryClient.I.logError(
        type: 'session_duplicate_start',
        sessionId: sessionId,
        context: {'guard': 'ActiveSessionRegistry'},
      ));
      return;
    }
    _ownsSession = true;
    ActiveSessionRegistry.markActive(sessionId);
    // The player is a DI singleton — wipe whatever a previous session left
    // on the board before this one draws.
    player.clearCanvas();
    final getIt = GetIt.instance;
    final lessonAudio = AudioplayersLessonAudioSource();
    _lessonAudio = lessonAudio;
    // Second audio channel for the standing clips the framing track events
    // name (decisions #7/#9/#38/#39/#40) — the host's opening/handover/
    // timekeeping/signoff set and the tutor's greeting/signoff/ack. Kept
    // apart from the lesson source because a clip plays OVER the lesson
    // track, ducking it; AudioSync owns the duck-and-play and disposes it.
    final clipAudio = AudioplayersLessonAudioSource();
    _audioSync = AudioSync(
      manimPlayer: ManimSinkAdapter(player),
      sessionId: sessionId,
      // A demo session runs the live clock locally (no server round-trip);
      // a real session asks the backend where the class is and falls back
      // to the local session clock when unreachable.
      client: !DemoSession.demoActive && getIt.isRegistered<HttpService>()
          ? getIt.get<HttpService>().client(requireAuth: true)
          : null,
      manifestLoader: _loadManifest,
      audioSource: lessonAudio,
      audioPathLoader: _loadAudioPath,
      // Standing-clip channel. The clips are app-bundled team assets, not
      // session assets, so they resolve out of the asset bundle rather
      // than the AssetStore — and today they mostly do not resolve at all
      // (the recording session is still blocked on the voice-engine call),
      // which AudioSync treats as a skipped beat.
      clipSource: clipAudio,
      clipPathLoader: _loadStandingClipPath,
      // Offline/rejoin session clock: elapsed since the persisted session
      // start. A student who kills and reopens the app lands exactly where
      // the class is — never back at zero.
      fallbackTimestamp: _localSessionClock,
      // Drift-correction jump (>500ms visual lag) rebuilds the board via
      // the same instant fast-forward path late join and rejoin use,
      // instead of AudioSync's bare canvas clear — no more blank board
      // after backgrounding and returning mid-lesson.
      onVisualJump: primeTo,
    );
    _trackSub = _audioSync!.trackEvents.listen(
      _onTrackEvent,
      onDone: () => _emit(
          const LessonPlaybackEvent(LessonPlaybackEventType.completed)),
    );
    await _loadAnimations();
    await _audioSync!.startSession();
    // Late join / re-entry: place everything already "written" this session
    // instantly, so playback resumes on a settled board instead of the
    // camera racing through past bands. No-op for a join at t=0.
    final joinAt = _lessonAudio?.positionSeconds ?? 0;
    if (joinAt > 1) primeTo(joinAt);
    _animTicker = Timer.periodic(
        const Duration(milliseconds: 100), (_) => _renderDueAnimations());
    // Live-ness watchdog, zero network traffic by design (the data-saving
    // posture forbids probe pings): interface presence only. A live
    // session holds while offline and re-syncs to the live position on
    // reconnect (AudioSync refetches the clock, local fallback included).
    _netWatch = Timer.periodic(const Duration(seconds: 5), (_) async {
      final up = await _hasNetwork();
      if (!up && _online) {
        _online = false;
        await _audioSync?.handleNetworkDrop();
        _emit(const LessonPlaybackEvent(
            LessonPlaybackEventType.connectionLost));
      } else if (up && !_online) {
        _online = true;
        await _audioSync?.handleReconnect();
        _emit(const LessonPlaybackEvent(
            LessonPlaybackEventType.connectionRestored));
      }
    });
  }

  /// Offline session clock, ENGINE-owned: the first actual join of an
  /// airing writes the start row (that join IS second zero); a rejoin
  /// within the airing returns the elapsed position; a row older than the
  /// lesson's audio duration means the airing finished — roll over to a
  /// fresh start. Runs inside AudioSync's timestamp resolution, after the
  /// manifest loaded (so the duration is known).
  Future<double?> _localSessionClock() async {
    final sessionId = _sessionId;
    if (sessionId == null) return null;
    try {
      final db = AppDatabase();
      final now = DateTime.now();
      final row = await db.getItem('live_session_starts', sessionId);
      final raw = row?['startedAt'];
      final startedAt = raw is String ? DateTime.tryParse(raw) : null;
      final duration =
          ((_rawManifestJson?['audio']?['duration_seconds'] as num?) ??
                  double.maxFinite)
              .toDouble();
      if (startedAt != null) {
        final elapsed =
            now.difference(startedAt).inMilliseconds / 1000.0;
        if (elapsed > 0 && elapsed < duration) return elapsed;
      }
      await db.putItem('live_session_starts', sessionId,
          {'startedAt': now.toIso8601String()});
      return 0.0;
    } catch (e) {
      debugPrint('==> ReplayLessonEngine: local session clock failed: $e');
      return null;
    }
  }

  static Future<bool> _hasNetwork() async {
    try {
      final interfaces = await NetworkInterface.list();
      return interfaces
          .any((i) => i.addresses.any((a) => !a.isLoopback));
    } catch (_) {
      return true; // can't tell — don't disrupt the lesson
    }
  }

  Future<void> _loadAnimations() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    try {
      final assetStore = GetIt.instance.get<AssetStore>();
      final root = await assetStore.assetsRoot();
      final raw = await File(assetStore.animationPath(root, sessionId))
          .readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _animPrimitives = (decoded['primitives'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ManimPrimitive.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => _primTime(a).compareTo(_primTime(b)));
      _nextAnimIndex = 0;
      // Band-layout content steers the whiteboard camera itself
      // (camera_move/band_start — replaysdk-spec §4) and clear-vocabulary
      // content erases itself; only legacy add-only content (neither) gets
      // the subtopic-boundary wipe fallback in _onTrackEvent.
      _hasClearEvents = _animPrimitives.any((p) => p.isRemovalEvent);
      _hasCameraEvents = _animPrimitives.any((p) => p.isCameraEvent);
      _auditBandContract();
    } catch (e) {
      // A session with no/broken animations still plays audio + track
      // events; the whiteboard just stays empty (same posture as the
      // manifest loader above).
      debugPrint('==> ReplayLessonEngine: animations load failed: $e');
      _animPrimitives = const [];
    }
  }

  /// Check 2 (ADR-009 camera/band contract): every content band above 0
  /// must be reachable by a camera event, and every camera event must have
  /// a resolvable target. One audit at load time — no polling.
  void _auditBandContract() {
    if (!_hasCameraEvents) return; // legacy content, contract not in play
    final contentBands = <int>{};
    final cameraBands = <int>{};
    final malformed = <double>[];
    for (final p in _animPrimitives) {
      if (p.isCameraEvent) {
        final target = p.rawData['target'];
        final band = p.rawData['band'];
        if (target is Map && target['y'] is num) {
          // Targets sit a sliver above the band start (y = k - 0.04).
          cameraBands.add((target['y'] as num).ceil());
        } else if (band is num) {
          cameraBands.add(band.toInt());
        } else {
          malformed.add(_primTime(p));
        }
      } else if (!p.isRemovalEvent) {
        contentBands.add(p.normalizedY.floor());
      }
    }
    final unreachable = contentBands
        .where((b) => b > 0 && !cameraBands.contains(b))
        .toList();
    if (unreachable.isNotEmpty || malformed.isNotEmpty) {
      unawaited(TelemetryClient.I.logError(
        type: 'band_contract_mismatch',
        sessionId: _sessionId,
        context: {
          'content_bands': contentBands.toList()..sort(),
          'camera_bands': cameraBands.toList()..sort(),
          'unreachable_bands': unreachable,
          'malformed_camera_events_at_s': malformed,
        },
      ));
    }
  }

  static double _primTime(ManimPrimitive p) =>
      ((p.rawData['time'] as num?) ?? 0).toDouble();

  /// Renders every primitive due at the current audio position, exactly
  /// once, in order — the same catch-up semantics AudioSync uses for track
  /// events, so a seek or a slow tick can never skip a primitive. Waits for
  /// the whiteboard's first layout ([WhiteboardPlayer.isReady]) and holds while
  /// paused (renderPrimitive drops primitives while [WhiteboardPlayer.isPaused]).
  void _renderDueAnimations() {
    _checkAnimationStall();
    // Second-tutor entrance rides the existing tick (no new polling).
    final joinAt = _tutor2JoinTime;
    if (joinAt != null &&
        !_tutor2Announced &&
        (_lessonAudio?.positionSeconds ?? 0) >= joinAt) {
      _tutor2Announced = true;
      _emit(const LessonPlaybackEvent(
          LessonPlaybackEventType.secondTutorJoined));
    }
    if (_nextAnimIndex >= _animPrimitives.length) return;
    if (!player.isReady || player.isPaused) return;
    // Rendered 300ms behind the audio clock, deliberately: boundary track
    // events (the exercise-moment pause on subtopic_end) reach the notifier
    // through an async stream, and a camera_move sharing the boundary's
    // timestamp can otherwise race ahead of the pause — panning to the
    // empty next band right as the screen freezes for the quick check. The
    // lag guarantees the pause always lands first; 300ms is imperceptible
    // next to the spec's own drift tolerances.
    final pos = (_lessonAudio?.positionSeconds ?? 0) - 0.3;
    while (_nextAnimIndex < _animPrimitives.length &&
        _primTime(_animPrimitives[_nextAnimIndex]) <= pos) {
      final prim = _animPrimitives[_nextAnimIndex];
      debugPrint('==> anim render t=${_primTime(prim)} '
          '(${prim.primitiveType}) audio=${pos.toStringAsFixed(2)}');
      player.renderPrimitive(prim);
      _nextAnimIndex++;
    }
  }

  /// Fast-forwards the board to [toSeconds] with NO visible animation —
  /// every past primitive placed and the camera parked on its final band.
  /// Called once behind the recording gate (which is exactly the beat that
  /// buys the time), so a late join or re-entry opens on a settled board
  /// instead of watching the camera race through the lesson's history.
  /// Rejoin at the live position after time away (backgrounded/screen
  /// off): jump the clock to where the class is now, place everything
  /// written while away with no animation, then resume playback.
  @override
  void resumeAtLivePosition() {
    final sync = _audioSync;
    if (sync == null) return;
    // handleReconnect already means "rejoin where the class is now": it
    // refetches the session position (falling back to the local wall-clock
    // when offline), seeks there and resumes.
    unawaited(sync.handleReconnect().then((_) {
      final target = _lessonAudio?.positionSeconds ?? 0;
      primeTo(target);
      debugPrint('==> ReplayLessonEngine: rejoined live at '
          '${target.toStringAsFixed(1)}s');
    }).catchError((Object e) {
      debugPrint('==> ReplayLessonEngine: rejoin failed: $e');
    }));
  }

  @override
  void primeTo(double toSeconds) {
    if (!player.isReady) return;
    var placed = 0;
    while (_nextAnimIndex < _animPrimitives.length &&
        _primTime(_animPrimitives[_nextAnimIndex]) <= toSeconds) {
      player.renderPrimitiveInstant(_animPrimitives[_nextAnimIndex]);
      _nextAnimIndex++;
      placed++;
    }
    debugPrint('==> ReplayLessonEngine: primed board to '
        '${toSeconds.toStringAsFixed(1)}s ($placed primitives, no animation)');
  }

  /// Check 1: tutor audio is advancing but renderable animation events are
  /// sitting overdue and nothing is being consumed — the silent-whiteboard
  /// class ("nothing ever fed animations.json into WhiteboardPlayer", or a
  /// renderer stuck paused by drift). A 5s-overdue backlog must persist
  /// for ~3s of ticks before logging, so a late join's one-tick catch-up
  /// burst can't false-positive. Runs from the same 100ms tick.
  void _checkAnimationStall() {
    if (_animStallLogged || _animPrimitives.isEmpty) return;
    final audioPos = _lessonAudio?.positionSeconds ?? 0;
    final overdue = _nextAnimIndex < _animPrimitives.length &&
        _primTime(_animPrimitives[_nextAnimIndex]) <= audioPos - 5.3;
    if (!overdue) {
      _stallTicks = 0;
      return;
    }
    if (++_stallTicks < 30) return;
    _animStallLogged = true;
    final lastRendered = _nextAnimIndex == 0
        ? null
        : _animPrimitives[_nextAnimIndex - 1];
    unawaited(TelemetryClient.I.logError(
      type: 'animation_stall',
      sessionId: _sessionId,
      context: {
        'audio_position_s': audioPos,
        'events_loaded': _animPrimitives.length,
        'events_rendered': _nextAnimIndex,
        'next_overdue_event_at_s':
            _primTime(_animPrimitives[_nextAnimIndex]),
        'last_rendered_event_at_s':
            lastRendered == null ? null : _primTime(lastRendered),
        'renderer_paused': player.isPaused,
      },
    ));
  }

  void _onTrackEvent(TrackEvent event) {
    debugPrint('==> ReplayLessonEngine: track ${event.type} '
        't=${event.time} audio=${_lessonAudio?.positionSeconds}');
    switch (event.type) {
      case 'assistant_opening':
        // Decision #39: the opening five minutes belong to the host —
        // greeting, introduction and handover, and the whiteboard stays
        // shut until the handover fires.
        final opening = LessonPlaybackEvent(
          LessonPlaybackEventType.assistantOpening,
          assistantId: manifestFramingAssistantId(event.rawData),
          clipVariants: manifestClipVariants(event.rawData),
        );
        _emit(opening);
        _openingBeat = _playOpeningBeat(opening.clipVariants);
      case 'handover':
        // The floor passes to the tutor — the event that ends the opening
        // block (it used to be a five-minute timer with nothing to gate on).
        final handover = LessonPlaybackEvent(
          LessonPlaybackEventType.handoverToTutor,
          assistantId: manifestFramingAssistantId(event.rawData),
          afterEvent: manifestEventAfter(event.rawData),
        );
        final openingBeat = _openingBeat;
        if (openingBeat != null && handoverWaitsForOpening(event.rawData)) {
          // Factory #133: the handover shares `time: 0` with the opening
          // and states its real position as a DEPENDENCY, because the
          // opening's length is an estimate until the clip is recorded.
          // Firing it at its stated time is what collapses #39's host
          // block to nothing, so it waits for the opening's beat instead.
          // Bounded twice over: AudioSync caps the beat, and the
          // notifier's five-minute intro window is the backstop.
          unawaited(_emitAfter(openingBeat, handover));
        } else {
          _emit(handover);
        }
      case 'assistant_interjection':
        // Decision #38: the host calls the time OVER the tutor. The clip
        // rides the second channel and ducks the lesson track, so the
        // tutor's audio was never cut for it; roughly one block in four
        // carries the tutor's acknowledgement after the five-minute call.
        final interjection = LessonPlaybackEvent(
          LessonPlaybackEventType.assistantInterjection,
          assistantId: manifestFramingAssistantId(event.rawData),
          interjectionKind:
              assistantInterjectionKind(event.rawData['kind']?.toString()),
          clipRef: event.rawData['clip']?.toString(),
          ackClipRef: event.rawData['ack_clip']?.toString(),
        );
        _emit(interjection);
        unawaited(
            _playInterjection(interjection.clipRef, interjection.ackClipRef));
      case 'assistant_signoff':
        final hostSignoff = LessonPlaybackEvent(
          LessonPlaybackEventType.assistantSignoff,
          assistantId: manifestFramingAssistantId(event.rawData),
          clipRef: event.rawData['clip']?.toString(),
        );
        _emit(hostSignoff);
        _playStandingClip(hostSignoff.clipRef);
      case 'recording_stopped':
        // Decision #40: the cut point. Office hours are live-only, so this
        // is the live students' heads-up about what is about to disappear.
        final cut = LessonPlaybackEvent(
          LessonPlaybackEventType.recordingStopped,
          assistantId: manifestFramingAssistantId(event.rawData),
          clipRef: event.rawData['clip']?.toString(),
        );
        _emit(cut);
        _playStandingClip(cut.clipRef);
      case 'profile':
        final profile = LessonPlaybackEvent(
          LessonPlaybackEventType.speakingStarted,
          clipRef: event.rawData['clip']?.toString(),
        );
        _emit(profile);
        // The tutor's assigned greeting from their standing pool — persona
        // only, and deliberately knowing nothing about today's topic
        // (decision #38's greeting-vs-intro split).
        _playStandingClip(profile.clipRef);
      case 'subtopic_start':
        // Renderer-side half of the pile-up fix, legacy content only:
        // band-layout content pans its camera to clean space and
        // clear-vocabulary content erases itself, but add-only content
        // (neither) gets its board wiped (fading, like a tutor erasing) at
        // each subtopic boundary.
        if (!_hasClearEvents && !_hasCameraEvents) {
          player.clearCanvas(fade: true);
        }
        _emit(const LessonPlaybackEvent(
            LessonPlaybackEventType.speakingStarted));
      case 'signoff':
        _emit(const LessonPlaybackEvent(
            LessonPlaybackEventType.speakingStarted));
        // §9: the signoff segment is the cross-promotion moment.
        final tutorSignoff = LessonPlaybackEvent(
          LessonPlaybackEventType.signoffReached,
          clipRef: event.rawData['clip']?.toString(),
        );
        _emit(tutorSignoff);
        // The tutor's assigned signoff from their standing pool.
        _playStandingClip(tutorSignoff.clipRef);
      case 'subtopic_end':
        _emit(const LessonPlaybackEvent(
            LessonPlaybackEventType.speakingStopped));
        _emit(LessonPlaybackEvent(
          LessonPlaybackEventType.subtopicBoundary,
          subtopicRef: event.rawData['ref']?.toString() ??
              event.rawData['qa_transcript_ref']?.toString(),
          mcqBatch: _resolveMcqBatch(event.rawData['exercise']),
        ));
      case 'stretch_break':
      case 'break_start':
        _emit(const LessonPlaybackEvent(
            LessonPlaybackEventType.speakingStopped));
        // The Mandy bridge between the session's two parts — the second
        // tutor's join moment on the attendee list, plus the break's
        // evergreen Q&A beats (2-4) the lesson screen puts on the board.
        // The subtopic ref and context transcript ride along for the
        // break-bridge Q&A lane (agentsdk-spec §4).
        final breakStart = LessonPlaybackEvent(
          LessonPlaybackEventType.breakStarted,
          subtopicRef: event.rawData['ref']?.toString(),
          contextTranscriptRef:
              event.rawData['context_transcript_ref']?.toString(),
          breakQuestions: _resolveBreakQuestions(event.rawData['questions']),
          breakSeconds:
              ((event.rawData['duration_seconds'] ?? 0) as num).toDouble(),
          assistantId: manifestBridgeAssistantId(event.rawData),
          clipVariants: manifestClipVariants(event.rawData),
        );
        _emit(breakStart);
        // The host's bridge line INTO the break. `out_of_break` belongs to
        // the far side of the swap, which no track event marks: the break
        // ends on the notifier's clock, so the notifier cues that one back
        // through [playStandingClip].
        _playStandingClip(breakStart.clipVariants['into_break']);
      default:
        // movement/action/animation events belong to the render pipeline,
        // not the lesson chrome — ignore here.
        break;
    }
  }

  /// `questions` on a break_start track: inline objects (question text +
  /// optional ask/answer seconds). Evergreen by contract — see
  /// [BreakQuestion]; capped at 4 so a break stays a break.
  List<BreakQuestion> _resolveBreakQuestions(dynamic raw) {
    if (raw is! List) return const [];
    final out = <BreakQuestion>[];
    for (final entry in raw) {
      if (entry is Map) {
        out.add(BreakQuestion.fromJson(Map<String, dynamic>.from(entry)));
      } else if (entry is String) {
        out.add(BreakQuestion(question: entry));
      }
      if (out.length == 4) break;
    }
    return out;
  }

  /// `exercise` entries are either inline question objects or question IDs
  /// pointing into the manifest-level `questions` bank. Unresolvable IDs are
  /// skipped (an empty batch simply means no exercise moment fires).
  List<McqQuestion> _resolveMcqBatch(dynamic exercise) {
    if (exercise is! List) return const [];
    final bank = _rawManifestJson?['questions'];
    final batch = <McqQuestion>[];
    for (final entry in exercise) {
      if (entry is Map) {
        batch.add(McqQuestion.fromJson(Map<String, dynamic>.from(entry)));
      } else if (entry is String && bank is Map && bank[entry] is Map) {
        batch.add(McqQuestion.fromJson(
            Map<String, dynamic>.from(bank[entry] as Map)
              ..putIfAbsent('id', () => entry)));
      } else {
        debugPrint('==> ReplayLessonEngine: unresolvable MCQ entry: $entry');
      }
    }
    return batch;
  }

  void _emit(LessonPlaybackEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  @override
  Stream<LessonPlaybackEvent> get events => _events.stream;

  // Exercise moments and buffering both route through here: setBuffering
  // pauses/resumes the real audio player, so the master clock (which reads
  // the audio position) freezes with it — paused time can never desync the
  // track events. The position logs are the verification trail: the resume
  // line must match the pause line exactly.
  @override
  void pause() {
    debugPrint('==> ReplayLessonEngine: pause '
        '@${_lessonAudio?.positionSeconds}s');
    _audioSync?.setBuffering(true);
    // Check 3: an exercise pause that never resumes (audio stuck paused).
    // Three questions x 30s + reveal beats stays well under 5 minutes.
    final pausedAt = _lessonAudio?.positionSeconds;
    _pauseWatchdog?.cancel();
    _pauseWatchdog = Timer(const Duration(minutes: 5), () {
      unawaited(TelemetryClient.I.logError(
        type: 'pause_never_resumed',
        sessionId: _sessionId,
        context: {
          'paused_at_audio_s': pausedAt,
          'stuck_for_s': 300,
        },
      ));
    });
  }

  /// Beats the LESSON STATE cues rather than a track event: `out_of_break`,
  /// which belongs to whichever of the break's three end paths actually
  /// closed the break — only the notifier knows which of them did.
  @override
  void playStandingClip(String ref) => _playStandingClip(ref);

  @override
  void resume() {
    debugPrint('==> ReplayLessonEngine: resume '
        '@${_lessonAudio?.positionSeconds}s');
    _pauseWatchdog?.cancel();
    _pauseWatchdog = null;
    _audioSync?.setBuffering(false);
  }

  @override
  void dispose() {
    _animTicker?.cancel();
    _netWatch?.cancel();
    _pauseWatchdog?.cancel();
    _trackSub?.cancel();
    _audioSync?.dispose();
    final sessionId = _sessionId;
    if (sessionId != null && _ownsSession) {
      ActiveSessionRegistry.release(sessionId);
    }
    _events.close();
  }
}

/// DEMO ONLY — a stand-in for the session host's private lane.
///
/// Demo runs with no assistant stack registered, which left the composer
/// permanently showing "Chat disabled" and made the in-session chat
/// impossible to review. This gives a live demo session a host that
/// answers, so the bar's chat behaviour can actually be judged.
///
/// It speaks ONLY for the host: the notifier already appends the student's
/// own message when it is sent, so echoing it back here would double it.
///
/// The replies below are demo fixtures, not product copy — they are
/// deliberately not routed through TrKeys because the real assistant
/// service supplies its own text and these strings never ship to a
/// student on a real account.
class _DemoAssistantBridge implements LessonAssistantBridge {
  final String hostName;
  final StreamController<LessonChatMessage> _out =
      StreamController<LessonChatMessage>.broadcast();

  _DemoAssistantBridge(this.hostName);

  @override
  bool get isAvailable => true;

  @override
  Stream<LessonChatMessage> get messages => _out.stream;

  @override
  Future<void> sendMessage(String text) async {
    // A beat before replying: an instant answer reads as a canned echo and
    // tells you nothing about how the arriving-message case looks.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (_out.isClosed) return;
    _out.add(LessonChatMessage(
      text: reply(text),
      fromStudent: false,
      at: DateTime.now(),
    ));
  }

  /// Shared with the demo break bridge's backend-fallback stand-in, so a
  /// break question and a chat message get the same demo host voice.
  static String reply(String text) {
    final t = text.toLowerCase();
    if (t.contains('?')) {
      return "Good question — hold that thought and I'll pick it up at the "
          "break so the whole class hears it.";
    }
    if (t.contains('lost') || t.contains('confus') || t.contains('slow')) {
      return "You're not behind — that step trips most people. Watch the "
          "next worked example and tell me if it still doesn't land.";
    }
    return "Got it, thanks. I'm here the whole session if you need me.";
  }

  void close() => _out.close();
}

/// This-session manifest titles for the office-hours weak-concepts source:
/// subtopic ref -> track title, from the session's own manifest. Host-owned
/// because only the host reads session manifests (same AssetStore pattern
/// as [_LessonRouteViewState._manifestSubject]). This is the surviving half
/// of the PR #85 `ManifestWeakConcepts` stand-in — titles still win over
/// the server's humanized labels for display.
Future<Map<String, String>> _manifestSubtopicTitles(String sessionId) async {
  var titles = const <String, String>{};
  try {
    final assetStore = GetIt.instance.get<AssetStore>();
    final root = await assetStore.assetsRoot();
    final path = assetStore.manifestPath(root, sessionId);
    if (await assetStore.isAssetPresent(path)) {
      final json =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      final tracks = json['tracks'];
      if (tracks is List) {
        titles = {
          for (final t in tracks)
            if (t is Map &&
                t['type'] == 'subtopic_start' &&
                t['ref'] != null &&
                '${t['title'] ?? ''}'.trim().isNotEmpty)
              t['ref'].toString(): '${t['title']}'.trim(),
        };
      }
    }
  } catch (e) {
    debugPrint('==> weak concepts: manifest read failed: $e');
  }
  return titles;
}

/// Cross-session weak-concept aggregates via users_sdk
/// (`paas.api.user.get_weak_concepts`, Users PR #17), mapped onto lms_sdk's
/// consumer-owned seam (ADR-005: the host adapts, the SDKs never meet).
///
/// `limit: 5` on purpose: the office-hours greeting and the follow-up
/// review task join these names into one sentence — the five weakest
/// (server sorts by score desc) is personal without becoming a wall of
/// text. Failures return [WeakConceptsFetch.failure] with the admin detail
/// (for telemetry ONLY — [CrossSessionWeakConcepts] keeps students on the
/// friendly path, per decision #56 / the PR #99 error-surface rule).
Future<WeakConceptsFetch> _fetchWeakConceptAggregates() async {
  final result = await UserRepository().getWeakConcepts(limit: 5);
  return result.when(
    success: (data) => WeakConceptsFetch.success(
      sourceAvailable: data.sourceAvailable,
      concepts: [
        for (final c in data.concepts)
          ServerWeakConcept(ref: c.subtopicRef, label: c.label),
      ],
    ),
    failure: (error, statusCode) => WeakConceptsFetch.failure(
      diagnostic: error,
      statusCode: statusCode,
    ),
  );
}

/// DEMO ONLY — the break bridge's infrastructure stand-ins, mirroring
/// [_DemoAssistantBridge]'s role for the chat lane. Real builds get NO
/// break bridge (see [_LessonRouteViewState._buildDeps]): the on-device
/// vector cache and the backend synthesize endpoint don't exist yet, and
/// wiring canned answers into a real build would be exactly the ungated
/// simulation the app audit flags.
class _EmptyVectorCache implements VectorDatabase {
  // Honest empty cache: every lookup misses, so the bridge always falls
  // through to its backend fn (the demo reply below).
  @override
  Future<String?> searchSimilarity(String queryText, double threshold) async =>
      null;
}

/// Host route shell for [LessonPlayerPage] (lms_sdk-resident page).
///
/// The @RoutePage annotation must sit DIRECTLY above this class: Dart
/// attaches annotations to the next declaration even across doc comments,
/// and it once drifted onto [_DemoAssistantBridge] when that class was
/// inserted in between — auto_route then generated LessonRoute from the
/// wrong class and every LessonRoute(...) call site broke.
@RoutePage(name: 'LessonRoute')
class LessonRouteView extends StatefulWidget {
  final String sessionId;
  final String tutorName;

  /// The LMS `Course Lesson` id, when navigation comes from a course/lesson
  /// list rather than an already-known Replay Session id. When given,
  /// [LessonNotifier] resolves the real session via
  /// `rlms.api.course.get_lesson_session` before playback starts, and
  /// records progress/quiz results/watch time against it as the lesson
  /// plays. [sessionId] is still required as the pre-resolution fallback
  /// (and stays the only thing that matters for callers with no LMS catalog
  /// data, e.g. a direct session link).
  final String? lessonId;

  /// Free sample lesson from tutor discovery — bypasses the live-session
  /// access gate (samples ARE the funnel).
  final bool isSample;

  /// Library rewatch (§6): gates on libraryAttended so lapsed students keep
  /// what they earned.
  final bool isRecording;

  /// Leaving the session when it is NOT a pushed route — the schedule
  /// shell renders this view inside a plane (frame 52), where popping
  /// would take the schedule down with it. Null keeps the pop, which is
  /// what every routed entry wants.
  final VoidCallback? onLeave;

  const LessonRouteView({
    super.key,
    required this.sessionId,
    this.tutorName = 'Tutor',
    this.lessonId,
    this.isSample = false,
    this.isRecording = false,
    this.onLeave,
  });

  @override
  State<LessonRouteView> createState() => _LessonRouteViewState();
}

class _LessonRouteViewState extends State<LessonRouteView> {
  late final WhiteboardPlayer _player;

  /// Built once, only after the manifest's `second_tutor` has resolved —
  /// deps is the lesson provider's family key, so replacing it later would
  /// remount the page and restart the session.
  LessonScreenDeps? _deps;

  /// Demo-only stand-in for the host's private lane (see
  /// [_DemoAssistantBridge]). Held so it can be closed on the way out.
  _DemoAssistantBridge? _demoAssistant;

  @override
  void dispose() {
    _demoAssistant?.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<WhiteboardPlayer>()) {
      LmsSdkDependencies.register(getIt);
    }
    _player = getIt.get<WhiteboardPlayer>();
    unawaited(_prepareDeps());
  }

  /// The single tutor-id resolution rule, shared by BOTH tutor slots: the
  /// manifest-provided id wins; the display name is only a last-resort
  /// derivation when the manifest carries no id. Using the display name as
  /// the primary source (the old first-tutor bug) coupled the id to a
  /// factory-owned, renameable string — so renaming a tutor's display name
  /// silently broke id matching. Both slots now call this, so they resolve
  /// identically by construction.
  static String _resolveTutorId(String? manifestId, String displayName) =>
      (manifestId != null && manifestId.trim().isNotEmpty)
          ? manifestId.trim()
          : displayName.toLowerCase().replaceAll(' ', '_');

  /// The primary tutor's id, read from the manifest's `profile` track event
  /// (`tutor` slug) — the same manifest source the second tutor's id comes
  /// from (`second_tutor.id`). Null when the manifest is absent or carries
  /// no profile tutor, in which case [_resolveTutorId] falls back to the
  /// display name.
  Future<String?> _loadPrimaryTutorId() async {
    try {
      final assetStore = GetIt.instance.get<AssetStore>();
      final root = await assetStore.assetsRoot();
      final path = assetStore.manifestPath(root, widget.sessionId);
      if (!await assetStore.isAssetPresent(path)) return null;
      final json =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      final tracks = json['tracks'];
      if (tracks is List) {
        for (final t in tracks) {
          if (t is Map && t['type'] == 'profile' && t['tutor'] != null) {
            return t['tutor'].toString().trim();
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('==> primary tutor lookup failed: $e');
      return null;
    }
  }

  /// The paired tutor for a two-part session, read from the manifest's
  /// top-level `second_tutor` block. The pipeline emits snake_case
  /// (`display_name`); TutorPersona wants `displayName` — this is the only
  /// place that mapping happens, so a rename on either side breaks here
  /// loudly rather than silently rendering an unnamed tile.
  Future<TutorPersona?> _loadSecondTutor() async {
    try {
      final assetStore = GetIt.instance.get<AssetStore>();
      final root = await assetStore.assetsRoot();
      final path = assetStore.manifestPath(root, widget.sessionId);
      if (!await assetStore.isAssetPresent(path)) return null;
      final json =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      final block = json['second_tutor'];
      if (block is! Map) return null;
      final displayName = (block['display_name'] ?? '').toString().trim();
      final id = (block['id'] ?? '').toString().trim();
      if (displayName.isEmpty && id.isEmpty) return null;
      final resolved = _resolveTutorId(id, displayName);
      return TutorPersona(
        id: resolved,
        displayName: displayName.isNotEmpty ? displayName : id,
        // Demo: the bundled square render is built for exactly these
        // slots (speaker tile, chat header, attendee rows).
        avatarAsset: DemoSession.demoActive ? demoTutorAvatar(resolved) : null,
      );
    } catch (e) {
      debugPrint('==> second tutor lookup failed: $e');
      return null;
    }
  }

  Future<void> _prepareDeps() async {
    final secondTutor = await _loadSecondTutor();
    final primaryTutorId = await _loadPrimaryTutorId();
    // Which of the three session hosts this student gets is decided by
    // their grade (roster.json). Resolved here, host-side, because grade is
    // a host-owned value that lms_sdk models deliberately never carry.
    final grade = await studentGrade();
    if (!mounted) return;
    setState(() => _deps = _buildDeps(secondTutor, primaryTutorId, grade));
  }

  LessonScreenDeps _buildDeps(
      TutorPersona? secondTutor, String? primaryTutorId, int? grade) {
    final getIt = GetIt.instance;
    // LmsRepository/SubjectEntitlements are lms_sdk-owned (registered by
    // LmsSdkDependencies.register), not host adapters — register here if
    // whoever composed the app hasn't already.
    if (!getIt.isRegistered<LmsRepository>()) {
      LmsSdkDependencies.register(getIt);
    }
    final host = assistantPersonaForGrade(grade);
    final studentId = LocalStorage.getUser()?.id?.toString();
    return LessonScreenDeps(
      sessionId: widget.sessionId,
      // Name the host assigned to THIS student. Hard-coding one persona
      // told a Grade 10 student they were talking to the Grade 12 host.
      assistantPersona: host,
      lessonId: widget.lessonId,
      repository: getIt.get<LmsRepository>(),
      engine: ReplayLessonEngine(player: _player),
      secondTutor: secondTutor,
      // The real bridge is registered by the host app once the assistant
      // stack is configured; everything degrades gracefully when absent.
      // Demo has no such stack, so a LIVE demo session gets a stand-in and
      // the composer can actually be exercised. Recordings get nothing —
      // chat stays closed on a rewatch exactly as it does in production.
      assistant: getIt.isRegistered<LessonAssistantBridge>()
          ? getIt.get<LessonAssistantBridge>()
          : (DemoSession.demoActive && !widget.isRecording)
              ? (_demoAssistant ??= _DemoAssistantBridge(host.displayName))
              : null,
      tutor: TutorPersona(
        // id from the manifest (profile track's `tutor` slug), resolved the
        // SAME way as the second tutor's id — never derived from the
        // route-supplied display name, so a factory-side display-name rename
        // needs no code change here. displayName stays the route arg (the
        // primary tutor has no manifest display_name; the profile event
        // carries only the slug).
        id: _resolveTutorId(primaryTutorId, widget.tutorName),
        displayName: widget.tutorName,
        // Same square render the second tutor gets — the speaker tile and
        // the attendee rows are exactly what avatar_512 is built for.
        avatarAsset: DemoSession.demoActive
            ? demoTutorAvatar(_resolveTutorId(primaryTutorId, widget.tutorName))
            : null,
      ),
      onLiveJoinNotice: playRecordingNotice,
      accessSource: KvAccessStatusSource(),
      // The chat lane's plan gate (owner's rule 2026-08-14): a host-
      // registered adapter wins (same override convention as the office
      // hours SubscriptionStatusProvider); real builds otherwise read the
      // entitlement summary's assistant_chat flag (rlms my_entitlements,
      // resolved server-side from the student's governing LMS Plan).
      // FAIL-OPEN throughout — demo gets no gate at all.
      chatPlanGate: getIt.isRegistered<AssistantChatPlanGate>()
          ? getIt.get<AssistantChatPlanGate>()
          : DemoSession.demoActive
              ? null
              : EntitlementsAssistantChatGate(),
      // §7 leaderboard: the weekly badge reads the rlms league endpoints
      // (server-authoritative points/ranks); the overlay keeps the
      // student's own tally whenever the source answers null.
      leaderboard: HttpLeaderboardSource(),
      isSample: widget.isSample,
      isRecording: widget.isRecording,
      onCompleted: _recordInLibrary,
      crossTutorAlternate: _crossTutorAlternate,
      onCrossTutorRemind: (session) =>
          ProductivityStudyPlanner().scheduleSessionReminder(
        sessionId: session.sessionId,
        title:
            '${session.tutorName}: ${session.topic} (${session.subject})',
        startTime: session.startTime,
      ),
      // §5 profile ledgers ride the seams built for them: the student's own
      // reaction history and the per-session data-usage estimate.
      onReaction: (event) => ProfileStore()
          .recordReaction(event)
          .catchError((e) => debugPrint('==> reaction history: $e')),
      onDataUsage: (record) => ProfileStore()
          .recordDataUsage(record)
          .catchError((e) => debugPrint('==> data usage: $e')),
      // #15 presence-with-gaps: the watched seconds merge onto the local
      // attendance ledger row (the upsert keeps the better outcome and the
      // fuller watch time), so the progress view and partner report can
      // surface x/60 minutes. The same seconds also ride the backend
      // attendance event, synced from the notifier.
      onAttendanceWatch: (sessionId, secondsWatched) => ProfileStore()
          .recordAttendance(AttendanceRecord(
            sessionId: sessionId,
            at: DateTime.now(),
            outcome: AttendanceOutcome.attendedWithinGrace,
            secondsWatched: secondsWatched,
          ))
          .catchError((e) => debugPrint('==> attendance watch: $e')),
      onShowPlans: () =>
          context.router.push(TutorDiscoveryRoute()),
      // Decision #11: end-of-session next-lesson prompt, resolved from the
      // same schedule feed the §9 cross-promo uses. Server clock only.
      nextLessonPrompt: NextLessonPromptDeps(
        sessionId: widget.sessionId,
        upcoming: () => DemoSession.demoActive
            ? DemoScheduleSource().upcoming()
            : ReplayScheduleSource().upcoming(),
        resolveSubject: _manifestSubject,
        skills: DemoSession.demoActive
            ? DemoSkillLessonSource()
            : BackendSkillLessonSource(fallback: AssetSkillLessonSource()),
        // #11.3-4: inferred slot preference names the student's own time;
        // yes/no intents land through the shared KV stores (skip gate
        // untouched — a "no" here records intent only).
        slotPreference:
            KvSlotPreferenceStore(now: getIt.get<ServerClock>().now),
        recordIntent: (sessionId, willAttend) =>
            AttendanceIntentStore().record(sessionId, willAttend: willAttend),
        // #11.5: already-reviewed skills drop out of the study-ahead list.
        isSkillReviewed:
            KvSkillReviewLedger(now: getIt.get<ServerClock>().now).isReviewed,
        now: getIt.get<ServerClock>().now,
      ),
      studentProfileRef: studentId ?? '',
      // The break's Q&A lane (agentsdk-spec §4). Its two infrastructure
      // halves — the on-device vector cache and the backend synthesize
      // endpoint — don't exist yet, so REAL builds get no bridge and break
      // chat stays on the assistant lane; a LIVE demo session gets honest
      // stand-ins (empty cache + the same demo host voice as the chat
      // lane) so the flow can actually be exercised. Recordings never get
      // one: the break Q&A is a live beat.
      breakBridge: (DemoSession.demoActive && !widget.isRecording)
          ? BreakBridgeController(
              localCacheDb: _EmptyVectorCache(),
              backendSynthesizeFn: (profile, subtopicRef, question) async {
                // Same thinking-and-typing beat as the demo chat lane.
                await Future<void>.delayed(
                    const Duration(milliseconds: 900));
                return _DemoAssistantBridge.reply(question);
              },
            )
          : null,
      // Post-session Mandy office hours (agentsdk-spec §5; the notifier
      // enforces live-only — decision #40). Wired only when the host has
      // registered a SubscriptionStatusProvider (the controller gates the
      // feature on an active subscription, and deny-by-default needs a
      // real answer, not a stand-in) and the student is known.
      officeHoursBuilder: (studentId != null &&
              getIt.isRegistered<SubscriptionStatusProvider>())
          ? ({required onMessageReceived, required onSessionClosed}) =>
              OfficeHoursController(
                studentId: studentId,
                onMessageReceived: onMessageReceived,
                onSessionClosed: onSessionClosed,
                // Cross-session server aggregates first, this-session
                // manifest derivation as the fallback; manifest titles win
                // for display either way (see CrossSessionWeakConcepts).
                usersSdk: CrossSessionWeakConcepts(
                  fetchAggregates: _fetchWeakConceptAggregates,
                  loadSubtopicTitles: _manifestSubtopicTitles,
                ),
                subscriptionStatusProvider:
                    getIt.get<SubscriptionStatusProvider>(),
                createProductivityTask: _createOfficeHoursReviewTask,
                assistantDisplayName: host.displayName,
              )
          : null,
      // The blocked screen's pay-for-this-lesson CTA: the server catalog
      // decides whether it renders (an active, priced Per Lesson plan);
      // purchase runs the same student-vs-sponsor checkout as the plans
      // surfaces.
      plans: DemoSession.demoActive
          ? DemoLessonPlans()
          : SubscriptionsLessonPlansAdapter(),
      // #52 knowledge bites: resolved host-side (only the host can read
      // the session manifest and owns the KV store), offered by the
      // notifier at the end of playback, persisted only on accept.
      knowledgeBiteOffer: _resolveKnowledgeBiteOffer,
      onKnowledgeBiteAccepted: _persistAcceptedBite,
    );
  }

  /// Decision #11: the completed session's subject from the local manifest
  /// (same read [_crossTutorAlternate] does). Null degrades the prompt's
  /// same-subject-first resolution to earliest-eligible.
  Future<String?> _manifestSubject() async {
    try {
      final assetStore = GetIt.instance.get<AssetStore>();
      final root = await assetStore.assetsRoot();
      final path = assetStore.manifestPath(root, widget.sessionId);
      if (!await assetStore.isAssetPresent(path)) return null;
      final json = jsonDecode(await File(path).readAsString())
          as Map<String, dynamic>;
      final subject = (json['subject'] ?? '').toString();
      return subject.isEmpty ? null : subject;
    } catch (e) {
      debugPrint('==> next-lesson subject lookup failed: $e');
      return null;
    }
  }

  /// Office-hours follow-up: the "Review <weak concepts>" revision task
  /// lands in ProductivitySDK's todo store — the same store the study
  /// planner's session reminders ride ([ProductivityStudyPlanner]).
  void _createOfficeHoursReviewTask(String title, String desc) {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<prod.TodoRepositoryFacade>()) return;
    unawaited(() async {
      final repo = getIt.get<prod.TodoRepositoryFacade>();
      final todos = await repo.loadTodos();
      todos.add({
        'id': 'office-hours-review-${widget.sessionId}',
        'title': title,
        'description': desc,
        'source': 'lms_office_hours_review',
        'sessionId': widget.sessionId,
      });
      await repo.saveTodos(todos);
    }()
        .catchError(
            (Object e) => debugPrint('==> office-hours review task: $e')));
  }

  /// #52: the bite to offer when THIS playback completes, or null.
  ///
  /// JOIN-KEY DERIVATION (a documented, correctable choice): the bites
  /// index is keyed by the session-tree lesson slug
  /// (`session/{grade}/{term}/{topic}/{lesson-slug}` — decision log line
  /// ~1374), but no Dart model or manifest field carries that slug today.
  /// So the slug is RE-DERIVED the way the factory derives its directory
  /// names — [lessonSlugFromName] over the display names the manifest DOES
  /// carry — trying, in order: an explicit `lesson_slug` field (absent
  /// today; wins outright once the pipeline emits it), then the
  /// `subtopic`, then the `topic`. A candidate that misses the index
  /// simply yields no offer (the same non-forcing degrade as every skills
  /// surface); nothing here can error at the student.
  Future<KnowledgeBite?> _resolveKnowledgeBiteOffer() async {
    try {
      final assetStore = GetIt.instance.get<AssetStore>();
      final root = await assetStore.assetsRoot();
      final path = assetStore.manifestPath(root, widget.sessionId);
      if (!await assetStore.isAssetPresent(path)) return null;
      final json = jsonDecode(await File(path).readAsString())
          as Map<String, dynamic>;
      final candidates = <String>{
        (json['lesson_slug'] ?? '').toString(),
        lessonSlugFromName((json['subtopic'] ?? '').toString()),
        lessonSlugFromName((json['topic'] ?? '').toString()),
      }..removeWhere((s) => s.isEmpty);
      if (candidates.isEmpty) return null;
      final KnowledgeBiteSource source = DemoSession.demoActive
          ? DemoKnowledgeBiteSource()
          : BackendKnowledgeBiteSource(fallback: AssetKnowledgeBiteSource());
      final store = KnowledgeBiteStore();
      for (final slug in candidates) {
        final bites = await source.bitesFor(slug);
        if (bites.isEmpty) continue;
        // First candidate that resolves owns the decision: either the
        // deterministic offer, or "already accepted → nothing to offer".
        return KnowledgeBiteOfferPolicy.chooseOffer(
          bites: bites,
          alreadyAccepted: await store.isAccepted(slug),
          // Sitting-scoped decline memory lives in LessonNotifier, which
          // never calls this resolver after a decline.
          declinedThisSitting: false,
        );
      }
      return null;
    } catch (e) {
      debugPrint('==> knowledge-bite offer resolution failed: $e');
      return null;
    }
  }

  /// #52 acceptance: the ONLY write path for bites — fired exclusively by
  /// the student's explicit accept on the offer sheet. Persists the full
  /// bite content locally (offline-forever payoff), attached to this
  /// playback's session id — the same id [_recordInLibrary] stamps on the
  /// LibraryEntry, so the Library joins the two exactly. Local-only for
  /// now; backend acceptance sync is a recorded follow-up.
  Future<void> _persistAcceptedBite(KnowledgeBite bite) async {
    try {
      await KnowledgeBiteStore().accept(AcceptedKnowledgeBite(
        bite: bite,
        sessionId: widget.sessionId,
        lessonId: widget.lessonId,
        acceptedAt: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('==> knowledge-bite accept persist failed: $e');
    }
  }

/// §9: the other tutor's next session on this topic, resolved from the
  /// schedule feed against the local manifest's subject/topic/tutor.
  Future<ScheduledSession?> _crossTutorAlternate() async {
    try {
      final assetStore = GetIt.instance.get<AssetStore>();
      final root = await assetStore.assetsRoot();
      final path = assetStore.manifestPath(root, widget.sessionId);
      if (!await assetStore.isAssetPresent(path)) return null;
      final json = jsonDecode(await File(path).readAsString())
          as Map<String, dynamic>;
      final subject = (json['subject'] ?? '').toString();
      final topic = (json['topic'] ?? '').toString();
      if (topic.isEmpty) return null;
      final sessions = await ReplayScheduleSource().upcoming();
      return TopicLinkResolver.alternateFor(
        sessions,
        subject: subject,
        topic: topic,
        excludeTutor: widget.tutorName,
        after: DateTime.now(),
      );
    } catch (e) {
      debugPrint('==> cross-tutor alternate lookup failed: $e');
      return null;
    }
  }

  /// §6: a completed session lands in the student's library (recording
  /// unlocks the following day). Topic/subject come from the local manifest;
  /// the post-session comprehension score from the MCQ results.
  Future<void> _recordInLibrary(List<McqResult> results) async {
    try {
      String subject = '';
      String topic = widget.tutorName;
      try {
        final assetStore = GetIt.instance.get<AssetStore>();
        final root = await assetStore.assetsRoot();
        final path = assetStore.manifestPath(root, widget.sessionId);
        if (await assetStore.isAssetPresent(path)) {
          final json = jsonDecode(await File(path).readAsString())
              as Map<String, dynamic>;
          subject = (json['subject'] ?? '').toString();
          topic = (json['topic'] ?? topic).toString();
        }
      } catch (_) {}
      final answered =
          results.where((r) => r.outcome != McqOutcome.skipped).length;
      final skipped =
          results.where((r) => r.outcome == McqOutcome.skipped).length;
      final correct =
          results.where((r) => r.outcome == McqOutcome.correct).length;
      // §5 engagement aggregate (answered vs skipped) — same results, no
      // second tracking path.
      await ProfileStore()
          .recordEngagement(answered: answered, skipped: skipped);
      final attendedAt = DateTime.now();
      await LibraryStore().recordAttended(LibraryEntry(
        sessionId: widget.sessionId,
        lessonId: widget.lessonId,
        subject: subject,
        topic: topic,
        tutorName: widget.tutorName,
        attendedAt: attendedAt,
        recordingAvailableAt:
            LibraryEntry.defaultRecordingUnlock(attendedAt),
        postScore: answered == 0 ? null : (correct * 100 ~/ answered),
      ));
    } catch (e) {
      debugPrint('==> library write failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final deps = _deps;
    if (deps == null) {
      // One frame at most: resolving the manifest's second_tutor before the
      // page mounts, so deps (the provider key) is built exactly once.
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return LessonPlayerPage(
      deps: deps,
      player: _player,
      onLeave: widget.onLeave,
    );
  }
}

/// lms_sdk's plans slice over lms_sdk's OWN backend (rlms).
///
/// getPlans renders the SERVER's configurable catalog — `LMS Plan` records
/// via `rlms.api.billing.plans` ([HttpLessonPlanCatalog]); purchase runs
/// the REAL wallet-mediated checkout (#33/#34) through
/// [HttpLessonCheckout] -> rlms.api.billing: a student pays from their own
/// wallet (student_checkout), a payer-capable partner pays for their
/// linked students (sponsor_checkout). Checkout names the PLAN, so the
/// server charges that record's own price per its kind — including the
/// one-off Holiday Programme (bounded server-side to the plan's upcoming
/// window), which the old months-only path could not buy.
///
/// The owner's rule ("sub plans should be configurable") means no price
/// constant survives in this real path: prices, terms and availability are
/// whatever the records say, and a failed fetch is an honest empty state
/// (decision #47), never a hardcoded fallback catalog.
class SubscriptionsLessonPlansAdapter implements LessonPlans {
  final LessonCheckout _checkout = HttpLessonCheckout();
  final LessonPlanCatalog _catalog = HttpLessonPlanCatalog();

  /// The last catalog fetch, so purchase(planId) can resolve the chosen
  /// plan without a second round trip. The funnel always loads plans
  /// before offering the CTA, so this is normally warm; a cold lookup
  /// re-fetches once.
  List<LessonPlanOption> _lastPlans = const [];

  /// Prices are displayed exactly as the server catalog returns them — no
  /// client-side partner discount (the rate decision is server-side in
  /// `billing_rules.charge_per_student` / `plan_rules.charge_for_plan`,
  /// charged to whoever actually pays, per decisions #23/#34). The app's
  /// job is to show what will be charged, not to recompute it.
  @override
  Future<List<LessonPlanOption>> getPlans() async {
    final snapshot = await _catalog.fetch();
    return _lastPlans = snapshot.plans;
  }

  @override
  Future<LessonPurchaseResult> purchase(String planId) => _run(planId);

  /// Per-lesson checkout from the locked-lesson screen: the same flow as
  /// [purchase] with the LMS lesson id riding along, so the server links
  /// the once-off charge to THAT lesson (billing record honoured by
  /// `course.get_lesson_session` for that lesson only).
  @override
  Future<LessonPurchaseResult> purchaseForLesson(String planId,
          {required String lesson}) =>
      _run(planId, lesson: lesson);

  Future<LessonPurchaseResult> _run(String planId, {String? lesson}) async {
    var plan = _planById(planId);
    if (plan == null) {
      // Cold path (no catalog in memory yet): one re-fetch, then give up
      // honestly rather than guessing a term.
      await getPlans();
      plan = _planById(planId);
    }
    if (plan == null) {
      debugPrint('==> purchase: plan $planId not in catalog');
      return const LessonPurchaseResult.failed();
    }
    // The client sends only WHO and WHICH PLAN. The rate decision (partner
    // discount to the PAYER) and every amount live server-side
    // (billing_rules.charge_per_student / plan_rules.charge_for_plan) —
    // nothing is priced here. Naming the plan is what lets one-off plans
    // (months == 0, e.g. the Holiday Programme) check out for real: the
    // server resolves the plan's upcoming programme window and bounds the
    // coverage to it. A refusal (unpriced plan, no announced window,
    // per-lesson plan bought without a lesson) surfaces the server's own
    // message, same as any other checkout refusal.
    try {
      if (isPartnerViewer) {
        return await _sponsorPurchase(plan, lesson: lesson);
      }
      final receipt = await _checkout.studentCheckout(
        plan: plan.id,
        months: plan.months,
        lesson: lesson,
        mathsTrack: await _storedMathsTrackSubject(),
      );
      return LessonPurchaseResult.completed(total: receipt.total);
    } on LessonCheckoutException catch (e) {
      // #56 posture: only a recognized server refusal (student-facing copy
      // — the top-up message names the exact amount) may reach the sheet /
      // blocked screen verbatim. Technical detail was already logged to
      // telemetry by HttpLessonCheckout; a null message here makes both
      // surfaces fall back to their friendly generic line.
      return LessonPurchaseResult.failed(
          message: e.isRefusal ? e.serverMessage : null);
    } catch (e) {
      debugPrint('==> purchase failed: $e');
      return const LessonPurchaseResult.failed();
    }
  }

  LessonPlanOption? _planById(String planId) {
    for (final plan in _lastPlans) {
      if (plan.id == planId) return plan;
    }
    return null;
  }

  /// Partner-side purchase: sponsor_checkout for the linked students this
  /// account pays for — the ones with billing responsibility assumed
  /// (paid_by_partner), or, when none is marked yet, every payer-capable
  /// link (can_pay is the SERVER's answer from rlms.payer_rules; a teacher
  /// link is never charged for). The backend re-verifies both the link and
  /// the relationship before any wallet hop.
  Future<LessonPurchaseResult> _sponsorPurchase(LessonPlanOption plan,
      {String? lesson}) async {
    final linked = await HttpPartnerReportSource().students();
    final payable = [for (final s in linked) if (s.canPay) s];
    final assumed = [for (final s in payable) if (s.paidByPartner) s];
    final covered = assumed.isNotEmpty ? assumed : payable;
    if (covered.isEmpty) {
      // Shouldn't be reachable — the plans surface shows "add your
      // student(s)" instead of a CTA when nothing is linked — but a stale
      // sheet must fail honestly, not charge nobody.
      return LessonPurchaseResult.failed(
          message: AppHelpers.getTranslation(TrKeys.linkStudentExplainer));
    }
    final receipt = await _checkout.sponsorCheckout(
      students: [for (final s in covered) s.id],
      plan: plan.id,
      months: plan.months,
      lesson: lesson,
    );
    return LessonPurchaseResult.completed(total: receipt.total);
  }

  /// Decision #29: the maths track persisted by the subscribe surface's
  /// picker (see SubscribePage._selectTrack — same KV) rides with the
  /// checkout, so the server records it through its exclusivity-enforcing
  /// writer BEFORE charging.
  Future<String?> _storedMathsTrackSubject() async {
    try {
      final row = await AppDbScheduleStore().get('lms_maths_track', 'value');
      return MathsTrack.fromName(row?['track']?.toString())?.subject;
    } catch (_) {
      return null;
    }
  }
}

/// Host route shell for [TutorDiscoveryPage] (lms_sdk-resident page).
@RoutePage(name: 'TutorDiscoveryRoute')
class TutorDiscoveryRouteView extends StatefulWidget {
  const TutorDiscoveryRouteView({super.key});

  @override
  State<TutorDiscoveryRouteView> createState() =>
      _TutorDiscoveryRouteViewState();
}

class _TutorDiscoveryRouteViewState extends State<TutorDiscoveryRouteView> {
  TutorDiscoveryDeps? _deps;

  @override
  void initState() {
    super.initState();
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<TutorCatalog>()) {
      LmsSdkDependencies.register(getIt);
    }
    // Grade-filtered discovery (mirrors CourseCatalogRouteView below):
    // resolve the captured student grade once, then build deps — guests /
    // students who haven't set a grade yet still see the unfiltered stack.
    // Decision #24: a PARENT has no grade of their own, so parents pass no
    // grade and see ALL tutors unfiltered — grade filtering is a student's
    // own onboarding choice, not a parent's.
    final isParent = isPartnerViewer;
    final gradeFuture = isParent ? Future<int?>.value(null) : studentGrade();
    gradeFuture.then((grade) {
      if (!mounted) return;
      setState(() {
        _deps = TutorDiscoveryDeps(
          catalog: getIt.get<TutorCatalog>(),
          plans: DemoSession.demoActive ? DemoLessonPlans() : SubscriptionsLessonPlansAdapter(),
          subscriptionStatus: getIt.isRegistered<SubscriptionStatusProvider>()
              ? getIt.get<SubscriptionStatusProvider>()
              : null,
          userId: LocalStorage.getUser()?.id?.toString(),
          grade: grade,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final deps = _deps;
    if (deps == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Read again here rather than reusing initState's local: the nav overlay
    // below picks the partner or student pill, and initState's copy is out of
    // scope in build.
    final isParent = isPartnerViewer;
    return Stack(
      children: [
        // Decision #32: Discover is the tutors surface alone — the Board
        // moved to per-subject entry from the Subjects catalog.
        TutorDiscoveryPage(
          deps: deps,
          // Sample playback resolves the Replay session from the LMS lesson
          // id inside LessonNotifier; sessionId stays empty as the
          // pre-resolution fallback.
          onPlaySample: (lessonId) => context.router.push(
            LessonRoute(sessionId: '', lessonId: lessonId, isSample: true),
          ),
          // UI #2: the commit funnel opens the plans as the same solid full
          // page the nav Subscribe slot uses — no in-page overlay bleed.
          onRequirePlan: () => showSubscribePage(context),
          // In-card sample: the card back swaps its text block for this
          // whiteboard playback (demo: the bundled real lesson).
          sampleBuilder: DemoSession.demoActive
              ? (onEnded) => DemoSampleLessonPlayer(onEnded: onEnded)
              : null,
          // The snippet button reads the tutor's own authored
          // 30-second sample (the team folder's samples.json).
          snippetsByTutor:
              DemoSession.demoActive ? kDemoTutorSnippets : const {},
          // Founder card "Hear more": the founder's self-intro video
          // (TutorProfile.introVideoRef, vendored from
          // lms/team/founders/<Name>/appearance/intro.mp4 by
          // tool/sync_team_assets.dart). The app ships no video-playback
          // dependency yet, so there is no host player to wire — leaving
          // the hook null keeps the button visible but disabled. When a
          // video capability lands, pass a callback here that presents
          // founder.introVideoRef; nothing else needs to change.
          onPlayFounderIntro: null,
        ),
        // Floating pill nav — same overlay the Schedule shell mounts. The
        // page reserves bottom clearance for it.
        Align(
          alignment: Alignment.bottomCenter,
          // A parent reaches this same deck from THEIR nav, so the
          // overlay has to be the partner one or the tabs underneath jump.
          child: isParent
              ? const SupachargePartnerNav(currentIndex: 2)
              : const SupachargeNav(currentIndex: 2),
        ),
      ],
    );
  }
}

/// Host route shell for [CourseCatalogPage] (lms_sdk-resident page).
@RoutePage(name: 'CourseCatalogRoute')
class CourseCatalogRouteView extends StatefulWidget {
  /// Narrows the catalog to one subject slug — leave null to browse
  /// everything published.
  final String? subject;

  const CourseCatalogRouteView({super.key, this.subject});

  @override
  State<CourseCatalogRouteView> createState() =>
      _CourseCatalogRouteViewState();
}

class _CourseCatalogRouteViewState extends State<CourseCatalogRouteView> {
  CourseCatalogDeps? _deps;

  /// Parent-side grade tab, null = "All". Unused for students, whose catalog
  /// is scoped to their own captured grade instead.
  int? _partnerGrade;

  @override
  void initState() {
    super.initState();
    final getIt = GetIt.instance;
    // LmsRepository is lms_sdk-owned (registered by LmsSdkDependencies), not
    // a host adapter — register here if whoever composed the app hasn't.
    if (!getIt.isRegistered<LmsRepository>()) {
      LmsSdkDependencies.register(getIt);
    }
    // A parent has no grade of their own (decision #24, same rule as the
    // tutor deck), so they open on "All" and pick a grade from the tabs.
    if (isPartnerViewer) {
      _deps = CourseCatalogDeps(
        repository: getIt.get<LmsRepository>(),
        subject: widget.subject,
      );
      return;
    }
    // Grade-scope the catalog (student-grade brief): resolve the student's
    // grade first (last-known-good, so this is fast and offline-safe), then
    // build the deps ONCE — deps identity keys the provider family.
    studentGrade().then((grade) {
      if (!mounted) return;
      setState(() {
        _deps = CourseCatalogDeps(
          repository: getIt.get<LmsRepository>(),
          subject: widget.subject,
          grade: grade,
        );
      });
    });
  }

  /// A CourseSummary carries no grade, so the tab re-scopes the FETCH: new
  /// deps means a new provider-family entry, which re-inits the catalog.
  void _selectPartnerGrade(int? grade) {
    setState(() {
      _partnerGrade = grade;
      _deps = CourseCatalogDeps(
        repository: GetIt.instance.get<LmsRepository>(),
        subject: widget.subject,
        grade: grade,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final deps = _deps;
    if (deps == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isParent = isPartnerViewer;
    final page = CourseCatalogPage(
      deps: deps,
      // Same pre-resolution handoff as the sample-lesson route above:
      // sessionId stays empty, LessonNotifier resolves it from lessonId.
      onOpenLesson: (lessonId) => context.router.push(
        LessonRoute(sessionId: '', lessonId: lessonId),
      ),
      // Decision #32: an enrolled subject's card opens its own Board.
      onOpenBoard: (subject) =>
          context.router.push(SubjectBoardRoute(subject: subject)),
      // Parent: grade tabs instead of the enrolment filter — they browse
      // every grade and enrol in none.
      gradeOptions: isParent ? kPartnerGradeOptions : null,
      selectedGrade: isParent ? _partnerGrade : null,
      onSelectGrade: isParent ? _selectPartnerGrade : null,
    );
    // For a student this is a pushed page (it keeps its back arrow). For a
    // parent it is a root tab, so it carries the partner nav like the rest
    // of their side — content scrolls under it, as on the dashboard.
    if (!isParent) return page;
    return Stack(
      children: [
        page,
        const Align(
          alignment: Alignment.bottomCenter,
          child: SupachargePartnerNav(currentIndex: 1),
        ),
      ],
    );
  }
}

/// Demo-only plans (`--dart-define=IS_DEMO=true`): a monthly + yearly student
/// plan so the subscribe/plans page isn't empty without the subscriptions
/// backend. Purchase reports completed (the demo student is already treated
/// as subscribed). Never used in production.
class DemoLessonPlans implements LessonPlans {
  @override
  Future<List<LessonPlanOption>> getPlans() async => const [
        // One plan FAMILY (same title) with a monthly and a yearly variant —
        // the plans sheet groups by title into a single card whose 50:50
        // term tabs switch the variant (UI #3). Different titles would split
        // it into separate tab-less cards.
        // Standard rate. The catalog advertises the STANDARD price; the
        // partner rate (a flat R50 off) is applied server-side at checkout
        // by `billing_rules.charge_per_student` for whoever actually pays,
        // not shown as a second plan and not discounted again here.
        // Previously this listed R249 — the partner-discounted price — as
        // the only price, so the standard tier didn't exist in the app.
        LessonPlanOption(
          id: 'demo-monthly',
          title: 'Full Access',
          description: 'Every live lesson, recording and skill review. '
              'Cancel anytime. R50 off with an accountability partner.',
          price: kStandardMonthlyRate,
          months: 1,
        ),
        // Two months free (10 x standard). The partner discount does NOT
        // stack here: the annual commitment already buys the retention the
        // partner discount exists to buy. R2490 was 249 x 10 — the yearly
        // plan had silently been derived from the partner rate.
        LessonPlanOption(
          id: 'demo-yearly',
          title: 'Full Access',
          description: 'Every live lesson, recording and skill review — '
              'two months free, billed once a year.',
          price: kStandardYearlyRate,
          months: 12,
        ),
        // Second family (own card, swipe target): the standalone Holiday
        // Programme — for students who only want the holiday catch-up
        // programmes, no year-round subscription.
        LessonPlanOption(
          id: 'demo-holiday',
          title: 'Holiday Programme',
          description: 'The full holiday catch-up programme only — live '
              'revision sessions and their recordings for the school '
              'holidays. No year-round subscription.',
          price: kHolidayProgrammeRate,
          // Pay-per-programme: one purchase for one holiday
          // programme, never a recurring subscription. The real
          // catalog's counterpart is an LMS Plan of kind
          // One-Off Programme, bought for the plan record's upcoming
          // window.
          months: 0,
          kind: PlanKind.oneOffProgramme,
        ),
      ];

  @override
  Future<LessonPurchaseResult> purchase(String planId) async =>
      const LessonPurchaseResult.completed();

  @override
  Future<LessonPurchaseResult> purchaseForLesson(String planId,
          {required String lesson}) =>
      purchase(planId);
}

/// Demo-only: the bundled square avatar render for a tutor persona (app-
/// shell assets under `assets/team/`, vendored from agent-repo `lms/team/`)
/// — the crop built for these slots (speaker tile, chat header, attendee
/// rows).
/// Personas without a generated portrait return null and fall back to
/// initials.
String? demoTutorAvatar(String personaId) {
  // Path fragment, not a tutor id: assistants live in a different
  // directory, and mapping to the fragment lets both resolve here.
  // Legacy TUTOR name-slugs are kept as aliases so anything still passing
  // one keeps working; legacy ASSISTANT spellings (old slug, display name,
  // grade-keyed assistant_gNN) normalize to the canonical assistant_NNN
  // ids through resolveAssistantId before the lookup.
  const byPersona = {
    'tutor_001': 'tutors/CAPS/tutor_001',
    'tutor_002': 'tutors/CAPS/tutor_002',
    'tutor_003': 'tutors/CAPS/tutor_003',
    'tutor_004': 'tutors/CAPS/tutor_004',
    'tutor_005': 'tutors/CAPS/tutor_005',
    'tutor_006': 'tutors/CAPS/tutor_006',
    'tutor_007': 'tutors/CAPS/tutor_007',
    'tutor_008': 'tutors/CAPS/tutor_008',
    'tutor_009': 'tutors/CAPS/tutor_009',
    'tutor_010': 'tutors/CAPS/tutor_010',
    'tutor_011': 'tutors/CAPS/tutor_011',
    'tutor_012': 'tutors/CAPS/tutor_012',
    'grandmaster': 'tutors/CAPS/tutor_001',
    'big_john': 'tutors/CAPS/tutor_002',
    'science_queen': 'tutors/CAPS/tutor_003',
    'uncle_vusi': 'tutors/CAPS/tutor_004',
    'prof_mokoena': 'tutors/CAPS/tutor_005',
    'aunty_grace': 'tutors/CAPS/tutor_006',
    'ms_mahlangu': 'tutors/CAPS/tutor_007',
    'bra_sipho': 'tutors/CAPS/tutor_008',
    'dr_molefe': 'tutors/CAPS/tutor_009',
    'ranger_themba': 'tutors/CAPS/tutor_010',
    'mrs_pillay': 'tutors/CAPS/tutor_011',
    'uncle_joe': 'tutors/CAPS/tutor_012',
    // Assistants: canonical opaque ids only (roster v2). Legacy spellings
    // (slug, display name, grade-keyed assistant_gNN) are normalized to
    // these by resolveAssistantId below, not duplicated here.
    'assistant_001': 'assistants/CAPS/assistant_001',
    'assistant_002': 'assistants/CAPS/assistant_002',
    'assistant_003': 'assistants/CAPS/assistant_003',
  };
  final fragment = byPersona[
      resolveAssistantId(personaId).toLowerCase().replaceAll(' ', '_')];
  if (fragment == null) return null;
  return 'assets/team/$fragment/appearance/renders/avatar_512.webp';
}

/// Demo-only tutor snippets (`--dart-define=IS_DEMO=true`): the real
/// 30-second teaching samples authored in
/// `lms/team/tutors/CAPS/{tutor_id}/samples.json`, keyed by the seeded
/// catalog's tutor id. GENERATED from those files - re-run the factory
/// script rather than editing scripts here, or the app and the recorded
/// audio will say different things.
const Map<String, List<TutorSnippet>> kDemoTutorSnippets = {
  'tutor_001': [
    TutorSnippet(
      id: 'tutor_001_sample_01',
      title: 'Factorise like the examiner marks it',
      subject: 'Maths',
      grade: 11,
      sourceKind: 'skill',
      sourceRef: 'maths.factorisation_techniques',
      durationTargetSeconds: 30,
      script: 'Factorise six x squared minus seven x minus three. Method: multiply a by c - six times minus three, minus eighteen. Find the factor pair of minus eighteen summing to minus seven: minus nine and two. Split the middle term, group in pairs, extract the common binomial. Two x minus three, times three x plus one. That split line earns the method mark; the final brackets earn the answer mark. Distinction habit: expand your answer back in your head before moving on - thirty seconds buys you certainty.',
    ),
  ],
  'tutor_002': [
    TutorSnippet(
      id: 'tutor_002_sample_01',
      title: 'Factorising is just un-multiplying',
      subject: 'Maths',
      grade: 11,
      sourceKind: 'skill',
      sourceRef: 'maths.factorisation_techniques',
      durationTargetSeconds: 30,
      script: 'You know how to multiply two brackets - factorising is walking that road backwards. Think of eighteen sweets: which two packets made them? Same idea here. Six x squared minus seven x minus three. I need two numbers that multiply to minus eighteen and add to minus seven. Try them like counting taxi change: minus nine and two. Split, group, and the brackets fall out on their own. No magic. If you can unpack a shopping bag, you can un-multiply an expression.',
    ),
  ],
  'tutor_003': [
    TutorSnippet(
      id: 'tutor_003_sample_01',
      title: 'Choosing the right equation of motion',
      subject: 'Physical Sciences',
      grade: 10,
      sourceKind: 'skill',
      sourceRef: 'physical_sciences.equations_of_motion',
      durationTargetSeconds: 30,
      script: 'A car accelerates uniformly from ten metres per second to twenty-five metres per second over three hundred metres. Which equation? List what you have: initial velocity, final velocity, displacement - and no time. So select v f squared equals v i squared plus two a delta x, the only equation on your data sheet without time in it. Substitute explicitly, solve for a: zero comma eight seven five metres per second squared. Units stated, correctly rounded. That substitution line is where the mark sheet pays you.',
    ),
  ],
  'tutor_004': [
    TutorSnippet(
      id: 'tutor_004_sample_01',
      title: 'Every force is a wheelbarrow',
      subject: 'Physical Sciences',
      grade: 10,
      sourceKind: 'skill',
      sourceRef: 'physical_sciences.force_and_free_body_diagrams',
      durationTargetSeconds: 30,
      script: 'Load a wheelbarrow and push it across the yard. Feel that? Your push forward, the ground dragging back on the wheel, the earth holding it up, the load pressing down. Four forces - and you just drew your first free-body diagram without touching a pen. Now on paper: one dot for the barrow, one arrow for each thing acting on it. Push, friction, normal force, weight. Name them, point them the way you felt them. The physics was already in your hands; the diagram just writes it down.',
    ),
  ],
  'tutor_005': [
    TutorSnippet(
      id: 'tutor_005_sample_01',
      title: 'Debit the asset, credit the capital - because',
      subject: 'Accounting',
      grade: 10,
      sourceKind: 'skill',
      sourceRef: 'accounting.double_entry',
      durationTargetSeconds: 30,
      script: 'The owner deposits one hundred thousand rand as capital. Watch the double entry. Debit bank - an asset increases. Credit capital - the owner interest increases. Say the because aloud: every debit has its credit, and the accounting equation stays in balance. Assets equal owner equity plus liabilities: one hundred thousand equals one hundred thousand plus zero. Draw the skeleton first, post in the marked order, balance visibly. The numbers never lie - every figure you write must be traceable to this logic.',
    ),
  ],
  'tutor_006': [
    TutorSnippet(
      id: 'tutor_006_sample_01',
      title: 'The tin and the notebook',
      subject: 'Accounting',
      grade: 10,
      sourceKind: 'skill',
      sourceRef: 'accounting.double_entry',
      durationTargetSeconds: 30,
      script: 'At the spaza, money lives in the tin and the story lives in the notebook. A customer pays twenty rand for bread - the tin gets fuller, and the notebook says why. That is all double entry is: every move of money has two sides, where it came from and where it went. The tin side we call debit bank. The why side - sales - we credit. Two entries, one truth. Master the tin and the notebook, and the exam ledgers are just your notebook in Sunday clothes.',
    ),
  ],
  'tutor_007': [
    TutorSnippet(
      id: 'tutor_007_sample_01',
      title: 'State, explain, illustrate: the demand curve',
      subject: 'Economics',
      grade: 10,
      sourceKind: 'skill',
      sourceRef: 'economics.demand_and_supply',
      durationTargetSeconds: 30,
      script: 'State: demand is the quantity of a good consumers are willing and able to buy at each price, per period. Explain: as price falls, quantity demanded rises - the inverse relationship. Illustrate: axes first - price vertical, quantity horizontal. The demand curve slopes downward from left to right. When income changes, the whole curve shifts; when price changes, we move along it. That distinction - shift versus movement - is where markets move, and where examiners separate the top answers from the rest.',
    ),
  ],
  'tutor_008': [
    TutorSnippet(
      id: 'tutor_008_sample_01',
      title: 'Petrol up, fares up - that is economics',
      subject: 'Economics',
      grade: 10,
      sourceKind: 'skill',
      sourceRef: 'economics.demand_and_supply',
      durationTargetSeconds: 30,
      script: 'Month-end at the taxi rank. Petrol price goes up, and by Monday the fare is two rand more. Fewer people take the taxi for short trips - they walk. You just watched demand with your own eyes. Price up, quantity demanded down. No graph yet - first feel it. The gogo buying six loaves when bread is on special? Price down, quantity up. Now we draw the picture: price up the side, amount along the bottom, and the line slides down like a taxi rolling downhill.',
    ),
  ],
  'tutor_009': [
    TutorSnippet(
      id: 'tutor_009_sample_01',
      title: 'Gradient in the format that scores',
      subject: 'Geography',
      grade: 12,
      sourceKind: 'skill',
      sourceRef: 'geography.gradient_calculation',
      durationTargetSeconds: 30,
      script: 'Trig beacon at one thousand two hundred metres, spot height at nine hundred - and on a one to fifty thousand map they are four comma five centimetres apart. Gradient equals vertical interval over horizontal equivalent. Vertical: three hundred metres. Horizontal: four comma five centimetres times fifty thousand - two thousand two hundred and fifty metres. Divide both sides by three hundred. Answer: one in seven comma five - always stated as one to x, units cancelled, working shown. That exact format is what the memorandum rewards.',
    ),
  ],
  'tutor_010': [
    TutorSnippet(
      id: 'tutor_010_sample_01',
      title: 'The wind you felt this morning',
      subject: 'Geography',
      grade: 10,
      sourceKind: 'skill',
      sourceRef: 'geography.synoptic_map_reading',
      durationTargetSeconds: 30,
      script: 'That cold wind on your walk to school this morning - it was not random. Air is lazy: it slides from where pressure is high to where pressure is low, like water finding the door. On the weather map, those curved lines are pressure lines. Squeezed close together? The slope is steep and the wind runs hard - that is what you felt. Far apart, calm day. Read the map like the ground under your feet: find the high, find the low, and the whole journey of the wind is written between them.',
    ),
  ],
  'tutor_011': [
    TutorSnippet(
      id: 'tutor_011_sample_01',
      title: 'The discount and the VAT, in the right order',
      subject: 'Mathematical Literacy',
      grade: 10,
      sourceKind: 'skill',
      sourceRef: 'maths_literacy.percentage_calculations',
      durationTargetSeconds: 30,
      script: 'A jacket on the rail: eight hundred and fifty rand, fifteen percent discount, then VAT at fifteen percent on the discounted price. Order matters. Discount first: eight fifty times zero comma eight five - seven hundred and twenty-two rand fifty. Then VAT: times one comma one five - eight hundred and thirty rand and eighty-eight cents. Money rounds to two decimal places, always. And state the answer in context: the jacket costs R830,88 at the till. A number without its context earns nothing on this paper.',
    ),
  ],
  'tutor_012': [
    TutorSnippet(
      id: 'tutor_012_sample_01',
      title: 'Ten percent you can do in your head',
      subject: 'Mathematical Literacy',
      grade: 10,
      sourceKind: 'skill',
      sourceRef: 'maths_literacy.percentage_calculations',
      durationTargetSeconds: 30,
      script: 'Forget the calculator for a second. Ten percent of anything? Move the comma one step. Ten percent of two hundred and forty rand airtime is twenty-four rand. Five percent is half of that - twelve rand. Fifteen percent? Twenty-four plus twelve - thirty-six rand. You just did the till-slip discount in your head while the queue was still moving. Estimate first, then let the calculator confirm you were close. If the machine says something wild, your head catches the slip before your money does.',
    ),
  ],
};

/// Demo-only skills source (`--dart-define=IS_DEMO=true`): representative
/// on-demand skill lessons for the Library's skills shelf without the
/// downloaded skills_index.json (absent in demo). All 'evaluated' so they're
/// servable. Never used in production.
class DemoSkillLessonSource implements SkillLessonSource {
  /// Seed copy lifted verbatim from the real CAPS skill files
  /// (factory/lessons/curriculum/CAPS/{subject}/skills/…) so the demo shows
  /// authentic importance hooks and the gradient→contour requires chain.
  static const List<SkillLessonInfo> _skills = [
    SkillLessonInfo(
      skillRef: 'maths.factorisation_techniques',
      cardId: 'maths.factorisation_techniques',
      subject: 'Mathematics',
      grade: 10,
      name: 'Factorisation techniques',
      status: 'evaluated',
      importanceSummary:
          'Feeds the Algebra section every year (30/100 Gr 10, 45/150 Gr 11, '
          '25/150 Gr 12 on Paper 1) AND Gr 12 Differential Calculus.',
      requiredByTopics: 2,
      coveredBy: [SkillCoverage(grade: 10, topic: 'Algebra')],
      exampleProblem:
          'Factorise fully: 3x² − 12, x² − 5x − 14, and 2x³ + 16.',
      priorKnowledge: 'Products of binomials; HCF; difference of squares',
    ),
    SkillLessonInfo(
      skillRef: 'physical_sciences.formulae_and_balanced_equations',
      cardId: 'physical_sciences.formulae_and_balanced_equations',
      subject: 'Physical Sciences',
      grade: 10,
      name: 'Writing formulae and balancing equations',
      status: 'evaluated',
      importanceSummary:
          'Underpins the entire Chemical Change section - 92/150 of the Gr 12 '
          'Paper 2, the single largest block in Physical Sciences - and every '
          'chemistry topic from Gr 11 term 3 onward.',
      requiredByTopics: 6,
      coveredBy: [
        SkillCoverage(
            grade: 10, topic: 'CHEMICAL CHANGE: Representing chemical change'),
      ],
      exampleProblem:
          'Write formulae for calcium chloride, ammonium sulphate and '
          'iron(III) oxide, then balance: C3H8 + O2 -> CO2 + H2O.',
      priorKnowledge: 'The periodic table; valency; cation and anion table',
    ),
    SkillLessonInfo(
      skillRef: 'maths.trig_ratios',
      cardId: 'maths.trig_ratios',
      subject: 'Mathematics',
      grade: 10,
      name: 'Trigonometric ratios and special angles',
      status: 'evaluated',
      importanceSummary:
          'Gateway to Trigonometry - the biggest Paper 2 section: 40/100 in '
          'the Gr 10 final, 50/150 in Gr 11 and 40/150 in Gr 12.',
      requiredByTopics: 2,
      coveredBy: [SkillCoverage(grade: 10, topic: 'Trigonometry')],
      exampleProblem:
          'Without a calculator, evaluate sin 60°·cos 30° + sin 30°.',
      priorKnowledge: 'Similar triangles; Pythagoras',
    ),
    SkillLessonInfo(
      skillRef: 'geography.contour_reading',
      cardId: 'geography.contour_reading',
      subject: 'Geography',
      grade: 10,
      name: 'Reading contour lines',
      status: 'evaluated',
      importanceSummary:
          'Mapwork is Question 3 on BOTH Geography papers, every year: 30/150 '
          'per paper in Gr 11 and Gr 12 - contour reading is the entry point.',
      requiredByTopics: 2,
      coveredBy: [
        SkillCoverage(
            grade: 10, topic: 'Consolidation of Grade 8 and 9 map skills'),
      ],
      exampleProblem:
          'On a 1:50 000 extract with a 20 m contour interval, identify the '
          'river valley, the steepest slope and the highest point.',
      priorKnowledge: 'Map symbols; scale',
    ),
    SkillLessonInfo(
      skillRef: 'geography.gradient_calculation',
      cardId: 'geography.gradient_calculation',
      subject: 'Geography',
      grade: 12,
      name: 'Gradient calculation',
      status: 'evaluated',
      importanceSummary:
          "A named mapwork calculation: part of Question 3's map skills and "
          'calculations (10 of the 30 mapwork marks on each paper) and '
          'required for fluvial/geomorphology cross-section work.',
      requiredByTopics: 1,
      // Chain: reviewing gradient may first suggest contour reading.
      requiresSkills: ['geography.contour_reading'],
      exampleProblem:
          'Calculate the average gradient between trig beacon 251 (1 200 m) '
          'and a spot height of 900 m, 4.5 cm apart on a 1:50 000 map.',
      priorKnowledge: 'Contour reading; map scale; unit conversion',
    ),
  ];

  /// Synchronous ref lookup for chain resolution (prerequisite chips).
  static SkillLessonInfo? byRef(String skillRef) {
    for (final s in _skills) {
      if (s.skillRef == skillRef) return s;
    }
    return null;
  }

  @override
  Future<SkillLessonInfo?> lookup(String skillRef) async => byRef(skillRef);

  @override
  Future<List<SkillLessonInfo>> available() async => _skills;
}

/// In-card sample-lesson player for the tutor card back: plays the bundled
/// demo lesson's whiteboard animation + audio inside the card's text area
/// (no navigation, no lesson chrome). Owns its own [WhiteboardPlayer]
/// instance so it never stomps the real lesson player's shared canvas.
/// Ends by audio completion (or the card's Stop button disposing it).
class DemoSampleLessonPlayer extends StatefulWidget {
  final void Function() onEnded;

  const DemoSampleLessonPlayer({super.key, required this.onEnded});

  @override
  State<DemoSampleLessonPlayer> createState() =>
      _DemoSampleLessonPlayerState();
}

class _DemoSampleLessonPlayerState extends State<DemoSampleLessonPlayer> {
  final WhiteboardPlayer _player = WhiteboardPlayer();
  final AudioPlayer _audio = AudioPlayer();
  final Stopwatch _elapsed = Stopwatch();
  List<ManimPrimitive> _prims = const [];
  int _next = 0;
  Timer? _tick;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await seedDemoLessonAssets();
      final store = GetIt.instance.get<AssetStore>();
      final root = await store.assetsRoot();
      final raw = await File(
              store.animationPath(root, kDemoLessonSessionId))
          .readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _prims = (decoded['primitives'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ManimPrimitive.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => _t(a).compareTo(_t(b)));
      if (!mounted) return;
      _audio.onPlayerComplete.listen((_) => widget.onEnded());
      // Audio failure is non-fatal — the animation still plays silently.
      unawaited(_audio
          .play(DeviceFileSource(store.audioPath(root, kDemoLessonSessionId)))
          .catchError((Object e) {
        debugPrint('==> DemoSampleLessonPlayer: audio failed: $e');
      }));
      _elapsed.start();
      _tick = Timer.periodic(const Duration(milliseconds: 120), (_) {
        if (!_player.isReady) return;
        final pos = _elapsed.elapsedMilliseconds / 1000.0;
        while (_next < _prims.length && _t(_prims[_next]) <= pos) {
          _player.renderPrimitive(_prims[_next]);
          _next++;
        }
        // Silent-audio fallback: everything rendered and nothing playing →
        // wind down rather than sitting on a frozen board forever.
        if (_next >= _prims.length &&
            _prims.isNotEmpty &&
            pos > _t(_prims.last) + 8) {
          widget.onEnded();
        }
      });
      setState(() {});
    } catch (e) {
      debugPrint('==> DemoSampleLessonPlayer: load failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  static double _t(ManimPrimitive p) =>
      ((p.rawData['time'] as num?) ?? 0).toDouble();

  @override
  void dispose() {
    _tick?.cancel();
    _audio.stop();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Text('Sample unavailable right now.',
            style:
                TextStyle(fontSize: 13, color: AppStyle.textDarkSecondary)),
      );
    }
    return WhiteboardCanvas(player: _player);
  }
}

/// Demo-only review content (`--dart-define=IS_DEMO=true`): authored
/// diagnostic/recap/exit sets for the seed skills, in the factory Level-3
/// form. Skills without an authored set get a recap generated from their
/// CAPS fields so every card opens something sensible. Production builds
/// get [BackendSkillReviewSource] instead — authored sets from the
/// published skills index, never fabricated review content.
class DemoSkillReviewSource implements SkillReviewSource {
  static final Map<String, SkillReviewContent> _authored = {
    'maths.factorisation_techniques': const SkillReviewContent(
      skillRef: 'maths.factorisation_techniques',
      diagnostic: [
        McqQuestion(
          id: 'fact-d1',
          prompt: 'Factorise: x² − 9',
          options: ['(x − 3)(x + 3)', '(x − 3)²', 'x(x − 9)', '(x − 9)(x + 1)'],
          correctIndex: 0,
        ),
        McqQuestion(
          id: 'fact-d2',
          prompt: 'What comes FIRST in any factorisation?',
          options: [
            'Take out the highest common factor',
            'Try the quadratic formula',
            'Complete the square',
            'Split the middle term'
          ],
          correctIndex: 0,
        ),
      ],
      recap:
          'Factorising is unmultiplying: writing an expression as a product '
          'of brackets. Always work in the same order.\n\n'
          '1. HCF first — every time. 3x² − 12 becomes 3(x² − 4) before you '
          'do anything else. Missing the HCF is the single most common lost '
          'mark.\n\n'
          '2. Count the terms. TWO terms: look for a difference of squares '
          'a² − b² = (a − b)(a + b), or a sum/difference of cubes. THREE '
          'terms: a trinomial — find two numbers that multiply to give ac '
          'and add to give b, then split and group. FOUR terms: group in '
          'pairs and pull a common bracket.\n\n'
          '3. Check inside the brackets — a bracket like (x² − 4) can often '
          'be factorised again. "Factorise fully" means keep going until '
          'nothing factorises.\n\n'
          'Multiply your brackets back out mentally; if you don\'t land on '
          'the original expression, a sign is wrong.',
      exitCheck: [
        McqQuestion(
          id: 'fact-e1',
          prompt: 'Factorise fully: 3x² − 12',
          options: [
            '3(x − 2)(x + 2)',
            '3(x² − 4)',
            '(3x − 6)(x + 2)',
            '3x(x − 4)'
          ],
          correctIndex: 0,
        ),
        McqQuestion(
          id: 'fact-e2',
          prompt: 'Factorise: x² − 5x − 14',
          options: [
            '(x − 7)(x + 2)',
            '(x + 7)(x − 2)',
            '(x − 14)(x + 1)',
            '(x − 5)(x − 14)'
          ],
          correctIndex: 0,
        ),
        McqQuestion(
          id: 'fact-e3',
          prompt: '2x³ + 16 factorises to…',
          options: [
            '2(x + 2)(x² − 2x + 4)',
            '2(x − 2)(x² + 2x + 4)',
            '(2x + 4)(x² + 4)',
            '2(x³ + 8) and no further'
          ],
          correctIndex: 0,
        ),
      ],
    ),
    'geography.gradient_calculation': const SkillReviewContent(
      skillRef: 'geography.gradient_calculation',
      diagnostic: [
        McqQuestion(
          id: 'grad-d1',
          prompt:
              'Gradient between two points is expressed as…',
          options: [
            'Vertical interval : horizontal equivalent, as 1 : n',
            'Horizontal distance ÷ map scale',
            'Contour interval × distance',
            'Height difference × scale'
          ],
          correctIndex: 0,
        ),
      ],
      recap:
          'Gradient answers one question: how steep is the slope between two '
          'points?\n\n'
          '1. Vertical interval (VI): subtract the lower height from the '
          'higher one — trig beacon 1 200 m and spot height 900 m give '
          'VI = 300 m.\n\n'
          '2. Horizontal equivalent (HE): measure the map distance between '
          'the points and convert with the scale. On a 1:50 000 map, '
          '4.5 cm × 50 000 = 225 000 cm = 2 250 m.\n\n'
          '3. Divide: gradient = VI : HE = 300 : 2 250. Reduce to 1 : n by '
          'dividing both sides by the VI → 1 : 7.5.\n\n'
          'Always give the answer as 1 : n, keep units the same (both in '
          'metres) and show VI and HE — the mark allocation rewards the '
          'working, not just the ratio.',
      exitCheck: [
        McqQuestion(
          id: 'grad-e1',
          prompt:
              'VI = 300 m, map distance 4.5 cm on a 1:50 000 map. The gradient is…',
          options: ['1 : 7.5', '1 : 75', '1 : 15', '1 : 750'],
          correctIndex: 0,
        ),
        McqQuestion(
          id: 'grad-e2',
          prompt: 'A gradient of 1 : 3 compared to 1 : 30 is…',
          options: [
            'Much steeper',
            'Much gentler',
            'The same steepness',
            'Impossible to compare'
          ],
          correctIndex: 0,
        ),
      ],
    ),
    'geography.contour_reading': const SkillReviewContent(
      skillRef: 'geography.contour_reading',
      diagnostic: [
        McqQuestion(
          id: 'cont-d1',
          prompt: 'Closely spaced contour lines mean…',
          options: [
            'A steep slope',
            'A gentle slope',
            'A river',
            'Flat ground'
          ],
          correctIndex: 0,
        ),
      ],
      recap:
          'Contour lines join points of equal height; the pattern they make '
          'IS the landscape.\n\n'
          'Spacing = steepness: close together is steep, far apart is '
          'gentle, evenly spaced is a uniform slope.\n\n'
          'Shapes: V-shapes pointing UPHILL mark a river valley (the stream '
          'flows out of the V). Rounded U-shapes pointing downhill are '
          'spurs. Closed rings are hills; the innermost ring is the summit '
          'area. A ridge reads as a long, narrow band of rings.\n\n'
          'Heights: read the labelled contours and count intervals — on a '
          '20 m interval map, three lines above the 200 m contour is 260 m. '
          'The highest possible point inside a closed ring is just under one '
          'interval above its value.',
      exitCheck: [
        McqQuestion(
          id: 'cont-e1',
          prompt: 'Contour V-shapes point upstream. The river flows…',
          options: [
            'Out of the V — downhill',
            'Into the V — uphill',
            'Along the contour',
            'There is no river'
          ],
          correctIndex: 0,
        ),
        McqQuestion(
          id: 'cont-e2',
          prompt:
              'On a 20 m interval map, a point two contours above the 300 m line is…',
          options: ['340 m', '320 m', '360 m', '302 m'],
          correctIndex: 0,
        ),
      ],
    ),
  };

  @override
  Future<SkillReviewContent?> contentFor(String skillRef) async {
    final authored = _authored[skillRef];
    if (authored != null) return authored;
    // Un-authored seed skills still open a sensible recap built from their
    // CAPS fields (importance + worked example), with no question stages.
    final info = DemoSkillLessonSource.byRef(skillRef);
    if (info == null) return null;
    return SkillReviewContent(
      skillRef: skillRef,
      recap: '${info.importanceSummary}\n\n'
          'Work through the example below; if it feels shaky, the full '
          'lesson covers this from first principles.',
    );
  }
}

/// Demo-only schedule (`--dart-define=IS_DEMO=true`): representative upcoming
/// sessions so the student Schedule renders populated without the replay
/// backend (which returns "no host" in demo). Times are relative to now so a
/// live/soon card is always present. Never used in production.
class DemoScheduleSource implements SessionScheduleSource {
  /// One-time copy of the bundled demo triple into the AssetStore so every
  /// joinable demo session below plays real content instead of "not ready".
  static Future<void>? _seeding;

  @override
  Future<List<ScheduledSession>> upcoming() async {
    await (_seeding ??= seedDemoLessonAssets());
    final mocks = demoWeekMockSessionIds();
    final now = DateTime.now();
    ScheduledSession s(
      String id,
      String subject,
      String topic,
      String tutor,
      DateTime start, {
      String? secondTutor,
      bool skill = false,
      List<String> requires = const [],
      String? lessonId,
    }) =>
        ScheduledSession(
          sessionId: id,
          // Plays of the same lesson share a lessonId — the door-closed
          // recovery matches on it to offer the next play of the day.
          lessonId: lessonId ?? id,
          subject: subject,
          topic: topic,
          tutorName: tutor,
          secondTutorName: secondTutor,
          startTime: start,
          isSkillLesson: skill,
          requiresSkills: requires,
        );
    return [
      // A lesson broadcasts three times a day. Play 1's door locked 25 min
      // ago → the card offers catching the later play; carries
      // requires_skills → also exercises the pre-lesson review prompt.
      // Every lesson is taught by the subject's DUO (expert + simplifier per
      // roster.json) — two tutors per session is the platform's shape, not
      // an occasional two-part broadcast, so every card names both.
      s(kDemoLessonSessionId, 'Mathematics', 'Quadratic functions',
          'Sifiso Zulu', now.subtract(const Duration(minutes: 25)),
          secondTutor: 'John Petersen',
          lessonId: 'demo-lesson-quadratic',
          requires: ['maths.factorisation_techniques']),
      s(mocks[0], 'Mathematics', 'Quadratic functions', 'Sifiso Zulu',
          now.add(const Duration(hours: 3)),
          secondTutor: 'John Petersen',
          lessonId: 'demo-lesson-quadratic',
          requires: ['maths.factorisation_techniques']),
      s(mocks[1], 'Mathematics', 'Quadratic functions', 'Sifiso Zulu',
          now.add(const Duration(hours: 7)),
          secondTutor: 'John Petersen',
          lessonId: 'demo-lesson-quadratic',
          requires: ['maths.factorisation_techniques']),
      // Locked AND the day's last play -> the Library-release reminder path.
      s(mocks[2], 'Physical Sciences', 'Newton\'s second law', 'Lindiwe Dlamini',
          now.subtract(const Duration(minutes: 90)),
          secondTutor: 'Rudzani Mudau'),
      // Live now (inside the door grace window) -> joinable, plays the real
      // seeded content; gradient chains to contour reading -> the deeper
      // review path from the prompt.
      s(mocks[3], 'Geography', 'Mapwork: cross-sections & gradient',
          'Kagiso Molefe', now.subtract(const Duration(minutes: 2)),
          secondTutor: 'Pieter van Zyl',
          requires: ['geography.gradient_calculation']),
      // Two more real subjects rather than the invented 'English' and
      // 'Life Sciences' staff the demo used to carry: every card must name
      // the subject's real duo from roster.json, or the schedule and the
      // tutor cards disagree about who teaches what.
      s('demo-sess-3', 'Accounting', 'Bank reconciliation',
          'Anand Naicker',
          now.add(const Duration(days: 1, hours: 1)),
          secondTutor: 'Grace Mofokeng'),
      s('demo-sess-4', 'Economics', 'Demand and supply',
          'Nomsa Mahlangu',
          now.add(const Duration(days: 2, hours: 2)),
          secondTutor: 'Rhulani Chauke'),
      // A skill review, not a subject: 'Study skills' was never on the
      // curriculum, and skill: true already marked this as a review.
      s('demo-sess-6', 'Mathematical Literacy', 'Percentages: discount and VAT',
          'Priya Pillay', now.add(const Duration(days: 3)),
          secondTutor: 'Joe September', skill: true),
    ];
  }
}

/// Demo-only library (`--dart-define=IS_DEMO=true`): the first read of an
/// empty library seeds a few already-attended demo-week sessions so the
/// "Recently attended" strip renders populated. Lesson COMPLETION is the
/// only production write path ([_LessonRouteViewState._recordInLibrary]) and
/// the guided tour never plays a lesson through, so without this the demo
/// Library shows the skills shelf alone. Entries sit days in the past so
/// their recordings are already unlocked (play disc, not padlock), and every
/// session id carries the seeded demo asset triple, so each tile replays
/// real content. Never used in production.
class DemoLibraryStore extends LibraryStore {
  /// One-time seed per launch, same shape as [DemoScheduleSource._seeding].
  static Future<void>? _seeding;

  @override
  Future<List<LibraryEntry>> load() async {
    await (_seeding ??= _seedIfEmpty());
    return super.load();
  }

  Future<void> _seedIfEmpty() async {
    // A student who has really completed demo lessons keeps their own
    // entries — seed only the never-written store.
    if ((await super.load()).isNotEmpty) return;
    await seedDemoLessonAssets();
    final mocks = demoWeekMockSessionIds();
    final now = DateTime.now();
    LibraryEntry attended(
      String id,
      String subject,
      String topic,
      String tutor, {
      required int daysAgo,
      String? lessonId,
      int? postScore,
    }) {
      final attendedAt = now.subtract(Duration(days: daysAgo));
      return LibraryEntry(
        sessionId: id,
        lessonId: lessonId ?? id,
        subject: subject,
        topic: topic,
        tutorName: tutor,
        attendedAt: attendedAt,
        recordingAvailableAt:
            LibraryEntry.defaultRecordingUnlock(attendedAt),
        postScore: postScore,
      );
    }

    await save([
      // The bundled demo session itself: tapping this tile replays the real
      // recorded lesson, exactly like the schedule's hero card.
      attended(kDemoLessonSessionId, 'Mathematics', 'Quadratic functions',
          'Sifiso Zulu',
          daysAgo: 3, lessonId: 'demo-lesson-quadratic', postScore: 80),
      // Same subjects/topics/duos as [DemoScheduleSource], so the library
      // and the schedule tell one coherent demo-week story.
      attended(mocks[2], 'Physical Sciences', 'Newton\'s second law',
          'Lindiwe Dlamini',
          daysAgo: 4, postScore: 65),
      attended(mocks[3], 'Geography', 'Mapwork: cross-sections & gradient',
          'Kagiso Molefe',
          daysAgo: 6, postScore: 90),
    ]);
  }
}

/// lms_sdk's schedule slice over replay's published-sessions feed. Enriches
/// with the local manifest (topic/tutor/door policy/prerequisite skills)
/// when the session's assets are already downloaded; otherwise sensible
/// defaults keep the card usable.
class ReplayScheduleSource implements SessionScheduleSource {
  @override
  Future<List<ScheduledSession>> upcoming() async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<HttpService>()) return const [];
    final response = await getIt
        .get<HttpService>()
        .client(requireAuth: true)
        .post(_kGatewayPath,
            data: {'cmd': 'api.replay.get_upcoming_sessions'});
    final body = response.data;
    final raw = body is Map<String, dynamic>
        ? (body['message'] ?? body['data'])
        : body;
    if (raw is! List) return const [];
    final sessions = <ScheduledSession>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        final up = UpcomingSession.fromJson(Map<String, dynamic>.from(item));
        final manifest = await _manifestJson(up.sessionId);
        sessions.add(ScheduledSession(
          sessionId: up.sessionId,
          subject: up.subject,
          topic: manifest?['topic']?.toString() ?? up.subject,
          tutorName: await _tutorFor(up.sessionId) ?? 'Tutor',
          // Decision #18: two-part broadcast — the manifest's top-level
          // `second_tutor` names the bridge-in tutor for the card's tutor line.
          secondTutorName: _secondTutorName(manifest),
          startTime: up.scheduledAt,
          doorCloseSeconds: (manifest?['door_close_seconds'] is num)
              ? (manifest!['door_close_seconds'] as num).toInt()
              : 300,
          // Factory lesson-skills schema: requires_skills rides the
          // manifest same as topic; category 'skill' marks library-only
          // content the schedule must drop defensively.
          requiresSkills: parseRequiresSkills(manifest?['requires_skills']),
          isSkillLesson: manifest?['category']?.toString() == 'skill',
          // Decision #45: the airing carries its context (live / holiday /
          // revision); unknown values fall back to a normal live airing.
          airingContext: AiringContext.parse(up.airingContext),
          // Real lesson length for the calendar export when the assets are
          // already downloaded; consumers default to an hour otherwise.
          durationSeconds:
              (manifest?['audio']?['duration_seconds'] as num?)?.toInt(),
        ));
      } catch (e) {
        debugPrint('==> ReplayScheduleSource: skipping bad record: $e');
      }
    }
    return sessions;
  }

  /// The bridge-in tutor's display name from a session manifest's top-level
  /// `second_tutor` block (decision #18), or null for a single-tutor session.
  static String? _secondTutorName(Map<String, dynamic>? manifest) {
    final second = manifest?['second_tutor'];
    if (second is Map) {
      return (second['display_name'] ?? second['name'])?.toString();
    }
    return null;
  }

  Future<Map<String, dynamic>?> _manifestJson(String sessionId) async {
    try {
      final assetStore = GetIt.instance.get<AssetStore>();
      final root = await assetStore.assetsRoot();
      final path = assetStore.manifestPath(root, sessionId);
      if (!await assetStore.isAssetPresent(path)) return null;
      return jsonDecode(await File(path).readAsString())
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _tutorFor(String id) async {
    final tracks = (await _manifestJson(id))?['tracks'];
    if (tracks is List) {
      for (final t in tracks) {
        if (t is Map && t['type'] == 'profile' && t['tutor'] != null) {
          return t['tutor'].toString();
        }
      }
    }
    return null;
  }

}

/// The per-session pre-authored MCQ set, read from the downloaded manifest —
/// the SAME questions the in-lesson exercise moments use (one quiz system
/// worn three ways: exercise moment, pre-session assessment, skip gate).
class ManifestQuestionSource implements SessionQuestionSource {
  @override
  Future<List<McqQuestion>> questionsForSession(String sessionId) async {
    try {
      final assetStore = GetIt.instance.get<AssetStore>();
      final root = await assetStore.assetsRoot();
      final path = assetStore.manifestPath(root, sessionId);
      if (!await assetStore.isAssetPresent(path)) return const [];
      final json = jsonDecode(await File(path).readAsString())
          as Map<String, dynamic>;
      final bank = json['questions'];
      final out = <McqQuestion>[];
      final tracks = json['tracks'];
      if (tracks is List) {
        for (final t in tracks) {
          if (t is! Map || t['type'] != 'subtopic_end') continue;
          final exercise = t['exercise'];
          if (exercise is! List) continue;
          for (final entry in exercise) {
            if (entry is Map) {
              out.add(McqQuestion.fromJson(Map<String, dynamic>.from(entry)));
            } else if (entry is String && bank is Map && bank[entry] is Map) {
              out.add(McqQuestion.fromJson(
                  Map<String, dynamic>.from(bank[entry] as Map)
                    ..putIfAbsent('id', () => entry)));
            }
          }
        }
      }
      return out;
    } catch (e) {
      debugPrint('==> ManifestQuestionSource: $e');
      return const [];
    }
  }
}

/// One-time (per app run) LocalNotifications init, shared by every local
/// scheduling path here. The plugin's initialize is not called on any boot
/// path (productivity's tasks page calls it in its own initState), so each
/// caller ensures it lazily; repeat awaits reuse the same future.
Future<void> _ensureLocalNotifications() =>
    _localNotificationsInit ??= LocalNotifications.initialize();
Future<void>? _localNotificationsInit;

/// Stable 31-bit notification id from a logical key (FNV-1a over the code
/// units). The same session always maps to the same platform notification
/// id, so cancel-and-reschedule stays idempotent across schedule refreshes
/// AND app restarts — a random id (the tasks page's own pattern) would
/// orphan the pending notification on every reload.
int _stableNotifId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

/// Host adapter for lms_sdk's [SessionAlarmScheduler] (ADR-005) over
/// comms_sdk's [LocalNotifications]: the device-local "session starts
/// soon" heads-up every student gets without opting in. Failures degrade
/// silently — an alert is decoration on the schedule, never an error
/// surface.
class LocalSessionAlarmScheduler implements SessionAlarmScheduler {
  @override
  Future<void> scheduleSessionAlert({
    required String sessionId,
    required String title,
    required String body,
    required DateTime notifyAt,
  }) async {
    try {
      await _ensureLocalNotifications();
      final notifId = _stableNotifId('session-alert-$sessionId');
      await LocalNotifications.cancelNotification(notifId);
      // A notifyAt already in the past no-ops inside scheduleNotification.
      await LocalNotifications.scheduleNotification(
        id: notifId,
        title: title,
        body: body,
        scheduledDate: notifyAt,
      );
    } catch (e) {
      debugPrint('==> LocalSessionAlarmScheduler: $e');
    }
  }
}

/// Host adapter for lms_sdk's [LessonCalendarSharer] (ADR-005) — the
/// OPT-IN calendar layer on top of the no-opt-in session alerts above.
/// Delivers the generated .ics through the platform share sheet, so the
/// student drops it into whichever calendar app they use and the app never
/// asks for a calendar permission. Same file-share primitive productivity's
/// todo backup uses (share_plus over a temp file).
class IcsLessonCalendarSharer implements LessonCalendarSharer {
  @override
  Future<bool> shareLessonCalendar({
    required String ics,
    required String filename,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(ics);
    final result = await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/calendar')],
      text: 'Your upcoming Supacharge lessons',
    );
    // Dismissed = not exported: the banner keeps the offer available.
    return result.status != ShareResultStatus.dismissed;
  }
}

/// StudyPlanner over ProductivitySDK: reminders land in the todo store, and
/// skips feed the recovery module's procrastination ledger — the same
/// primitive the accountability partner will read (see lms docs ADR).
class ProductivityStudyPlanner implements StudyPlanner {
  /// The registered facade when a host registered one; otherwise the same
  /// direct construction productivity's own tasks page uses
  /// ([prod.TodoRepositoryImpl] over the shared [AppDatabase] singleton).
  /// The previous isRegistered guard silently no-oped every reminder in
  /// the composed app — nothing anywhere registers TodoRepositoryFacade.
  prod.TodoRepositoryFacade get _todos {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<prod.TodoRepositoryFacade>()) {
      return getIt.get<prod.TodoRepositoryFacade>();
    }
    return prod.TodoRepositoryImpl(AppDatabase());
  }

  /// How far before startTime the reminder notification fires — the
  /// StudyPlanner contract's "at (or suitably before) startTime", early
  /// enough to still make the door.
  static const Duration _reminderLead = Duration(minutes: 10);

  /// Writes/updates one todo in the tasks-page schema (deadline / reminder
  /// / notifId / isDone — NOT dueDate), so LMS-created tasks render with
  /// their deadline in the tasks page. Same-id rows upsert: saveTodos
  /// writes by id, so repeat calls update in place instead of stacking.
  Future<void> _upsertTodo({
    required String id,
    required String title,
    required DateTime deadline,
    required bool reminder,
    required String source,
    required String sessionId,
  }) async {
    final repo = _todos;
    final todos = await repo.loadTodos();
    todos.removeWhere((t) => t['id'] == id);
    todos.add({
      'id': id,
      'notifId': _stableNotifId(id),
      'title': title,
      'isDone': false,
      'deadline': deadline.toIso8601String(),
      'reminder': reminder,
      'priority': 'Medium',
      'recurrence': 'None',
      'createdAt': DateTime.now().toIso8601String(),
      'source': source,
      'sessionId': sessionId,
      'subtasks': const [],
    });
    await repo.saveTodos(todos);
  }

  @override
  Future<void> scheduleSessionReminder({
    required String sessionId,
    required String title,
    required DateTime startTime,
  }) async {
    final id = 'session-reminder-$sessionId';
    await _upsertTodo(
      id: id,
      title: title,
      deadline: startTime,
      reminder: true,
      source: 'lms_session_reminder',
      sessionId: sessionId,
    );
    // The notification half of the StudyPlanner contract ("a task with a
    // notification"), previously missing entirely: schedule it the way the
    // tasks page does, under the task's own stable notifId. Fail-open —
    // the task above survives a notification-stack hiccup.
    try {
      await _ensureLocalNotifications();
      final notifId = _stableNotifId(id);
      await LocalNotifications.cancelNotification(notifId);
      final early = startTime.subtract(_reminderLead);
      await LocalNotifications.scheduleNotification(
        id: notifId,
        title: 'Task Reminder',
        body: title,
        scheduledDate: early.isAfter(DateTime.now()) ? early : startTime,
      );
    } catch (e) {
      debugPrint('==> ProductivityStudyPlanner: notification failed: $e');
    }
  }

  @override
  Future<void> recordSkip({
    required String sessionId,
    required DateTime sessionStart,
    required int scorePercent,
  }) async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<prod.RecoveryRepositoryFacade>()) return;
    await getIt.get<prod.RecoveryRepositoryFacade>().logProcrastination(
          ritualId: null,
          scheduledTime: sessionStart,
          delayCount: 1,
          reason: 'session-skip (gate score $scorePercent%)',
        );
  }

  @override
  Future<void> recordAttendanceConfirmation({
    required String sessionId,
    required DateTime sessionStart,
  }) async {
    // Streak-positive signal: nothing in the recovery facade models a
    // confirmation yet (see the weekly-rollup gap in the lms ADR); recorded
    // as an open intention in the todo store for now. No extra
    // notification here — the schedule's session-start alerts already
    // cover confirmed sessions.
    await _upsertTodo(
      id: 'session-confirm-$sessionId',
      title: 'Attend session',
      deadline: sessionStart,
      reminder: false,
      source: 'lms_attendance_confirmation',
      sessionId: sessionId,
    );
  }
}

/// Skill-lesson lookup over the generated `skills_index.json` shipped with
/// the downloaded assets (factory lesson-skills schema — lms_sdk owns the
/// parse; this adapter only locates the bytes). The OFFLINE fallback behind
/// [BackendSkillLessonSource]'s backend-first fetch. Missing/malformed index
/// degrades to an empty one: suggestions vanish, nothing breaks.
class AssetSkillLessonSource implements SkillLessonSource {
  SkillLessonIndex? _cached;

  Future<SkillLessonIndex> _index() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final assetStore = GetIt.instance.get<AssetStore>();
      final root = await assetStore.assetsRoot();
      final file = File('$root/skills_index.json');
      if (!await file.exists()) return SkillLessonIndex.empty;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _cached = SkillLessonIndex.parse(json);
    } catch (e) {
      debugPrint('==> AssetSkillLessonSource: index unavailable: $e');
      return SkillLessonIndex.empty;
    }
  }

  @override
  Future<SkillLessonInfo?> lookup(String skillRef) async =>
      (await _index()).lookup(skillRef);

  @override
  Future<List<SkillLessonInfo>> available() async =>
      (await _index()).servable;
}

/// Knowledge-bite lookup over the generated `knowledge_bites_index.json`
/// shipped with the downloaded assets (#52 — lms_sdk owns the parse; this
/// adapter only locates the bytes). The OFFLINE fallback behind
/// [BackendKnowledgeBiteSource]'s backend-first fetch. Missing/malformed
/// index degrades to an empty one: the offer vanishes, nothing breaks.
class AssetKnowledgeBiteSource implements KnowledgeBiteSource {
  KnowledgeBiteIndex? _cached;

  Future<KnowledgeBiteIndex> _index() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final assetStore = GetIt.instance.get<AssetStore>();
      final root = await assetStore.assetsRoot();
      final file = File('$root/knowledge_bites_index.json');
      if (!await file.exists()) return KnowledgeBiteIndex.empty;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _cached = KnowledgeBiteIndex.parse(json);
    } catch (e) {
      debugPrint('==> AssetKnowledgeBiteSource: index unavailable: $e');
      return KnowledgeBiteIndex.empty;
    }
  }

  @override
  Future<List<KnowledgeBite>> bitesFor(String lessonSlug) async =>
      (await _index()).bitesFor(lessonSlug);
}

/// Demo-only bite source (`--dart-define=IS_DEMO=true`): answers ONE real
/// rehoused bite (factory
/// `lessons/curriculum/CAPS/maths/knowledge_bites/grade11/
/// lines-gradients-and-inclination/dbe-maths-g12-p2-2025-nov-q3-1/`,
/// verbatim) for EVERY lesson slug, so the end-of-lesson offer → accept →
/// Library attachment → reading page loop is previewable on the demo
/// lesson without a published index. Never used in production.
class DemoKnowledgeBiteSource implements KnowledgeBiteSource {
  static const _questionMd = '''
# Past-Paper Worked Example — Q3.1

**Source:** Department of Basic Education — Grade 12 Maths P2, November 2025, question Q3.1.

**© Department of Basic Education, 2025. Reproduced for educational use with attribution.**

## Question (2 marks)

In the diagram, P(-1 ; 8), Q(-4 ; -6) and R(12 ; 2) are the vertices of ΔPQR. The angle of inclination of QR is θ. Calculate the length of QR. Leave your answer in simplified surd form.

## Method

distance formula

## Memo working

Apply the distance formula to Q(-4 ; -6) and R(12 ; 2): QR = sqrt((-4 - 12)^2 + (-6 - 2)^2) = sqrt(256 + 64) = √320 = 8√5.

## Answer (per marking guidelines)

QR = √320 = 8√5 units
''';

  @override
  Future<List<KnowledgeBite>> bitesFor(String lessonSlug) async => [
        KnowledgeBite(
          lessonSlug: lessonSlug,
          biteSlug: 'dbe-maths-g12-p2-2025-nov-q3-1',
          subject: 'maths',
          grade: 11,
          title: 'Past-Paper Worked Example — Q3.1',
          questionMd: _questionMd,
        ),
      ];
}

/// Opens a skill lesson's on-demand content in the lesson player. The
/// card id doubles as the content/session id for asset lookup; isRecording
/// because skill lessons are Library playback, never a live door.
/// Joins a scheduled session, with the NON-FORCING pre-lesson skill nudge:
/// when the session's topic carries `requires_skills`, offer a quick review
/// of each resolvable skill first — always with "Start the lesson" a single
/// tap away. Unresolvable refs (no servable content) never block the join.
/// [openInPlane] is the schedule shell's seam for the approved session
/// plane flow (frame 52): at plane widths the session opens BESIDE the
/// schedule instead of being pushed over it. Null — a phone, or any
/// caller without a flow — pushes the route exactly as before.
Future<void> _joinSession(
    BuildContext context, ScheduledSession session,
    {VoidCallback? openInPlane}) async {
  void pushLesson() {
    if (openInPlane != null) {
      openInPlane();
      return;
    }
    context.router.push(
      LessonRoute(
        sessionId: session.sessionId,
        lessonId: session.lessonId,
        tutorName: session.tutorName,
      ),
    );
  }

  if (session.requiresSkills.isEmpty) {
    pushLesson();
    return;
  }
  final SkillLessonSource skills = DemoSession.demoActive
      ? DemoSkillLessonSource()
      : BackendSkillLessonSource(fallback: AssetSkillLessonSource());
  final resolved = <SkillLessonInfo>[];
  for (final ref in session.requiresSkills) {
    final info = await skills.lookup(ref);
    if (info != null && info.servable) resolved.add(info);
  }
  if (!context.mounted) return;
  if (resolved.isEmpty) {
    pushLesson();
    return;
  }
  await SkillReviewPrompt.show(
    context,
    skills: resolved,
    onReview: (skill) => _openSkillLesson(context, skill),
    onContinue: pushLesson,
  );
}

/// Opens a skill as its dedicated REVIEW flow (diagnostic → recap → exit
/// check), never the lesson player — a skill is a refresher, not a first
/// teaching. Pushed as a plain page on the current navigator (same pattern
/// as [showSubscribePage]); chain-aware: a prerequisite chip inside the
/// review opens that skill's own review on top.
Future<void> _openSkillLesson(
    BuildContext context, SkillLessonInfo skill) async {
  // Authored review sets (diagnostic/recap/exit, factory Level-3 form)
  // ride the published skills_index entries; refs without one fall back to
  // the skill's own CAPS fields via the null branch below.
  final SkillReviewSource source = DemoSession.demoActive
      ? DemoSkillReviewSource()
      : BackendSkillReviewSource();
  final content = await source.contentFor(skill.skillRef) ??
      SkillReviewContent(skillRef: skill.skillRef);
  // Decision #27: resolve the covered_by full-lesson affordance against
  // subscription history (demo fakes the three states; production resolves
  // none until history periods are queryable — product log #25).
  final CoveredLessonResolver covered = DemoSession.demoActive
      ? DemoCoveredLessonResolver()
      : NoCoveredLessonResolver();
  final coveredLesson = await covered.resolve(skill);
  // Prerequisite chips resolve through the SAME source the join flow uses —
  // backend index first, asset-file fallback in real builds, never the
  // demo catalog.
  final SkillLessonSource skills = DemoSession.demoActive
      ? DemoSkillLessonSource()
      : BackendSkillLessonSource(fallback: AssetSkillLessonSource());
  final prereqs = <String, SkillLessonInfo>{};
  for (final ref in skill.requiresSkills) {
    final info = await skills.lookup(ref);
    if (info != null) prereqs[ref] = info;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (ctx) => SkillPlayerPage(
        skill: skill,
        content: content,
        // #11.5: a completed review lands in the local ledger — the
        // pre-class reminder and the study-ahead list both read it.
        onReviewCompleted: () => KvSkillReviewLedger(
          now: GetIt.instance.isRegistered<ServerClock>()
              ? GetIt.instance.get<ServerClock>().now
              : null,
        ).recordReviewed(skill.skillRef),
        coveredLesson: coveredLesson,
        onWatchFullLesson: coveredLesson == null || !coveredLesson.entitled
            ? null
            : () => ctx.router.push(LessonRoute(
                  sessionId: coveredLesson.sessionId,
                  tutorName: coveredLesson.attendedTutor ?? 'Tutor',
                  isRecording: true,
                )),
        prerequisiteName: (ref) =>
            prereqs[ref]?.displayName ?? ref.split('.').last,
        onOpenPrerequisite: (ref) {
          final prereq = prereqs[ref];
          if (prereq != null) _openSkillLesson(context, prereq);
        },
      ),
    ),
  );
}

/// Demo-only covered-lesson resolver (`--dart-define=IS_DEMO=true`): fakes
/// the three decision-#27 states so the full-lesson affordance is fully
/// previewable —
///   * factorisation: entitled AND attended last year → rewatch framing;
///   * formulae / contour: entitled, never attended → plain "watch";
///   * trig ratios: NOT entitled (no subscription in that period) → locked,
///     visible, explained, no upsell.
/// Never used in production — real resolution needs subscription history
/// periods server-side (product log #25); until then real builds get
/// [NoCoveredLessonResolver].
class DemoCoveredLessonResolver implements CoveredLessonResolver {
  @override
  Future<CoveredLessonInfo?> resolve(SkillLessonInfo skill) async {
    final coverage = skill.coveredBy.isEmpty ? null : skill.coveredBy.first;
    if (coverage == null) return null;
    final now = DateTime.now();
    switch (skill.skillRef) {
      case 'maths.factorisation_techniques':
        return CoveredLessonInfo(
          coverage: coverage,
          sessionId: 'demo-covered-factorisation',
          entitled: true,
          attendedAt: DateTime(now.year - 1, 3, 14),
          attendedTutor: 'Mr Dlamini',
        );
      case 'maths.trig_ratios':
        return CoveredLessonInfo(
          coverage: coverage,
          sessionId: 'demo-covered-trig',
          entitled: false,
          lockReason:
              'From a period before your subscription started. Your plan '
              'covers full lessons from the periods you were subscribed.',
        );
      default:
        return CoveredLessonInfo(
          coverage: coverage,
          sessionId: 'demo-covered-${skill.skillRef.split('.').last}',
          entitled: true,
        );
    }
  }
}

/// Production covered-lesson resolver until subscription-history periods are
/// queryable server-side (product log #25): resolves nothing, so no
/// full-lesson affordance renders rather than a fabricated entitlement.
class NoCoveredLessonResolver implements CoveredLessonResolver {
  @override
  Future<CoveredLessonInfo?> resolve(SkillLessonInfo skill) async => null;
}

/// Plays the local "this live meeting is being recorded" notice — fired on
/// every live-session join, ALONE, behind the recording gate overlay; the
/// returned future completes when the audio finishes so the lesson only
/// starts after (playing it unconditionally beats guessing when the
/// recording started). Local playback only.
Future<void> playRecordingNotice() async {
  final player = AudioPlayer();
  try {
    final done = player.onPlayerComplete.first;
    await player.play(AssetSource('audio/recording_notice.wav'));
    await done.timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('==> recording notice failed: $e');
  } finally {
    unawaited(player.dispose());
  }
}

/// The app's four root tabs behind the floating pill nav (nav_floating.html
/// recovered spec; base_sdk owns the component, the host owns the IA).
List<FloatingNavTab> get kSupachargeNavTabs => [
  FloatingNavTab(
    selectIcon: Remix.calendar_2_fill,
    unSelectIcon: Remix.calendar_2_line,
    label: AppHelpers.getTranslation(TrKeys.schedule),
  ),
  FloatingNavTab(
    selectIcon: Remix.book_open_fill,
    unSelectIcon: Remix.book_open_line,
    label: AppHelpers.getTranslation(TrKeys.library),
  ),
  FloatingNavTab(
    selectIcon: Remix.compass_3_fill,
    unSelectIcon: Remix.compass_3_line,
    label: AppHelpers.getTranslation(TrKeys.discover),
  ),
  FloatingNavTab(
    selectIcon: Remix.user_fill,
    unSelectIcon: Remix.user_line,
    label: AppHelpers.getTranslation(TrKeys.profile),
  ),
];

/// Documented launch prices (supacharge-business.md §Plans) — DEMO DISPLAY
/// ONLY since plans became server-configurable records (LMS Plan, seeded
/// from these same documented rates). Real (non-demo) surfaces render the
/// server catalog (`rlms.api.billing.plans`) and the rates LMS Settings
/// holds (`base_monthly_rate` / `partner_monthly_rate`, fallbacks
/// 299/249); nothing in the real path prices from these constants.
///
/// The partner rate is a flat R50 off the standard rate, charged to
/// whoever actually pays (`billing_rules.charge_per_student`). It is NOT a
/// percentage, and it does NOT stack on the annual plan, whose two-free-
/// months discount already buys the same 12-month commitment.
const int kStandardMonthlyRate = 299;
const int kPartnerMonthlyRate = 249;
const int kStandardYearlyRate = 2990; // 10 x standard, two months free
const int kHolidayProgrammeRate = 449; // separate premium product

/// A promotional R100/month founder rate was previously wired in as if it
/// were the standing partner rate, which made the partner billing summary
/// quote a parent less than half of what `charge_per_student` would bill
/// them. It is a promotion to be granted per subscription (and held while
/// a payment streak lasts), not a global rate — so it does not belong in
/// this table until there is somewhere per-subscription to store it.
const int kFounderPromoMonthlyRate = 100;

/// Which side of the app the viewer is on, for the ONE surface both sides
/// share.
///
/// Production answers from the account role. Demo cannot: there is no backend
/// to source a role from, so a parent reaches the partner side by navigation
/// alone (see IntroRouteView._onComplete) and LocalStorage's role is never
/// 'partner' there. Every partner page except Discover hard-codes its nav, so
/// Discover was the only one that had to ask — and in demo it always heard
/// "student", which both swapped its nav and grade-filtered its deck.
///
/// So the tab switches latch the side they move to. Production is unaffected:
/// the role check already answers before the latch is consulted.
bool _demoPartnerSide = false;

/// True when the viewer is a parent/partner rather than a student.
bool get isPartnerViewer =>
    LocalStorage.getUser()?.role == 'partner' ||
    (DemoSession.demoActive && _demoPartnerSide);

/// Root-tab navigation: replace (not push) so tabs never stack on each
/// other — the back gesture leaves the tab set, it doesn't walk it.
void openSupachargeNavTab(BuildContext context, int index, int current) {
  if (index == current) return;
  // Moving onto a student tab: this is the student side.
  _demoPartnerSide = false;
  switch (index) {
    case 0:
      context.router.replace(const ScheduleRoute());
    case 1:
      context.router.replace(const LibraryRoute());
    case 2:
      context.router.replace(TutorDiscoveryRoute());
    case 3:
      context.router.replace(const StudentProfileRoute());
  }
}

/// Partner-side bottom nav tab set (P3.1). The accountability-partner persona
/// has a far smaller surface than the student — just the weekly reports and
/// the add-a-student flow. Two tabs, no subscription/profile slot: a partner
/// account has no learning surface to reach.
/// Grades a parent can browse on their Subjects tab. Fixed rather than derived
/// from what loaded: the catalog is fetched per grade, so this is the ask-list,
/// not a summary of the answer.
const List<int> kPartnerGradeOptions = [10, 11, 12];

List<FloatingNavTab> get kSupachargePartnerNavTabs => [
  FloatingNavTab(
    selectIcon: Remix.line_chart_fill,
    unSelectIcon: Remix.line_chart_line,
    label: AppHelpers.getTranslation(TrKeys.reports),
  ),
  // Adding a student already has its own entry on the dashboard, so the slot
  // goes to Subjects — what a parent is actually buying, browsable by grade.
  FloatingNavTab(
    selectIcon: Remix.book_2_fill,
    unSelectIcon: Remix.book_2_line,
    label: AppHelpers.getTranslation(TrKeys.subjects),
  ),
  // A parent browses the same team deck a student does, so Discover is a
  // partner tab too. Without it the list was one short of what
  // openSupachargePartnerNavTab switches on, so the third tab said "Profile"
  // and opened Discovery — which is why the partner side looked like it lost
  // Discover and flipped to the student nav on a Profile tap.
  FloatingNavTab(
    selectIcon: Remix.compass_3_fill,
    unSelectIcon: Remix.compass_3_line,
    label: AppHelpers.getTranslation(TrKeys.discover),
  ),
  FloatingNavTab(
    selectIcon: Remix.user_fill,
    unSelectIcon: Remix.user_line,
    label: AppHelpers.getTranslation(TrKeys.profile),
  ),
];

/// Root-tab navigation for the partner side: replace (not push) so the
/// partner tabs never stack on each other — same rule as
/// [openSupachargeNavTab].
void openSupachargePartnerNavTab(
    BuildContext context, int index, int current) {
  if (index == current) return;
  // Moving onto a partner tab: this is the partner side. Discover reads this
  // to keep the partner nav (and its unfiltered, every-grade deck) instead of
  // falling back to the student view — see [isPartnerViewer].
  _demoPartnerSide = true;
  switch (index) {
    case 0:
      context.router.replace(const PartnerDashboardRoute());
    case 1:
      context.router.replace(CourseCatalogRoute());
    case 2:
      context.router.replace(TutorDiscoveryRoute());
    case 3:
      context.router.replace(const PartnerProfileRoute());
  }
}

/// The partner-side floating nav — mirrors [SupachargeNav]'s overlay behavior
/// with the fixed two-tab partner set (no state-swapped slot).
class SupachargePartnerNav extends StatelessWidget {
  final int currentIndex;

  const SupachargePartnerNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return FloatingBottomNav(
      mode: FloatingNavTabsMode(
        tabs: kSupachargePartnerNavTabs,
        currentIndex: currentIndex,
        onSelect: (i) {
          if (i == currentIndex) return;
          openSupachargePartnerNavTab(context, i, currentIndex);
        },
      ),
    );
  }
}

/// The bottom nav with the 4th slot's identity swapped by subscription
/// state (decision #24), same if/else-by-state shape as the wallet/liked
/// precedent: a non-subscriber (guest OR logged-in-unsubscribed) sees a
/// "Subscribe" slot that opens PlansSheet directly — no login gate first,
/// same principle as decision #22 (seeing pricing is free, only purchase
/// needs an account); a subscriber sees the normal "Profile" slot. The
/// first three tabs never change.
class SupachargeNav extends StatefulWidget {
  final int currentIndex;

  /// When set, a tap on a slot other than the current one routes through this
  /// instead of the default tab switch. The subscription page — presented as
  /// an overlay pushed over a tab — uses it to dismiss itself first, then
  /// switch the tab underneath, so its bottom nav behaves like every other
  /// page's while still popping cleanly.
  final void Function(int index)? onTabOverride;

  const SupachargeNav({
    super.key,
    required this.currentIndex,
    this.onTabOverride,
  });

  @override
  State<SupachargeNav> createState() => _SupachargeNavState();
}

class _SupachargeNavState extends State<SupachargeNav> {
  // The real gate's answer, from the KV access status. A demo session is
  // NOT folded in here: DemoSession.demoActive is read in build() instead,
  // per frame, because a marked account can sign in (or sign out) long
  // after this state was created and a bool captured here would pin the
  // slot to whichever side happened to be active at mount.
  bool _subscribed = false;

  /// Whether the 4th slot is Profile rather than Subscribe. A getter, not a
  /// field: DemoSession.demoActive is re-read on every access — once per
  /// build for the slot itself and again inside onSelect when the slot is
  /// tapped, which can be many frames later and on the other side of a
  /// demo sign-in or sign-out.
  bool get _profileSlot => DemoSession.demoActive || _subscribed;

  @override
  void initState() {
    super.initState();
    // A demo session already resolves the slot to Profile in build(), so
    // there is nothing for the KV read to add; leaving _subscribed false
    // also means a session that ENDS falls back to the real gate's
    // conservative answer (Subscribe) rather than a leftover true.
    if (DemoSession.demoActive) return;
    KvAccessStatusSource().current().then((status) {
      if (mounted) {
        setState(() =>
            _subscribed = status.subscription == SubscriptionState.active);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // A demo session forces the 4th slot to Profile so the profile surface
    // is reachable without a real subscribed account; production keeps the
    // real gate.
    final fourth = _profileSlot
        ? FloatingNavTab(
            selectIcon: Remix.user_fill,
            unSelectIcon: Remix.user_line,
            label: AppHelpers.getTranslation(TrKeys.profile),
          )
        : FloatingNavTab(
            selectIcon: Remix.vip_crown_fill,
            unSelectIcon: Remix.vip_crown_line,
            label: AppHelpers.getTranslation(TrKeys.subscribe),
          );
    return FloatingBottomNav(
      mode: FloatingNavTabsMode(
        tabs: [...kSupachargeNavTabs.take(3), fourth],
        currentIndex: widget.currentIndex,
        onSelect: (i) {
          if (i == widget.currentIndex) return;
          // Overlay hosts (the subscription page) dismiss themselves first,
          // then switch — see [SupachargeNav.onTabOverride].
          if (widget.onTabOverride != null) {
            widget.onTabOverride!(i);
            return;
          }
          // The swapped slot: unsubscribed opens the plans as their own solid
          // full-screen page (UI #2), pushed as a fullscreen dialog on THIS
          // tab's navigator — it covers the shell completely (no
          // bleed-through) yet pops straight back to this exact tab, so no
          // navigation context is lost.
          if (i == 3 && !_profileSlot) {
            showSubscribePage(context);
            return;
          }
          openSupachargeNavTab(context, i, widget.currentIndex);
        },
      ),
    );
  }
}

/// Opens the plans surface (decision #24 + UI #2) as a solid full-screen page
/// pushed on the current tab's navigator as a fullscreen dialog: it covers the
/// shell completely — no bleed-through from the tab beneath — yet dismissing
/// pops straight back to the same tab. Both entry points (the nav Subscribe
/// slot and the tutor-discovery commit funnel) route here.
Future<void> showSubscribePage(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const SubscribePage(),
    ),
  );
}

/// The plans page (decision #24 + UI #2): its own plan load on a solid, full
/// dark surface, dismissable back to the tab the student came from. Purchase
/// rides subscriptions_sdk's real flow.
class SubscribePage extends StatefulWidget {
  const SubscribePage({super.key});

  @override
  State<SubscribePage> createState() => _SubscribePageState();
}

class _SubscribePageState extends State<SubscribePage> {
  // Both sides are built once and kept, and the side is chosen per read:
  // SubscriptionsLessonPlansAdapter caches its last catalog fetch so
  // purchase(planId) can resolve the chosen plan without a second round
  // trip, so a fresh instance per read would go cold. The DemoSession read
  // itself is never captured — a sign-in mid-page lands on the very next
  // call, the same per-call switch SessionSwitchingLmsRepository uses.
  final LessonPlans _demoPlans = DemoLessonPlans();
  final LessonPlans _serverPlans = SubscriptionsLessonPlansAdapter();
  LessonPlans get _plans =>
      DemoSession.demoActive ? _demoPlans : _serverPlans;
  bool _loading = true;
  bool _purchasing = false;
  LessonPurchaseOutcome? _outcome;

  /// The server's own refusal text (it names exact amounts — the top-up
  /// message says how much this checkout needs). Shown verbatim by the
  /// sheet; never composed here.
  String? _outcomeMessage;

  /// Whether a partner viewer has at least one linked student — with one,
  /// they see the student plans and sponsor-checkout for their students;
  /// without, the "add your student(s)" panel.
  bool _hasLinkedStudent = false;
  List<LessonPlanOption> _options = const [];

  @override
  void initState() {
    super.initState();
    _loadTrack();
    _loadLinkedStudents();
    _plans.getPlans().then((plans) {
      if (mounted) {
        setState(() {
          _options = plans;
          _loading = false;
        });
      }
    }).catchError((Object _) {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _loadLinkedStudents() async {
    if (!isPartnerViewer) return;
    try {
      final students = DemoSession.demoActive
          ? await _DemoPartnerReportSource().students()
          : await HttpPartnerReportSource().students();
      if (mounted) {
        setState(() => _hasLinkedStudent = students.isNotEmpty);
      }
    } catch (e) {
      debugPrint('==> SubscribePage: linked students load failed: $e');
    }
  }

  /// Decision #29: the chosen maths track. Loaded server-first
  /// (`student_my_maths_track`) so a reinstall or second device preselects
  /// and locks the track the server would enforce anyway, with the shared
  /// KV as the offline fallback and cache; persisted to both the moment
  /// it's picked, so it survives into the payment path (the payment bundle
  /// reads the same key; the backend enforces exclusivity).
  MathsTrack? _track;
  MathsTrack? _lockedTrack;

  /// Same lazy resolution as the capture adapters above (ensures lms_sdk's
  /// DI is registered whatever entry path pushed this page).
  LmsRepository get _lmsRepository {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<LmsRepository>()) {
      LmsSdkDependencies.register(getIt);
    }
    return getIt.get<LmsRepository>();
  }

  Future<void> _loadTrack() async {
    MathsTrack? local;
    try {
      final row = await AppDbScheduleStore().get('lms_maths_track', 'value');
      local = MathsTrack.fromName(row?['track']?.toString());
    } catch (_) {}
    try {
      final status = await _lmsRepository.myMathsTrack();
      final server = status.track ?? status.chosen;
      if (server != null) {
        // Server wins: it enforces exclusivity, so its record is what a
        // stale local cache must converge on. Refresh the KV the payment
        // bundle reads to match.
        if (mounted) {
          setState(() {
            _track = server;
            _lockedTrack = status.locked ? server : null;
          });
        }
        if (local != server) {
          try {
            await AppDbScheduleStore().put('lms_maths_track', 'value', {
              'track': server.name,
              'subject': server.subject,
            });
          } catch (_) {/* best-effort local cache */}
        }
        return;
      }
      // Server has no track but a pre-wiring local pick exists: push it up
      // once, best-effort, so choices made before this wiring existed sync.
      if (local != null && !status.locked) {
        try {
          await _lmsRepository.setMathsTrack(local);
        } catch (e) {
          debugPrint('==> SubscribePage: track migration failed: $e');
        }
      }
    } catch (_) {/* offline: fall back to the local pick as before */}
    if (mounted && local != null) {
      final held = local;
      setState(() {
        _track = held;
        _lockedTrack = held;
      });
    }
  }

  Future<void> _selectTrack(MathsTrack track) async {
    // A track already held can't be swapped here — the picker locks the
    // other option, and the backend is the real guard.
    if (_lockedTrack != null) return;
    setState(() => _track = track);
    try {
      await AppDbScheduleStore().put('lms_maths_track', 'value', {
        'track': track.name,
        'subject': track.subject,
      });
    } catch (e) {
      debugPrint('==> SubscribePage: track persist failed: $e');
    }
    // Best-effort backend record on top (LmsSchoolCaptureAdapter posture):
    // the KV pick above already rides the checkout, and the server's
    // exclusivity writer re-records it there — a refusal or outage here
    // never breaks the sheet.
    try {
      await _lmsRepository.setMathsTrack(track);
    } catch (e) {
      debugPrint('==> SubscribePage: track backend sync failed: $e');
    }
  }

  Future<void> _purchase(LessonPlanOption plan) async {
    setState(() {
      _purchasing = true;
      // A fresh attempt never wears the previous one's outcome.
      _outcome = null;
      _outcomeMessage = null;
    });
    // The track is already persisted (see _selectTrack); the adapter reads
    // the same KV and sends it with the checkout, so the server records it
    // through its exclusivity-enforcing writer BEFORE charging.
    final result = await _plans.purchase(plan.id);
    if (!mounted) return;
    setState(() {
      _purchasing = false;
      _outcome = result.outcome;
      _outcomeMessage = result.message;
    });
    if (result.outcome == LessonPurchaseOutcome.completed) {
      // Server-confirmed: name the total the SERVER charged (its number,
      // verbatim — never computed here) and return to the tab.
      final total = result.total;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(total == null
            ? AppHelpers.getTranslation(TrKeys.planActive)
            : '${AppHelpers.getTranslation(TrKeys.planActive)} · R$total'),
      ));
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParent = LocalStorage.getUser()?.role == 'partner';
    // Solid full page (UI #2), not a rounded sheet: a Scaffold with an opaque
    // dark surface so nothing behind can show through. The header X
    // (onDismiss) pops back to the originating tab.
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: Stack(
        children: [
          SafeArea(
            child: PlansSheet(
              loading: _loading,
              plans: _options,
              purchasing: _purchasing,
              outcome: _outcome,
              outcomeMessage: _outcomeMessage,
              plansAvailable: true,
              viewerTier: isParent ? PlanTier.partner : PlanTier.student,
              // A partner with a linked student falls through to the plans
              // and sponsor-checkouts for their students; without one they
              // are asked to add their student(s) first.
              hasLinkedStudent: _hasLinkedStudent,
              // Same pop-then-route dance as onTabOverride below: this page
              // is a dialog pushed over a tab, so leave it first.
              onAddStudent: isParent
                  ? () {
                      final router = context.router;
                      Navigator.of(context).maybePop();
                      router.replace(const AddStudentRoute());
                    }
                  : null,
              // Decision #29: students choose their maths track here; a
              // parent buys for a student and picks no track of their own.
              selectedTrack: _track,
              lockedTrack: _lockedTrack,
              onSelectTrack: isParent ? null : _selectTrack,
              onPurchase: _purchase,
              // #33: the insufficient-funds refusal's door to add money.
              // The top-up screen ships in wallet_sdk and registers the
              // /wallet-topup route; a shell composed without it lands in
              // onFailure/catch and stays put — the refusal text still
              // names the exact amount, so nothing breaks.
              onTopUp: () {
                try {
                  context.router.pushNamed(
                    '/wallet-topup',
                    onFailure: (failure) => debugPrint(
                        '==> wallet top-up route unavailable: $failure'),
                  );
                } catch (e) {
                  debugPrint('==> wallet top-up route unavailable: $e');
                }
              },
              onDismiss: () => Navigator.of(context).maybePop(),
            ),
          ),
          // Same floating nav every other page carries. This page is an
          // overlay pushed over a tab, so a tab tap must pop it first, then
          // switch the tab underneath (onTabOverride); the current slot is
          // the Subscribe slot.
          Align(
            alignment: Alignment.bottomCenter,
            child: SupachargeNav(
              currentIndex: 3,
              onTabOverride: (i) {
                final router = context.router;
                Navigator.of(context).maybePop();
                switch (i) {
                  case 0:
                    router.replace(const ScheduleRoute());
                  case 1:
                    router.replace(const LibraryRoute());
                  case 2:
                    router.replace(TutorDiscoveryRoute());
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Host route shell for [SchedulePage] (lms_sdk-resident page). Wrapped in
/// the January grade-rollover gate: a stored grade from a previous academic
/// year hides the schedule behind [GradeRolloverGate] until the student
/// confirms the new year's grade. Confirming stores the previous grade +
/// year alongside — last year's attendance and library entries stay intact
/// under it (they filter by grade; skill covered_by still reaches them),
/// and a repeating student's new-year records never overwrite last year's
/// (that history is the improvement baseline).
@RoutePage(name: 'ScheduleRoute')
class ScheduleRouteView extends StatefulWidget {
  const ScheduleRouteView({super.key});

  @override
  State<ScheduleRouteView> createState() => _ScheduleRouteViewState();
}

class _ScheduleRouteViewState extends State<ScheduleRouteView> {
  bool _checked = false;
  bool _needsRollover = false;

  /// The live session holding a plane beside the schedule (frame 52).
  /// Null = none open. Ignored on one-plane screens, where joining
  /// pushes the LessonRoute exactly as it always did — a phone plane is
  /// already the schedule's, and the ruling is that the schedule stays.
  ScheduledSession? _session;

  /// Whether the plan opens the Holiday Programme at all
  /// (my_entitlements.holiday_access). Starts true and only an explicit
  /// None hides the glance doorway — unresolvable fails open, same as the
  /// server side.
  bool _holidayInPlan = true;

  /// Badge value, or null for no badge — resolved once via
  /// [resolveContentCurriculumLabel]: the student's stored choice only
  /// while the served content actually honours it. Starts at the app
  /// constant, which is served, so a CAPS student never sees it flicker.
  String? _curriculum = kSupachargeCurriculum;

  @override
  void initState() {
    super.initState();
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<LmsRepository>()) {
      LmsSdkDependencies.register(getIt);
    }
    getIt.get<LmsRepository>().myGrade().then((status) {
      if (mounted) {
        setState(() {
          _checked = true;
          _needsRollover = status.needsConfirmation;
        });
      }
    }).catchError((Object e) {
      debugPrint('==> ScheduleRouteView: grade check failed: $e');
      // Never strand the student outside their schedule on a lookup error.
      if (mounted) setState(() => _checked = true);
    });
    resolveContentCurriculumLabel().then((c) {
      if (mounted && c != _curriculum) setState(() => _curriculum = c);
    });
    HttpEntitlementsSource().summary().then((summary) {
      final excluded = summary.holidayAccess == HolidayAccessLevel.none;
      if (mounted && excluded) setState(() => _holidayInPlan = false);
    }).catchError((Object e) {
      // Unresolvable stays shown — the page itself gates on the level too.
      debugPrint('==> ScheduleRouteView: holiday access check failed: $e');
    });
  }

  Future<void> _storeRollover(
      int newGrade, int? previousGrade, bool repeating) async {
    try {
      final store = AppDbScheduleStore();
      final row = await store.get('lms_grade', 'value') ?? {};
      // Decision #31: preserve last year's numbers as the progress card's
      // comparison baseline. Repeat-path only — a student moving up has no
      // like-for-like grade to compare against.
      final baseline = repeating ? await _lastYearBaseline() : null;
      await store.put('lms_grade', 'value', {
        ...row,
        'grade': newGrade,
        'year': DateTime.now().year,
        if (previousGrade != null) 'previousGrade': previousGrade,
        if (previousGrade != null) 'previousYear': DateTime.now().year - 1,
        'repeating': repeating,
        if (baseline != null) 'lastYearBaseline': baseline.toJson(),
      });
    } catch (e) {
      debugPrint('==> ScheduleRouteView: rollover store failed: $e');
    }
  }

  /// Last year's attendance baseline. Production reads the preserved
  /// previous-grade records via `student_last_year_baseline` (decision #31);
  /// demo ships representative numbers (matching the rollover gate's own
  /// diagnostic), and any endpoint failure/empty answer falls back to the
  /// same pre-endpoint behavior — demo numbers in demo, no baseline in prod.
  Future<LastYearBaseline?> _lastYearBaseline() async {
    LastYearBaseline? remote;
    try {
      remote =
          await GetIt.instance.get<LmsRepository>().lastYearBaseline();
    } catch (e) {
      // Defensive: the shipped repositories never throw here, but a host
      // override might — and a baseline fetch must never break rollover.
      debugPrint('==> ScheduleRouteView: last-year baseline fetch failed: $e');
    }
    if (remote != null) return remote;
    if (!DemoSession.demoActive) return null;
    return LastYearBaseline(
      year: DateTime.now().year - 1,
      attendanceRatePercent: 46,
      ratesByWindow: const {
        ProfileWindow.day: 5,
        ProfileWindow.week: 38,
        ProfileWindow.month: 46,
      },
      sessionsAttended: 61,
      sessionsScheduled: 132,
      quizzesSkipped: 38,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The approved session plane flow (frame 52). The schedule is the
    // flow's root and KEEPS its plane; the session's own claim
    // (LessonPlayerPage.span) takes the next one and grows into a third
    // when there is one going spare, which is where the attendees panel
    // lands. On a phone the flow hosts the schedule alone and joining
    // pushes the route, unchanged.
    return LayoutBuilder(builder: (context, constraints) {
      final bool inPlanes =
          LmsSessionPlaneFlow.holdsSession(constraints.maxWidth);
      final ScheduledSession? session = inPlanes ? _session : null;
      return Stack(
        children: [
          Positioned.fill(
            child: LmsSessionPlaneFlow(
              sessionOpen: session != null,
              scheduleBuilder: (context) =>
                  _buildSchedule(context, inPlanes: inPlanes),
              sessionBuilder: (context) => LessonRouteView(
                // Keyed by the session so joining a different airing
                // rebuilds the player rather than reusing the last
                // one's state.
                key: ValueKey('lesson-plane-${session!.sessionId}'),
                sessionId: session.sessionId,
                lessonId: session.lessonId,
                tutorName: session.tutorName,
                // No route to pop: the board's header exit closes the
                // plane and the schedule is already beside it.
                onLeave: () => setState(() => _session = null),
              ),
            ),
          ),
          // Floating pill nav (Phase 1 component) — content scrolls
          // under it. Two-state nav (12d): while the session holds a
          // plane the root tabs fold away and the lesson's own session
          // bar is the app's one bar, exactly as on a phone.
          //
          // The grade-rollover gate is the third state: it is a BLOCKING
          // screen (the schedule stays hidden behind it until the student
          // says which grade they are in now), and its confirm CTA sits at
          // the bottom of its own Scaffold — directly under this floating
          // pill, which is painted over the page and therefore wins the hit
          // test. A tap aimed at "That's me — Grade 12" landed on the nav
          // instead and switched to the Discover tab, so the grade was
          // never confirmed: the guided tour's `schedule` step captured the
          // tutor-discovery screen (byte-identical to its later `tutors`
          // step), and every screen after it still showed last year's
          // grade. The gate has nowhere to navigate to anyway — hiding the
          // nav while it is up is what "blocking" already meant.
          if (session == null && !_needsRollover)
            const Align(
              alignment: Alignment.bottomCenter,
              child: SupachargeNav(currentIndex: 0),
            ),
        ],
      );
    });
  }

  /// The schedule itself — the flow's root plane.
  Widget _buildSchedule(BuildContext context, {required bool inPlanes}) {
    final getIt = GetIt.instance;
    if (!_checked) {
      return Scaffold(
        backgroundColor: AppStyle.surfaceDark,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_needsRollover) {
      return GradeRolloverGate(
        deps: StudentGradeDeps(repository: getIt.get<LmsRepository>()),
        // Demo: representative last-year numbers for the repeat path
        // (46% attendance, skipped quick checks — the "why" mirror).
        performance: DemoSession.demoActive
            ? () async => const RolloverPerformance(
                  attendanceRatePercent: 46,
                  sessionsAttended: 61,
                  sessionsScheduled: 132,
                  quizzesSkipped: 38,
                )
            : null,
        onConfirmed: (newGrade, previousGrade, repeating) async {
          await _storeRollover(newGrade, previousGrade, repeating);
          if (mounted) setState(() => _needsRollover = false);
        },
      );
    }
    return SchedulePage(
      deps: ScheduleScreenDeps(
        schedule: DemoSession.demoActive
            ? DemoScheduleSource()
            : ReplayScheduleSource(),
        questions: ManifestQuestionSource(),
        planner: ProductivityStudyPlanner(),
        profile: ProfileStore(),
        behavior: RecoveryStudyBehaviorSignal(),
        alertStore: PartnerAlertStore(),
        // P3.2: backend attendance-event sync — powers the cross-device
        // partner report fields and the server-side streak-break alert.
        repository: getIt.get<LmsRepository>(),
        skills: DemoSession.demoActive ? DemoSkillLessonSource() : AssetSkillLessonSource(),
        // #11.3: joined airings feed the inferred slot preference the
        // end-of-session prompt reads.
        slotPreference:
            KvSlotPreferenceStore(now: getIt.get<ServerClock>().now),
        // #11.5: the pre-class reminder's "reviewed" record.
        skillLedger:
            KvSkillReviewLedger(now: getIt.get<ServerClock>().now),
        // One-way operator announcements (schedule changes, holiday
        // programme news) riding the glance card — loaded with every
        // schedule refresh; failures are silent to the student.
        announcements: HttpAnnouncementSource(),
        // Device-local session-start alerts (no opt-in): every schedule
        // load reschedules a heads-up before each upcoming airing.
        alarms: LocalSessionAlarmScheduler(),
        // Shared authoritative clock (same instance the Library uses) so
        // door/skip/join gating can't be spoofed via the device clock.
        clock: getIt.get<ServerClock>(),
        // #22 schedule paywall: same ADR-005 subscription adapter the
        // discovery funnel takes — unsubscribed students see locked
        // session cards whose Join/Remind taps open the plans surface.
        subscriptionStatus:
            getIt.isRegistered<SubscriptionStatusProvider>()
                ? getIt.get<SubscriptionStatusProvider>()
                : null,
        userId: LocalStorage.getUser()?.id?.toString(),
      ),
      // Frame 52: at plane widths joining opens the session in the
      // plane BESIDE this one instead of pushing over it. The
      // skill-review prompt in front of it is untouched — it still
      // runs first, and continues into whichever opener applies.
      onJoinSession: (session) => _joinSession(
        context,
        session,
        openInPlane:
            inPlanes ? () => setState(() => _session = session) : null,
      ),
      onOpenSkillLesson: (skill) => _openSkillLesson(context, skill),
      // #22: the locked cards' destination — the same subscribe surface
      // the discovery funnel routes to.
      onRequirePlan: () => showSubscribePage(context),
      // Opt-in calendar export (student profile toggle): confirmed
      // upcoming airings offered as an .ics through the share sheet.
      calendarSharer: IcsLessonCalendarSharer(),
      // Adaptive practice queue entry (#42 item 2): a standing glance
      // signal — practice fills the time BETWEEN broadcasts and never
      // touches the schedule itself. The queue's composition is fully
      // server-side; this is just the doorway.
      extraGlanceSignals: () => [
        GlanceSignal(
          message: 'Quick practice — sharpen this week\'s weak spots.',
          icon: Icons.psychology_alt_outlined,
          onTap: () => context.router.push(const PracticeRoute()),
        ),
        // Holiday Programme doorway — the page itself gates on the
        // subscription access its checkout grants. A plan whose
        // holiday_access is None gets no doorway at all.
        if (_holidayInPlan)
          GlanceSignal(
            message: 'Holiday Programme — your shelf for the break.',
            icon: Icons.beach_access_outlined,
            onTap: () =>
                context.router.push(const HolidayProgrammeRoute()),
          ),
      ],
      curriculum: _curriculum,
    );
  }
}

/// Host route shell for [LibraryPage] (lms_sdk-resident page).
@RoutePage(name: 'LibraryRoute')
class LibraryRouteView extends StatefulWidget {
  const LibraryRouteView({super.key});

  @override
  State<LibraryRouteView> createState() => _LibraryRouteViewState();
}

class _LibraryRouteViewState extends State<LibraryRouteView> {
  /// Badge value, or null for no badge: same
  /// [resolveContentCurriculumLabel] read path the Schedule header uses, so
  /// both badges always agree — including on showing nothing.
  String? _curriculum = kSupachargeCurriculum;

  @override
  void initState() {
    super.initState();
    resolveContentCurriculumLabel().then((c) {
      if (mounted && c != _curriculum) setState(() => _curriculum = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<LmsRepository>()) {
      LmsSdkDependencies.register(getIt);
    }
    return Stack(
      children: [
        LibraryPage(
          deps: LibraryScreenDeps(
            // KvAccessStatusSource is demo-aware (it reports an active
            // subscription for a demo session), so the library isn't
            // paywalled.
            accessSource: KvAccessStatusSource(),
            // A demo session reads entries through the seeding store so
            // the "Recently attended" strip renders without a completed
            // lesson (completion — the only production writer — never
            // happens in the guided tour).
            store: DemoSession.demoActive ? DemoLibraryStore() : null,
            skills: DemoSession.demoActive ? DemoSkillLessonSource() : AssetSkillLessonSource(),
            // #52: accepted bites surface ONLY as affordances on their
            // tied lesson's entry (never browsable on their own).
            bites: KnowledgeBiteStore(),
            // Same shared authoritative clock the Schedule uses — the
            // recording unlock gate reads it instead of the spoofable
            // device clock.
            clock: getIt.get<ServerClock>(),
          ),
          onShowPlans: () => showSubscribePage(context),
          // #40 item 2: pre-session questions run before a recorded watch
          // too — the same non-blocking quick-check surface the Schedule
          // hands out at attendance confirmation, then the player. No
          // questions (or a skip) goes straight through.
          onOpenRecording: (entry) async {
            await showPreWatchCheck(
              context,
              sessionId: entry.sessionId,
              questions: ManifestQuestionSource(),
            );
            if (!context.mounted) return;
            await context.router.push(
              LessonRoute(
                sessionId: entry.sessionId,
                lessonId: entry.lessonId,
                tutorName: entry.tutorName,
                isRecording: true,
              ),
            );
          },
          onOpenSkillLesson: (skill) => _openSkillLesson(context, skill),
          // #52 reading surface: a plain page on the current navigator
          // (same pattern as _openSkillLesson) — NOT the lesson player.
          onOpenKnowledgeBite: (accepted) => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => KnowledgeBitePage(bite: accepted.bite),
            ),
          ),
          curriculum: _curriculum,
        ),
        // Floating pill nav — same overlay Schedule/Tutors mount. The
        // Library reserves bottom clearance for it.
        Align(
          alignment: Alignment.bottomCenter,
          child: const SupachargeNav(currentIndex: 1),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Profile host wiring (base_sdk GenericProfilePage + ProfileSectionRegistry).
//
// Supacharge serves BOTH personas in one binary — student vs accountability
// partner is a runtime role decided at login/onboarding, not a compose-time
// app_type flavor (this SDK's Dart manifest declares no flavor blocks). The
// section registry is app-global, so each persona's sections carry a
// visibility gate reading which profile ROUTE is on screen: the route shells
// below set the persona before building the host page, exactly preserving
// "the page you navigated to decides what you see".
// ---------------------------------------------------------------------------

enum _LmsProfilePersona { student, partner }

_LmsProfilePersona _lmsProfilePersona = _LmsProfilePersona.student;

Future<bool> _isStudentProfilePersona() async =>
    _lmsProfilePersona == _LmsProfilePersona.student;

Future<bool> _isPartnerProfilePersona() async =>
    _lmsProfilePersona == _LmsProfilePersona.partner;

/// Partner-profile deps: same demo/real split the old PartnerProfileRouteView
/// carried (no league source here — the profile tab never showed the league
/// card; the dashboard keeps its own deps).
///
/// The split is decided by [DemoSession.demoActive] on every call — a
/// TOUR_MODE build or a server-marked demo account that signed in at runtime.
/// The answer is never held in a local or a field: a demo sign-in happens
/// minutes after boot and a sign-out ends the session mid-run, so the next
/// caller must get the other side.
PartnerDashboardDeps _partnerProfileDeps() {
  return DemoSession.demoActive
      ? PartnerDashboardDeps(
          access: _DemoAccessStatusSource(),
          source: _DemoPartnerReportSource(),
          billing: _DemoPartnerBilling(),
          links: _DemoPartnerStudentLinks(),
        )
      : PartnerDashboardDeps(
          access: KvAccessStatusSource(),
          source: HttpPartnerReportSource(),
          billing: HttpPartnerBilling(),
          links: HttpPartnerStudentLinks(),
        );
}

/// The per-student monthly partner rate (decision #23), from the SAME server
/// answer the plans catalog rides on (`rlms.api.billing.plans` → LMS
/// Settings' partner_monthly_rate). Null (also on failure) hides the cost
/// card: an honest absent quote beats a stale hardcoded one (decision #47).
/// Demo keeps the documented constant — there is no backend to ask.
Future<int?> _partnerMonthlyRate() async {
  if (DemoSession.demoActive) return kPartnerMonthlyRate;
  try {
    final snapshot = await HttpLessonPlanCatalog().fetch();
    final rate = snapshot.partnerMonthlyRate;
    return (rate != null && rate > 0) ? rate.round() : null;
  } catch (e) {
    debugPrint('==> partner monthly rate fetch failed: $e');
    return null;
  }
}

/// Registers every lms profile section with base_sdk's
/// [ProfileSectionRegistry] — called once at boot from this SDK's
/// `di_hooks` manifest entry (after the generated sdk-di block, so GetIt is
/// ready). The hooks are the SAME callbacks the deprecated route shells
/// passed to StudentProfilePage/PartnerProfilePage, reshaped to take the
/// section's BuildContext (registration happens before any router exists).
void registerSupachargeProfileSections() {
  final getIt = GetIt.instance;
  if (!getIt.isRegistered<LmsRepository>()) {
    LmsSdkDependencies.register(getIt);
  }

  // base_sdk's profileProvider (which GenericProfilePage watches for the
  // identity header) eagerly resolves these marketplace-side facades at
  // construction. This app composes no marketplace SDK, and the profile
  // host only ever exercises UserRepositoryFacade.getProfileDetails() —
  // so the unwired facades get throwing stand-ins: never invoked by the
  // host, and any future misuse degrades to a visible StateError instead
  // of a silent null (the same posture as base_sdk's _UnsetEmbeddedWidgets
  // and the orders manifest's unwired-seam convention).
  if (!getIt.isRegistered<ShopsRepositoryFacade>()) {
    getIt.registerLazySingleton<ShopsRepositoryFacade>(
        () => _UnwiredShopsRepository());
  }
  if (!getIt.isRegistered<GalleryRepositoryFacade>()) {
    getIt.registerLazySingleton<GalleryRepositoryFacade>(
        () => _UnwiredGalleryRepository());
  }

  // The default base.footer meta row's time-spent badge (lms claims no
  // footer override, so base_sdk's BaseProfileFooter renders it) shows
  // ONE period; lms (the home SDK) chooses the ISO-week figure (Ray
  // 2026-08-28: "radio and lms is weeks, default is year"). Last-wins
  // home-SDK seam, same shape as AppStyle.injectBrandColors.
  AppUsageBadge.period = AppUsagePeriod.week;

  // Header logout affordance — same sign-out both personas used from their
  // app-bar pills. (No onEditProfile: the old pages had no edit flow, so
  // the host hides that affordance.)
  ProfileSectionRegistry.I.onLogout = (context) {
    LocalStorage.logout();
    context.router.replaceAll([const LoginRoute()]);
  };

  LmsProfileSections.registerStudentSections(
    visible: _isStudentProfilePersona,
    // School row (school-capture brief): suggestions sweep every
    // curriculum's pool; the chip falls back to the app constant when
    // nothing is stored (the card itself prefers the stored KV value,
    // matching resolveStudentCurriculum's order).
    schoolSuggester: supachargeSchoolSuggester,
    defaultCurriculum: kSupachargeCurriculum,
    gradeDeps: StudentGradeDeps(
      repository: getIt.get<LmsRepository>(),
      onGradeSaved: (grade) async {
        final userId = LocalStorage.getUser()?.id?.toString();
        if (userId != null && userId.isNotEmpty) {
          await _cacheStudentGrade(userId, grade);
        }
      },
    ),
    // Link a parent as accountability partner — the student sends an
    // invite; the parent confirms with a one-time code.
    onLinkPartner: (context) =>
        context.router.push(const PartnerInviteRoute()),
    // Reach Subjects from the profile, not only the tab bar. At plane
    // widths the student profile route hosts the approved 1d cascade
    // (LmsProfilePlaneFlow): the row opens the Subjects thread in the
    // LAST plane beside the spread profile instead of pushing a route.
    // No scope (a phone, or the partner persona's shell) keeps the push.
    onOpenSubjects: (context) {
      final openThread = LmsProfileSubjectsScope.maybeOf(context)?.openSubjects;
      if (openThread != null) {
        openThread();
        return;
      }
      context.router.push(CourseCatalogRoute());
    },
    // The row's detail for base_sdk's own plane host (/generic-profile):
    // the same Subjects list the thread shows, the student profile's
    // DEFAULT section there (Ray 2026-09-07, a three-plane profile never
    // lands with its third plane empty). This shell hosts the student
    // tab through LmsProfilePlaneFlow, which seeds the same landing state
    // itself (StudentProfileRouteView); here a subject's Board is the
    // pushed route, the flow's level swap being the flow's own.
    subjectsDetailBuilder: (context) => _ProfileSubjectsPane(
      onOpenLesson: (lessonId) => context.router.push(
        LessonRoute(sessionId: '', lessonId: lessonId),
      ),
      onOpenBoard: (subject) =>
          context.router.push(SubjectBoardRoute(subject: subject)),
    ),
    // Streak & League (/league, decision #42 gap 4).
    onOpenStreakLeague: (context) =>
        context.router.push(const LeagueRoute()),
    // The student's own Term Report (/term-report).
    onOpenTermReport: (context) => context.router.push(TermReportRoute()),
    // The account's billing surfaces: coverage (/my-plan) and the payment
    // audit trail (/billing-history).
    onOpenMyPlan: (context) =>
        context.router.push(const EntitlementsRoute()),
    // The header plan row's data: title + active + expiry from the shared
    // 'user_subscriptions' KV row (the demo cast in demo), and the
    // planBack face's coverage/benefits summary from lms's own
    // entitlements endpoint (the same demo source /my-plan uses in demo).
    planSnapshot: _studentPlanSnapshot,
    entitlements: DemoSession.demoActive
        ? _DemoEntitlementsSource()
        : HttpEntitlementsSource(),
    onOpenBillingHistory: (context) =>
        context.router.push(const BillingHistoryRoute()),
    // Admin-only lesson review entry (hidden unless the backend's
    // admin_can_review_lessons says yes — asked once per app run).
    canOpenLessonReview: supachargeLessonReviewAllowed,
    onOpenLessonReview: (context) =>
        context.router.push(const LessonReviewRoute()),
    // Operator-only announcements entry (hidden unless the backend's
    // can_manage_announcements says yes — same gate shape).
    canOpenAnnouncements: supachargeAnnouncementsAllowed,
    onOpenAnnouncements: (context) =>
        context.router.push(const AnnouncementsAdminRoute()),
    // Admin-only homework fulfilment queue, same gate as lesson review.
    onOpenHomeworkFulfilment: (context) =>
        context.router.push(const HomeworkFulfilmentRoute()),
    // Async anytime homework help (product log #42 item 1).
    onOpenHomeworkHelp: (context) =>
        context.router.push(const HomeworkHelpRoute()),
    // Downloads / storage manager (/downloads, decision #7).
    onOpenDownloads: (context) =>
        context.router.push(const StorageManagerRoute()),
  );

  // ONE deps instance for the partner sections and the Students detail:
  // deps identity keys partnerDashboardProvider's family, so the row in
  // the profile and the list in the detail plane share a single state.
  final partnerDeps = _partnerProfileDeps();
  LmsProfileSections.registerPartnerSections(
    visible: _isPartnerProfilePersona,
    deps: partnerDeps,
    monthlyRatePerStudent: _partnerMonthlyRate,
    // The Students section's detail for a plane host (LmsProfilePlaneHost
    // here, base_sdk's own /generic-profile host elsewhere): the same
    // pay-toggle list, embedded — the partner profile's DEFAULT section,
    // so a three-plane tablet never lands with its third plane empty
    // (Ray 2026-09-07). Phones keep the list inline as before.
    studentsDetailBuilder: (context) =>
        LmsPartnerStudentsPane(deps: partnerDeps),
  );

  // The shared wallet card ('wallet.card', order 120) is wallet_sdk's own
  // registration — its di_hook (order 20) runs after this one, and the
  // section's gate and builder re-read this static seam on every profile
  // mount, so hook ordering can't stale it. Two adaptations (Ray's ask:
  // the wallet card on the STUDENT profile):
  //  - visible: the seam's default (any stored auth token) would surface
  //    the card on BOTH personas' profile routes; the student gate keeps
  //    it off /partner-profile — the same persona split every lms section
  //    carries.
  //  - symbol: lms never seeds LocalStorage's currency, so the card leads
  //    with the same hand-rolled Rand the billing surfaces use
  //    (billing_format.dart's formatRand).
  // Top-up / Send actions stay on their defaults: wallet_sdk's composed
  // /wallet-topup and /wallet-history routes and Send sheet work as-is in
  // this shell (the plans sheet already pushes /wallet-topup today).
  WalletCardSection.visible = _isStudentProfilePersona;
  WalletCardSection.symbol = 'R';

  // Theme toggle row + bottom clearance for the floating nav pills the
  // route shells overlay on both profile routes.
  LmsProfileSections.registerSharedSections();
}

/// Unwired marketplace-side facade stand-ins (see the registrations in
/// [registerSupachargeProfileSections]): base_sdk's profileProvider resolves
/// them eagerly, the profile host never calls them, and any other caller
/// gets a descriptive StateError rather than a GetIt "not registered" crash.
class _UnwiredShopsRepository implements ShopsRepositoryFacade {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'ShopsRepositoryFacade is not wired in this app: no marketplace-side '
      'SDK is composed. The generic profile host never calls it.');
}

class _UnwiredGalleryRepository implements GalleryRepositoryFacade {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'GalleryRepositoryFacade is not wired in this app: no marketplace-side '
      'SDK is composed. The generic profile host never calls it.');
}

/// Host route shell for the student Profile tab, now rendering base_sdk's
/// generic profile host. Route name and /profile path are unchanged, so
/// everything composed against StudentProfileRoute keeps working; the
/// sections come from [registerSupachargeProfileSections].
///
/// At plane widths the shell mounts the approved plane cascade (frames
/// 1d/1e/1g via lms_sdk's [LmsProfilePlaneFlow]): the profile declares
/// TWO planes and self-spreads; the Subjects row opens the Subjects list
/// (340) in the LAST plane; tapping an enrolled subject's Board
/// level-swaps that plane to the per-subject detail (341); the corner
/// back pill pops the newest level, never the profile. On phones the flow
/// hosts the profile alone and every destination stays the pushed route
/// it always was.
///
/// THREE planes land with Subjects already open (Ray 2026-09-07, "on a
/// tablet the generic profile host must not leave the third plane
/// empty"): the list is the last plane's landing state, not a pushed
/// step — the tab keeps its full nav and no pill shows until a subject's
/// Board is opened on top of it (the pill then pops back to the list).
@RoutePage(name: 'StudentProfileRoute')
class StudentProfileRouteView extends StatefulWidget {
  const StudentProfileRouteView({super.key});

  @override
  State<StudentProfileRouteView> createState() =>
      _StudentProfileRouteViewState();
}

class _StudentProfileRouteViewState extends State<StudentProfileRouteView> {
  /// The Subjects thread (340) holds the last plane. Survives width
  /// changes: a phone-width interlude hides the thread, widening back
  /// restores it (back restores).
  bool _subjectsOpen = false;

  /// Non-null while the thread shows the subject detail (341).
  String? _subject;

  /// The corner pill: pops the NEWEST level — detail -> list (341 -> 340),
  /// then closes the thread. The profile beneath never moves; it goes
  /// home only when it is the last thing left (the shell's own back).
  void _popNewest() {
    setState(() {
      if (_subject != null) {
        _subject = null;
      } else {
        _subjectsOpen = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _lmsProfilePersona = _LmsProfilePersona.student;
    return LayoutBuilder(
      builder: (context, constraints) {
        final int planes = PlaneHost.planeCountFor(constraints.maxWidth);
        final bool wide = planes > 1;
        // Three planes: the Subjects list is the third plane's landing
        // state (open without a push); the nav folds only for a step the
        // user pushed on top — a subject's Board, or the thread itself on
        // two planes.
        final bool subjectsDefault = planes >= 3;
        final bool threadOpen = wide &&
            (_subject != null || (_subjectsOpen && !subjectsDefault));
        return Stack(
          children: [
            Positioned.fill(
              child: LmsProfileSubjectsScope(
                // The profile's Subjects row goes through this seam: open
                // the thread in place at plane widths, push the route on
                // phones (see registerSupachargeProfileSections).
                openSubjects: wide
                    ? () => setState(() => _subjectsOpen = true)
                    : null,
                child: LmsProfilePlaneFlow(
                  subjectsOpen: _subjectsOpen,
                  subjectsDefault: subjectsDefault,
                  selectedSubject: _subject,
                  profileBuilder: (context) => const GenericProfilePage(),
                  subjectsBuilder: (context) => _ProfileSubjectsPane(
                    onOpenLesson: (lessonId) => context.router.push(
                      LessonRoute(sessionId: '', lessonId: lessonId),
                    ),
                    // Decision #32 in-thread: the enrolled subject's card
                    // swaps the last plane to its Board (340 -> 341)
                    // instead of pushing SubjectBoardRoute.
                    onOpenBoard: (subject) =>
                        setState(() => _subject = subject),
                  ),
                  // The per-subject detail (341): the same Board the
                  // pushed SubjectBoardRoute shows, minus the app-bar
                  // back — the corner pill is the screen's one back.
                  subjectDetailBuilder: (context, subject) => TheBoardPage(
                    subject: subject,
                    engagement: HttpEngagementSource(),
                    onOpenLeague: () =>
                        context.router.push(const LeagueRoute()),
                  ),
                  onBack: _popNewest,
                ),
              ),
            ),
            // Floating pill nav — the Profile slot (index 3). The section
            // list ends in a clearance spacer so content scrolls above it.
            // Two-state nav (12d): while the thread holds a plane the full
            // nav folds away and PlaneHost's corner back pill takes over.
            if (!threadOpen)
              const Align(
                alignment: Alignment.bottomCenter,
                child: SupachargeNav(currentIndex: 3),
              ),
          ],
        );
      },
    );
  }
}

/// The Subjects list (chip 340) as the thread's first level: the same
/// [CourseCatalogPage] + student-side deps resolution as
/// [CourseCatalogRouteView], minus the route shell — the plane flow
/// hosts it, so it never touches the router itself (host callbacks only).
class _ProfileSubjectsPane extends StatefulWidget {
  final void Function(String lessonId) onOpenLesson;
  final void Function(String subject) onOpenBoard;

  const _ProfileSubjectsPane({
    required this.onOpenLesson,
    required this.onOpenBoard,
  });

  @override
  State<_ProfileSubjectsPane> createState() => _ProfileSubjectsPaneState();
}

class _ProfileSubjectsPaneState extends State<_ProfileSubjectsPane> {
  CourseCatalogDeps? _deps;

  @override
  void initState() {
    super.initState();
    final getIt = GetIt.instance;
    // LmsRepository is lms_sdk-owned (registered by LmsSdkDependencies),
    // not a host adapter — register here if whoever composed the app
    // hasn't (same guard as CourseCatalogRouteView).
    if (!getIt.isRegistered<LmsRepository>()) {
      LmsSdkDependencies.register(getIt);
    }
    // Grade-scope the catalog exactly as the pushed route does: resolve
    // the student's grade (last-known-good, offline-safe), then build the
    // deps ONCE — deps identity keys the provider family. This pane only
    // ever renders for the student persona (the student profile route).
    studentGrade().then((grade) {
      if (!mounted) return;
      setState(() {
        _deps = CourseCatalogDeps(
          repository: GetIt.instance.get<LmsRepository>(),
          grade: grade,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final deps = _deps;
    if (deps == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return CourseCatalogPage(
      deps: deps,
      onOpenLesson: widget.onOpenLesson,
      onOpenBoard: widget.onOpenBoard,
    );
  }
}

/// One `admin_can_review_lessons` ask per app run: the Future itself is
/// cached, so concurrent callers share a single request and the answer —
/// true or false — stays settled until restart. Gates the profile's
/// "Lesson review" row (lms_sdk hides it on false or failure).
Future<bool>? _lessonReviewAccess;
Future<bool> supachargeLessonReviewAllowed() {
  final getIt = GetIt.instance;
  if (!getIt.isRegistered<LmsRepository>()) {
    LmsSdkDependencies.register(getIt);
  }
  return _lessonReviewAccess ??= getIt.get<LmsRepository>().canReviewLessons();
}

/// Host adapter for lms_sdk's [LessonStorageInventory] (ADR-005): the
/// storage-manager surface over replay_sdk's [LessonStorageManager] — the
/// machinery that lists sealed `.rok` bundles, deletes them, and
/// re-downloads through the universal platform gateway (decisions #7/#46).
class ReplayLessonStorageAdapter implements LessonStorageInventory {
  final LessonStorageManager _manager;

  ReplayLessonStorageAdapter(this._manager);

  @override
  Future<List<StoredLesson>> listDownloads() async {
    final records = await _manager.listDownloads();
    return [
      for (final record in records)
        StoredLesson(
          sessionId: record.sessionId,
          sizeBytes: record.sizeBytes,
          subject: record.meta.subject,
          scheduledAt: record.meta.scheduledAt,
          downloadedAt: record.meta.downloadedAt,
        ),
    ];
  }

  @override
  Future<void> deleteDownload(String sessionId) =>
      _manager.deleteDownload(sessionId);

  @override
  Future<void> redownload(String sessionId) async {
    await _manager.redownload(sessionId);
  }
}

/// Host route shell for lms_sdk's [StorageManagerPage] — the Downloads
/// surface reached from the profile (decision #7: per-lesson
/// size/delete/re-download instead of clearing app data from Settings).
@RoutePage(name: 'StorageManagerRoute')
class StorageManagerRouteView extends StatelessWidget {
  const StorageManagerRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<LessonStorageManager>()) {
      ReplaySdkDependencies.register(getIt);
    }
    return StorageManagerPage(
      inventory:
          ReplayLessonStorageAdapter(getIt.get<LessonStorageManager>()),
    );
  }
}

/// Host adapter for lms_sdk's [LessonReviewPlayback] (ADR-005): downloads
/// the lesson's produced triple (manifest/audio/animations) from its factory
/// asset URLs into replay_sdk's AssetStore session directory — the exact
/// place the real playback path (SessionGatekeeper -> ManifestParser ->
/// AudioSync -> WhiteboardPlayer) reads — then opens the regular
/// [LessonRoute] on it. The reviewer watches precisely what a student gets.
class ReviewLessonPlayback implements LessonReviewPlayback {
  final BuildContext context;

  ReviewLessonPlayback(this.context);

  @override
  Future<void> play(LessonReviewEntry lesson) async {
    final assets = lesson.assets;
    if (assets == null) {
      throw StateError('lesson ${lesson.id} has no produced assets');
    }
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<AssetStore>()) {
      ReplaySdkDependencies.register(getIt);
    }
    if (!getIt.isRegistered<HttpService>()) {
      throw StateError('no HTTP client registered');
    }
    final store = getIt.get<AssetStore>();
    final root = await store.assetsRoot();
    final sessionId = lesson.id;
    // requireAuth stays false: the assets live on public raw URLs and the
    // app's auth token must never leak to a third-party host.
    final client = getIt.get<HttpService>().client();
    final downloads = <String, String>{
      assets.manifestUrl: store.manifestPath(root, sessionId),
      assets.audioUrl: store.audioPath(root, sessionId),
      assets.animationsUrl: store.animationPath(root, sessionId),
    };
    for (final entry in downloads.entries) {
      // Always overwrite: a re-review must play the latest produced content,
      // never a stale cached copy (the demo seeder learned that the hard way).
      await File(entry.value).parent.create(recursive: true);
      await client.download(entry.key, entry.value);
    }
    // A review always starts from second zero: reset the local session clock
    // row the engine's offline fallback would otherwise resume from.
    await AppDatabase().putItem('live_session_starts', sessionId, {
      'startedAt': DateTime.now().toIso8601String(),
    });
    if (!context.mounted) return;
    await context.router.push(LessonRoute(
      sessionId: sessionId,
      // The player resolves the tutor id from the downloaded manifest's
      // profile track; this display name is only the fallback label.
      tutorName: 'Tutor',
      // Reviewer shortcut through the subscription gate — the sample path
      // already bypasses it, and the review account is not a subscribed
      // student.
      isSample: true,
    ));
  }
}

/// Host route shell for the admin lesson review screen (/lesson-review).
/// Reached from the profile's gated "Lesson review" row.
@RoutePage(name: 'LessonReviewRoute')
class LessonReviewRouteView extends StatelessWidget {
  const LessonReviewRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<LmsRepository>()) {
      LmsSdkDependencies.register(getIt);
    }
    // Demo session (a TOUR_MODE build, or a server-marked demo account
    // signed in at runtime): the factory repo's published review index is
    // live operator data, so the preview serves a small in-memory index
    // instead — populated, deterministic, and offline-safe (the guided tour
    // walks this screen). DemoLmsRepository's reviewLesson is already a
    // no-op, so demo decisions never leave the device. A null fetchIndex
    // keeps the production path (the published index) unchanged.
    return LessonReviewPage(
      repository: getIt.get<LmsRepository>(),
      playback: ReviewLessonPlayback(context),
      fetchIndex: DemoSession.demoActive ? _demoLessonReviewIndex : null,
    );
  }
}

/// Demo-only stand-in for the factory repo's `lessons/review_index.json`:
/// a handful of generated CAPS lessons in the exact wire shape
/// [LessonReviewIndex.fromJson] parses, so the review queue previews with
/// pending, approved and denied rows across subjects and grades. The
/// unproduced entries exercise the awaiting-production presentation; no
/// entry carries an asset triple, so nothing on the demo queue is playable
/// (playback needs the real factory assets). Never used in production.
Future<Map<String, dynamic>> _demoLessonReviewIndex() async => {
      'version': 1,
      'generated_at': '2026-08-17T06:00:00Z',
      'lessons': [
        {
          'id': 'demo-review-1',
          'source': 'pipeline',
          'subject': 'Mathematics',
          'grade': 10,
          'term': 3,
          'topic': 'Algebraic expressions',
          'subtopic': 'Factorising trinomials',
          'package_path': 'lessons/packages/demo-review-1',
          'produced': true,
          'review': {'status': 'pending'},
        },
        {
          'id': 'demo-review-2',
          'source': 'pipeline',
          'subject': 'Mathematics',
          'grade': 12,
          'term': 3,
          'topic': 'Functions',
          'subtopic': 'Interpreting graphs of hyperbolas',
          'package_path': 'lessons/packages/demo-review-2',
          'produced': true,
          'review': {
            'status': 'approved',
            'reviewed_at': '2026-08-15T09:30:00Z',
          },
        },
        {
          'id': 'demo-review-3',
          'source': 'pipeline',
          'subject': 'Physical Sciences',
          'grade': 11,
          'term': 3,
          'topic': 'Electricity and magnetism',
          'subtopic': "Ohm's law calculations",
          'package_path': 'lessons/packages/demo-review-3',
          'produced': true,
          'review': {'status': 'pending'},
        },
        {
          'id': 'demo-review-4',
          'source': 'session',
          'subject': 'Physical Sciences',
          'grade': 12,
          'term': 2,
          'topic': 'Chemical change',
          'subtopic': 'Rates of reaction',
          'package_path': 'lessons/packages/demo-review-4',
          'produced': true,
          'review': {
            'status': 'denied',
            'reason': 'Board work runs ahead of the narration from slide 4.',
            'reviewed_at': '2026-08-14T14:05:00Z',
          },
        },
        {
          'id': 'demo-review-5',
          'source': 'pipeline',
          'subject': 'Accounting',
          'grade': 11,
          'term': 3,
          'topic': 'Reconciliations',
          'subtopic': 'Bank reconciliation statements',
          'package_path': 'lessons/packages/demo-review-5',
          'produced': false,
          'review': {'status': 'pending'},
        },
        {
          'id': 'demo-review-6',
          'source': 'pipeline',
          'subject': 'Geography',
          'grade': 10,
          'term': 3,
          'topic': 'Geomorphology',
          'subtopic': 'River landforms',
          'package_path': 'lessons/packages/demo-review-6',
          'produced': false,
          'review': {'status': 'pending'},
        },
      ],
    };

/// One `can_manage_announcements` ask per app run PER SIDE (the
/// lesson-review gate's caching pattern): the Future itself is cached so
/// concurrent callers share a single request and the answer stays settled
/// until restart. Gates the profile's "Announcements" row.
///
/// The two sides cache SEPARATELY on purpose. A single cache would have made
/// the demo/real decision itself sticky: the first ask of an app run would
/// pin one side's Future, and a demo account signing in minutes later (or
/// signing out) would keep reading the other side's settled answer for the
/// rest of the run — exactly the staleness [DemoSession.demoActive] exists
/// to end. Read the session per call, then reuse only that side's request.
Future<bool>? _announcementsAccessDemo;
Future<bool>? _announcementsAccessLive;
Future<bool> supachargeAnnouncementsAllowed() {
  // Demo session: there is no backend to answer can_manage_announcements, so
  // the gate would fail closed and hide the operator preview. Open it against
  // the same in-memory admin the route view serves below — a real session
  // keeps the server-gated answer.
  if (DemoSession.demoActive) {
    return _announcementsAccessDemo ??= _DemoAnnouncementAdmin().canManage();
  }
  return _announcementsAccessLive ??= HttpAnnouncementAdmin().canManage();
}

/// Demo-only [AnnouncementAdmin]: a short seeded list so the operator page
/// previews populated (one live schedule change, one scheduled notice, one
/// retired post), with create/retire succeeding instantly so both flows are
/// exercisable in the IS_DEMO preview. Nothing is persisted — the seeded
/// list comes back on restart. Never used in production.
class _DemoAnnouncementAdmin implements AnnouncementAdmin {
  @override
  Future<bool> canManage() async => true;

  @override
  Future<List<Announcement>> listAll() async {
    final now = DateTime.now();
    return [
      Announcement(
        id: 'demo-ann-1',
        title: "Friday's session moves to 15:00",
        body: 'Mr Ndlovu is invigilating — the Grade 12 Mathematics '
            'session shifts one hour later this week only.',
        subject: 'Mathematics',
        grade: 12,
        startsAt: now.subtract(const Duration(days: 1)),
      ),
      Announcement(
        id: 'demo-ann-2',
        title: 'Holiday programme bookings open Monday',
        body: 'The September holiday programme schedule goes live for all '
            'grades — spaces are first come, first served.',
        startsAt: now.add(const Duration(days: 3)),
        endsAt: now.add(const Duration(days: 17)),
      ),
      Announcement(
        id: 'demo-ann-3',
        title: 'Term 2 reports are in the library',
        body: 'Every subject report from last term is now available under '
            'Library for students and their partners.',
        startsAt: now.subtract(const Duration(days: 30)),
        endsAt: now.subtract(const Duration(days: 9)),
        retired: true,
      ),
    ];
  }

  @override
  Future<Announcement> create({
    required String title,
    required String body,
    int? grade,
    String? subject,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async =>
      Announcement(
        id: 'demo-ann-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: body,
        subject: subject,
        grade: grade,
        startsAt: startsAt,
        endsAt: endsAt,
      );

  @override
  Future<void> retire(String id) async {}
}

/// Host route shell for the announcements operator screen
/// (/announcements-admin). Reached from the profile's gated
/// "Announcements" row; the backend re-gates every write server-side.
@RoutePage(name: 'AnnouncementsAdminRoute')
class AnnouncementsAdminRouteView extends StatelessWidget {
  const AnnouncementsAdminRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    // Demo session: serve the in-memory admin so the operator preview lists
    // seeded posts instead of a retry state (no backend to answer
    // list_announcements). Never reached by a real session.
    return AnnouncementsAdminPage(
      admin: DemoSession.demoActive
          ? _DemoAnnouncementAdmin()
          : HttpAnnouncementAdmin(),
    );
  }
}

/// Host route shell for the admin homework fulfilment screen
/// (/homework-fulfilment). Reached from the profile's gated "Homework
/// queue" row — the operator half of async homework help (the endpoints
/// are System-Manager-gated server-side; the profile row shares the
/// lesson-review gate).
@RoutePage(name: 'HomeworkFulfilmentRoute')
class HomeworkFulfilmentRouteView extends StatelessWidget {
  const HomeworkFulfilmentRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    // Demo session: serve the in-memory queue so the operator preview lists
    // seeded questions instead of a retry state (no backend to answer
    // homework_pending_requests). Never reached by a real session.
    return HomeworkFulfilmentPage(
      repository: DemoSession.demoActive
          ? _DemoHomeworkFulfilmentRepository()
          : HttpHomeworkFulfilmentRepository(),
    );
  }
}

/// Demo-only [HomeworkFulfilmentRepository]: a few seeded student questions
/// (oldest first, as the real queue lists them) so the fulfilment page
/// previews populated. Draft answers a credible MCQ set instantly and
/// publish/decline succeed without persisting — the seeded queue comes back
/// on restart. Never used in production.
class _DemoHomeworkFulfilmentRepository implements HomeworkFulfilmentRepository {
  @override
  Future<List<HomeworkPendingRequest>> pendingRequests() async {
    final now = DateTime.now();
    return [
      HomeworkPendingRequest(
        id: 'demo-hw-1',
        member: 'Amahle',
        subject: 'Mathematics',
        grade: 10,
        questionText: 'Solve for x: 3x - 7 = 2x + 5. '
            'Please show how to get the answer step by step.',
        status: 'Submitted',
        submittedAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      HomeworkPendingRequest(
        id: 'demo-hw-2',
        member: 'Sipho',
        subject: 'Physical Sciences',
        grade: 11,
        questionText: 'A 2 kg trolley accelerates at 1.5 m/s². '
            'What net force acts on it?',
        status: 'Submitted',
        submittedAt: now.subtract(const Duration(hours: 20)),
      ),
      HomeworkPendingRequest(
        id: 'demo-hw-3',
        member: 'Naledi',
        subject: 'Accounting',
        grade: 11,
        questionText: 'Why does the bank statement balance differ from the '
            'bank account in the general ledger?',
        status: 'In Review',
        submittedAt: now.subtract(const Duration(hours: 6)),
      ),
    ];
  }

  @override
  Future<HomeworkMcqDraft> draftMcq({required String id}) async =>
      const HomeworkMcqDraft(
        question: 'Solve for x: 3x - 7 = 2x + 5',
        options: ['x = 12', 'x = 2', 'x = -12', 'x = 5'],
        correctIndex: 0,
        explanation: 'Subtract 2x from both sides (x - 7 = 5), then add 7 '
            'to both sides: x = 12.',
      );

  @override
  Future<void> publishMcq({
    required String id,
    required HomeworkMcqDraft mcq,
  }) async {}

  @override
  Future<void> decline({required String id, required String reason}) async {}
}

/// Which school break the Holiday Programme currently serves, plus the
/// just-ended term's revision window — HOST configuration by contract
/// (holiday_models: "which dates each covers is host configuration").
/// Approximated from the SA term rhythm by month (terms track the school
/// quarters) rather than a pinned yearly calendar, so the surface works
/// every year without a data update; refine to the gazetted DBE calendar
/// when precision starts to matter. Mid-term dates resolve to the most
/// recently ENDED term, so the shelf is a useful revision surface between
/// breaks too.
(SchoolHoliday, DateTime, DateTime) supachargeHolidayWindow(DateTime now) {
  final year = now.year;
  if (now.month == 12 || now.month == 1) {
    // Year-end break: the school year that just ended, whole.
    final startYear = now.month == 1 ? year - 1 : year;
    return (
      SchoolHoliday.yearEnd,
      DateTime(startYear, 1, 15),
      DateTime(startYear, 12, 5),
    );
  }
  if (now.month <= 4) {
    return (
      SchoolHoliday.term1Break,
      DateTime(year, 1, 15),
      DateTime(year, 3, 31),
    );
  }
  if (now.month <= 7) {
    return (
      SchoolHoliday.term2Break,
      DateTime(year, 4, 1),
      DateTime(year, 6, 30),
    );
  }
  return (
    SchoolHoliday.term3Break,
    DateTime(year, 7, 1),
    DateTime(year, 9, 30),
  );
}

/// Subjects the Holiday Programme builds shelves for: the student's own
/// enrolled subjects when the backend answers, else the broadcast grid's
/// core subject slugs — a standalone holiday buyer may hold no enrollment
/// at all and must still get shelves.
Future<List<String>> supachargeHolidaySubjects() async {
  try {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<LmsRepository>()) {
      LmsSdkDependencies.register(getIt);
    }
    final subjects = await getIt.get<LmsRepository>().allowedSubjects();
    if (subjects.isNotEmpty) return subjects;
  } catch (e) {
    debugPrint('==> holiday subjects: falling back to the core set ($e)');
  }
  // The weekly broadcast grid's subject slugs (replay data/weekly_grid.json).
  return const [
    'maths',
    'maths_literacy',
    'physical_sciences',
    'accounting',
    'economics',
    'geography',
  ];
}

/// Host route shell for the Holiday Programme (/holiday-programme) — the
/// experience surface behind the standalone R449 purchase and the plans'
/// holiday perk. That checkout writes a plain LMS Subscription Period (the
/// same record a regular subscription writes), so access is the same
/// subscription gate every other paid surface reads
/// ([KvAccessStatusSource]) — deliberately no new access axis.
@RoutePage(name: 'HolidayProgrammeRoute')
class HolidayProgrammeRouteView extends StatelessWidget {
  const HolidayProgrammeRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    final (holiday, termStart, termEnd) =
        supachargeHolidayWindow(DateTime.now());
    return HolidayProgrammePage(
      deps: HolidayProgrammeDeps(
        access: KvAccessStatusSource(),
        planner: HolidayProgrammePlanner(
            content: BackendHolidayContentSource()),
        // Plan-scoped level (Full / First Week / None) from the same
        // entitlement summary My-plan reads; the page fails open to Full
        // when this throws.
        holidayAccess: () async =>
            (await HttpEntitlementsSource().summary()).holidayAccess,
        holiday: holiday,
        termStart: termStart,
        termEnd: termEnd,
        grade: studentGrade,
        subjects: supachargeHolidaySubjects,
        // §5 attendance ledger: missed-session evidence for weak-topic
        // catch-up.
        attendance: () => ProfileStore().attendance(),
        // Until the plan's personalized-catch-up entitlement is modeled
        // client-side, catch-up personalizes purely on the student's own
        // ledger evidence — the planner falls back to plain term revision
        // when there is none, never inventing weakness.
        personalizedCatchUp: true,
      ),
      onShowPlans: () => showSubscribePage(context),
      // Produced holiday content is served through the regular lesson
      // player as a recording (§6 library semantics).
      onOpenLesson: (lesson) => context.router.push(LessonRoute(
        sessionId: lesson.sessionId,
        lessonId: lesson.lessonId,
        isRecording: true,
      )),
    );
  }
}

/// Host route shell for [PracticePage] (lms_sdk-resident page) — the
/// adaptive practice queue (/practice, product log #42 item 2). Reached
/// from the Schedule's standing practice glance signal. The server owns
/// selection end to end; this shell only injects the repository.
@RoutePage(name: 'PracticeRoute')
class PracticeRouteView extends StatelessWidget {
  const PracticeRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<LmsRepository>()) {
      LmsSdkDependencies.register(getIt);
    }
    return PracticePage(repository: getIt.get<LmsRepository>());
  }
}

/// P3 Half 1 — the ADR reuse. Adapter over productivity_sdk's
/// RecoveryRepositoryFacade satisfying lms_sdk's StudyBehaviorSignal. THIS
/// class owns the vocabulary translation (see
/// agent/lms/docs/adr-recovery-reuse-for-accountability.md): the recovery
/// module's addiction-recovery sentinels ('Resisted'/'Relapsed') are used
/// only as the DB streak sentinels the impl requires — they never leave this
/// file. Supacharge terms ('attended-session', 'skip-urge') go in the
/// free-form trigger/reason columns. A skip breaks the study streak
/// (Relapsed); an attendance extends it (Resisted).
class RecoveryStudyBehaviorSignal implements StudyBehaviorSignal {
  prod.RecoveryRepositoryFacade? get _recovery =>
      GetIt.instance.isRegistered<prod.RecoveryRepositoryFacade>()
          ? GetIt.instance.get<prod.RecoveryRepositoryFacade>()
          : null;

  @override
  Future<void> recordAttendance({required DateTime at}) async {
    // Attending resists the urge to skip -> study streak extends.
    await _recovery?.logUrge(
      intensity: 0,
      triggerType: 'attended-session',
      outcome: 'Resisted',
    );
  }

  @override
  Future<void> recordSkip({required DateTime at, required bool answered}) async {
    final r = _recovery;
    if (r == null) return;
    // The skip breaks the study streak...
    await r.logUrge(
      intensity: 0,
      triggerType: 'skipped-session',
      outcome: 'Relapsed',
    );
    // ...and is recorded as a delayed/postponed study task.
    await r.logProcrastination(
      ritualId: null,
      scheduledTime: at,
      delayCount: 1,
      reason: answered ? 'skipped-answered' : 'skipped-unanswered',
    );
  }

  @override
  Future<void> recordSkipUrge(
      {required DateTime at, required bool attended}) async {
    // Supplementary to recordSkip/recordAttendance (which own the streak):
    // logs the skip-decision moment for the weekly rollup.
    await _recovery?.logProcrastination(
      ritualId: null,
      scheduledTime: at,
      delayCount: 0,
      reason: attended ? 'skip-urge-resisted' : 'skip-urge-gave-in',
    );
  }

  @override
  Future<StudyBehaviorSummary> weeklySummary(DateTime weekStart) async {
    final m = await _recovery?.getWeeklySummary(weekStart) ?? const {};
    return StudyBehaviorSummary(
      currentStreak: m['currentStreak'] ?? 0,
      skipUrges: m['urgeEvents'] ?? 0,
      skips: m['procrastinations'] ?? 0,
    );
  }
}

/// Shared response parsing for the two invite directions (P3.2): the backend
/// returns the minted 6-digit pairing code + expiry alongside the send.
PartnerInviteResult _parseInviteResponse(dynamic data, int statusCode) {
  if (statusCode < 200 || statusCode >= 300) return PartnerInviteResult.failed;
  final m = data is Map ? (data['message'] ?? data) : null;
  return PartnerInviteResult(
    PartnerInviteOutcome.sent,
    pairingCode: m is Map ? m['code']?.toString() : null,
    expiresAt: m is Map && m['expires_at'] is String
        ? DateTime.tryParse(m['expires_at'] as String)
        : null,
  );
}

/// P3 Half 2 — invite delivery. comms_sdk has no SMS/email send capability
/// and delivery is a backend concern, so this calls the backend endpoint
/// that sends the message and mints the pairing code (P3.2 — no web page).
class HttpPartnerInviteSender implements PartnerInviteSender {
  @override
  Future<PartnerInviteResult> send(PartnerInvite invite) async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<HttpService>()) {
      return PartnerInviteResult.failed;
    }
    try {
      final res = await getIt.get<HttpService>().client(requireAuth: true).post(
        _kGatewayPath,
        data: {
          'cmd': 'api.lms.partner_invite',
          'payload': {
            'contact': invite.contact,
            'channel': invite.channel.name,
            'relationship': invite.relationship.name,
          },
        },
      );
      return _parseInviteResponse(res.data, res.statusCode ?? 0);
    } catch (e) {
      debugPrint('==> partner invite send failed: $e');
      return PartnerInviteResult.failed;
    }
  }
}

/// Host route shell for the student-side partner invite screen.
@RoutePage(name: 'PartnerInviteRoute')
class PartnerInviteRouteView extends StatelessWidget {
  const PartnerInviteRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    return PartnerInvitePage(
      deps: PartnerInviteDeps(
        sender: HttpPartnerInviteSender(),
        // Adding a partner unlocks the discounted rate: route the student to
        // the plans surface (same subscriptions adapter as P1).
        onPartnerAdded: () async =>
            context.router.push(TutorDiscoveryRoute()),
      ),
    );
  }
}

/// Real cross-device report source (rlms.api.partner.weekly_report) — the
/// partner is on their own separate account/device, so [LocalPartnerReportComposer]
/// (which reads the STUDENT's on-device §5 ledgers) cannot serve this case;
/// that composer stays as the same-device/test path only, per its own doc
/// comment. Alerts are no longer same-device-only: they come from the
/// backend feed (rlms.api.partner.alerts — see alerts() below), with
/// PartnerAlertStore remaining the same-device/test path.
class HttpPartnerReportSource implements PartnerReportSource {
  /// P3.1 multi-student: the partner's linked students, from
  /// rlms.api.partner.my_students. Relationship comes back as the stored
  /// label ('Parent'…) — mapped tolerantly, unknown values default to parent.
  @override
  Future<List<LinkedStudent>> students() async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<HttpService>()) return const [];
    final res = await getIt.get<HttpService>().client(requireAuth: true).post(
          _kGatewayPath,
          data: {'cmd': 'api.lms.partner_my_students'},
        );
    final m = (res.data is Map ? res.data['message'] : res.data) as Map?;
    final raw = m?['students'];
    if (raw is! List) return const [];
    return [
      for (final s in raw)
        if (s is Map)
          LinkedStudent(
            id: (s['student'] ?? '').toString(),
            name: (s['student_name'] ?? '').toString(),
            relationship: PartnerRelationship.values.firstWhere(
              (r) =>
                  r.name ==
                  (s['relationship'] ?? '').toString().toLowerCase(),
              orElse: () => PartnerRelationship.parent,
            ),
            paidByPartner: s['paid_by_partner'] == true,
            // #33: the SERVER's payer-capability answer (rlms.payer_rules
            // — a teacher link cannot pay). Absent field keeps the model's
            // permissive default; the backend still refuses regardless.
            canPay: s['can_pay'] != false,
          ),
    ];
  }

  @override
  Future<PartnerReport> weeklyReport(DateTime weekStart,
      {String? studentId}) async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<HttpService>()) {
      return PartnerReport(studentName: '', weekStart: weekStart);
    }
    final res = await getIt.get<HttpService>().client(requireAuth: true).post(
      _kGatewayPath,
      data: {
        'cmd': 'api.lms.partner_weekly_report',
        'payload': {
          'week_start': weekStart.toIso8601String(),
          if (studentId != null) 'student': studentId,
        },
      },
    );
    final m = (res.data is Map ? res.data['message'] : res.data) as Map?;
    if (m == null) return PartnerReport(studentName: '', weekStart: weekStart);
    return PartnerReport(
      studentName: (m['student_name'] ?? '').toString(),
      weekStart: weekStart,
      sessionsScheduled: (m['sessions_scheduled'] as num?)?.toInt() ?? 0,
      sessionsAttended: (m['sessions_attended'] as num?)?.toInt() ?? 0,
      sessionsSkippedAnswered:
          (m['sessions_skipped_answered'] as num?)?.toInt() ?? 0,
      sessionsSkippedUnanswered:
          (m['sessions_skipped_unanswered'] as num?)?.toInt() ?? 0,
      performanceScores: (m['performance_scores'] as Map? ?? const {}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      ),
      engagementRatePercent:
          (m['engagement_rate_percent'] as num?)?.toInt() ?? 0,
      dataUsedMb: (m['data_used_mb'] as num?)?.toDouble() ?? 0,
      currentStreak: (m['current_streak'] as num?)?.toInt() ?? 0,
      // #15 presence-with-gaps: null (absent key or an old server) means
      // unknown — the dashboard hides the row rather than showing 0.
      avgMinutesWatched: (m['avg_minutes_watched'] as num?)?.toInt(),
      // Usage reporting v1 (presence vs performance). All three follow the
      // same absent-means-hidden stance: null days (telemetry not composed
      // or an old server) hides the presence row; empty lists hide their
      // cards; the windowed flag keeps the recorded-lessons label honest.
      daysActiveInApp: (m['days_active_in_app'] as num?)?.toInt(),
      liveSessions: m['live_sessions'] is List
          ? [
              for (final s in m['live_sessions'] as List)
                if (s is Map)
                  if (LiveSessionWatch.fromJson(Map<String, dynamic>.from(s))
                      case final w?)
                    w,
            ]
          : const [],
      recordedLessons:
          RecordedLessonWatch.listFromJson(m['recorded_lessons']),
      recordedLessonsWindowed: m['recorded_lessons_windowed'] != false,
    );
  }

  /// P3.2: alerts come from the backend feed (rlms.api.partner.alerts) —
  /// rows written server-side when record_attendance_event detects a streak
  /// break, so they reach the partner's own device. The push notification is
  /// the instant nudge; this feed is what the dashboard lists.
  @override
  Future<List<PartnerAlert>> alerts() async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<HttpService>()) return const [];
    try {
      final res = await getIt.get<HttpService>().client(requireAuth: true).post(
            _kGatewayPath,
            data: {'cmd': 'api.lms.partner_alerts'},
          );
      final m = res.data is Map ? res.data['message'] : res.data;
      final raw = m is Map ? m['alerts'] : null;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((a) => PartnerAlert.fromJson({
                'type': a['type'],
                'message': a['message'],
                'at': a['at'],
                // Backend field is snake_case; the model reads studentId.
                'studentId': a['student_id'],
              }))
          .whereType<PartnerAlert>()
          .toList();
    } catch (e) {
      debugPrint('==> partner alerts fetch failed: $e');
      return const [];
    }
  }
}

/// Partner-scoped league standings (rlms.api.engagement.
/// partner_students_league): where each of the partner's OWN linked
/// students stands in this week's league. The server resolves the caller's
/// Active links and answers tier/points/rank/cohort-size per student —
/// never anything about any other cohort member. Students with no league
/// membership this week come back with a null league and are skipped.
class HttpPartnerLeagueSource implements PartnerLeagueSource {
  @override
  Future<List<StudentLeagueStanding>> studentsLeague() async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<HttpService>()) return const [];
    try {
      final res = await getIt.get<HttpService>().client(requireAuth: true).post(
            _kGatewayPath,
            data: {'cmd': 'api.lms.partner_students_league'},
          );
      final m = (res.data is Map ? res.data['message'] : res.data) as Map?;
      final raw = m?['students'];
      if (raw is! List) return const [];
      return [
        for (final s in raw)
          if (s is Map && s['league'] is Map)
            StudentLeagueStanding(
              studentId: (s['student'] ?? '').toString(),
              tier: ((s['league'] as Map)['tier'] ?? '').toString(),
              points:
                  ((s['league'] as Map)['points'] as num?)?.toInt() ?? 0,
              rank: ((s['league'] as Map)['rank'] as num?)?.toInt(),
              cohortSize:
                  ((s['league'] as Map)['cohort_size'] as num?)?.toInt() ?? 0,
            ),
      ];
    } catch (e) {
      debugPrint('==> partner league fetch failed: $e');
      return const [];
    }
  }
}

/// Host route shell for the partner-facing dashboard. Gated by AccessPolicy
/// (a non-partner account is denied) and sourced from the backend — the
/// partner is on their own separate account/device from the student.
@RoutePage(name: 'PartnerDashboardRoute')
class PartnerDashboardRouteView extends StatelessWidget {
  const PartnerDashboardRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    // Demo session: there is no backend to source a partner account or its
    // reports from, so the parent-role preview would hit the access gate and
    // show empty. Swap in representative in-memory sources so the reporting
    // side renders. Never reached by a real session.
    return Stack(
      children: [
        PartnerDashboardPage(
          deps: DemoSession.demoActive
              ? PartnerDashboardDeps(
                  access: _DemoAccessStatusSource(),
                  source: _DemoPartnerReportSource(),
                  billing: _DemoPartnerBilling(),
                  links: _DemoPartnerStudentLinks(),
                )
              : PartnerDashboardDeps(
                  access: KvAccessStatusSource(),
                  source: HttpPartnerReportSource(),
                  billing: HttpPartnerBilling(),
                  links: HttpPartnerStudentLinks(),
                  league: HttpPartnerLeagueSource(),
                ),
          onAddStudent: () => context.router.replace(const AddStudentRoute()),
          // Sponsor/CSI channel entry (#42 item 3): cohort aggregates +
          // packaged outcome report, pushed so back returns here.
          onSponsorReports: () =>
              context.router.push(const SponsorDashboardRoute()),
          // The weekly report's big sibling: the selected student's whole
          // term per subject, pushed so back returns here.
          onOpenTermReport: (studentId) =>
              context.router.push(TermReportRoute(studentId: studentId)),
        ),
        // Partner-side floating nav — content scrolls under it.
        const Align(
          alignment: Alignment.bottomCenter,
          child: SupachargePartnerNav(currentIndex: 0),
        ),
      ],
    );
  }
}

/// Host route shell for the partner Profile tab, now rendering base_sdk's
/// generic profile host. Route name and /partner-profile path are unchanged;
/// the billing/students sections (and their demo/real source split, and the
/// server-quoted monthly rate) are registered by
/// [registerSupachargeProfileSections].
///
/// At plane widths the shell hosts the profile in lms_sdk's
/// [LmsProfilePlaneHost] — a two-plane PlaneHost, the universal profile
/// cap (frames 1c/1f): the page spreads over two planes. On THREE planes
/// the host seeds the Students section's detail (the pay-toggle list,
/// [LmsProfileSections.partnerStudentsSectionId]) into the third plane
/// from the first frame, so the tab never lands with an empty stage (Ray
/// 2026-09-07); that landing state is not a pushed step, so the FULL
/// partner nav stays put: a top-level tab keeps its floating nav
/// (12:36Z); the corner Back pill belongs to pushed pages only (12d). On
/// two planes nothing is seeded and the page keeps both planes; on phones
/// the host is the bare page, exactly as before.
@RoutePage(name: 'PartnerProfileRoute')
class PartnerProfileRouteView extends StatelessWidget {
  const PartnerProfileRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    _lmsProfilePersona = _LmsProfilePersona.partner;
    return Stack(
      children: [
        Positioned.fill(
          child: LmsProfilePlaneHost(
            defaultSectionId: LmsProfileSections.partnerStudentsSectionId,
            profileBuilder: (context) => const GenericProfilePage(),
          ),
        ),
        // Partner-side floating nav — content scrolls under it.
        const Align(
          alignment: Alignment.bottomCenter,
          child: SupachargePartnerNav(currentIndex: 3),
        ),
      ],
    );
  }
}

/// Host route shell for the per-subject Board (decision #32): pushed from an
/// enrolled subject's card in the catalog, back button returns to Subjects.
@RoutePage(name: 'SubjectBoardRoute')
class SubjectBoardRouteView extends StatelessWidget {
  final String subject;

  const SubjectBoardRouteView({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    return TheBoardPage(
      subject: subject,
      showBack: true,
      // The student's own weekly-league strip (tier, points, rank — server
      // answers via the same engagement endpoints /league reads), tapping
      // through to the full Streak & League surface.
      engagement: HttpEngagementSource(),
      onOpenLeague: () => context.router.push(const LeagueRoute()),
    );
  }
}

/// Host route shell for the per-subject Term Report (/term-report) — the
/// weekly report's big sibling, server-assembled from synced evidence.
/// Reached from the partner dashboard (with the linked student's id) and
/// from the student's own profile (no id: the caller's own report). Which
/// endpoint answers is decided here; permissions are the server's
/// (partner_term_report only ever serves the caller's own Active links).
@RoutePage(name: 'TermReportRoute')
class TermReportRouteView extends StatelessWidget {
  /// Null = the signed-in student's own report; set = the partner variant
  /// for that linked student.
  final String? studentId;

  const TermReportRouteView({super.key, this.studentId});

  @override
  Widget build(BuildContext context) {
    final source = HttpTermReportSource();
    return TermReportPage(
      load: () => studentId == null
          ? source.myTermReport()
          : source.partnerTermReport(studentId!),
    );
  }
}

/// Demo-only access source: reports a partner account so the dashboard's
/// AccessPolicy gate opens without a real logged-in partner.
class _DemoAccessStatusSource implements AccessStatusSource {
  @override
  Future<AccessStatus> current() async => AccessStatus.partner;
}

/// Demo-only billing source: the partner-as-payer toggle succeeds instantly
/// so the assume/release switch is exercisable in the IS_DEMO preview (no real
/// payment backend). Never used in production.
class _DemoPartnerBilling implements PartnerBilling {
  @override
  Future<PartnerBillingOutcome> assumeBilling(String studentId) async =>
      PartnerBillingOutcome.updated;

  @override
  Future<PartnerBillingOutcome> releaseBilling(String studentId) async =>
      PartnerBillingOutcome.updated;
}

/// Demo-only student links: unlinking succeeds instantly so the remove flow
/// is exercisable in the IS_DEMO preview. The removal is not persisted — the
/// seeded list is const and comes back on restart. Never used in production.
class _DemoPartnerStudentLinks implements PartnerStudentLinks {
  @override
  Future<bool> unlink(String studentId) async => true;
}

/// P3.1 partner-link host adapter: severs the partner↔student link
/// (rlms.api.partner.unlink_student via its manifest alias
/// paas.api.lms.partner_unlink_student, same base as every other partner
/// call here). The student's own account, history and progress are
/// untouched; only the link and the billing that rides on it go — the
/// backend hands billing back to the student before revoking.
class HttpPartnerStudentLinks implements PartnerStudentLinks {
  @override
  Future<bool> unlink(String studentId) async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<HttpService>()) return false;
    try {
      final client = getIt.get<HttpService>().client(requireAuth: true);
      final res = await client.post(
        _kGatewayPath,
        // Same parameter name as the sibling partner-side calls
        // (assume/release_billing): the backend resolves it against the
        // caller's OWN Active links only.
        data: {
          'cmd': 'api.lms.partner_unlink_student',
          'payload': {'student': studentId},
        },
      );
      final message = res.data is Map ? res.data['message'] : null;
      // Treat an explicit false as a refusal; anything else 2xx is a success.
      return message is Map ? message['ok'] != false : true;
    } catch (e) {
      debugPrint('==> PartnerStudentLinks: unlink failed: $e');
      return false;
    }
  }
}

/// Demo-only report source: several linked students with representative
/// weekly reports and alerts, so the partner dashboard previews as a
/// populated reporting surface (parent role in IS_DEMO).
///
/// Deliberately a sponsor-sized roster (a charity or foundation account),
/// not a two-child family: it is the only way the surfaces built for scale
/// are reachable in the preview — the switcher's "4+" overflow, the
/// profile's collapsed student list, and its search box all appear only
/// past their own thresholds.
class _DemoPartnerReportSource implements PartnerReportSource {
  static const _students = [
    LinkedStudent(id: 'demo-1', name: 'Amahle', paidByPartner: true),
    LinkedStudent(id: 'demo-2', name: 'Sipho'),
    LinkedStudent(id: 'demo-3', name: 'Naledi', paidByPartner: true),
    LinkedStudent(id: 'demo-4', name: 'Thabo'),
    LinkedStudent(id: 'demo-5', name: 'Zanele', paidByPartner: true),
    LinkedStudent(id: 'demo-6', name: 'Lerato'),
    LinkedStudent(id: 'demo-7', name: 'Kagiso', paidByPartner: true),
    LinkedStudent(id: 'demo-8', name: 'Nomsa'),
    LinkedStudent(id: 'demo-9', name: 'Tshepo', paidByPartner: true),
    LinkedStudent(id: 'demo-10', name: 'Palesa'),
    LinkedStudent(id: 'demo-11', name: 'Katlego', paidByPartner: true),
    LinkedStudent(id: 'demo-12', name: 'Refilwe'),
  ];

  @override
  Future<List<LinkedStudent>> students() async => _students;

  @override
  Future<PartnerReport> weeklyReport(DateTime weekStart,
      {String? studentId}) async {
    // Derive the report from the seeded list rather than naming two students
    // inline: every student the switcher can reach needs their own numbers,
    // otherwise picking one from the overflow shows someone else's week.
    final i = _students.indexWhere((s) => s.id == studentId);
    final index = i < 0 ? 0 : i;
    final student = _students[index];
    // Spread deterministically off the index so each student reads as a
    // distinct week and the switcher visibly changes the report.
    final attended = 5 - (index % 3);
    final base = 80 - (index * 4);
    return PartnerReport(
      studentName: student.name,
      weekStart: weekStart,
      sessionsScheduled: 5,
      sessionsAttended: attended,
      sessionsSkippedAnswered: index.isEven ? 1 : 0,
      sessionsSkippedUnanswered: 5 - attended - (index.isEven ? 1 : 0) > 0
          ? 5 - attended - (index.isEven ? 1 : 0)
          : 0,
      performanceScores: {
        'Algebra': base,
        'Functions': base + 6,
        'Trigonometry': base - 5,
      },
      engagementDeltaPercent: index.isEven ? 6 - index : index - 4,
      engagementRatePercent: 82 - (index * 3),
      dataUsedMb: 145.8 - (index * 9.4),
      currentStreak: (5 - index) < 0 ? 0 : 5 - index,
    );
  }

  @override
  Future<List<PartnerAlert>> alerts() async {
    final now = DateTime.now();
    return [
      PartnerAlert(
        type: PartnerAlertType.milestoneReached,
        message: 'Amahle hit a 5-session streak',
        at: now.subtract(const Duration(hours: 6)),
        studentId: 'demo-1',
      ),
      PartnerAlert(
        type: PartnerAlertType.sessionSkipped,
        message: "Sipho skipped Tuesday's Algebra class",
        at: now.subtract(const Duration(days: 1, hours: 2)),
        studentId: 'demo-2',
      ),
      PartnerAlert(
        type: PartnerAlertType.scoreDropped,
        message: "Sipho's Geometry score dropped 8%",
        at: now.subtract(const Duration(days: 2)),
        studentId: 'demo-2',
      ),
    ];
  }
}

/// P3.1 partner-as-payer host adapter: flips billing responsibility on the
/// partner link (rlms.api.partner.assume/release_billing). Delegated
/// billing only — the actual charge rides subscriptions_sdk's normal
/// purchase flow with beneficiary_user_id set; this records who is
/// responsible.
class HttpPartnerBilling implements PartnerBilling {
  Future<PartnerBillingOutcome> _call(String method, String studentId) async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<HttpService>()) {
      return PartnerBillingOutcome.failed;
    }
    try {
      final res =
          await getIt.get<HttpService>().client(requireAuth: true).post(
        _kGatewayPath,
        data: {
          'cmd': 'api.lms.$method',
          'payload': {'student': studentId},
        },
      );
      final code = res.statusCode ?? 0;
      return code >= 200 && code < 300
          ? PartnerBillingOutcome.updated
          : PartnerBillingOutcome.failed;
    } catch (e) {
      debugPrint('==> partner billing $method failed: $e');
      return PartnerBillingOutcome.failed;
    }
  }

  @override
  Future<PartnerBillingOutcome> assumeBilling(String studentId) =>
      _call('partner_assume_billing', studentId);

  @override
  Future<PartnerBillingOutcome> releaseBilling(String studentId) =>
      _call('partner_release_billing', studentId);
}

/// P3.1 partner-first signup — the reversed invite. Same backend-owned
/// delivery posture as HttpPartnerInviteSender: the server sends the
/// SMS/email and mints the pairing code the student enters after signup.
class HttpStudentInviteSender implements StudentInviteSender {
  @override
  Future<PartnerInviteResult> send(PartnerInvite invite) async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<HttpService>()) {
      return PartnerInviteResult.failed;
    }
    try {
      final res =
          await getIt.get<HttpService>().client(requireAuth: true).post(
        _kGatewayPath,
        data: {
          'cmd': 'api.lms.partner_invite_student',
          'payload': {
            'contact': invite.contact,
            'channel': invite.channel.name,
            'relationship': invite.relationship.name,
          },
        },
      );
      return _parseInviteResponse(res.data, res.statusCode ?? 0);
    } catch (e) {
      debugPrint('==> student invite send failed: $e');
      return PartnerInviteResult.failed;
    }
  }
}

/// Student-side redemption of a partner-initiated invite code
/// (rlms.api.partner.redeem_student_invite). Frappe signals the two
/// user-correctable rejections through thrown messages — matched here to
/// give the student an actionable error instead of a generic failure.
class HttpPartnerLinkRedeemer implements PartnerLinkRedeemer {
  @override
  Future<RedeemOutcome> redeem(String code) async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<HttpService>()) return RedeemOutcome.failed;
    try {
      final res =
          await getIt.get<HttpService>().client(requireAuth: true).post(
        _kGatewayPath,
        data: {
          'cmd': 'api.lms.partner_redeem_student_invite',
          'payload': {'token': code},
        },
      );
      final status = res.statusCode ?? 0;
      return status >= 200 && status < 300
          ? RedeemOutcome.linked
          : RedeemOutcome.failed;
    } catch (e) {
      final text = e.toString();
      if (text.contains('already have an accountability partner')) {
        return RedeemOutcome.alreadyPartnered;
      }
      if (text.contains('invalid or has already been used')) {
        return RedeemOutcome.invalidCode;
      }
      debugPrint('==> partner code redeem failed: $e');
      return RedeemOutcome.failed;
    }
  }
}

/// Host route shell for the partner-side "add a student" screen (P3.1).
@RoutePage(name: 'AddStudentRoute')
class AddStudentRouteView extends StatelessWidget {
  const AddStudentRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    // Reached from a dashboard action, not from the nav bar, so it gets a
    // back button and NO floating nav. It previously carried
    // SupachargePartnerNav(currentIndex: 1), which lit up "Subjects" as the
    // active tab while the student form was on screen — the nav claimed the
    // viewer was somewhere they weren't, and there was no way back out.
    return AddStudentPage(
      deps: AddStudentDeps(sender: HttpStudentInviteSender()),
      showBack: true,
    );
  }
}

/// Host route shell for the student-side "redeem partner code" screen
/// (P3.1). On success the student's partner-linked state is refreshed so
/// the discounted rate shows immediately, same as the student-initiated
/// invite path.
@RoutePage(name: 'RedeemPartnerCodeRoute')
class RedeemPartnerCodeRouteView extends StatelessWidget {
  const RedeemPartnerCodeRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    return RedeemPartnerCodePage(
      deps: RedeemPartnerCodeDeps(
        redeemer: HttpPartnerLinkRedeemer(),
        onLinked: () async {
          final userId = LocalStorage.getUser()?.id?.toString();
          if (userId != null && userId.isNotEmpty) {
            await hasAccountabilityPartner(userId);
          }
        },
      ),
    );
  }
}

// ── P3.2 partner-side account entry (accept invite / partner-first signup) ──
//
// Appended after the RedeemPartnerCodeRoute region deliberately: the
// HttpPartnerStudentLinks block above is under concurrent change (PR #51),
// so nothing here touches or reorders that region.

/// Partner-side redemption of a STUDENT-initiated invite
/// (rlms.api.partner.accept_invite). GUEST endpoint — the acceptor has no
/// session yet, so `requireAuth: false` (TokenInterceptor skips auth
/// entirely). Frappe signals every user-correctable rejection through
/// thrown localized messages; the substring → typed-outcome mapping lives
/// in lms_sdk (mapAcceptInviteError) so it is unit-tested, unlike the
/// inline matching HttpPartnerLinkRedeemer started with.
class HttpPartnerInviteAccepter implements PartnerInviteAccepter {
  @override
  Future<AcceptInviteOutcome> acceptInvite({
    required String code,
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
  }) async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<HttpService>()) return AcceptInviteOutcome.failed;
    try {
      final res =
          await getIt.get<HttpService>().client(requireAuth: false).post(
        _kGatewayPath,
        data: {
          'cmd': 'api.lms.partner_accept_invite',
          'payload': {
            // P3.2: the wire name stays `token` for compatibility; it
            // carries the 6-digit pairing code the partner typed.
            'token': code,
            'email': email,
            'password': password,
            'first_name': firstName,
            'last_name': lastName,
          },
        },
      );
      // Success body is only {email: ...} (no session — the route view
      // chains a real login), so the status is the whole signal, same as
      // HttpPartnerLinkRedeemer.
      final status = res.statusCode ?? 0;
      return status >= 200 && status < 300
          ? AcceptInviteOutcome.success
          : AcceptInviteOutcome.failed;
    } catch (e) {
      final outcome = mapAcceptInviteError(e.toString());
      if (outcome == AcceptInviteOutcome.failed) {
        debugPrint('==> partner accept invite failed: $e');
      }
      return outcome;
    }
  }
}

/// P3.1 partner-first signup (rlms.api.partner.signup): mints a partner
/// account with no student links yet. Same guest posture and same
/// SDK-owned error mapping as [HttpPartnerInviteAccepter].
class HttpPartnerSignupService implements PartnerSignupService {
  @override
  Future<PartnerSignupOutcome> signup({
    required String email,
    required String password,
    required String firstName,
    String lastName = '',
  }) async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<HttpService>()) return PartnerSignupOutcome.failed;
    try {
      final res =
          await getIt.get<HttpService>().client(requireAuth: false).post(
        _kGatewayPath,
        data: {
          'cmd': 'api.lms.partner_signup',
          'payload': {
            'email': email,
            'password': password,
            'first_name': firstName,
            'last_name': lastName,
          },
        },
      );
      final status = res.statusCode ?? 0;
      return status >= 200 && status < 300
          ? PartnerSignupOutcome.success
          : PartnerSignupOutcome.failed;
    } catch (e) {
      final outcome = mapPartnerSignupError(e.toString());
      if (outcome == PartnerSignupOutcome.failed) {
        debugPrint('==> partner signup failed: $e');
      }
      return outcome;
    }
  }
}

/// Success handoff for both partner account-entry flows: accept_invite and
/// signup return `{email}` only — NO session — so this chains a normal
/// email+password login through auth_sdk's registered facade (the same
/// exchange the login screen performs) and then navigates EXPLICITLY to
/// /partner-dashboard.
///
/// The explicit path is deliberate, not a shortcut: the account was minted
/// with Frappe role "Accountability Partner", and no client code maps that
/// to the 'partner' role string LocalStorage-based gating reads — so
/// nothing here branches on the login payload's role. If the chained login
/// fails (backend hiccup — the account/link DOES exist server-side), the
/// user lands on the normal login screen with a clear message; LoginPage
/// takes no prefill argument, so the email is not pre-entered.
Future<void> _partnerPostAuthHandoff(
    BuildContext context, String email, String password) async {
  final getIt = GetIt.instance;
  String token = '';
  if (getIt.isRegistered<AuthRepositoryFacade>()) {
    try {
      final res = await getIt
          .get<AuthRepositoryFacade>()
          .login(email: email, password: password);
      res.when(
        success: (data) => token = data.data?.accessToken ?? '',
        failure: (failure, status) =>
            debugPrint('==> partner handoff login refused: $failure ($status)'),
      );
    } catch (e) {
      debugPrint('==> partner handoff login failed: $e');
    }
  }
  if (token.isNotEmpty) {
    await LocalStorage.setToken(token);
  }
  if (!context.mounted) return;
  if (token.isNotEmpty) {
    context.router.replaceNamed('/partner-dashboard');
  } else {
    AppHelpers.showCheckTopSnackBar(
        context, AppHelpers.getTranslation(TrKeys.accountReadySignIn));
    context.router.replaceNamed('/login');
  }
}

/// Host route shell for the partner-side accept-invite screen (P3.2 typed
/// pairing codes — this page IS the redemption surface; no web page or
/// deep link exists). Stateful for the same reason as the onboarding
/// shell: the deps object is the riverpod family key, so it must be built
/// ONCE — rebuilding it per frame would reset the form mid-entry.
@RoutePage(name: 'PartnerAcceptInviteRoute')
class PartnerAcceptInviteRouteView extends StatefulWidget {
  const PartnerAcceptInviteRouteView({super.key});

  @override
  State<PartnerAcceptInviteRouteView> createState() =>
      _PartnerAcceptInviteRouteViewState();
}

class _PartnerAcceptInviteRouteViewState
    extends State<PartnerAcceptInviteRouteView> {
  late final PartnerAcceptInviteDeps _deps = PartnerAcceptInviteDeps(
    accepter: HttpPartnerInviteAccepter(),
    onAccountReady: (email, password) =>
        _partnerPostAuthHandoff(context, email, password),
    onGoToSignup: () => context.router.replaceNamed('/partner-signup'),
  );

  @override
  Widget build(BuildContext context) => PartnerAcceptInvitePage(deps: _deps);
}

/// Host route shell for partner-first signup (P3.1): no code — the partner
/// creates the reporting-only login first and invites students from the
/// dashboard afterwards (AddStudentRoute).
@RoutePage(name: 'PartnerSignupRoute')
class PartnerSignupRouteView extends StatefulWidget {
  const PartnerSignupRouteView({super.key});

  @override
  State<PartnerSignupRouteView> createState() => _PartnerSignupRouteViewState();
}

class _PartnerSignupRouteViewState extends State<PartnerSignupRouteView> {
  late final PartnerSignupDeps _deps = PartnerSignupDeps(
    service: HttpPartnerSignupService(),
    onAccountReady: (email, password) =>
        _partnerPostAuthHandoff(context, email, password),
    onGoToAcceptInvite: () =>
        context.router.replaceNamed('/partner-accept-invite'),
  );

  @override
  Widget build(BuildContext context) => PartnerSignupPage(deps: _deps);
}

/// Host route shell for the async homework help screen (/homework-help —
/// product log #42 item 1: #4's send-and-wait design + #1's
/// guide-don't-solve tool). The student submits a homework question
/// anytime and later gets back a guided multiple-choice check built from
/// their own problem — never a pasted answer; essay-type questions come
/// back politely declined.
///
/// The fronting persona is the student's own grade-assigned session host
/// ([assistantPersonaForGrade] over the host-side [studentGrade] read —
/// decision #40's one-host-per-grade rule; never a hard-coded name).
/// Access rides [LessonCapability.homeworkTool] through the same
/// [KvAccessStatusSource] the lesson player gates with.
@RoutePage(name: 'HomeworkHelpRoute')
class HomeworkHelpRouteView extends StatefulWidget {
  const HomeworkHelpRouteView({super.key});

  @override
  State<HomeworkHelpRouteView> createState() => _HomeworkHelpRouteViewState();
}

class _HomeworkHelpRouteViewState extends State<HomeworkHelpRouteView> {
  int? _grade;
  bool _gradeResolved = false;

  @override
  void initState() {
    super.initState();
    studentGrade().then((grade) {
      if (mounted) {
        setState(() {
          _grade = grade;
          _gradeResolved = true;
        });
      }
    }).catchError((Object e) {
      debugPrint('==> homework help grade lookup failed: $e');
      if (mounted) setState(() => _gradeResolved = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_gradeResolved) {
      // One frame at most (the LessonRouteView pattern): resolve the grade
      // before mounting so the page greets the student's ACTUAL host.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return HomeworkHelpPage(
      repository: HttpHomeworkRepository(),
      assistant: assistantPersonaForGrade(_grade),
      accessSource: KvAccessStatusSource(),
      onShowPlans: () => context.router.push(TutorDiscoveryRoute()),
    );
  }
}

/// Host route shell for the per-subject Supacharge Readiness Score
/// (decisions log #42, gap 5): the student sees each enrolled subject's
/// server-computed score and can mint a shareable, verifiable snapshot —
/// the WhatsApp card parents forward and sponsors receive.
///
/// The SERVER is the sole authority for every number and every share
/// artefact on this page (`my_readiness` / `readiness_create_share` in
/// rlms's api/readiness.py): the app renders what the backend answered and
/// never computes, adjusts, or re-labels a score. Reached from a profile/
/// dashboard action, so it gets a back button and NO floating nav (same
/// posture as AddStudentRoute).
@RoutePage(name: 'ReadinessRoute')
class ReadinessRouteView extends StatefulWidget {
  const ReadinessRouteView({super.key});

  @override
  State<ReadinessRouteView> createState() => _ReadinessRouteViewState();
}

class _ReadinessRouteViewState extends State<ReadinessRouteView> {
  // Talks to the concrete HTTP repository on purpose: the readiness
  // methods are not on the LmsRepository interface (promoting them would
  // break the demo repository and the test fakes), and this surface is
  // production-only — demo mode has no backend to verify a credential
  // against, and a credential is exactly the thing that must never be
  // seeded from demo data (decisions log #47).
  final HttpLmsRepository _repository = HttpLmsRepository();
  late Future<List<SubjectReadiness>> _scores;

  @override
  void initState() {
    super.initState();
    _scores = _repository.myReadiness();
  }

  Future<void> _reload() async {
    setState(() => _scores = _repository.myReadiness());
    await _scores;
  }

  Future<void> _share(SubjectReadiness entry) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final share = await _repository.createReadinessShare(entry.subject);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => _ReadinessShareSheet(share: share),
      );
    } catch (e) {
      debugPrint('==> ReadinessRouteView.share failure: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not create a share link. Attend sessions and answer '
            'exercise questions, then try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Readiness Score')),
      body: FutureBuilder<List<SubjectReadiness>>(
        future: _scores,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const <SubjectReadiness>[];
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No Readiness Scores yet',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enrol in a subject, attend sessions and answer '
                      'exercise questions — your per-subject score is '
                      'computed from that work.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _reload,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: entry.hasScore
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: entry.score! / 100.0,
                                      strokeWidth: 6,
                                    ),
                                    Text(
                                      '${entry.score}',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                  ],
                                )
                              : Icon(
                                  Icons.hourglass_empty,
                                  color: theme.disabledColor,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.subject,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.hasScore
                                    ? (entry.band ?? '')
                                    : 'Not enough activity yet',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (entry.hasScore)
                          FilledButton.icon(
                            onPressed: () => _share(entry),
                            icon: const Icon(Icons.ios_share, size: 18),
                            label: const Text('Share'),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// The share sheet for one minted Readiness Score snapshot. Everything on
/// it — the WhatsApp message, the verify link, the card image URL — was
/// assembled SERVER-side at mint time; this sheet only offers copy actions
/// (no share_plus/url_launcher dependency: WhatsApp sharing is
/// paste-driven, which is how the link travels between apps anyway).
class _ReadinessShareSheet extends StatelessWidget {
  final ReadinessShare share;

  const _ReadinessShareSheet({required this.share});

  Future<void> _copy(BuildContext context, String label, String text) async {
    final messenger = ScaffoldMessenger.of(context);
    await services.Clipboard.setData(services.ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${share.subject} — ${share.score}/100',
              style: theme.textTheme.titleLarge,
            ),
            if (share.band != null) ...[
              const SizedBox(height: 4),
              Text(share.band!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            Text(
              'Anyone with the link sees only: first name, subject, score '
              'and month — nothing else.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  _copy(context, 'WhatsApp message', share.whatsappText),
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('Copy WhatsApp message'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _copy(context, 'Verify link', share.verifyUrl),
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: const Text('Copy verify link'),
            ),
            if (share.cardUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _copy(context, 'Card link', share.cardUrl),
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('Copy card image link'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Real sponsor-report source (rlms.api.sponsor): the sponsor/CSI channel's
/// two aggregate endpoints, both scoped server-side to the logged-in
/// sponsor. AGGREGATES ONLY come back — no learner names, no per-learner
/// rows — so this adapter has nothing per-learner to parse by construction.
class HttpSponsorReportSource implements SponsorReportSource {
  @override
  Future<SponsorDashboardSummary> dashboard() async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<HttpService>()) {
      return const SponsorDashboardSummary();
    }
    final res = await getIt.get<HttpService>().client(requireAuth: true).post(
          _kGatewayPath,
          data: {'cmd': 'api.lms.sponsor_dashboard'},
        );
    final m = (res.data is Map ? res.data['message'] : res.data) as Map?;
    return SponsorDashboardSummary.fromJson(m);
  }

  @override
  Future<SponsorOutcomeReport> outcomeReport(
      {DateTime? start, DateTime? end}) async {
    final getIt = GetIt.instance;
    final e = end ?? DateTime.now();
    final s = start ?? e.subtract(const Duration(days: 90));
    if (!getIt.isRegistered<HttpService>()) {
      return SponsorOutcomeReport(periodStart: s, periodEnd: e);
    }
    String d(DateTime t) => '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
    final res = await getIt.get<HttpService>().client(requireAuth: true).post(
      _kGatewayPath,
      data: {
        'cmd': 'api.lms.sponsor_outcome_report',
        'payload': {
          if (start != null) 'period_start': d(s),
          if (end != null) 'period_end': d(e),
        },
      },
    );
    final m = (res.data is Map ? res.data['message'] : res.data) as Map?;
    return SponsorOutcomeReport.fromJson(m, s, e);
  }
}

/// Host route shell for the sponsor/CSI dashboard (#42 item 3), pushed from
/// the partner dashboard's "Sponsor reports" action. Same AccessPolicy gate
/// as the partner surface (the sponsor is a partner persona); an active demo
/// session swaps in the SDK's deterministic demo source, matching the partner
/// preview.
@RoutePage(name: 'SponsorDashboardRoute')
class SponsorDashboardRouteView extends StatelessWidget {
  const SponsorDashboardRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    return SponsorDashboardPage(
      deps: DemoSession.demoActive
          ? SponsorDashboardDeps(
              access: _DemoAccessStatusSource(),
              source: const DemoSponsorReportSource(),
            )
          : SponsorDashboardDeps(
              access: KvAccessStatusSource(),
              source: HttpSponsorReportSource(),
            ),
    );
  }
}

/// Host route shell for the streaks + weekly-league surface (decision #42
/// gap 4). Everything on it is a server answer — points, ranks, and tiers
/// come from the rlms engagement endpoints via [HttpEngagementSource]; the
/// device computes nothing. Pushed (e.g. from the profile), so it keeps a
/// back affordance and carries no floating nav.
@RoutePage(name: 'LeagueRoute')
class LeagueRouteView extends StatelessWidget {
  const LeagueRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    // Demo session: there is no backend to answer the engagement endpoints,
    // so the streak reads 0 and the league card falls back to its offline
    // copy. Swap in a representative in-memory week so the surface previews
    // populated. Never reached by a real session.
    return LeaguePage(
        source: DemoSession.demoActive
            ? _DemoEngagementSource()
            : HttpEngagementSource());
  }
}

/// Demo-only engagement source (`--dart-define=IS_DEMO=true`): a lived-in
/// attendance streak and a representative Silver-league week so /league
/// previews as the populated surface (in production every number here is a
/// server answer from the rlms engagement endpoints — nothing is computed
/// on device, and nothing in the real path reads these rows). The viewer
/// sits at rank 4, one place outside the promotion zone, which is exactly
/// the "climb the league" framing the tour caption sells; the cohort uses
/// the same privacy-reduced first-name + last-initial shape the server
/// emits. Never used in production.
class _DemoEngagementSource implements EngagementSource {
  @override
  Future<StreakStatus> myStreak() async =>
      const StreakStatus(current: 6, best: 14);

  @override
  Future<LeagueWeek?> leagueWeek() async => const LeagueWeek(
        tier: 'Silver',
        points: 402,
        rank: 4,
        cohortSize: 10,
        // Tighter zones than the server defaults (10/5): with a ten-strong
        // cohort they put both zone dividers on screen — top three promote,
        // bottom three demote — so the ladder mechanics are visible.
        promoteTop: 3,
        demoteBottom: 3,
        standings: [
          LeagueStanding(displayName: 'Lubanzi K.', points: 512, rank: 1),
          LeagueStanding(displayName: 'Anele M.', points: 468, rank: 2),
          LeagueStanding(displayName: 'Karabo S.', points: 431, rank: 3),
          LeagueStanding(
              displayName: 'Sibusiso D.', points: 402, rank: 4, isMe: true),
          LeagueStanding(displayName: 'Precious N.', points: 371, rank: 5),
          LeagueStanding(displayName: 'Lwazi T.', points: 340, rank: 6),
          LeagueStanding(displayName: 'Ayanda B.', points: 312, rank: 7),
          LeagueStanding(displayName: 'Olwethu Z.', points: 288, rank: 8),
          LeagueStanding(displayName: 'Neo R.', points: 245, rank: 9),
          LeagueStanding(displayName: 'Palesa J.', points: 210, rank: 10),
        ],
      );
}

/// Host route shell for the billing history screen (/billing-history): the
/// money side of the account — every payment this login has funded for
/// Supacharge live session tutoring, from
/// rlms.api.billing.my_billing_history via its manifest alias (same
/// paas.api.lms.* base as every other rlms call here). A student sees
/// their own receipts; a payer-partner sees each linked student's charges
/// named. Reached from a profile action, not the nav bar, so it keeps the
/// default back affordance.
@RoutePage(name: 'BillingHistoryRoute')
class BillingHistoryRouteView extends StatelessWidget {
  const BillingHistoryRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    return BillingHistoryPage(
      source: HttpBillingHistorySource(),
      // Rows covering the viewer themselves drop the redundant "For <id>"
      // line; a partner's per-student rows keep it.
      currentUserId: LocalStorage.getUser()?.id?.toString(),
    );
  }
}

/// Host route shell for the current-entitlements screen (/my-plan): the
/// coverage side — whether the plan is active today and which date ranges
/// it covered, from rlms.api.student.my_entitlements (product log #27), so
/// the app explains locks instead of letting the student discover them by
/// being refused. "See plans" routes into the same tutor-discovery/plans
/// surface as the other subscribe paths.
@RoutePage(name: 'EntitlementsRoute')
class EntitlementsRouteView extends StatelessWidget {
  const EntitlementsRouteView({super.key});

  @override
  Widget build(BuildContext context) {
    // Demo session: there is no backend to answer
    // rlms.api.student.my_entitlements, so the screen lands on its retry
    // state. Swap in an in-memory active plan so the coverage surface
    // previews as the explainer it is. Never reached by a real session.
    return EntitlementsPage(
      source: DemoSession.demoActive
          ? _DemoEntitlementsSource()
          : HttpEntitlementsSource(),
      onShowPlans: () => context.router.push(TutorDiscoveryRoute()),
      // Where a holiday buyer looks for what they bought: the coverage
      // page routes them straight into the programme surface.
      onOpenHolidayProgramme: () =>
          context.router.push(const HolidayProgrammeRoute()),
    );
  }
}

/// Demo-only entitlements source (`--dart-define=IS_DEMO=true`): an ACTIVE
/// plan with a believable coverage history, so /my-plan previews as the
/// surface that explains access — live sessions and every grade's skills
/// open, the Holiday Programme doorway showing (the summary's fail-open
/// defaults keep assistant chat and holiday access on), and covered date
/// ranges under it — instead of the offline retry state. Consistent with
/// the rest of the demo cast: the demo student is already treated as
/// subscribed (the Full Access plan the demo catalog sells at
/// [kStandardMonthlyRate] — R299/month, R249 with a partner), and this is
/// the coverage side of that same story. Dates are relative to today so
/// the preview never goes stale: the current stretch has been paying for
/// about six months (a Grade 12 year in progress), and a closed stretch
/// from last year keeps the "lapsed coverage stays watchable" promise
/// demonstrable. Nothing here prices or grants anything; production reads
/// the server summary only. Never used in production.
class _DemoEntitlementsSource implements EntitlementsSource {
  @override
  Future<EntitlementSummary> summary() async {
    final now = DateTime.now();
    return EntitlementSummary(
      active: true,
      // Most-recent-first, the same order EntitlementSummary.fromJson
      // delivers after sorting the server rows.
      periods: [
        // The open, currently-paying stretch (no end date — ongoing).
        EntitlementPeriod(start: DateTime(now.year, now.month - 6, 1)),
        // Last school year's finished stretch: February through November,
        // the shape a real CAPS-year subscription leaves behind.
        EntitlementPeriod(
          start: DateTime(now.year - 1, 2, 1),
          end: DateTime(now.year - 1, 11, 30),
        ),
      ],
    );
  }
}
