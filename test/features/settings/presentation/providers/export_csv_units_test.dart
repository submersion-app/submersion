import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The Transfer CSV export builds its units from the chosen mode (#1813).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer make(_FakeExportService export) {
    final container = ProviderContainer(
      overrides: [
        divesProvider.overrideWith(
          (ref) async => [Dive(id: 'd1', dateTime: DateTime.utc(2026, 3, 1))],
        ),
        settingsProvider.overrideWith((ref) => _ImperialSettings()),
        exportServiceProvider.overrideWithValue(export),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('My units builds the export units from the diver settings', () async {
    final export = _FakeExportService();
    await make(export)
        .read(exportNotifierProvider.notifier)
        .exportDivesToCsv(unitMode: CsvUnitMode.myUnits);
    expect(export.units?.isMetric, isFalse);
    expect(export.units?.formatter?.settings.depthUnit, DepthUnit.feet);
  });

  test('Metric passes the metric units', () async {
    final export = _FakeExportService();
    await make(export)
        .read(exportNotifierProvider.notifier)
        .saveDivesCsvToFile(unitMode: CsvUnitMode.metric);
    expect(export.units, same(CsvExportUnits.metric));
  });
}

class _FakeExportService implements ExportService {
  CsvExportUnits? units;

  @override
  Future<String> exportDivesToCsv(
    List<Dive> dives, {
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    this.units = units;
    return '/tmp/d.csv';
  }

  @override
  Future<String?> saveDivesCsvToFile(
    List<Dive> dives, {
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    this.units = units;
    return '/tmp/d.csv';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ImperialSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _ImperialSettings() : super(const AppSettings(depthUnit: DepthUnit.feet));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
