import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:window_manager/window_manager.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pop_out/data/pop_out_channel.dart';
import 'package:submersion/features/pop_out/domain/cursor_sync.dart';
import 'package:submersion/features/pop_out/domain/dive_follow_state.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// What this pop-out window was opened with. Overridden at its root.
final popOutLaunchProvider = Provider<PopOutLaunch>(
  (ref) => throw UnimplementedError('Overridden in the pop-out window'),
);

/// The pop-out's end of the channel to the main window. Overridden at its
/// root.
final popOutChannelProvider = Provider<PopOutChannel>(
  (ref) => throw UnimplementedError('Overridden in the pop-out window'),
);

/// The pop-out's own OS window.
abstract interface class PopOutWindowControl {
  Future<void> show();
  Future<void> focus();
  Future<void> close();
  Future<void> setTitle(String title);
}

class _WindowManagerControl implements PopOutWindowControl {
  const _WindowManagerControl();

  @override
  Future<void> show() => windowManager.show();

  @override
  Future<void> focus() => windowManager.focus();

  // The window's own close is held back (setPreventClose) so the main
  // window hears about it first. Dropping the hold before closing marks the
  // close as asked for. Never windowManager.destroy(): on macOS it
  // terminates the whole app.
  @override
  Future<void> close() async {
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  Future<void> setTitle(String title) => windowManager.setTitle(title);
}

final popOutWindowControlProvider = Provider<PopOutWindowControl>(
  (ref) => const _WindowManagerControl(),
);

class PopOutClientState extends Equatable {
  final DiveFollowState follow;

  /// App Lock has the app locked: the dive stays hidden until it unlocks.
  final bool locked;

  const PopOutClientState({required this.follow, required this.locked});

  PopOutClientState copyWith({DiveFollowState? follow, bool? locked}) =>
      PopOutClientState(
        follow: follow ?? this.follow,
        locked: locked ?? this.locked,
      );

  @override
  List<Object?> get props => [follow, locked];
}

/// The pop-out window's side of the profile pop-out (issue #5078).
final popOutClientProvider = NotifierProvider<PopOutClient, PopOutClientState>(
  PopOutClient.new,
);

/// Follows the main window's dive unless pinned, keeps the shared cursor in
/// step, and mirrors the main window's prefs and lock.
class PopOutClient extends Notifier<PopOutClientState> {
  late PopOutChannel _channel;
  final _gate = CursorEchoGate();
  late CursorCoalescer _coalescer;

  @override
  PopOutClientState build() {
    final launch = ref.watch(popOutLaunchProvider);
    _channel = ref.watch(popOutChannelProvider);
    _coalescer = CursorCoalescer(
      (diveId, seconds) => _channel.send(CursorMessage(diveId, seconds)),
    );
    _channel.setHandler(_onMessage);
    ref.onDispose(() {
      _channel.setHandler(null);
      _coalescer.dispose();
    });
    return PopOutClientState(
      follow: const DiveFollowState().followed(launch.diveId),
      locked: launch.locked,
    );
  }

  void pin() => state = state.copyWith(follow: state.follow.pin());

  void unpin() => state = state.copyWith(follow: state.follow.unpin());

  /// The dive [id] turned out not to exist (deleted, or gone in a sync).
  void diveMissing(String id) =>
      state = state.copyWith(follow: state.follow.diveMissing(id));

  /// This window's cursor for [diveId] moved to [seconds].
  void sendCursor(String diveId, int? seconds) {
    if (!_gate.shouldSend(diveId, seconds)) return;
    _coalescer.push(diveId, seconds);
  }

  void _onMessage(PopOutMessage message) {
    switch (message) {
      case ShowDiveMessage(:final diveId):
        state = state.copyWith(follow: state.follow.followed(diveId));
      case CursorMessage(:final diveId, :final seconds):
        if (diveId != state.follow.shownDiveId) return;
        _gate.noteReceived(diveId, seconds);
        ref.read(profileReviewProvider(diveId).notifier).state = seconds;
      case PrefsMessage(:final values):
        unawaited(_applyPrefs(values));
      case LockMessage(:final locked):
        state = state.copyWith(locked: locked);
      case FocusRequestMessage():
        unawaited(_bringToFront());
      case CloseMessage():
        unawaited(ref.read(popOutWindowControlProvider).close());
      default:
        break;
    }
  }

  Future<void> _bringToFront() async {
    final control = ref.read(popOutWindowControlProvider);
    await control.show();
    await control.focus();
  }

  /// Makes this window's in-memory prefs match the main window's, then
  /// rereads what depends on them.
  Future<void> _applyPrefs(Map<String, Object> values) async {
    final prefs = ref.read(sharedPreferencesProvider);
    for (final key in prefs.getKeys().toList()) {
      if (!values.containsKey(key)) await prefs.remove(key);
    }
    for (final MapEntry(:key, :value) in values.entries) {
      switch (value) {
        case final String v:
          await prefs.setString(key, v);
        case final bool v:
          await prefs.setBool(key, v);
        case final int v:
          await prefs.setInt(key, v);
        case final double v:
          await prefs.setDouble(key, v);
        case final List<String> v:
          await prefs.setStringList(key, v);
      }
    }
    ref
      ..invalidate(currentDiverIdProvider)
      ..invalidate(displayZoomNotifierProvider)
      ..invalidate(settingsProvider);
  }
}
