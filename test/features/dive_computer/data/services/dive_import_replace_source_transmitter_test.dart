import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart'
    as domain;
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

import '../../../../helpers/test_database.dart';

/// Issue #4388, end to end: a dive whose cylinder came in without its
/// transmitter is downloaded again with Replace source. The cylinder takes
/// the download's serial and the setup the diver gave that transmitter.
void main() {
  late AppDatabase db;
  final computer = domain.DiveComputer.create(id: 'perdix', name: 'Perdix');

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'Me', 1, 1)",
    );
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'perdix',
            name: 'Perdix',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  });
  tearDown(() => tearDownTestDatabase());

  DownloadedDive dive({String? serial}) => DownloadedDive(
    fingerprint: 'fp1',
    startTime: DateTime(2026, 10, 1, 9),
    durationSeconds: 1800,
    maxDepth: 18.0,
    profile: const [],
    tanks: [
      DownloadedTank(
        index: 0,
        o2Percent: 21,
        startPressure: 206.8,
        endPressure: 80,
        transmitterSerial: serial,
      ),
    ],
  );

  Future<void> download(DownloadedDive d, ImportMode mode) => DiveImportService(
    repository: DiveComputerRepository(),
    diveRepository: DiveRepository(),
  ).importDives(dives: [d], computer: computer, diverId: 'me', mode: mode);

  test('Replace source gives a set-up transmitter to the cylinder that '
      'lacked it', () async {
    await download(dive(), ImportMode.newOnly);
    await TransmitterRepository().create(
      Transmitter(
        id: 'tx',
        diverId: 'me',
        transmitterSerial: '76287',
        label: 'T2',
        role: TankRole.sidemountLeft,
        volumeL: 10,
        createdAt: DateTime.utc(2026, 11, 1),
        updatedAt: DateTime.utc(2026, 11, 1),
      ),
    );

    await download(dive(serial: '76287'), ImportMode.replaceSource);

    final tank = (await db.select(db.diveTanks).get()).single;
    expect(tank.transmitterSerial, '76287');
    expect(tank.tankRole, 'sidemountLeft');
    expect(tank.volume, 10);
    expect(tank.tankName, 'T2');
  });

  test('Replace source gives a serial the diver has never seen its '
      'Transmitter item (#3676)', () async {
    await download(dive(), ImportMode.newOnly);

    await download(dive(serial: '76287'), ImportMode.replaceSource);

    final rows = await db.select(db.transmitters).get();
    expect(rows.single.transmitterSerial, '76287');
    expect(rows.single.isConfigured, isFalse);
  });
}
