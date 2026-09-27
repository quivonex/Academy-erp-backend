import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Could not load video: ${snapshot.error}',
          );
        }

        if (snapshot.connectionState !=
            ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final aspectRatio =
        _controller.value.aspectRatio > 0
            ? _controller.value.aspectRatio
            : 16 / 9;

        return Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: VideoPlayer(_controller),
            ),
            VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(
                vertical: 12,
              ),
            ),
            FilledButton.icon(
              onPressed: _togglePlayback,
              icon: Icon(
                _controller.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
              label: Text(
                _controller.value.isPlaying
                    ? 'Pause video'
                    : 'Play video',
              ),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 8),
              Text(_saveError!),
              TextButton(
                onPressed: _saveProgress,
                child: const Text('Retry'),
              ),
            ],
          ],
        );
      },
    );
  }
}