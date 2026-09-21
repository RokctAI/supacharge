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



// The standing-clip channel behind AudioSync: the second audio source that
// plays the framing clips a manifest names OVER the lesson track, ducking
// it (decisions #7/#9/#38/#39/#40). The skip paths matter as much as the
// play path — the clip recordings do not exist yet (blocked on the
// voice-engine call), so a manifest that names clips it has no audio for is
// the ORDINARY case at runtime today, not an error case.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:replay_sdk/src/common/controllers/audio_sync.dart';
import 'package:replay_sdk/src/common/domain/interface/lesson_audio_source.dart';
import 'package:replay_sdk/src/common/domain/interface/manim_render_sink.dart';
import 'package:replay_sdk/src/common/infrastructure/models/data/manifest.dart';

class _SilentSink implements ManimRenderSink {
  @override
  void pauseRendering() {}

  @override
  void resumeRendering() {}

  @override
  void clearCanvas() {}
}

/// Records the volume TRAIL, not just the final level: the duck is only
/// correct if the lesson went down before the clip played and came back up
/// after, and a source that never ducked also ends at 1.0.
class _ScriptedAudioSource implements LessonAudioSource {
  final bool failOnLoad;

  /// Signals end-of-track from inside [play] itself — the very short clip
  /// whose completion arrives before a late listener could hear it.
  final bool completesOnPlay;
  String? loaded;

  /// Every path handed to [load], in order. The TRAIL is what says two
  /// beats stacked on one timestamp played one after another instead of
  /// the second cutting the first off — `loaded` alone only ever shows the
  /// survivor.
  final loads = <String>[];
  bool playing = false;
  double position = 0.0;
  final volumes = <double>[];

  /// BROADCAST, like the real player's `onPlayerComplete`: an end-of-track
  /// event fired before anyone is listening is gone for good. A Completer
  /// would have papered over exactly the ordering this channel has to get
  /// right.
  final _completions = StreamController<void>.broadcast();

  _ScriptedAudioSource({
    this.failOnLoad = false,
    this.completesOnPlay = false,
  });

  /// Ends the "clip" that is currently playing.
  void finish() {
    if (!_completions.isClosed) _completions.add(null);
  }

  @override
  Future<void> load(String filePath) async {
    if (failOnLoad) throw StateError('cannot decode $filePath');
    loaded = filePath;
    loads.add(filePath);
  }

  @override
  Future<void> seek(double seconds) async => position = seconds;

  @override
  Future<void> play() async {
    playing = true;
    if (completesOnPlay) finish();
  }

  @override
  Future<void> pause() async => playing = false;

  @override
  double get positionSeconds => position;

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> get completion => _completions.stream.first;

  @override
  void dispose() {
    _completions.close();
  }
}

ReplayManifest _manifest({
  Map<String, dynamic> clips = const {},
  List<Map<String, dynamic>> tracks = const [],
}) {
  return ReplayManifest.fromJson({
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
      'duration_seconds': 600,
    },
    'assets': const <String>[],
    'tracks': tracks,
    if (clips.isNotEmpty) 'clips': clips,
  });
}

/// A recorded clip: the shape the table takes once the standing-clip
/// recording session has happened.
Map<String, dynamic> _recorded(String ref) => {
      'speaker': ref.split('/').first,
      'script': 'assistants/CAPS/$ref.md',
      'audio': 'assistants/CAPS/$ref.mp3',
    };

/// An authored-but-unrecorded clip: the shape the table takes TODAY.
Map<String, dynamic> _textOnly(String ref) => {
      'speaker': ref.split('/').first,
      'script': 'assistants/CAPS/$ref.md',
    };

void main() {
  const halfway = 'assistant_003/timekeeping/halfway';

  test('duck and play: the lesson track drops for the clip and is restored '
      'when the clip ends', () async {
    final lesson = _ScriptedAudioSource();
    final clip = _ScriptedAudioSource();
    final sync = AudioSync(
      manimPlayer: _SilentSink(),
      sessionId: 's1',
      audioSource: lesson,
      audioPathLoader: () async => '/fake/audio.mp3',
      clipSource: clip,
      clipPathLoader: (c) async => '/fake/${c.ref}.mp3',
      manifestLoader: () async => _manifest(clips: {halfway: _recorded(halfway)}),
    );
    await sync.startSession();

    final beat = sync.playStandingClip(halfway);
    // Let the load/duck/play sequence run up to the completion await.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(clip.loaded, '/fake/$halfway.mp3', reason: 'clip channel loaded');
    expect(clip.playing, isTrue);
    expect(lesson.volumes, [kStandingClipDuckLevel],
        reason: 'lesson ducked, and not yet restored while the clip runs');
    // The lesson track keeps PLAYING under the clip — pausing it would
    // freeze the master clock and drift this device off the live class.
    expect(lesson.playing, isTrue);

    clip.finish();
    expect(await beat, isTrue);
    expect(lesson.volumes, [kStandingClipDuckLevel, 1.0],
        reason: 'lesson restored to full after the clip');
    sync.dispose();
  });

  test('a clip that ends the instant it starts still unducks, without '
      'waiting out the timeout', () async {
    // The end-of-track signal is broadcast: if the channel only listened
    // after play() returned, this clip's completion would be lost and the
    // lesson would sit ducked for kStandingClipMaxDuration.
    final lesson = _ScriptedAudioSource();
    final clip = _ScriptedAudioSource(completesOnPlay: true);
    final sync = AudioSync(
      manimPlayer: _SilentSink(),
      sessionId: 's1',
      audioSource: lesson,
      audioPathLoader: () async => '/fake/audio.mp3',
      clipSource: clip,
      clipPathLoader: (c) async => '/fake/${c.ref}.mp3',
      manifestLoader: () async => _manifest(clips: {halfway: _recorded(halfway)}),
    );
    await sync.startSession();

    final played = await sync
        .playStandingClip(halfway)
        .timeout(const Duration(seconds: 2));
    expect(played, isTrue);
    expect(lesson.volumes, [kStandingClipDuckLevel, 1.0]);
    sync.dispose();
  });

  test('a clip the manifest table has no audio for is skipped, and the '
      'lesson track is never touched', () async {
    final lesson = _ScriptedAudioSource();
    final clip = _ScriptedAudioSource();
    var lookups = 0;
    final sync = AudioSync(
      manimPlayer: _SilentSink(),
      sessionId: 's1',
      audioSource: lesson,
      audioPathLoader: () async => '/fake/audio.mp3',
      clipSource: clip,
      clipPathLoader: (c) async {
        lookups++;
        return '/fake/${c.ref}.mp3';
      },
      // The text-first table: authored script, no recording yet.
      manifestLoader: () async => _manifest(clips: {halfway: _textOnly(halfway)}),
    );
    await sync.startSession();

    expect(await sync.playStandingClip(halfway), isFalse);
    expect(lookups, 0, reason: 'no asset lookup for an unrecorded clip');
    expect(clip.loaded, isNull);
    expect(lesson.volumes, isEmpty, reason: 'never ducked for a skipped beat');
    expect(lesson.playing, isTrue);
    sync.dispose();
  });

  test('a clip whose asset does not resolve on this device is skipped', () async {
    final lesson = _ScriptedAudioSource();
    final clip = _ScriptedAudioSource();
    final sync = AudioSync(
      manimPlayer: _SilentSink(),
      sessionId: 's1',
      audioSource: lesson,
      audioPathLoader: () async => '/fake/audio.mp3',
      clipSource: clip,
      // Recorded per the manifest, absent from this build's bundle.
      clipPathLoader: (c) async => null,
      manifestLoader: () async => _manifest(clips: {halfway: _recorded(halfway)}),
    );
    await sync.startSession();

    expect(await sync.playStandingClip(halfway), isFalse);
    expect(clip.loaded, isNull);
    expect(lesson.volumes, isEmpty);
    sync.dispose();
  });

  test('a ref the manifest table does not carry at all is skipped', () async {
    final lesson = _ScriptedAudioSource();
    final clip = _ScriptedAudioSource();
    final sync = AudioSync(
      manimPlayer: _SilentSink(),
      sessionId: 's1',
      audioSource: lesson,
      audioPathLoader: () async => '/fake/audio.mp3',
      clipSource: clip,
      clipPathLoader: (c) async => '/fake/${c.ref}.mp3',
      manifestLoader: () async => _manifest(clips: {halfway: _recorded(halfway)}),
    );
    await sync.startSession();

    expect(await sync.playStandingClip('assistant_003/intro/new'), isFalse);
    expect(clip.loaded, isNull);
    expect(lesson.volumes, isEmpty);
    sync.dispose();
  });

  test('a clip channel that throws on load restores the lesson volume', () async {
    final lesson = _ScriptedAudioSource();
    final clip = _ScriptedAudioSource(failOnLoad: true);
    final sync = AudioSync(
      manimPlayer: _SilentSink(),
      sessionId: 's1',
      audioSource: lesson,
      audioPathLoader: () async => '/fake/audio.mp3',
      clipSource: clip,
      clipPathLoader: (c) async => '/fake/${c.ref}.mp3',
      manifestLoader: () async => _manifest(clips: {halfway: _recorded(halfway)}),
    );
    await sync.startSession();

    expect(await sync.playStandingClip(halfway), isFalse);
    // The throw happens before the duck here, but the restore runs in the
    // finally either way — the lesson can never be left quiet.
    expect(lesson.volumes.isEmpty || lesson.volumes.last == 1.0, isTrue);
    expect(lesson.playing, isTrue);
    sync.dispose();
  });

  test('single-source behaviour is unchanged when no clip channel is wired',
      () async {
    final lesson = _ScriptedAudioSource();
    final sync = AudioSync(
      manimPlayer: _SilentSink(),
      sessionId: 's1',
      audioSource: lesson,
      audioPathLoader: () async => '/fake/audio.mp3',
      manifestLoader: () async => _manifest(clips: {halfway: _recorded(halfway)}),
    );
    await sync.startSession();

    expect(await sync.playStandingClip(halfway), isFalse);
    expect(lesson.loaded, '/fake/audio.mp3');
    expect(lesson.playing, isTrue);
    expect(lesson.volumes, isEmpty);
    sync.dispose();
  });

  test('two beats on one timestamp play in order, not over each other',
      () async {
    // The emitter stacks FOUR framing events on the lesson's last
    // timestamp (assistant_signoff, recording_stopped, the tutor signoff
    // and the wrap_up call) and three on t=0, and the track dispatch fires
    // every due event in one synchronous pass. Without a queue each beat
    // loads straight over the one before it and only the last is audible —
    // while the first clip's completion releases the duck for all of them.
    const signoff = 'assistant_003/signoff/session_end';
    const cut = 'assistant_003/signoff/recording_stopped';
    final lesson = _ScriptedAudioSource();
    final clip = _ScriptedAudioSource();
    final sync = AudioSync(
      manimPlayer: _SilentSink(),
      sessionId: 's1',
      audioSource: lesson,
      audioPathLoader: () async => '/fake/audio.mp3',
      clipSource: clip,
      clipPathLoader: (c) async => '/fake/${c.ref}.mp3',
      manifestLoader: () async => _manifest(
          clips: {signoff: _recorded(signoff), cut: _recorded(cut)}),
    );
    await sync.startSession();

    // Exactly what the route shell does at a shared timestamp: each due
    // event fires its beat without awaiting, in track order.
    final first = sync.playStandingClip(signoff);
    final second = sync.playStandingClip(cut);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(clip.loads, ['/fake/$signoff.mp3'],
        reason: 'the second beat waits its turn rather than loading over '
            'the first');
    expect(lesson.volumes, [kStandingClipDuckLevel]);

    clip.finish();
    expect(await first, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(clip.loads, ['/fake/$signoff.mp3', '/fake/$cut.mp3'],
        reason: 'the second beat starts once the first has ENDED');
    expect(lesson.volumes, [kStandingClipDuckLevel],
        reason: 'the duck belongs to the queue: it is not released and '
            'retaken between two consecutive beats');

    clip.finish();
    expect(await second, isTrue);
    expect(lesson.volumes, [kStandingClipDuckLevel, 1.0],
        reason: 'the lesson comes back only after the LAST queued beat');
    sync.dispose();
  });

  test('an unplayable beat in the middle of the queue does not stall it',
      () async {
    // Every skip path is the ordinary case today (the recordings do not
    // exist yet), so a queue that waited on them would silence the beats
    // behind them for the rest of the session.
    const first = 'assistant_003/timekeeping/wrap_up';
    const missing = 'assistant_003/signoff/session_end';
    const last = 'assistant_003/signoff/recording_stopped';
    final lesson = _ScriptedAudioSource();
    final clip = _ScriptedAudioSource();
    final sync = AudioSync(
      manimPlayer: _SilentSink(),
      sessionId: 's1',
      audioSource: lesson,
      audioPathLoader: () async => '/fake/audio.mp3',
      clipSource: clip,
      clipPathLoader: (c) async => '/fake/${c.ref}.mp3',
      manifestLoader: () async => _manifest(clips: {
        first: _recorded(first),
        // Authored, not recorded — and the ref between them is not in the
        // table at all.
        missing: _textOnly(missing),
        last: _recorded(last),
      }),
    );
    await sync.startSession();

    final beats = [
      sync.playStandingClip(first),
      sync.playStandingClip(missing),
      sync.playStandingClip('assistant_003/intro/new'),
      sync.playStandingClip(last),
    ];
    await Future<void>.delayed(const Duration(milliseconds: 20));
    clip.finish(); // ends `first`
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // The two skips fell straight through; `last` is already playing.
    expect(clip.loads, ['/fake/$first.mp3', '/fake/$last.mp3']);
    clip.finish();

    expect(await Future.wait(beats), [true, false, false, true]);
    expect(lesson.volumes, [kStandingClipDuckLevel, 1.0]);
    sync.dispose();
  });

  test('a beat whose ref is still being resolved keeps its slot in track '
      'order', () async {
    // The opening's new/returning pick is the app's (decision #39), so its
    // ref arrives one attendance-ledger read after the event fires — while
    // the tutor's greeting on the same t=0 has its ref in hand. The
    // opening must still be heard first.
    const opening = 'assistant_003/intro/returning';
    const greeting = 'tutor_007/greetings/02';
    final lesson = _ScriptedAudioSource();
    final clip = _ScriptedAudioSource();
    final pick = Completer<String?>();
    final sync = AudioSync(
      manimPlayer: _SilentSink(),
      sessionId: 's1',
      audioSource: lesson,
      audioPathLoader: () async => '/fake/audio.mp3',
      clipSource: clip,
      clipPathLoader: (c) async => '/fake/${c.ref}.mp3',
      manifestLoader: () async => _manifest(
          clips: {opening: _recorded(opening), greeting: _recorded(greeting)}),
    );
    await sync.startSession();

    final first = sync.playStandingClip(pick.future);
    final second = sync.playStandingClip(greeting);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(clip.loads, isEmpty, reason: 'the queue waits on the pick');

    pick.complete(opening);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(clip.loads, ['/fake/$opening.mp3']);

    clip.finish();
    expect(await first, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(clip.loads, ['/fake/$opening.mp3', '/fake/$greeting.mp3']);

    clip.finish();
    expect(await second, isTrue);
    sync.dispose();
  });

  test('a beat whose ref resolves to nothing is skipped like any other',
      () async {
    // No host on this lesson's grade, or an event carrying no clips at all.
    final lesson = _ScriptedAudioSource();
    final clip = _ScriptedAudioSource();
    final sync = AudioSync(
      manimPlayer: _SilentSink(),
      sessionId: 's1',
      audioSource: lesson,
      audioPathLoader: () async => '/fake/audio.mp3',
      clipSource: clip,
      clipPathLoader: (c) async => '/fake/${c.ref}.mp3',
      manifestLoader: () async => _manifest(clips: {halfway: _recorded(halfway)}),
    );
    await sync.startSession();

    expect(await sync.playStandingClip(Future<String?>.value(null)), isFalse);
    expect(await sync.playStandingClip(''), isFalse);
    expect(clip.loads, isEmpty);
    expect(lesson.volumes, isEmpty);
    sync.dispose();
  });

  test('a manifest with no clips table parses and carries an empty one',
      () async {
    final manifest = _manifest();
    expect(manifest.clips, isEmpty);
    expect(manifest.toJson().containsKey('clips'), isFalse);
  });

  test('the clips table parses refs, speakers, scripts and audio', () {
    final manifest = _manifest(clips: {
      halfway: _recorded(halfway),
      'tutor_007/greetings/02': {
        'speaker': 'tutor_007',
        'script': 'tutors/CAPS/tutor_007/greetings/02.md',
      },
    });
    final recorded = manifest.clips[halfway]!;
    expect(recorded.ref, halfway);
    expect(recorded.speaker, 'assistant_003');
    expect(recorded.script, 'assistants/CAPS/$halfway.md');
    expect(recorded.audio, 'assistants/CAPS/$halfway.mp3');

    final greeting = manifest.clips['tutor_007/greetings/02']!;
    expect(greeting.speaker, 'tutor_007');
    expect(greeting.audio, isNull, reason: 'text-first until recorded');

    // Round-trips, so a re-serialized manifest still names its clips.
    final table = manifest.toJson()['clips'] as Map<String, dynamic>;
    expect(table.keys, containsAll([halfway, 'tutor_007/greetings/02']));
    expect((table[halfway] as Map)['audio'], 'assistants/CAPS/$halfway.mp3');
    expect((table['tutor_007/greetings/02'] as Map).containsKey('audio'),
        isFalse);
  });
}
