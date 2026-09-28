import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const kConnectionsViewKey = 'connections_view_v2';

/// Phase 1 stored only the lens here; read once to migrate.
const kConnectionsLegacyLensKey = 'connections_last_lens';

const _log = LoggerService('ConnectionsView');

/// The whole Connections view, remembered on this device only.
class ConnectionsViewNotifier extends StateNotifier<ConnectionsViewState> {
  ConnectionsViewNotifier(
    SharedPreferences prefs, {
    Future<bool> Function(String key, String value)? write,
  }) : _write = write ?? prefs.setString,
       super(_restore(prefs));

  final Future<bool> Function(String key, String value) _write;

  static ConnectionsViewState _restore(SharedPreferences prefs) {
    final raw = prefs.getString(kConnectionsViewKey);
    if (raw != null) {
      try {
        final parsed = ConnectionsViewState.fromJson(jsonDecode(raw));
        if (parsed != null) return parsed;
      } on FormatException {
        // Fall through to the legacy key and then the initial view.
      }
    }
    return ConnectionsViewState.fromLegacyLens(
      prefs.getString(kConnectionsLegacyLensKey),
    );
  }

  /// Applies [change] at once and persists the result. A failed write is
  /// logged and otherwise ignored: the view is a convenience, not data.
  Future<void> update(
    ConnectionsViewState Function(ConnectionsViewState) change,
  ) async {
    final next = change(state);
    if (next == state) return;
    state = next;
    try {
      await _write(kConnectionsViewKey, jsonEncode(next.toJson()));
    } catch (e, st) {
      _log.warning(
        'Could not remember the connections view',
        error: e,
        stackTrace: st,
      );
    }
  }
}

final connectionsViewProvider =
    StateNotifierProvider<ConnectionsViewNotifier, ConnectionsViewState>((ref) {
      final notifier = ConnectionsViewNotifier(
        ref.watch(sharedPreferencesProvider),
      );
      // The view is remembered per device, but a centre is one diver's
      // entity: another diver must not open Around on it.
      ref.listen<String?>(currentDiverIdProvider, (previous, next) {
        if (previous != null && previous != next) {
          notifier.update((s) => s.copyWith(clearFocus: true));
        }
      });
      return notifier;
    });
