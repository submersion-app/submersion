import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Both full UDDF export paths load each site's features and pass them on
/// (issue #2200).
///
/// The round-trip test proves the writers and parsers agree; this proves the
/// app actually reaches them. Without it the export could pass an empty map
/// forever while every round-trip test stayed green.
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
      const DiveSite(id: '', name: 'Lake wreck', diverId: 'me'),
    );
    siteId = site.id;
    await SiteFeatureRepository().addFeature(
      siteId: site.id,
      typeName: 'wreck',
      name: 'Bow section',
      latitude: 36.123456,
      longitude: -5.654321,
      bearingDeg: 135,
      depthMeters: 18.5,
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
    test(
      '${save ? 'saving' : 'sharing'} passes each site its features',
      () async {
        final export = _CapturingExportService();
        final container = make(export);
        final notifier = container.read(exportNotifierProvider.notifier);
        await (save ? notifier.saveUddfToFile() : notifier.exportDivesToUddf());

        final state = container.read(exportNotifierProvider);
        expect(state.status, ExportStatus.success, reason: state.message);
        final features = export.siteFeaturesBySite?[siteId];
        expect(features, isNotNull, reason: 'the export loaded no features');
        expect(features, hasLength(1));
        expect(features!.single.typeName, 'wreck');
        expect(features.single.name, 'Bow section');
        expect(features.single.bearingDeg, 135);
        expect(features.single.depthMeters, 18.5);
      },
    );
  }
}

class _CapturingExportService implements ExportService {
  Map<String, List<SiteFeature>>? siteFeaturesBySite;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #exportAllDataToUddf || name == #saveAllDataToUddfFile) {
      siteFeaturesBySite =
          invocation.namedArguments[#siteFeaturesBySite]
              as Map<String, List<SiteFeature>>?;
      return name == #exportAllDataToUddf
          ? Future<String>.value('/tmp/export.uddf')
          : Future<String?>.value('/tmp/export.uddf');
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
