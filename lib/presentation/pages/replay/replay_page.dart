// ==========================================
// [GENERATED TEMPLATE FILE]
// This file was installed from: replay_sdk
// Feel free to modify and customize this code.
// Note: If you edit this file, the SDK installer will detect your changes
// and automatically skip overwriting it during future upgrades.
// ==========================================

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:replay_sdk/replay_sdk.dart';
import 'package:supacharge/core/presentation/theme/theme.dart';

@RoutePage(name: 'ReplayRoute')
class ReplayPage extends StatefulWidget {
  final String sessionId;

  const ReplayPage({
    super.key,
    required this.sessionId,
  });

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {
  AudioSync? _audioSync;
  final ManimPlayer _manimPlayer = ManimPlayer();
  late final SessionGatekeeper _gatekeeper;

  /// Null while the readiness check is running.
  SessionReadiness? _readiness;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<SessionGatekeeper>()) {
      ReplaySdkDependencies.register(getIt);
    }
    _gatekeeper = getIt.get<SessionGatekeeper>();
    _verifyAndStart();
  }

  /// Pre-session gatekeeper: playback only starts when every local asset is
  /// present; otherwise the student is shown exactly what is still missing.
  Future<void> _verifyAndStart() async {
    setState(() {
      _checking = true;
      _readiness = null;
    });

    final readiness = await _gatekeeper.verifySessionReady(widget.sessionId);
    if (!mounted) return;

    setState(() {
      _readiness = readiness;
      _checking = false;
    });

    if (readiness.isReady) {
      ActiveSessionRegistry.markActive(widget.sessionId);
      _audioSync = AudioSync(
        manimPlayer: _manimPlayer,
        sessionId: widget.sessionId,
      );
      await _audioSync!.startSession();
    }
  }

  @override
  void dispose() {
    _audioSync?.dispose();
    ActiveSessionRegistry.release(widget.sessionId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.mainBack,
      appBar: AppBar(
        backgroundColor: AppStyle.mainBack,
        title: Text(
          'Lesson Replay - ${widget.sessionId}',
          style: AppStyle.interNormal(size: 16),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_checking) {
      return const Center(child: CircularProgressIndicator());
    }

    final readiness = _readiness;
    if (readiness == null || !readiness.isReady) {
      return _SessionNotReadyView(
        readiness: readiness,
        onRetry: _verifyAndStart,
      );
    }

    return Stack(
      children: [
        // Whiteboard Animation Rendering area
        Positioned.fill(
          child: WhiteboardCanvas(player: _manimPlayer),
        ),
        // Interactive controls overlays
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: ReplayControls(
            audioSync: _audioSync!,
          ),
        ),
      ],
    );
  }
}

/// Shown when the pre-session gatekeeper blocks entry because assets are
/// still missing locally.
class _SessionNotReadyView extends StatelessWidget {
  final SessionReadiness? readiness;
  final VoidCallback onRetry;

  const _SessionNotReadyView({
    required this.readiness,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final missing = readiness?.missingDescription ?? '';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_download_outlined,
              size: 56,
              color: AppStyle.textGrey,
            ),
            const SizedBox(height: 16),
            Text(
              'This session is not ready yet',
              style: AppStyle.interSemi(size: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              missing.isEmpty
                  ? 'The lesson files have not finished downloading. Please stay connected and try again shortly, or pick another slot.'
                  : 'Still downloading: $missing. Please stay connected and try again shortly, or pick another slot.',
              style: AppStyle.interRegular(size: 14, color: AppStyle.textGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(
                'Check again',
                style: AppStyle.interNormal(size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WhiteboardCanvas extends StatelessWidget {
  final ManimPlayer player;

  const WhiteboardCanvas({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppStyle.blackColor,
      child: Center(
        child: Text(
          'Manim Render Canvas (16:9 viewport)',
          style: AppStyle.interRegular(size: 14, color: AppStyle.white),
        ),
      ),
    );
  }
}

class ReplayControls extends StatelessWidget {
  final AudioSync audioSync;

  const ReplayControls({super.key, required this.audioSync});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.play_arrow),
          color: AppStyle.icons,
          onPressed: () => audioSync.setBuffering(false),
        ),
        IconButton(
          icon: const Icon(Icons.pause),
          color: AppStyle.icons,
          onPressed: () => audioSync.setBuffering(true),
        ),
      ],
    );
  }
}
