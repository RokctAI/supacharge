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


// compliance-ignore-file: flutter-http-timeout (test double: Dio uses a scripted in-memory adapter, no real network)
// compliance-ignore-file: obs-flutter-trace (test double: no real network; trace propagation is exercised in the app wiring, not here)

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
// src-path imports (not the replay_sdk barrel) — same pattern as
// audio_sync_events_test: the barrel's full export graph only compiles
// inside a composed host app.
import 'package:replay_sdk/src/common/controllers/audio_sync.dart';
import 'package:replay_sdk/src/common/domain/interface/lesson_audio_source.dart';
import 'package:replay_sdk/src/common/domain/interface/manim_render_sink.dart';
import 'package:replay_sdk/src/common/infrastructure/models/data/manifest.dart';
import 'package:replay_sdk/src/common/infrastructure/models/data/track_event.dart';
import 'package:replay_sdk/src/common/infrastructure/services/asset_store.dart';
import 'package:replay_sdk/src/common/replay_sdk_facade.dart';

class _RecordingSink implements ManimRenderSink {
  int pauses = 0;
  int resumes = 0;
  int clears = 0;

  @override
  void pauseRendering() => pauses++;

  @override
  void resumeRendering() => resumes++;

  @override
  void clearCanvas() => clears++;
}

class _ScriptedAudioSource implements LessonAudioSource {
  String? loaded;
  bool playing = false;
  double position = 0.0;
  final seeks = <double>[];
  double volume = 1.0;

  @override
  Future<void> load(String filePath) async => loaded = filePath;

  @override
  Future<void> seek(double seconds) async {
    seeks.add(seconds);
    position = seconds;
  }

  @override
  Future<void> play() async => playing = true;

  @override
  Future<void> pause() async => playing = false;

  @override
  double get positionSeconds => position;

  @override
  Future<void> setVolume(double volume) async => this.volume = volume;

  @override
  Future<void> get completion async {}

  @override
  void dispose() {}
}

Map<String, dynamic> _manifestJson({List<Map<String, dynamic>>? tracks}) => {
      'version': '1',
      'session_id': 's1',
      'subject': 'maths',
      'grade': 12,
      'topic': 'quadratics',
      'lesson_number': 1,
      'door_close_seconds': 300,
      'scheduled_at': '2026-07-01T10:00:00Z',
      'audio': {
        'lesson': 'a.mp3',
        'format': 'mp3',
        'duration_seconds': 10,
      },
      'assets': const <String>[],
      'tracks': tracks ??
          const [
            {'time': 1.0, 'type': 'subtopic_start', 'ref': 'r1'},
          ],
    };

void main() {
  test(
      'initializeSession loads and parses the session manifest from the '
      'asset store layout', () async {
    final dir = await Directory.systemTemp.createTemp('replay_sdk_facade');
    addTearDown(() => dir.delete(recursive: true));
    final store = AssetStore(client: Dio(), rootOverride: dir.path);
    final root = await store.assetsRoot();
    final manifestFile = File(store.manifestPath(root, 's1'));
    await manifestFile.parent.create(recursive: true);
    await manifestFile.writeAsString(jsonEncode(_manifestJson()));

    final sdk = ReplaySDK(sessionId: 's1', assetStore: store);
    expect(sdk.manifest, isNull);
    await sdk.initializeSession();
    expect(sdk.manifest, isNotNull);
    expect(sdk.manifest!.sessionId, 's1');
    expect(sdk.manifest!.tracks, hasLength(1));
  });

  test('initializeSession throws a StateError when no manifest is on disk',
      () async {
    final dir = await Directory.systemTemp.createTemp('replay_sdk_facade');
    addTearDown(() => dir.delete(recursive: true));
    final store = AssetStore(client: Dio(), rootOverride: dir.path);
    final sdk = ReplaySDK(sessionId: 'missing', assetStore: store);
    expect(sdk.initializeSession(), throwsStateError);
  });

  test(
      'seekTo delegates to the attached AudioSync: audio clock moves, and '
      'events before the target are skipped with late-join semantics, not '
      'replayed', () async {
    final source = _ScriptedAudioSource();
    final sync = AudioSync(
      manimPlayer: _RecordingSink(),
      sessionId: 's1',
      audioSource: source,
      audioPathLoader: () async => '/fake/audio.mp3',
      manifestLoader: () async => ReplayManifest.fromJson(_manifestJson(
        tracks: [
          {'time': 2.0, 'type': 'subtopic_start', 'ref': 'r1'},
          {'time': 6.0, 'type': 'subtopic_end', 'ref': 'r1'},
        ],
      )),
    );
    final received = <TrackEvent>[];
    sync.trackEvents.listen(received.add);

    await sync.startSession();
    final sdk = ReplaySDK(sessionId: 's1', audioSync: sync);
    sdk.seekTo(4.0);
    // The real player was asked to move to the target.
    expect(source.seeks, contains(4.0));

    // Ticks resume from the target: the 2.0s event (behind the seek) must
    // never fire; the 6.0s event fires once the clock passes it.
    source.position = 4.1;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(received, isEmpty);

    source.position = 6.2;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(received.map((e) => e.type).toList(), ['subtopic_end']);
    sync.dispose();
  });

  test('seekTo without an attached AudioSync is a safe no-op', () {
    final sdk = ReplaySDK(sessionId: 's1');
    expect(() => sdk.seekTo(12.5), returnsNormally);
  });
}
