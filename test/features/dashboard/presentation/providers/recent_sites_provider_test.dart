import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
    container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });
  tearDown(() async => tearDownTestDatabase());

  test(
    'returns deduplicated pins for GPS-bearing sites of last 10 dives',
    () async {
      final siteRepo = SiteRepository();
      final siteA = await siteRepo.createSite(
        const DiveSite(id: '', name: 'Site A', location: GeoPoint(36.0, 25.0)),
      );
      final siteB = await siteRepo.createSite(
        const DiveSite(id: '', name: 'Site B', location: GeoPoint(35.0, 24.0)),
      );

      await repository.createDive(
        domain.Dive(id: 'a1', dateTime: DateTime(2026, 7, 1), site: siteA),
      );
      await repository.createDive(
        domain.Dive(id: 'a2', dateTime: DateTime(2026, 7, 2), site: siteA),
      );
      await repository.createDive(
        domain.Dive(id: 'b1', dateTime: DateTime(2026, 7, 3), site: siteB),
      );
      await repository.createDive(
        domain.Dive(id: 'nosite', dateTime: DateTime(2026, 7, 4)),
      );

      final pins = await container.read(recentSitesProvider.future);
      expect(pins, hasLength(2));
      expect(pins.map((p) => p.siteName).toSet(), {'Site A', 'Site B'});
    },
  );

  test('empty when no dives have sited GPS', () async {
    await repository.createDive(
      domain.Dive(id: 'd1', dateTime: DateTime(2026, 7, 1)),
    );
    final pins = await container.read(recentSitesProvider.future);
    expect(pins, isEmpty);
  });

  test('distinct sites sharing coordinates both keep a pin', () async {
    final siteRepo = SiteRepository();
    final wreck = await siteRepo.createSite(
      const DiveSite(id: '', name: 'Wreck', location: GeoPoint(36.0, 25.0)),
    );
    // Same GPS fix, different site (e.g. a renamed or adjacent site).
    final reef = await siteRepo.createSite(
      const DiveSite(id: '', name: 'Reef', location: GeoPoint(36.0, 25.0)),
    );

    await repository.createDive(
      domain.Dive(id: 'w1', dateTime: DateTime(2026, 7, 1), site: wreck),
    );
    await repository.createDive(
      domain.Dive(id: 'r1', dateTime: DateTime(2026, 7, 2), site: reef),
    );

    final pins = await container.read(recentSitesProvider.future);
    expect(pins.map((p) => p.siteName).toSet(), {'Wreck', 'Reef'});
  });
}
