import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
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
        sitesProvider.overrideWith(
          (ref) async => const [DiveSite(id: 's1', name: 'Reef')],
        ),
        allEquipmentProvider.overrideWith(
          (ref) async => const [
            EquipmentItem(id: 'e1', name: 'Reg', type: EquipmentType.regulator),
          ],
        ),
        equipmentComponentRepositoryProvider.overrideWithValue(_NoComponents()),
        settingsProvider.overrideWith((ref) => _ImperialSettings()),
        exportServiceProvider.overrideWithValue(export),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// A container whose sites and equipment have loaded, since the notifier
  /// reads both providers' current values rather than awaiting them.
  Future<ProviderContainer> loaded(_FakeExportService export) async {
    final container = make(export);
    await container.read(sitesProvider.future);
    await container.read(allEquipmentProvider.future);
    return container;
  }

  test('sites and equipment exports get the My units too', () async {
    final export = _FakeExportService();
    final notifier = (await loaded(
      export,
    )).read(exportNotifierProvider.notifier);
    for (final run in <Future<void> Function()>[
      () => notifier.exportSitesToCsv(unitMode: CsvUnitMode.myUnits),
      () => notifier.saveSitesCsvToFile(unitMode: CsvUnitMode.myUnits),
      () => notifier.exportEquipmentToCsv(unitMode: CsvUnitMode.myUnits),
      () => notifier.saveEquipmentCsvToFile(unitMode: CsvUnitMode.myUnits),
    ]) {
      export.units = null;
      await run();
      expect(export.units?.isMetric, isFalse);
    }
  });

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
  Future<String> exportSitesToCsv(
    List<DiveSite> sites, {
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    this.units = units;
    return '/tmp/s.csv';
  }

  @override
  Future<String?> saveSitesCsvToFile(
    List<DiveSite> sites, {
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    this.units = units;
    return '/tmp/s.csv';
  }

  @override
  Future<String> exportEquipmentToCsv(
    List<EquipmentItem> equipment, {
    Map<String, List<String>> componentNames = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    this.units = units;
    return '/tmp/e.csv';
  }

  @override
  Future<String?> saveEquipmentCsvToFile(
    List<EquipmentItem> equipment, {
    Map<String, List<String>> componentNames = const {},
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    this.units = units;
    return '/tmp/e.csv';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoComponents extends Fake implements EquipmentComponentRepository {
  @override
  Future<List<EquipmentComponent>> getAllComponents() async => const [];
}

class _ImperialSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _ImperialSettings() : super(const AppSettings(depthUnit: DepthUnit.feet));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
