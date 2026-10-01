import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

/// dive_tanks.role_source (issue #2595): a role the computer read off a
/// transmitter's name stays marked until a person sets the role, and the
/// mark never outlives that edit.
void main() {
  late db.AppDatabase database;
  late DiveRepository repository;

  setUp(() async {
    database = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// A dive with one oxygen cylinder whose role came from the transmitter's
  /// name, as a download stores it.
  Future<Dive> diveWithNameDerivedOxygen() async {
    final created = await repository.createDive(
      Dive(
        id: '',
        dateTime: DateTime.utc(2026, 9, 12, 8),
        tanks: const [
          DiveTank(
            id: '',
            gasMix: GasMix(o2: 100.0),
            role: TankRole.oxygenSupply,
            transmitterSerial: '222222',
          ),
        ],
      ),
    );
    await database.customStatement(
      "UPDATE dive_tanks SET role_source = 'transmitterName'",
    );
    return (await repository.getDiveById(created.id))!;
  }

  Future<String?> storedRoleSource() async =>
      (await database.select(database.diveTanks).getSingle()).roleSource;

  test('the role source is read back onto the tank', () async {
    final dive = await diveWithNameDerivedOxygen();
    expect(dive.tanks.single.roleSource, TankRoleSource.transmitterName);
  });

  test('an edit that keeps the role keeps its source', () async {
    final dive = await diveWithNameDerivedOxygen();
    final tank = dive.tanks.single;
    // The tank editor rebuilds the tank field by field.
    await repository.updateDive(
      dive.copyWith(
        tanks: [
          DiveTank(
            id: tank.id,
            gasMix: tank.gasMix,
            role: tank.role,
            volume: 3.0,
            transmitterSerial: tank.transmitterSerial,
          ),
        ],
      ),
    );
    expect(await storedRoleSource(), 'transmitterName');
  });

  test('an edit that changes the role clears its source', () async {
    final dive = await diveWithNameDerivedOxygen();
    final tank = dive.tanks.single;
    await repository.updateDive(
      dive.copyWith(tanks: [tank.copyWith(role: TankRole.bailout)]),
    );
    expect(await storedRoleSource(), isNull);
    final reread = await repository.getDiveById(dive.id);
    expect(reread!.tanks.single.role, TankRole.bailout);
    expect(reread.tanks.single.roleSource, isNull);
  });

  test('a bulk spec edit that sets the role clears its source', () async {
    final dive = await diveWithNameDerivedOxygen();
    await repository.bulkUpdateTankSpecs(
      [dive.id],
      const DiveTank(id: '', role: TankRole.bailout),
      {TankSpecField.role},
    );
    expect(await storedRoleSource(), isNull);
  });

  test('a bulk spec edit of other fields keeps the source', () async {
    final dive = await diveWithNameDerivedOxygen();
    await repository.bulkUpdateTankSpecs(
      [dive.id],
      const DiveTank(id: '', volume: 3.0),
      {TankSpecField.volume},
    );
    expect(await storedRoleSource(), 'transmitterName');
  });

  test('a new tank added by hand has no source', () async {
    final dive = await diveWithNameDerivedOxygen();
    await repository.updateDive(
      dive.copyWith(
        tanks: [
          ...dive.tanks,
          const DiveTank(
            id: 'new-tank',
            gasMix: GasMix(o2: 21.0),
            role: TankRole.bailout,
            order: 1,
          ),
        ],
      ),
    );
    final rows = await (database.select(
      database.diveTanks,
    )..where((t) => t.id.equals('new-tank'))).get();
    expect(rows.single.roleSource, isNull);
  });

  test('a new tank that carries a source stores it', () async {
    // The planned-dive fill appends downloaded tanks this way.
    final dive = await diveWithNameDerivedOxygen();
    await repository.updateDive(
      dive.copyWith(
        tanks: [
          ...dive.tanks,
          const DiveTank(
            id: 'new-tank',
            gasMix: GasMix(o2: 15.0, he: 55.0),
            role: TankRole.diluent,
            roleSource: TankRoleSource.transmitterName,
            order: 1,
          ),
        ],
      ),
    );
    final rows = await (database.select(
      database.diveTanks,
    )..where((t) => t.id.equals('new-tank'))).get();
    expect(rows.single.roleSource, 'transmitterName');
  });

  test('createDive stores a source the tank carries', () async {
    final created = await repository.createDive(
      Dive(
        id: '',
        dateTime: DateTime.utc(2026, 9, 13, 8),
        tanks: const [
          DiveTank(
            id: '',
            gasMix: GasMix(o2: 100.0),
            role: TankRole.oxygenSupply,
            roleSource: TankRoleSource.transmitterName,
          ),
        ],
      ),
    );
    final reread = await repository.getDiveById(created.id);
    expect(reread!.tanks.single.roleSource, TankRoleSource.transmitterName);
  });
}
