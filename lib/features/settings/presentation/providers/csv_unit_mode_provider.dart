import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _kCsvUnitModeKey = 'csv_export_unit_mode';

/// The CSV unit choice, remembered on this device. Starts at My units; a
/// diver who feeds the CSV to a script picks Metric once and keeps it.
class CsvUnitModeNotifier extends StateNotifier<CsvUnitMode> {
  CsvUnitModeNotifier(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static CsvUnitMode _read(SharedPreferences prefs) =>
      CsvUnitMode.values.asNameMap()[prefs.getString(_kCsvUnitModeKey)] ??
      CsvUnitMode.myUnits;

  Future<void> set(CsvUnitMode mode) async {
    state = mode;
    await _prefs.setString(_kCsvUnitModeKey, mode.name);
  }
}

final csvUnitModeProvider =
    StateNotifierProvider<CsvUnitModeNotifier, CsvUnitMode>(
      (ref) => CsvUnitModeNotifier(ref.watch(sharedPreferencesProvider)),
    );
