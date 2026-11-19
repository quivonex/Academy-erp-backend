        watchedSeconds: _watchedMilliseconds ~/ 1000,
        lastPositionSeconds: position,
        markCompleted: true,
      );

      _completionSent = true;

      if (mounted) {
        widget.onProgressChanged();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saveError = 'Could not mark video as completed.';
        });
      }
    }
  }

  Future<void> _sendWatchHeartbeatIfNeeded({bool force = false}) async {
    final sessionUuid = _watchSessionUuid;
    if (sessionUuid == null || !_controller.value.isInitialized) return;

    final position = _controller.value.position.inSeconds;
    if (!force && position - _lastHeartbeatPositionSeconds < 10) return;

    try {
      final session = await _api.sendVideoWatchHeartbeat(
        sessionUuid: sessionUuid,
        playerPositionSeconds: position,
      );
      _lastHeartbeatPositionSeconds = position;
      if (session['is_verified_completed'] == true) {
        _completionSent = true;
      }
      if (mounted) widget.onProgressChanged();
    } catch (_) {
      // Legacy progress writes below preserve playback when a heartbeat fails.
    }
  }

  Future<void> _endWatchSession() async {
    final sessionUuid = _watchSessionUuid;
    if (sessionUuid == null || _endingWatchSession) return;
    _endingWatchSession = true;
    try {
      await _sendWatchHeartbeatIfNeeded(force: true);
      await _api.endVideoWatchSession(sessionUuid);
    } catch (_) {
      // The backend closes stale sessions safely; do not block app navigation.
    } finally {
      _watchSessionUuid = null;
    }
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