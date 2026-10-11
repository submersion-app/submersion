import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveComputerRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertComputer({
    required String id,
    String? manufacturer,
    String? model,
    String? serialNumber,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value(id),
            manufacturer: Value(manufacturer),
            model: Value(model),
            serialNumber: Value(serialNumber),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  group('findByHardwareIdentity (#3106)', () {
    test('a FIT row without a manufacturer is found by the Garmin cloud '
        'lookup', () async {
      await insertComputer(
        id: 'fit',
        model: 'Descent Mk3',
        serialNumber: '3412345678',
      );
      final found = await repository.findByHardwareIdentity(
        manufacturer: 'Garmin',
        model: 'Descent Mk3',
        serialNumber: '3412345678',
      );
      expect(found?.id, 'fit');
    });

    test('a Shearwater file row is found by a hex serial in another case, '
        'and by the decimal a download reports', () async {
      await insertComputer(
        id: 'file',
        model: 'Perdix 2',
        serialNumber: 'a1b2c3d4',
      );
      final byHex = await repository.findByHardwareIdentity(
        manufacturer: 'Shearwater',
        model: 'Perdix 2',
        serialNumber: 'A1B2C3D4',
      );
      final byDecimal = await repository.findByHardwareIdentity(
        manufacturer: 'Shearwater',
        model: 'Perdix 2',
        serialNumber: '2712847316',
      );
      expect(byHex?.id, 'file');
      expect(byDecimal?.id, 'file');
    });

    test('a different non-blank manufacturer still misses', () async {
      await insertComputer(
        id: 'x',
        manufacturer: 'Suunto',
        model: 'Descent Mk3',
        serialNumber: '3412345678',
      );
      final found = await repository.findByHardwareIdentity(
        manufacturer: 'Garmin',
        model: 'Descent Mk3',
        serialNumber: '3412345678',
      );
      expect(found, isNull);
    });
  });
}
