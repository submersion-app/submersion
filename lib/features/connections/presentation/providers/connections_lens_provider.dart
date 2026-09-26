import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/connections/domain/lenses/connection_lens.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const kConnectionsLastLensKey = 'connections_last_lens';

const _log = LoggerService('ConnectionsLens');

/// The active lens or custom pair, remembered on this device only.
class ConnectionsLensNotifier extends StateNotifier<LensSelection> {
  ConnectionsLensNotifier(
    SharedPreferences prefs, {
    Future<bool> Function(String key, String value)? write,
  }) : _write = write ?? prefs.setString,
       super(
         LensSelection.parse(prefs.getString(kConnectionsLastLensKey)) ??
             LensSelection.fallback,
       );

  final Future<bool> Function(String key, String value) _write;

  /// Switches the lens at once and persists it. A failed write is logged and
  /// otherwise ignored: the lens is a convenience, not data.
  Future<void> select(LensSelection selection) async {
    if (selection == state) return;
    state = selection;
    try {
      await _write(kConnectionsLastLensKey, selection.persisted);
    } catch (e, st) {
      _log.warning(
        'Could not remember the connections lens',
        error: e,
        stackTrace: st,
      );
    }
  }
}

final connectionsLensProvider =
    StateNotifierProvider<ConnectionsLensNotifier, LensSelection>(
      (ref) => ConnectionsLensNotifier(ref.watch(sharedPreferencesProvider)),
    );
