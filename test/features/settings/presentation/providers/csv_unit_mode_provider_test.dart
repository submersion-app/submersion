import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/features/settings/presentation/providers/csv_unit_mode_provider.dart';

void main() {
  test('starts at My units when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = CsvUnitModeNotifier(await SharedPreferences.getInstance());
    expect(notifier.state, CsvUnitMode.myUnits);
  });

  test('remembers the last choice', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await CsvUnitModeNotifier(prefs).set(CsvUnitMode.metric);
    expect(CsvUnitModeNotifier(prefs).state, CsvUnitMode.metric);
  });

  test('an unknown stored value falls back to My units', () async {
    SharedPreferences.setMockInitialValues({
      'csv_export_unit_mode': 'furlongs',
    });
    final notifier = CsvUnitModeNotifier(await SharedPreferences.getInstance());
    expect(notifier.state, CsvUnitMode.myUnits);
  });
}
