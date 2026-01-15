import 'dart:async';

import 'package:equatable/equatable.dart';

import 'package:submersion/core/providers/provider.dart';

/// State for dive profile playback functionality.
///
/// Manages an animated cursor that moves through the dive timeline,
/// allowing users to step through or auto-play the dive profile.
class PlaybackState extends Equatable {
  /// Whether playback is currently running
  final bool isPlaying;

  /// Current timestamp position in seconds from dive start
  final int currentTimestamp;

  /// Step increment in seconds for forward/backward stepping
  final int stepIncrement;

  /// Playback speed multiplier (1.0 = 1 second per second)
  final double playbackSpeed;

  /// Maximum timestamp in seconds (dive duration)
  final int maxTimestamp;

  /// Whether playback mode is active (cursor visible)
  final bool isActive;

  const PlaybackState({
    this.isPlaying = false,
    this.currentTimestamp = 0,
    this.stepIncrement = 10,
    this.playbackSpeed = 1.0,
    this.maxTimestamp = 0,
    this.isActive = false,
  });

  /// Whether we're at the start of the dive
  bool get atStart => currentTimestamp <= 0;

  /// Whether we're at the end of the dive
  bool get atEnd => currentTimestamp >= maxTimestamp;

  /// Progress as a value from 0.0 to 1.0
  double get progress =>
      maxTimestamp > 0 ? currentTimestamp / maxTimestamp : 0.0;

  /// Current time formatted as MM:SS
  String get formattedTime {
    final minutes = currentTimestamp ~/ 60;
    final seconds = currentTimestamp % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Total time formatted as MM:SS
  String get formattedTotalTime {
    final minutes = maxTimestamp ~/ 60;
    final seconds = maxTimestamp % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  PlaybackState copyWith({
    bool? isPlaying,
    int? currentTimestamp,
    int? stepIncrement,
    double? playbackSpeed,
    int? maxTimestamp,
    bool? isActive,
  }) {
    return PlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentTimestamp: currentTimestamp ?? this.currentTimestamp,
      stepIncrement: stepIncrement ?? this.stepIncrement,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      maxTimestamp: maxTimestamp ?? this.maxTimestamp,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
    isPlaying,
    currentTimestamp,
    stepIncrement,
    playbackSpeed,
    maxTimestamp,
    isActive,
  ];
}

/// Notifier for managing dive profile playback state.
class PlaybackNotifier extends StateNotifier<PlaybackState> {
  Timer? _timer;

  PlaybackNotifier() : super(const PlaybackState());

  /// Initialize playback with the dive duration
  void initialize(int durationSeconds) {
    _timer?.cancel();
    state = PlaybackState(
      maxTimestamp: durationSeconds,
      currentTimestamp: 0,
      isActive: false,
      isPlaying: false,
    );
  }

  /// Toggle playback mode on/off
  void togglePlaybackMode() {
    if (state.isActive) {
      // Turning off - stop playing and reset
      _timer?.cancel();
      state = state.copyWith(isActive: false, isPlaying: false);
    } else {
      // Turning on - activate at current position or start
      state = state.copyWith(isActive: true, currentTimestamp: 0);
    }
  }

  /// Start auto-playback
  void play() {
    if (!state.isActive || state.atEnd) return;

    state = state.copyWith(isPlaying: true);

    // Calculate interval based on playback speed and step increment
    // At 1x speed with 1-second steps, advance every 1 second
    final intervalMs = (1000 / state.playbackSpeed).round();

    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) => _tick());
  }

  /// Pause auto-playback
  void pause() {
    _timer?.cancel();
    state = state.copyWith(isPlaying: false);
  }

  /// Toggle between play and pause
  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  /// Advance by one step (usually 10 seconds)
  void stepForward() {
    if (!state.isActive) return;

    final newTimestamp = (state.currentTimestamp + state.stepIncrement).clamp(
      0,
      state.maxTimestamp,
    );
    state = state.copyWith(currentTimestamp: newTimestamp);

    // Stop playing if we reached the end
    if (newTimestamp >= state.maxTimestamp && state.isPlaying) {
      pause();
    }
  }

  /// Go back by one step (usually 10 seconds)
  void stepBackward() {
    if (!state.isActive) return;

    final newTimestamp = (state.currentTimestamp - state.stepIncrement).clamp(
      0,
      state.maxTimestamp,
    );
    state = state.copyWith(currentTimestamp: newTimestamp);
  }

  /// Jump to the start of the dive
  void skipToStart() {
    if (!state.isActive) return;
    state = state.copyWith(currentTimestamp: 0);
  }

  /// Jump to the end of the dive
  void skipToEnd() {
    if (!state.isActive) return;
    pause(); // Stop playing when jumping to end
    state = state.copyWith(currentTimestamp: state.maxTimestamp);
  }

  /// Seek to a specific timestamp
  void seekTo(int timestamp) {
    if (!state.isActive) return;

    final clampedTimestamp = timestamp.clamp(0, state.maxTimestamp);
    state = state.copyWith(currentTimestamp: clampedTimestamp);
  }

  /// Seek to a position based on progress (0.0 to 1.0)
  void seekToProgress(double progress) {
    if (!state.isActive) return;

    final timestamp = (progress * state.maxTimestamp).round();
    seekTo(timestamp);
  }

  /// Set the playback speed (1.0 = normal, 2.0 = 2x, etc.)
  void setSpeed(double speed) {
    state = state.copyWith(playbackSpeed: speed.clamp(0.5, 4.0));

    // If playing, restart the timer with the new speed
    if (state.isPlaying) {
      pause();
      play();
    }
  }

  /// Set the step increment in seconds
  void setStepIncrement(int seconds) {
    state = state.copyWith(stepIncrement: seconds.clamp(1, 60));
  }

  void _tick() {
    // Advance by 1 second each tick
    final newTimestamp = state.currentTimestamp + 1;

    if (newTimestamp >= state.maxTimestamp) {
      // Reached the end
      state = state.copyWith(currentTimestamp: state.maxTimestamp);
      pause();
    } else {
      state = state.copyWith(currentTimestamp: newTimestamp);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Provider for playback state, scoped by dive ID
final playbackProvider =
    StateNotifierProvider.family<PlaybackNotifier, PlaybackState, String>(
      (ref, diveId) => PlaybackNotifier(),
    );
