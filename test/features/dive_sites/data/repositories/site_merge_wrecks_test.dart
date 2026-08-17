import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db_lib;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/wrecks/data/repositories/wreck_repository.dart';
import 'package:submersion/features/wrecks/domain/entities/wreck.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SiteRepository repository;
  late WreckRepository wreckRepository;
  late db_lib.AppDatabase database;

  setUp(() async {
    await setUpTestDatabase();
    repository = SiteRepository();
    wreckRepository = WreckRepository();
    database = DatabaseService.instance.database;
  });

  tearDown(tearDownTestDatabase);

  test('merge re-points wrecks to the survivor; undo restores', () async {
    final keep = await repository.createSite(
      const DiveSite(id: 'keep', name: 'Salt Pier'),
    );
    final lose = await repository.createSite(
      const DiveSite(id: 'lose', name: 'Salt Peir'),
    );
    final wreck = await wreckRepository.createWreck(
      Wreck(id: '', name: 'Hilma Hooker', siteId: lose.id),
    );

    final snapshot = await repository.mergeSites(
      mergedSite: keep,
      siteIds: [keep.id, lose.id],
    );
    expect(snapshot, isNotNull);

    var row = await database.select(database.wrecks).getSingle();
    expect(row.siteId, 'keep');
    expect(snapshot!.wreckOriginalSiteIds, {wreck.id: 'lose'});

    await repository.undoMerge(snapshot);
    row = await database.select(database.wrecks).getSingle();
    expect(row.siteId, 'lose');
  });

  test('an unlinked wreck is untouched by a merge', () async {
    final keep = await repository.createSite(
      const DiveSite(id: 'keep', name: 'A'),
    );
    final lose = await repository.createSite(
      const DiveSite(id: 'lose', name: 'B'),
    );
    await wreckRepository.createWreck(const Wreck(id: '', name: 'Unlinked'));

    final snapshot = await repository.mergeSites(
      mergedSite: keep,
      siteIds: [keep.id, lose.id],
    );

    expect(snapshot!.wreckOriginalSiteIds, isEmpty);
    expect((await database.select(database.wrecks).getSingle()).siteId, isNull);
  });
}
