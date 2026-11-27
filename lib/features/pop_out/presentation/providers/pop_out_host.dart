import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/pop_out/data/pop_out_windows.dart';
import 'package:submersion/features/pop_out/domain/cursor_sync.dart';
import 'package:submersion/features/pop_out/domain/pop_out_frame.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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
  final _gate = CursorEchoGate();
  CursorCoalescer? _coalescer;
  void Function()? _removeCloseHook;

  /// [state], readable where Riverpod forbids reading state (onDispose).
  bool _open = false;

  void _setOpen(bool open) {
    _open = open;
    state = open;
  }

  @override
  bool build() {
    _windows = ref.watch(popOutWindowsProvider);
    ref.listen<String?>(mainWindowDiveIdProvider, (_, id) {
      if (state) _send(ShowDiveMessage(id));
    });
    ref.listen<Object?>(popOutPrefsTriggerProvider, (_, _) {
      if (state) _send(PrefsMessage(_prefsSnapshot()));
    });
    ref.listen<bool>(popOutAppLockedProvider, (_, locked) {
      if (state) _send(LockMessage(locked));
    });
    ref.onDispose(_dispose);
    return false;
  }

  /// Opens the pop-out on [diveId] (or the main window's dive), or brings
  /// the open one to the front.
  Future<void> openOrFocus({String? diveId}) async {
    if (diveId != null && diveId.isNotEmpty) {
      ref.read(mainWindowDiveIdProvider.notifier).state = diveId;
    }
    if (state) {
      await _send(const FocusRequestMessage());
      return;
    }
    final prefs = ref.read(sharedPreferencesProvider);
    final launch = PopOutLaunch(
      diveId: ref.read(mainWindowDiveIdProvider),
      prefs: _prefsSnapshot(),
      locked: ref.read(popOutAppLockedProvider),
      savedFrame: _savedFrame(prefs),
      mainFrame: await ref.read(mainWindowFrameProvider)(),
    );
    _windows.channel.setHandler(_onMessage);
    _coalescer = CursorCoalescer(
      (diveId, seconds) => _send(CursorMessage(diveId, seconds)),
    );
    _removeCloseHook = DatabaseService.instance.addBeforeCloseHook(close);
    _setOpen(true);
    await _windows.openProfile(launch);
  }

  /// Closes the pop-out, if open.
  Future<void> close() async {
    if (!state) return;
    await _send(const CloseMessage());
    _closed();
  }

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
      default:
        break;
    }
  }

  void _closed() {
    _setOpen(false);
    _windows.channel.setHandler(null);
    _coalescer?.dispose();
    _coalescer = null;
    _removeCloseHook?.call();
    _removeCloseHook = null;
    ref.read(popOutFocusedProvider.notifier).state = false;
  }

  void _dispose() {
    if (!_open) return;
    _open = false;
    unawaited(_windows.channel.send(const CloseMessage()));
    _windows.channel.setHandler(null);
    _coalescer?.dispose();
    _removeCloseHook?.call();
  }

  Future<void> _send(PopOutMessage message) => _windows.channel.send(message);

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
