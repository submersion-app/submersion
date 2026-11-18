import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_features_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_start.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A site's features are held in the sitting and written at Save as the
/// difference from what the sitting loaded (issue #4527, phase 2).
void main() {
  late SiteFeatureRepository repository;
  const site = DiveSite(id: 's1', name: 'A', location: GeoPoint(12, -68));

  setUp(() async {
    await setUpTestDatabase();
    repository = SiteFeatureRepository();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO dive_sites (id, name, latitude, longitude, created_at, "
      "updated_at) VALUES ('s1', 'A', 12, -68, 0, 0)",
    );
  });

  tearDown(tearDownTestDatabase);

  Future<SiteFeature> stored(String name) => repository.addFeature(
    siteId: 's1',
    typeName: 'mooring',
    latitude: 12,
    longitude: -68,
    name: name,
  );

  Future<List<String>> storedNames() async => [
    for (final f in await repository.getFeaturesForSite('s1')) f.name,
  ];

  Future<EditSession<DiveSite>> loaded() async {
    final session = EditSession<DiveSite>(site);
    addTearDown(session.dispose);
    await siteFeaturesList.load(session);
    return session;
  }

  SiteFeature placed(String name) => SiteFeature(
    id: 'held-$name',
    siteId: 's1',
    typeName: 'wreck',
    latitude: 12.1,
    longitude: -68.1,
    name: name,
  );

  test('features are equal by value', () {
    expect(placed('Bow'), placed('Bow'));
    expect(placed('Bow') == placed('Stern'), isFalse);
  });

  test('add, change and remove write the difference', () async {
    final buoy = await stored('Buoy');
    final pier = await stored('Pier');
    final session = await loaded();

    addFeatureInSitting(session, placed('Bow'));
    updateFeatureInSitting(session, buoy.copyWith(name: 'Red buoy'));
    removeFeatureInSitting(session, pier.id);
    await session.runHeldWrites();

    expect((await storedNames()).toSet(), {'Red buoy', 'Bow'});
  });

  test('a feature added on another device meanwhile survives', () async {
    await stored('Buoy');
    final session = await loaded();
    addFeatureInSitting(session, placed('Bow'));
    await stored('Synced');

    await session.runHeldWrites();

    expect((await storedNames()).toSet(), {'Buoy', 'Bow', 'Synced'});
  });

  test('a held list is a write of the features field', () async {
    final session = await loaded();
    addFeatureInSitting(session, placed('Bow'));

    expect(session.changedCardIds, {'features'});
    expect(siteLibraryFields(session), {'features'});
  });
}
