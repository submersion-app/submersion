import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const kConnectionsDisplayKey = 'connections_display';

const _log = LoggerService('ConnectionsDisplay');

/// How the Connections page presents its map, remembered on this device.
class ConnectionsDisplayNotifier extends StateNotifier<ConnectionsDisplay> {
  ConnectionsDisplayNotifier(
    SharedPreferences prefs, {
    Future<bool> Function(String key, String value)? write,
  }) : _write = write ?? prefs.setString,
       super(_restore(prefs));

  final Future<bool> Function(String key, String value) _write;

  static ConnectionsDisplay _restore(SharedPreferences prefs) {
    final raw = prefs.getString(kConnectionsDisplayKey);
    if (raw == null) return ConnectionsDisplay.initial;
    try {
      return ConnectionsDisplay.fromJson(jsonDecode(raw));
    } on FormatException {
      return ConnectionsDisplay.initial;
    }
  }

  /// The last write queued; each new one waits for it, so a slow write
  /// can never land after a newer one and restore a stale display.
  Future<void> _lastWrite = Future.value();

  /// Applies [change] at once and persists the result. A failed write is
  /// logged and otherwise ignored: the display is a convenience, not data.
  Future<void> update(ConnectionsDisplay Function(ConnectionsDisplay) change) {
    final next = change(state);
    if (next == state) return Future.value();
    state = next;
    return _lastWrite = _lastWrite.then((_) => _persist(next));
  }

  Future<void> _persist(ConnectionsDisplay display) async {
    try {
      await _write(kConnectionsDisplayKey, jsonEncode(display.toJson()));
    } catch (e, st) {
      _log.warning(
        'Could not remember the connections display',
        error: e,
        stackTrace: st,
      );
    }
  }
}

final connectionsDisplayProvider =
    StateNotifierProvider<ConnectionsDisplayNotifier, ConnectionsDisplay>(
      (ref) => ConnectionsDisplayNotifier(ref.watch(sharedPreferencesProvider)),
    );
