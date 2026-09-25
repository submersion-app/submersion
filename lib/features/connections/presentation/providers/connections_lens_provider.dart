import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/lenses/connection_lens.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const kConnectionsLastLensKey = 'connections_last_lens';

/// The active lens or custom pair, remembered on this device only.
class ConnectionsLensNotifier extends StateNotifier<LensSelection> {
  ConnectionsLensNotifier(this._prefs)
    : super(
        LensSelection.parse(_prefs.getString(kConnectionsLastLensKey)) ??
            LensSelection.fallback,
      );

  final SharedPreferences _prefs;

  void select(LensSelection selection) {
    if (selection == state) return;
    state = selection;
    _prefs.setString(kConnectionsLastLensKey, selection.persisted);
  }
}

final connectionsLensProvider =
    StateNotifierProvider<ConnectionsLensNotifier, LensSelection>(
      (ref) => ConnectionsLensNotifier(ref.watch(sharedPreferencesProvider)),
    );
