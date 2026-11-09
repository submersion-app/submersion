import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Device preferences of the species map (issue #4358).
///
/// Kept on the device rather than in synced diver settings: the public
/// layer governs what THIS device sends to GBIF, so another device turning
/// it on must not turn it on here.
const String kSpeciesMapPublicLayerKey = 'species_map.public_layer';
const String kSpeciesMapExpectedScopeKey = 'species_map.expected_scope';

/// Whether the species map shows GBIF's public records. Off until the diver
/// turns it on; while off the map sends nothing to GBIF.
class SpeciesMapPublicLayerNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;

  SpeciesMapPublicLayerNotifier(this._prefs)
    : super(_prefs.getBool(kSpeciesMapPublicLayerKey) ?? false);

  Future<void> set(bool on) async {
    state = on;
    await _prefs.setBool(kSpeciesMapPublicLayerKey, on);
  }
}

final speciesMapPublicLayerProvider =
    StateNotifierProvider<SpeciesMapPublicLayerNotifier, bool>(
      (ref) =>
          SpeciesMapPublicLayerNotifier(ref.watch(sharedPreferencesProvider)),
    );

/// Whose expected lists draw expected pins. "Mine" until changed; a value
/// this build does not know (written by a newer one) reads as "mine".
class SpeciesMapExpectedScopeNotifier extends StateNotifier<ExpectedSiteScope> {
  final SharedPreferences _prefs;

  SpeciesMapExpectedScopeNotifier(this._prefs) : super(_read(_prefs));

  static ExpectedSiteScope _read(SharedPreferences prefs) {
    final stored = prefs.getString(kSpeciesMapExpectedScopeKey);
    return ExpectedSiteScope.values.firstWhere(
      (scope) => scope.name == stored,
      orElse: () => ExpectedSiteScope.mine,
    );
  }

  Future<void> set(ExpectedSiteScope scope) async {
    state = scope;
    await _prefs.setString(kSpeciesMapExpectedScopeKey, scope.name);
  }
}

final speciesMapExpectedScopeProvider =
    StateNotifierProvider<SpeciesMapExpectedScopeNotifier, ExpectedSiteScope>(
      (ref) =>
          SpeciesMapExpectedScopeNotifier(ref.watch(sharedPreferencesProvider)),
    );
