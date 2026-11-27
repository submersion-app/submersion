import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/app/app_exit_guard.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/pop_out/data/pop_out_channel.dart';
import 'package:submersion/features/pop_out/data/pop_out_windows.dart';
import 'package:submersion/features/pop_out/domain/cursor_sync.dart';
import 'package:submersion/features/pop_out/domain/pop_out_frame.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _log = LoggerService('PopOutHost');

/// How long a close waits for the pop-out to confirm it closed: longer than
/// the pop-out takes to let go of the database (1.5 s), shorter than the
/// database service's before-close hook limit (4 s).
const _closeWait = Duration(seconds: 3);

/// The main window's side of the profile pop-out (issue #5078). State: open.
final popOutHostProvider = NotifierProvider<PopOutHost, bool>(PopOutHost.new);

/// Opens the pop-out, keeps it told what the main window shows, and takes in
/// what it reports back.
///
/// Closes the pop-out before the main window's database closes (restore,
/// storage move, demo switch, quit) and when this provider is disposed (a
/// soft restart rebuilds the whole scope).
class PopOutHost extends Notifier<bool> {
  late PopOutWindows _windows;
  late AppExitGuard _exitGuard;
  PopOutChannel? _channel;
  final _gate = CursorEchoGate();
  CursorCoalescer? _coalescer;
  void Function()? _removeCloseHook;

  /// [state], readable where Riverpod forbids reading state (onDispose).
  bool _open = false;

  /// An opening is under way: a second press waits for nothing and opens
  /// nothing.
  bool _opening = false;

  /// The prefs last sent, so an unchanged snapshot is not sent again.
  Map<String, Object>? _sentPrefs;

  /// Completes when the pop-out reports it closed.
  Completer<void>? _closedSignal;

  void _setOpen(bool open) {
    _open = open;
    state = open;
  }

  @override
  bool build() {
    _windows = ref.watch(popOutWindowsProvider);
    _exitGuard = ref.watch(appExitGuardProvider);
    ref.listen<String?>(mainWindowDiveIdProvider, (_, id) {
      if (state) _send(ShowDiveMessage(id));
    });
    ref.listen<Object?>(popOutPrefsTriggerProvider, (_, _) {
      if (state) _sendPrefs();
    });
    ref.listen<bool>(popOutAppLockedProvider, (_, locked) {
      if (state) _send(LockMessage(locked));
    });
    ref.onDispose(_dispose);
    return false;
  }

  /// Opens the pop-out on [diveId] (or the main window's dive), or brings
  /// the open one to the front. A press while one is opening does nothing.
  Future<void> openOrFocus({String? diveId}) async {
    if (diveId != null && diveId.isNotEmpty) {
      ref.read(mainWindowDiveIdProvider.notifier).state = diveId;
    }
    if (_opening) return;
    _opening = true;
    try {
      if (state) {
        if (await _windows.isOpen()) {
          await _send(const FocusRequestMessage());
          return;
        }
        // Gone without telling us (it crashed, say): start over.
        _closed();
      }
      await _openWindow();
    } finally {
      _opening = false;
    }
  }

  Future<void> _openWindow() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final channelName =
        'submersion/pop_out/${DateTime.now().microsecondsSinceEpoch}';
    final snapshot = _prefsSnapshot();
    final launch = PopOutLaunch(
      channel: channelName,
      diveId: ref.read(mainWindowDiveIdProvider),
      prefs: snapshot,
      locked: ref.read(popOutAppLockedProvider),
      savedFrame: _savedFrame(prefs),
      mainFrame: await ref.read(mainWindowFrameProvider)(),
    );
    final channel = _windows.channelNamed(channelName);
    _channel = channel;
    channel.setHandler(_onMessage);
    _coalescer = CursorCoalescer(
      (diveId, seconds) => _send(CursorMessage(diveId, seconds)),
    );
    _removeCloseHook = DatabaseService.instance.addBeforeCloseHook(close);
    _sentPrefs = snapshot;
    _closedSignal = Completer<void>();
    _setOpen(true);
    // It opens focused: the main window losing focus to it is no leave.
    ref.read(popOutFocusedProvider.notifier).state = true;
    try {
      await _exitGuard.otherWindowsOpen(true);
      await _windows.openProfile(launch);
    } catch (_) {
      _closed();
      rethrow;
    }
  }

  /// Closes the pop-out, if open, and waits briefly for it to confirm, so
  /// it lets go of the database before the caller closes it.
  Future<void> close() async {
    if (!state) return;
    final closed = _closedSignal;
    await _send(const CloseMessage());
    if (closed != null && !closed.isCompleted) {
      await closed.future.timeout(_closeWait, onTimeout: () {});
    }
    if (_open) _closed();
  }

  /// The main window is about to show an inbound position at [seconds],
  /// its own nearest sample to what the pop-out sent: that is an echo, not
  /// the diver's move, so it must not go back.
  void noteInboundApplied(String diveId, int? seconds) =>
      _gate.noteReceived(diveId, seconds);

  /// The main window's cursor for [diveId] moved to [seconds].
  void sendCursor(String diveId, int? seconds) {
    if (!state) return;
    if (!_gate.shouldSend(diveId, seconds)) return;
    _coalescer?.push(diveId, seconds);
  }

  void _onMessage(PopOutMessage message) {
    switch (message) {
      case CursorMessage():
        _gate.noteReceived(message.diveId, message.seconds);
        ref.read(popOutInboundCursorProvider.notifier).state = message;
      case FocusReportMessage(:final focused):
        ref.read(popOutFocusedProvider.notifier).state = focused;
      case FrameMessage(:final frame):
        unawaited(
          ref
              .read(sharedPreferencesProvider)
              .setString(kPopOutProfileFrameKey, jsonEncode(frame.toMap())),
        );
      case ClosedMessage():
        _closed();
      case ReadyMessage():
        _send(ShowDiveMessage(ref.read(mainWindowDiveIdProvider)));
        _send(LockMessage(ref.read(popOutAppLockedProvider)));
        _sendPrefs(force: true);
      case RefusedWriteMessage(:final statement):
        _log.warning('The pop-out refused a write: $statement');
      default:
        break;
    }
  }

  void _closed() {
    final closed = _closedSignal;
    _closedSignal = null;
    if (closed != null && !closed.isCompleted) closed.complete();
    _sentPrefs = null;
    unawaited(_exitGuard.otherWindowsOpen(false));
    _setOpen(false);
    _channel?.setHandler(null);
    _channel = null;
    _coalescer?.dispose();
    _coalescer = null;
    _removeCloseHook?.call();
    _removeCloseHook = null;
    ref.read(popOutFocusedProvider.notifier).state = false;
  }

  void _dispose() {
    if (!_open) return;
    _open = false;
    unawaited(_exitGuard.otherWindowsOpen(false));
    final channel = _channel;
    if (channel != null) {
      unawaited(channel.send(const CloseMessage()));
      channel.setHandler(null);
    }
    _coalescer?.dispose();
    _removeCloseHook?.call();
  }

  Future<void> _send(PopOutMessage message) async => _channel?.send(message);

  /// Sends the prefs when they changed since the last send, or always with
  /// [force].
  void _sendPrefs({bool force = false}) {
    final snapshot = _prefsSnapshot();
    if (!force && const DeepCollectionEquality().equals(snapshot, _sentPrefs)) {
      return;
    }
    _sentPrefs = snapshot;
    _send(PrefsMessage(snapshot));
  }

  Map<String, Object> _prefsSnapshot() {
    final prefs = ref.read(sharedPreferencesProvider);
    final values = <String, Object>{};
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      if (value is List) {
        values[key] = List<String>.from(value);
      } else if (value != null) {
        values[key] = value;
      }
    }
    return values;
  }

  static PopOutFrame? _savedFrame(SharedPreferences prefs) {
    final raw = prefs.getString(kPopOutProfileFrameKey);
    if (raw == null) return null;
    try {
      return PopOutFrame.fromMap(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }
}
