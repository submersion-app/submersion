import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site-1',
            name: 'Salt Pier',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('siteFeaturesProvider reads through the real repository', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // An empty site resolves to an empty list, not an error.
    expect(
      await container.read(siteFeaturesProvider('site-1').future),
      isEmpty,
    );

    await container
        .read(siteFeatureRepositoryProvider)
        .addFeature(
          siteId: 'site-1',
          typeName: 'hazard',
          latitude: 12.15,
          longitude: -68.3,
        );

    final features = await container.refresh(
      siteFeaturesProvider('site-1').future,
    );
    expect(features, hasLength(1));
    expect(features.single.typeName, 'hazard');
  });

  test('the family scopes rows to their own site', () async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site-2',
            name: 'Other',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(siteFeatureRepositoryProvider)
        .addFeature(
          siteId: 'site-1',
          typeName: 'mooring',
          latitude: 12.15,
          longitude: -68.3,
        );

    expect(
      await container.read(siteFeaturesProvider('site-1').future),
      hasLength(1),
    );
    expect(
      await container.read(siteFeaturesProvider('site-2').future),
      isEmpty,
    );
  });

  test('the repository provider hands out a usable repository', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(siteFeatureRepositoryProvider),
      isA<SiteFeatureRepository>(),
    );
  });
}
