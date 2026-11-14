import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/universal_import/data/services/garmin_activity_marker.dart';
import 'package:submersion/features/universal_import/data/services/garmin_download_history.dart';

import '../../../../helpers/test_database.dart';

/// Issue #4223: a Garmin's download marker lives on its saved computer.
void main() {
  late DiveComputerRepository repository;
  late RepositoryGarminDownloadHistory history;

  const older = GarminActivityMarker(name: '2026-10-01-08-00-00.fit');
  const newer = GarminActivityMarker(name: '2026-11-01-10-22-31.fit');

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveComputerRepository();
    history = RepositoryGarminDownloadHistory(
      repository,
      diverId: () async => null,
    );
  });

  tearDown(tearDownTestDatabase);

  Future<DiveComputer> garmin({String? serial, String? fingerprint}) async {
    final now = DateTime(2026, 11, 1);
    final created = await repository.createComputer(
      DiveComputer(
        id: '',
        name: 'Garmin Descent G2',
        manufacturer: 'Garmin',
        model: 'Descent G2',
        serialNumber: serial,
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (fingerprint != null) {
      await repository.updateLastFingerprint(created.id, fingerprint);
    }
    return created;
  }

  Future<GarminActivityMarker?> savedOn(DiveComputer computer) async =>
      GarminActivityMarker.fromFingerprint(
        (await repository.getComputerById(computer.id))?.lastDiveFingerprint,
      );

  test('finds the marker by computer, or by the watch serial', () async {
    final computer = await garmin(
      serial: '3456789012',
      fingerprint: newer.toFingerprint(),
    );

    expect(await history.markerFor(computerId: computer.id), newer);
    expect(await history.markerFor(serialNumber: '3456789012'), newer);
    expect(await history.markerFor(serialNumber: '999'), isNull);
    expect(await history.markerFor(), isNull);
  });

  test(
    'ignores the chosen computer when another watch is plugged in',
    () async {
      final computer = await garmin(
        serial: '3456789012',
        fingerprint: newer.toFingerprint(),
      );

      expect(
        await history.markerFor(computerId: computer.id, serialNumber: '111'),
        isNull,
      );
    },
  );

  test('reports the serial saved on a computer', () async {
    final withSerial = await garmin(serial: ' 3456789012 ');
    final without = await garmin();

    expect(await history.serialOf(withSerial.id), '3456789012');
    expect(await history.serialOf(without.id), isNull);
    expect(await history.serialOf('no-such-computer'), isNull);
  });

  test('a libdivecomputer fingerprint is not a marker', () async {
    final computer = await garmin(serial: '1', fingerprint: 'a1b2c3d4');

    expect(await history.markerFor(computerId: computer.id), isNull);
  });

  test('saves on the computer found by a FIT serial', () async {
    final computer = await garmin(serial: '3456789012');

    final saved = await history.save(
      newer,
      watchSerial: 'mtp-serial-that-differs',
      fitSerials: ['3456789012'],
    );

    expect(saved, isTrue);
    expect(await savedOn(computer), newer);
  });

  test('never moves the marker back', () async {
    final computer = await garmin(
      serial: '1',
      fingerprint: newer.toFingerprint(),
    );

    await history.save(older, computerId: computer.id);

    expect(await savedOn(computer), newer);
  });

  test('overlapping saves never put an older marker back', () async {
    // Two downloads can finish close together. Each save reads the stored
    // marker and writes the later of the two, so interleaved, the one
    // holding the older marker could write last.
    final computer = await garmin(serial: '1');

    await Future.wait([
      history.save(newer, computerId: computer.id),
      history.save(older, computerId: computer.id),
    ]);

    expect(await savedOn(computer), newer);
  });

  test('never touches a computer that is not a Garmin', () async {
    // The computer comes from a link. Handed some other computer's id, a
    // Garmin download must not replace that computer's own download cursor
    // with a Garmin marker, nor read one from it.
    final now = DateTime(2026, 11, 1);
    final shearwater = await repository.createComputer(
      DiveComputer(
        id: '',
        name: 'Shearwater Perdix',
        manufacturer: 'Shearwater',
        model: 'Perdix',
        serialNumber: '7',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.updateLastFingerprint(shearwater.id, 'a1b2c3d4');

    expect(await history.save(newer, computerId: shearwater.id), isFalse);
    expect(await history.markerFor(computerId: shearwater.id), isNull);
    expect(
      (await repository.getComputerById(shearwater.id))?.lastDiveFingerprint,
      'a1b2c3d4',
    );
  });

  test('takes a Garmin whatever the casing of its brand', () async {
    final now = DateTime(2026, 11, 1);
    final computer = await repository.createComputer(
      DiveComputer(
        id: '',
        name: 'Descent',
        manufacturer: ' GARMIN ',
        model: 'Descent Mk2',
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(await history.save(newer, computerId: computer.id), isTrue);
    expect(await savedOn(computer), newer);
  });

  test('reports when no computer matches', () async {
    expect(await history.save(newer, watchSerial: '42'), isFalse);
  });
}
