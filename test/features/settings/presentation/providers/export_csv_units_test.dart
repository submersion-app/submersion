import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart'
    as tag_entity;
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The Transfer CSV export builds its units from the chosen mode (#1813).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer make(_FakeExportService export) {
    final container = ProviderContainer(
      overrides: [
        // The dives CSV reads the logbook fresh through the validated diver id
        // (#1861), not through the cached divesProvider.
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
        diveRepositoryProvider.overrideWithValue(
          _FixedDivesRepository([
            Dive(id: 'd1', dateTime: DateTime.utc(2026, 3, 1)),
          ]),
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
        // The sites CSV now reads each site's features (issue #2200),
        // and this container has no database behind it.
        siteFeatureRepositoryProvider.overrideWithValue(_NoSiteFeatures()),
        // It reads each site's type and tag names too (issue #2201).
        siteClassificationRepositoryProvider.overrideWithValue(
          _NoSiteClassification(),
        ),
        equipmentTagRepositoryProvider.overrideWithValue(_OneTag()),
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

  test(
    "the equipment CSV gets each exported item's tag names (#1942)",
    () async {
      final export = _FakeExportService();
      final notifier = (await loaded(
        export,
      )).read(exportNotifierProvider.notifier);
      for (final run in <Future<void> Function()>[
        () => notifier.exportEquipmentToCsv(),
        () => notifier.saveEquipmentCsvToFile(),
      ]) {
        export.tagNames = null;
        await run();
        expect(export.tagNames, {
          'e1': ['Travel'],
        });
      }
    },
  );

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

/// Serves a fixed dive list as the diver's logbook.
class _FixedDivesRepository implements DiveRepository {
  _FixedDivesRepository(this.dives);
  final List<Dive> dives;

  @override
  Future<List<Dive>> getAllDives({String? diverId}) async => dives;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeExportService implements ExportService {
  CsvExportUnits? units;
  Map<String, List<String>>? tagNames;

  @override
  Future<String> exportDivesToCsv(
    List<Dive> dives, {
    CsvExportUnits units = CsvExportUnits.metric,
    Map<String, DiveTypeEntity> diveTypesById = const {},
  }) async {
    this.units = units;
    return '/tmp/d.csv';
  }

  @override
  Future<String?> saveDivesCsvToFile(
    List<Dive> dives, {
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
    Map<String, DiveTypeEntity> diveTypesById = const {},
  }) async {
    this.units = units;
    return '/tmp/d.csv';
  }

  @override
  Future<String> exportSitesToCsv(
    List<DiveSite> sites, {
    CsvExportUnits units = CsvExportUnits.metric,
    Map<String, List<SiteFeature>> featuresBySite = const {},
    Map<String, List<String>> typeNamesBySite = const {},
    Map<String, List<String>> tagNamesBySite = const {},
  }) async {
    this.units = units;
    return '/tmp/s.csv';
  }

  @override
  Future<String?> saveSitesCsvToFile(
    List<DiveSite> sites, {
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
    Map<String, List<SiteFeature>> featuresBySite = const {},
    Map<String, List<String>> typeNamesBySite = const {},
    Map<String, List<String>> tagNamesBySite = const {},
  }) async {
    this.units = units;
    return '/tmp/s.csv';
  }

  @override
  Future<String> exportEquipmentToCsv(
    List<EquipmentItem> equipment, {
    Map<String, List<String>> componentNames = const {},
    Map<String, List<String>> tagNames = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    this.units = units;
    this.tagNames = tagNames;
    return '/tmp/e.csv';
  }

  @override
  Future<String?> saveEquipmentCsvToFile(
    List<EquipmentItem> equipment, {
    Map<String, List<String>> componentNames = const {},
    Map<String, List<String>> tagNames = const {},
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    this.units = units;
    this.tagNames = tagNames;
    return '/tmp/e.csv';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoComponents extends Fake implements EquipmentComponentRepository {
  @override
  Future<List<EquipmentComponent>> getAllComponents() async => const [];
}

class _NoSiteClassification extends Fake
    implements SiteClassificationRepository {
  @override
  Future<Map<String, List<SiteTypeEntity>>> getTypesBySite() async => const {};

  @override
  Future<Map<String, List<tag_entity.Tag>>> getTagsBySite() async => const {};
}

class _NoSiteFeatures extends Fake implements SiteFeatureRepository {
  @override
  Future<Map<String, List<SiteFeature>>> getFeaturesForSites(
    List<String> siteIds,
  ) async => const {};
}

class _ImperialSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _ImperialSettings() : super(const AppSettings(depthUnit: DepthUnit.feet));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Tags for the exported item and for one that is not exported.
class _OneTag extends Fake implements EquipmentTagRepository {
  @override
  Future<Map<String, List<Tag>>> getTagsByEquipment() async {
    final now = DateTime.utc(2026);
    final travel = Tag(
      id: 't1',
      name: 'Travel',
      createdAt: now,
      updatedAt: now,
      scopes: const {TagScope.equipment},
    );
    return {
      'e1': [travel],
      'gone': [travel],
    };
  }
}
