import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';

import '../data/student_portal_repository.dart';

class TrackedVideoPlayer extends ConsumerStatefulWidget {
  const TrackedVideoPlayer({
    super.key,
    required this.materialUuid,
    required this.url,
    required this.onProgressChanged,
  });

  final String materialUuid;
  final String url;
  final VoidCallback onProgressChanged;

  @override
  ConsumerState<TrackedVideoPlayer> createState() =>
      _TrackedVideoPlayerState();
}

class _TrackedVideoPlayerState
    extends ConsumerState<TrackedVideoPlayer> {
  late final StudentPortalRepository _api;
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;

  Timer? _timer;
  Timer? _hideControlsTimer;

  int _watchedMilliseconds = 0;
  int _previousPositionMilliseconds = 0;
  int _lastSavedWatchedSeconds = 0;
  int _lastSavedPositionSeconds = 0;

  bool _saving = false;
  String? _saveError;
  bool _completionSent = false;
  bool _showControls = true;
  double _playbackSpeed = 1.0;
  bool _isFullscreen = false;
  String? _watchSessionUuid;
  bool _endingWatchSession = false;
  bool _heartbeatSending = false;
  DateTime? _lastHeartbeatAt;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  void initState() {
    super.initState();

    _api = ref.read(studentPortalRepositoryProvider);

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
    );

    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    final results = await Future.wait<Object?>([
      _api.materialProgress(widget.materialUuid),
      _controller.initialize(),
    ]);
    if (!mounted) return;
    final progress = results.first as Map<String, dynamic>;

    final session = await _api.startVideoWatchSession(widget.materialUuid);
    final sessionUuid = session['uuid']?.toString();
    if (sessionUuid == null || sessionUuid.isEmpty) {
      throw StateError('The server did not return a watch session.');
    }
    if (!mounted) {
      await _api.endVideoWatchSession(sessionUuid);
      return;
    }
    _watchSessionUuid = sessionUuid;
    _lastHeartbeatAt = DateTime.now();

    final watched =
        (progress['watched_seconds'] as num?)?.toInt() ?? 0;
    final lastPosition =
        (session['resume_position_seconds'] as num?)?.toInt() ?? 0;

    _watchedMilliseconds = watched * 1000;
    _lastSavedWatchedSeconds = watched;
    _lastSavedPositionSeconds = lastPosition;
    _completionSent = session['is_verified_completed'] == true;

    final videoDuration = _controller.value.duration;

    if (lastPosition > 0 &&
        Duration(seconds: lastPosition) < videoDuration) {
      await _controller.seekTo(
        Duration(seconds: lastPosition),
      );
    }

    if (!mounted) return;

    _previousPositionMilliseconds =
        _controller.value.position.inMilliseconds;

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        _samplePlayback();

        final unsavedSeconds =
            _watchedMilliseconds ~/ 1000 -
                _lastSavedWatchedSeconds;

        if (unsavedSeconds >= 10) {
          unawaited(_saveProgress());
        }

        unawaited(_markCompletedIfNeeded());

        if (mounted) setState(() {});
      },
    );

    _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  Future<void> _markCompletedIfNeeded() async {
    if (_completionSent || !_controller.value.isInitialized) return;
    await _sendWatchHeartbeatIfNeeded();
  }

  Future<void> _sendWatchHeartbeatIfNeeded({bool force = false}) async {
    final sessionUuid = _watchSessionUuid;
    if (sessionUuid == null || _heartbeatSending || _endingWatchSession ||
        !_controller.value.isInitialized) return;

    final position = _controller.value.position.inSeconds;
    final now = DateTime.now();
    if (!force && _lastHeartbeatAt != null &&
        now.difference(_lastHeartbeatAt!).inSeconds < 15) return;
    _heartbeatSending = true;
    _lastHeartbeatAt = now;

    try {
      final session = await _api.sendVideoWatchHeartbeat(
        sessionUuid: sessionUuid,
        playerPositionSeconds: position,
      );
      if (session['is_verified_completed'] == true) {
        _completionSent = true;
      }
      if (mounted) widget.onProgressChanged();
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = 'Could not verify video progress.');
      }
    } finally {
      _heartbeatSending = false;
    }
  }

  Future<void> _endWatchSession(int finalPositionSeconds) async {
    final sessionUuid = _watchSessionUuid;
    if (sessionUuid == null || _endingWatchSession) return;
    _endingWatchSession = true;
    try {
      await _api.sendVideoWatchHeartbeat(
        sessionUuid: sessionUuid,
        playerPositionSeconds: finalPositionSeconds,
      );
      await _api.endVideoWatchSession(sessionUuid);
    } catch (_) {
      // The backend closes stale sessions safely; do not block app navigation.
    } finally {
      _watchSessionUuid = null;
    }
  }

  void _samplePlayback() {
    if (!_controller.value.isInitialized) return;

    final currentMilliseconds = _controller.value.position.inMilliseconds;
    final difference = currentMilliseconds - _previousPositionMilliseconds;

    if (_controller.value.isPlaying && difference > 0 && difference <= 2500) {
      _watchedMilliseconds += difference;
    }

    _previousPositionMilliseconds = currentMilliseconds;
  }

  Future<void> _saveProgress() async {
    if (_saving || !_controller.value.isInitialized) return;

    final watchedSeconds = _watchedMilliseconds ~/ 1000;
    final positionSeconds = _controller.value.position.inSeconds;

    if (watchedSeconds == _lastSavedWatchedSeconds &&
        positionSeconds == _lastSavedPositionSeconds) {
      return;
    }

    _saving = true;

    try {
      await _api.saveMaterialProgress(
        materialUuid: widget.materialUuid,
        watchedSeconds: watchedSeconds,
        lastPositionSeconds: positionSeconds,
      );

      _lastSavedWatchedSeconds = watchedSeconds;
      _lastSavedPositionSeconds = positionSeconds;

      if (mounted) {
        setState(() => _saveError = null);
        widget.onProgressChanged();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = 'Could not save video progress. Tap Retry.');
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> _togglePlayback() async {
    if (_controller.value.isPlaying) {
      _samplePlayback();
      await _controller.pause();
      await _sendWatchHeartbeatIfNeeded(force: true);
      await _saveProgress();
      setState(() => _showControls = true);
    } else {
      _previousPositionMilliseconds =
          _controller.value.position.inMilliseconds;
      await _controller.play();
      _scheduleHideControls();
    }

    if (mounted) setState(() {});
  }

  Future<void> _skip(int seconds) async {
    final current = _controller.value.position;
    final target = current + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : target > _controller.value.duration
            ? _controller.value.duration
            : target;
    await _controller.seekTo(clamped);
    _previousPositionMilliseconds = clamped.inMilliseconds;
    if (mounted) setState(() {});
  }

  void _changeSpeed() {
    final currentIndex = _speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % _speeds.length;
    _playbackSpeed = _speeds[nextIndex];
    _controller.setPlaybackSpeed(_playbackSpeed);
    if (mounted) setState(() {});
  }

  Future<void> _toggleFullscreen() async {
    if (_isFullscreen) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      );
    }
    if (mounted) setState(() => _isFullscreen = !_isFullscreen);
  }

  @override
  void dispose() {
    _samplePlayback();
    _timer?.cancel();
    _hideControlsTimer?.cancel();

    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    final watchedSeconds = _watchedMilliseconds ~/ 1000;
    final positionSeconds = _controller.value.isInitialized
        ? _controller.value.position.inSeconds
        : _lastSavedPositionSeconds;
    _controller.dispose();
    unawaited(_endWatchSession(positionSeconds));

    if (watchedSeconds != _lastSavedWatchedSeconds ||
        positionSeconds != _lastSavedPositionSeconds) {
      unawaited(_api.saveMaterialProgress(
        materialUuid: widget.materialUuid,
        watchedSeconds: watchedSeconds,
        lastPositionSeconds: positionSeconds,
      ));
    }

    super.dispose();
  }

  String _clock(Duration value) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    return hours > 0
        ? '$hours:${two(minutes)}:${two(seconds)}'
        : '${two(minutes)}:${two(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    Widget stage(Widget child) => ClipRRect(
          borderRadius: _isFullscreen
              ? BorderRadius.zero
              : BorderRadius.circular(18),
          child: ColoredBox(
            color: const Color(0xFF0E1024),
            child: child,
          ),
        );

    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return stage(
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Could not load video: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFDAD7FF),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return stage(
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          );
        }

        final aspectRatio = _controller.value.aspectRatio > 0
            ? _controller.value.aspectRatio
            : 16 / 9;

        final videoWidget = stage(
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _controller,
            child: VideoPlayer(_controller),
            builder: (context, value, video) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: _isFullscreen
                        ? MediaQuery.sizeOf(context).aspectRatio
                        : aspectRatio,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleControls,
                      onDoubleTapDown: (details) {
                        final width = context.size?.width ?? 0;
                        if (details.localPosition.dx < width / 2) {
                          _skip(-10);
                        } else {
                          _skip(10);
                        }
                      },
                      onDoubleTap: () {},
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          video!,
                          if (value.isBuffering)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: _showControls ? 1 : 0,
                            child: IgnorePointer(
                              ignoring: !_showControls,
                              child: Container(
                                color: const Color(0x66000000),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _ControlButton(
                                      icon: Icons.replay_10_rounded,
                                      size: 36,
                                      onTap: () => _skip(-10),
                                    ),
                                    _ControlButton(
                                      icon: value.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 52,
                                      highlighted: true,
                                      primaryColor: colors.primary,
                                      onTap: _togglePlayback,
                                    ),
                                    _ControlButton(
                                      icon: Icons.forward_10_rounded,
                                      size: 36,
                                      onTap: () => _skip(10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      colors: VideoProgressColors(
                        playedColor: colors.secondary,
                        bufferedColor: const Color(0x55FFFFFF),
                        backgroundColor: const Color(0x22FFFFFF),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: value.isPlaying ? 'Pause' : 'Play',
                          onPressed: _togglePlayback,
                          iconSize: 22,
                          icon: Icon(
                            value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _clock(value.position),
                          style: textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          ' / ${_clock(value.duration)}',
                          style: textTheme.labelLarge?.copyWith(
                            color: const Color(0x99FFFFFF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: _changeSpeed,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x33FFFFFF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_playbackSpeed}x',
                              style: textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: _isFullscreen
                              ? 'Exit fullscreen'
                              : 'Fullscreen',
                          onPressed: _toggleFullscreen,
                          iconSize: 22,
                          icon: Icon(
                            _isFullscreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            videoWidget,
            if (_saveError != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(
                  color: colors.dangerBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 18, color: colors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _saveError!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.danger,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _saveProgress,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.highlighted = false,
    this.primaryColor,
  });

  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final bool highlighted;
  final Color? primaryColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size + 16,
        height: size + 16,
        decoration: highlighted
            ? BoxDecoration(
                color: primaryColor ?? Colors.white,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              )
            : null,
        child: Icon(
          icon,
          size: size,
          color: Colors.white,
        ),
      ),
    );
  }
}
