import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Both sites CSV paths load each site's features and pass them on
/// (issue #2200), so the column is not written blank forever.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String siteId;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.utc(2026, 3, 1);
    await DiverRepository().createDiver(
      Diver(
        id: 'me',
        name: 'Me',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final site = await SiteRepository().createSite(
      const DiveSite(id: '', name: 'Blue Hole', diverId: 'me'),
      classification: const SiteClassification(typeIds: ['wreck']),
    );
    siteId = site.id;
    await SiteFeatureRepository().addFeature(
      siteId: site.id,
      typeName: 'wreck',
      name: 'Bow section',
      latitude: 17.316,
      longitude: -87.535,
    );
  });

  tearDown(tearDownTestDatabase);

  ProviderContainer make(_CapturingExportService export) {
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier()..state = 'me',
        ),
        settingsProvider.overrideWith((ref) => _FixedSettings()),
        exportServiceProvider.overrideWithValue(export),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  for (final save in [false, true]) {
    test('${save ? 'saving' : 'sharing'} the sites CSV passes each site its '
        'features', () async {
      final export = _CapturingExportService();
      final container = make(export);
      // The notifier reads the sites provider's current value rather than
      // awaiting it, so it has to have loaded first.
      await container.read(sitesProvider.future);
      final notifier = container.read(exportNotifierProvider.notifier);
      await (save
          ? notifier.saveSitesCsvToFile()
          : notifier.exportSitesToCsv());

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.success, reason: state.message);
      final features = export.featuresBySite?[siteId];
      expect(features, isNotNull, reason: 'the export loaded no features');
      expect(features!.single.name, 'Bow section');
    });
  }

  test('the sites CSV gets each site its type names (issue #2201)', () async {
    final export = _CapturingExportService();
    final container = make(export);
    await container.read(sitesProvider.future);
    await container.read(exportNotifierProvider.notifier).exportSitesToCsv();

    expect(export.typeNamesBySite?[siteId], ['Wreck']);
  });
}

class _CapturingExportService implements ExportService {
  Map<String, List<SiteFeature>>? featuresBySite;
  Map<String, List<String>>? typeNamesBySite;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #exportSitesToCsv || name == #saveSitesCsvToFile) {
      featuresBySite =
          invocation.namedArguments[#featuresBySite]
              as Map<String, List<SiteFeature>>?;
      typeNamesBySite =
          invocation.namedArguments[#typeNamesBySite]
              as Map<String, List<String>>?;
      return name == #exportSitesToCsv
          ? Future<String>.value('/tmp/sites.csv')
          : Future<String?>.value('/tmp/sites.csv');
    }
    return null;
  }
}

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
