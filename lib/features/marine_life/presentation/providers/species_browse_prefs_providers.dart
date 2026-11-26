import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/species_grouping.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// How this device lays out the Species page (issue #5027). Device
/// preferences, not synced: a phone and a desktop are browsed differently.
const String kSpeciesGroupByKey = 'species_page.group_by';
const String kSpeciesBrowseGridKey = 'species_page.grid';

/// The Species page grouping. None until changed; a value this build does
/// not know (written by a newer one) reads as none.
class SpeciesGroupByNotifier extends StateNotifier<SpeciesGroupBy> {
  SpeciesGroupByNotifier(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static SpeciesGroupBy _read(SharedPreferences prefs) {
    final stored = prefs.getString(kSpeciesGroupByKey);
    return SpeciesGroupBy.values.firstWhere(
      (by) => by.name == stored,
      orElse: () => SpeciesGroupBy.none,
    );
  }

  Future<void> set(SpeciesGroupBy by) async {
    state = by;
    await _prefs.setString(kSpeciesGroupByKey, by.name);
  }
}

final speciesGroupByProvider =
    StateNotifierProvider<SpeciesGroupByNotifier, SpeciesGroupBy>(
      (ref) => SpeciesGroupByNotifier(ref.watch(sharedPreferencesProvider)),
    );

/// Whether the Species page shows picture cards (true) or the compact list.
class SpeciesBrowseGridNotifier extends StateNotifier<bool> {
  SpeciesBrowseGridNotifier(this._prefs)
    : super(_prefs.getBool(kSpeciesBrowseGridKey) ?? true);

  final SharedPreferences _prefs;

  Future<void> set(bool grid) async {
    state = grid;
    await _prefs.setBool(kSpeciesBrowseGridKey, grid);
  }
}

final speciesBrowseGridProvider =
    StateNotifierProvider<SpeciesBrowseGridNotifier, bool>(
      (ref) => SpeciesBrowseGridNotifier(ref.watch(sharedPreferencesProvider)),
    );
