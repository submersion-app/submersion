import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Issue #3229: the operator, boat, captain and surface conditions columns
/// ride on the Dive entity, so they round-trip through both row mappers and
/// a save that does not touch them cannot erase them.
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  domain.Dive makeDive({
    String id = '',
    String? diveOperator,
    String? boatName,
    String? boatCaptain,
    String? surfaceConditions,
  }) => domain.Dive(
    id: id,
    dateTime: DateTime.utc(2026, 7, 1, 10),
    diveOperator: diveOperator,
    boatName: boatName,
    boatCaptain: boatCaptain,
    surfaceConditions: surfaceConditions,
  );

  void expectAllFour(domain.Dive d) {
    expect(d.diveOperator, 'Buddy Dive');
    expect(d.boatName, 'Bonaire Breeze');
    expect(d.boatCaptain, 'Rik');
    expect(d.surfaceConditions, 'Choppy');
  }

  domain.Dive fullDive({String id = ''}) => makeDive(
    id: id,
    diveOperator: 'Buddy Dive',
    boatName: 'Bonaire Breeze',
    boatCaptain: 'Rik',
    surfaceConditions: 'Choppy',
  );

  test('createDive and getDiveById round-trip all four', () async {
    final created = await repository.createDive(fullDive());
    expectAllFour((await repository.getDiveById(created.id))!);
  });

  test('getAllDives carries all four', () async {
    await repository.createDive(fullDive());
    expectAllFour((await repository.getAllDives()).single);
  });

  test('updateDive with a fresh entity clears them', () async {
    final created = await repository.createDive(fullDive());
    // copyWith cannot null a field, so build the cleared dive the way the
    // edit form does: a fresh entity.
    await repository.updateDive(makeDive(id: created.id));
    final loaded = (await repository.getDiveById(created.id))!;
    expect(loaded.diveOperator, isNull);
    expect(loaded.boatName, isNull);
    expect(loaded.boatCaptain, isNull);
    expect(loaded.surfaceConditions, isNull);
  });

  test('an import-written row survives an unrelated update', () async {
    final created = await repository.createDive(makeDive());
    // The MacDive and UDDF importers write these columns straight to the
    // row, bypassing the entity.
    await (db.update(db.dives)..where((t) => t.id.equals(created.id))).write(
      const DivesCompanion(
        diveOperator: Value('Buddy Dive'),
        boatName: Value('Bonaire Breeze'),
        boatCaptain: Value('Rik'),
        surfaceConditions: Value('Choppy'),
      ),
    );
    final loaded = (await repository.getDiveById(created.id))!;
    expectAllFour(loaded);

    await repository.updateDive(loaded.copyWith(name: 'Renamed'));

    final reloaded = (await repository.getDiveById(created.id))!;
    expect(reloaded.name, 'Renamed');
    expectAllFour(reloaded);
  });
}
