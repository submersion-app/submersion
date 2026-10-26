import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_auto_registrar.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_setup_target.dart';

import '../../../../helpers/test_database.dart';

/// The unknown-transmitter repair opens the transmitter's Equipment page
/// (issue #3676), registering a serial no row knows first.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive1',
            diverId: const Value('d1'),
            diveDateTime: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'tank1',
            diveId: 'dive1',
            transmitterSerial: const Value('7C0B19'),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  TransmitterAutoRegistrar registrar() =>
      TransmitterAutoRegistrar(nameFor: (s) => 'Transmitter $s');

  test('the repair opens the transmitter\'s equipment page', () async {
    await registrar().registerNewSerials(['7C0B19'], diverId: 'd1');

    final itemId = await transmitterItemForSetup(
      serial: '7C0B19',
      diveId: 'dive1',
      registrar: registrar(),
    );

    expect(itemId, transmitterGearSeedId('d1', '7C0B19'));
  });

  test('the repair registers a serial with no row before opening it', () async {
    final itemId = await transmitterItemForSetup(
      serial: '7C0B19',
      diveId: 'dive1',
      registrar: registrar(),
    );

    expect(itemId, transmitterGearSeedId('d1', '7C0B19'));
    expect(await TransmitterRepository().getForDiver('d1'), hasLength(1));
  });

  test('an unknown dive yields no target', () async {
    expect(
      await transmitterItemForSetup(
        serial: '9D0001',
        diveId: 'missing',
        registrar: registrar(),
      ),
      isNull,
    );
  });
}
