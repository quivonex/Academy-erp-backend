import 'dart:async';

import 'package:flutter/material.dart';
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

  int _watchedMilliseconds = 0;
  int _previousPositionMilliseconds = 0;
  int _lastSavedWatchedSeconds = 0;
  int _lastSavedPositionSeconds = 0;

  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();

    _api = ref.read(studentPortalRepositoryProvider);

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: const {
        'ngrok-skip-browser-warning': 'true',
      },
    );

    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    final progress = await _api.materialProgress(
      widget.materialUuid,
    );

    final watched =
        (progress['watched_seconds'] as num?)?.toInt() ?? 0;
    final lastPosition =
        (progress['last_position_seconds'] as num?)?.toInt() ?? 0;

    _watchedMilliseconds = watched * 1000;
    _lastSavedWatchedSeconds = watched;
    _lastSavedPositionSeconds = lastPosition;

    await _controller.initialize();

    if (!mounted) return;

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

        if (mounted) setState(() {});
      },
    );
  }

  void _samplePlayback() {
    if (!_controller.value.isInitialized) return;

    final currentMilliseconds =
        _controller.value.position.inMilliseconds;

    final difference =
        currentMilliseconds -
            _previousPositionMilliseconds;

    // A large jump is a seek, not watched playback time.
    if (_controller.value.isPlaying &&
        difference > 0 &&
        difference <= 2500) {
      _watchedMilliseconds += difference;
    }

    _previousPositionMilliseconds =
        currentMilliseconds;
  }

  Future<void> _saveProgress() async {
    if (_saving || !_controller.value.isInitialized) {
      return;
    }

    final watchedSeconds =
        _watchedMilliseconds ~/ 1000;
    final positionSeconds =
        _controller.value.position.inSeconds;

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
        setState(() {
          _saveError =
          'Could not save video progress. Tap Retry.';
        });
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> _togglePlayback() async {
    if (_controller.value.isPlaying) {
      _samplePlayback();
      await _controller.pause();
      await _saveProgress();
    } else {
      _previousPositionMilliseconds =
          _controller.value.position.inMilliseconds;
      await _controller.play();
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _samplePlayback();
    _timer?.cancel();

    // Save any remaining watched time when leaving the screen.
    unawaited(_saveProgress());
    _controller.dispose();

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
          borderRadius: BorderRadius.circular(18),
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            stage(
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: aspectRatio,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            VideoPlayer(_controller),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _togglePlayback,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: value.isPlaying ? 0 : 1,
                                child: ColoredBox(
                                  color: const Color(0x55000000),
                                  child: Center(
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: colors.primary,
                                        shape: BoxShape.circle,
                                        boxShadow: colors.heroShadow,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
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
                        padding: const EdgeInsets.fromLTRB(6, 0, 14, 6),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: value.isPlaying ? 'Pause' : 'Play',
                              onPressed: _togglePlayback,
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
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
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
