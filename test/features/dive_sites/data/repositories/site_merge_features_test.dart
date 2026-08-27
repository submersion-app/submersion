import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SiteRepository repository;
  late SiteFeatureRepository featureRepository;
  late db.AppDatabase database;

  setUp(() async {
    await setUpTestDatabase();
    repository = SiteRepository();
    featureRepository = SiteFeatureRepository();
    database = DatabaseService.instance.database;
  });

  tearDown(tearDownTestDatabase);

  test('merge re-points features to the survivor; undo restores', () async {
    final keep = await repository.createSite(
      const DiveSite(id: 'keep', name: 'Salt Pier'),
    );
    final lose = await repository.createSite(
      const DiveSite(id: 'lose', name: 'Salt Peir'),
    );
    final feature = await featureRepository.addFeature(
      siteId: lose.id,
      typeName: 'wreck',
      latitude: 12.15,
      longitude: -68.3,
    );

    final snapshot = await repository.mergeSites(
      mergedSite: keep,
      siteIds: [keep.id, lose.id],
    );
    expect(snapshot, isNotNull);

    var row = await database.select(database.siteFeatures).getSingle();
    expect(row.siteId, 'keep');
    expect(snapshot!.featureOriginalSiteIds, {feature.id: 'lose'});

    await repository.undoMerge(snapshot);
    row = await database.select(database.siteFeatures).getSingle();
    expect(row.siteId, 'lose');
  });

  test('a merge with no features leaves an empty snapshot map', () async {
    final keep = await repository.createSite(
      const DiveSite(id: 'keep', name: 'A'),
    );
    final lose = await repository.createSite(
      const DiveSite(id: 'lose', name: 'B'),
    );

    final snapshot = await repository.mergeSites(
      mergedSite: keep,
      siteIds: [keep.id, lose.id],
    );

    expect(snapshot!.featureOriginalSiteIds, isEmpty);
  });
}
