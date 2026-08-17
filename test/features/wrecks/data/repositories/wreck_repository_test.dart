import 'package:flutter_test/flutter_test.dart';
// Drift names the generated row class `Wreck` too, so the database
// import is aliased and the domain entity keeps the bare name.
import 'package:submersion/core/database/database.dart' as db_lib;
import 'package:submersion/features/wrecks/data/repositories/wreck_repository.dart';
import 'package:submersion/features/wrecks/domain/entities/wreck.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late db_lib.AppDatabase db;
  late WreckRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = WreckRepository();
    await db
        .into(db.diveSites)
        .insert(
          db_lib.DiveSitesCompanion.insert(
            id: 'site-1',
            name: 'Salt Pier',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('create / read / update / delete with the sync ritual', () async {
    final created = await repo.createWreck(
      const Wreck(
        id: '',
        name: 'Hilma Hooker',
        siteId: 'site-1',
        latitude: 12.15,
        longitude: -68.3,
        vesselTypeName: 'ship',
        depthToDeckMeters: 18,
      ),
    );
    expect(created.id, isNotEmpty);
    expect(created.vesselType, WreckVesselType.ship);

    // The write ritual: pending mark plus an hlc stamp, no parent bump
    // (a wreck is top-level, like a site).
    final row = await (db.select(
      db.wrecks,
    )..where((t) => t.id.equals(created.id))).getSingle();
    expect(row.hlc, isNotNull);
    final pending = await db.select(db.syncRecords).get();
    expect(pending.where((p) => p.entityType == 'wrecks'), isNotEmpty);

    expect(await repo.getAllWrecks(), hasLength(1));
    expect(await repo.getWrecksForSite('site-1'), hasLength(1));
    expect((await repo.getWreckById(created.id))!.name, 'Hilma Hooker');

    await repo.updateWreck(created.copyWith(name: 'Hilma', yearSunk: 1984));
    final updated = (await repo.getAllWrecks()).single;
    expect(updated.name, 'Hilma');
    expect(updated.yearSunk, 1984);
    expect(updated.depthToDeckMeters, 18);

    await repo.deleteWreck(created.id);
    expect(await repo.getAllWrecks(), isEmpty);
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.where(
        (d) => d.entityType == 'wrecks' && d.recordId == created.id,
      ),
      isNotEmpty,
    );
  });

  test('an unknown enum name round-trips unchanged', () async {
    final created = await repo.createWreck(
      const Wreck(id: '', name: 'Mystery', vesselTypeName: 'submersible'),
    );
    final read = await repo.getWreckById(created.id);
    expect(read!.vesselTypeName, 'submersible');
    expect(read.vesselType, isNull);
  });

  test('wrecks with no site are excluded from the per-site query', () async {
    await repo.createWreck(const Wreck(id: '', name: 'Unlinked'));
    await repo.createWreck(
      const Wreck(id: '', name: 'Linked', siteId: 'site-1'),
    );
    expect(await repo.getWrecksForSite('site-1'), hasLength(1));
    expect(await repo.getAllWrecks(), hasLength(2));
  });

  test('an update can clear the site link and the depths', () async {
    final created = await repo.createWreck(
      const Wreck(
        id: '',
        name: 'Hilma Hooker',
        siteId: 'site-1',
        depthToDeckMeters: 18,
        depthToSeabedMeters: 30,
      ),
    );
    await repo.updateWreck(
      created.copyWith(clearSite: true, clearDepths: true),
    );
    final read = await repo.getWreckById(created.id);
    expect(read!.siteId, isNull);
    expect(read.depthToDeckMeters, isNull);
    expect(read.depthToSeabedMeters, isNull);
  });

  test('getWreckById returns null for an unknown id', () async {
    expect(await repo.getWreckById('nope'), isNull);
  });
}
