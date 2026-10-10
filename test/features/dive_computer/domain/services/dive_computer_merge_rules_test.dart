import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/services/dive_computer_merge_rules.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

DiveComputer _computer({
  required String id,
  String name = 'Petrel 3',
  String? diverId = 'diver-1',
  String? manufacturer = 'Shearwater',
  String? model = 'Petrel 3',
  String? serialNumber = '3101949313',
  String? firmwareVersion,
  String? connectionType,
  String? bluetoothAddress,
  DateTime? lastDownload,
  String? lastDiveFingerprint,
  int diveCount = 0,
  bool isFavorite = false,
  String notes = '',
  String? equipmentId,
}) {
  final now = DateTime(2026, 1, 1);
  return DiveComputer(
    id: id,
    name: name,
    diverId: diverId,
    manufacturer: manufacturer,
    model: model,
    serialNumber: serialNumber,
    firmwareVersion: firmwareVersion,
    connectionType: connectionType,
    bluetoothAddress: bluetoothAddress,
    lastDownload: lastDownload,
    lastDiveFingerprint: lastDiveFingerprint,
    diveCount: diveCount,
    isFavorite: isFavorite,
    notes: notes,
    equipmentId: equipmentId,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('duplicateCandidatesFor', () {
    test('returns other records that share serial, manufacturer and model', () {
      final target = _computer(id: 'a');
      final twin = _computer(id: 'b', name: 'ssss');
      final other = _computer(id: 'c', serialNumber: '999');

      final result = duplicateCandidatesFor(target, [target, twin, other]);

      expect(result.map((c) => c.id), ['b']);
    });

    test('matches case-insensitively and ignores surrounding whitespace', () {
      final target = _computer(id: 'a');
      final twin = _computer(
        id: 'b',
        manufacturer: ' shearwater ',
        model: 'PETREL 3',
        serialNumber: ' 3101949313 ',
      );

      expect(duplicateCandidatesFor(target, [twin]).map((c) => c.id), ['b']);
    });

    test(
      'treats a blank manufacturer or model on either side as compatible',
      () {
        final target = _computer(id: 'a', manufacturer: null);
        final twin = _computer(id: 'b', model: '');

        expect(duplicateCandidatesFor(target, [twin]).map((c) => c.id), ['b']);
      },
    );

    test('never matches on a blank serial number', () {
      final target = _computer(id: 'a', serialNumber: '');
      final twin = _computer(id: 'b', serialNumber: null);

      expect(duplicateCandidatesFor(target, [twin]), isEmpty);
    });

    test('rejects a different model with the same serial', () {
      final target = _computer(id: 'a');
      final other = _computer(id: 'b', model: 'Perdix 2');

      expect(duplicateCandidatesFor(target, [other]), isEmpty);
    });

    test('rejects a record owned by another diver', () {
      final target = _computer(id: 'a');
      final other = _computer(id: 'b', diverId: 'diver-2');

      expect(duplicateCandidatesFor(target, [other]), isEmpty);
    });
  });

  group('serialNumbersConflict', () {
    test('is false when every serial agrees or is blank', () {
      final records = [
        _computer(id: 'a'),
        _computer(id: 'b', serialNumber: ' 3101949313'),
        _computer(id: 'c', serialNumber: null),
      ];

      expect(serialNumbersConflict(records), isFalse);
    });

    test('is true when two records carry different non-blank serials', () {
      final records = [
        _computer(id: 'a'),
        _computer(id: 'b', serialNumber: '7'),
      ];

      expect(serialNumbersConflict(records), isTrue);
    });
  });

  group('defaultSurvivor', () {
    test('prefers the favorite record', () {
      final records = [
        _computer(id: 'a', diveCount: 50),
        _computer(id: 'b', isFavorite: true),
      ];

      expect(defaultSurvivor(records).id, 'b');
    });

    test('then prefers the record with the most dives', () {
      final records = [
        _computer(id: 'a', diveCount: 2),
        _computer(id: 'b', diveCount: 9),
      ];

      expect(defaultSurvivor(records).id, 'b');
    });

    test('then prefers the most recently downloaded record', () {
      final records = [
        _computer(id: 'a', lastDownload: DateTime(2026, 1, 1)),
        _computer(id: 'b', lastDownload: DateTime(2026, 3, 1)),
      ];

      expect(defaultSurvivor(records).id, 'b');
    });

    test('falls back to the first record', () {
      final records = [_computer(id: 'a'), _computer(id: 'b')];

      expect(defaultSurvivor(records).id, 'a');
    });
  });

  group('mergedDiveComputer', () {
    test('keeps the survivor identity and fills its blank fields', () {
      final survivor = _computer(
        id: 'a',
        name: 'Petrel 3',
        manufacturer: null,
        model: '',
        firmwareVersion: null,
        connectionType: null,
        bluetoothAddress: null,
        equipmentId: null,
      );
      final duplicate = _computer(
        id: 'b',
        name: 'ssss',
        firmwareVersion: '103',
        connectionType: 'bluetooth',
        bluetoothAddress: 'AAAA',
        equipmentId: 'gear-b',
      );

      final merged = mergedDiveComputer(survivor, [duplicate]);

      expect(merged.id, 'a');
      expect(merged.name, 'Petrel 3');
      expect(merged.manufacturer, 'Shearwater');
      expect(merged.model, 'Petrel 3');
      expect(merged.firmwareVersion, '103');
      expect(merged.connectionType, 'bluetooth');
      expect(merged.bluetoothAddress, 'AAAA');
      expect(merged.equipmentId, 'gear-b');
    });

    test('does not overwrite survivor fields that are already set', () {
      final survivor = _computer(
        id: 'a',
        firmwareVersion: '101',
        bluetoothAddress: 'SURVIVOR',
        equipmentId: 'gear-a',
      );
      final duplicate = _computer(
        id: 'b',
        firmwareVersion: '103',
        bluetoothAddress: 'DUP',
        equipmentId: 'gear-b',
      );

      final merged = mergedDiveComputer(survivor, [duplicate]);

      expect(merged.firmwareVersion, '101');
      expect(merged.bluetoothAddress, 'SURVIVOR');
      expect(merged.equipmentId, 'gear-a');
    });

    test(
      'sums dive counts and keeps favorite when any record was favorite',
      () {
        final survivor = _computer(id: 'a', diveCount: 21);
        final dupes = [
          _computer(id: 'b', diveCount: 2, isFavorite: true),
          _computer(id: 'c', diveCount: 3),
        ];

        final merged = mergedDiveComputer(survivor, dupes);

        expect(merged.diveCount, 26);
        expect(merged.isFavorite, isTrue);
      },
    );

    test('keeps the newest download timestamp with its fingerprint', () {
      final survivor = _computer(
        id: 'a',
        lastDownload: DateTime(2026, 1, 1),
        lastDiveFingerprint: 'old',
      );
      final duplicate = _computer(
        id: 'b',
        lastDownload: DateTime(2026, 2, 1),
        lastDiveFingerprint: 'new',
      );

      final merged = mergedDiveComputer(survivor, [duplicate]);

      expect(merged.lastDownload, DateTime(2026, 2, 1));
      expect(merged.lastDiveFingerprint, 'new');
    });

    test(
      'keeps the survivor fingerprint when no duplicate downloaded later',
      () {
        final survivor = _computer(
          id: 'a',
          lastDownload: DateTime(2026, 2, 1),
          lastDiveFingerprint: 'mine',
        );
        final duplicate = _computer(id: 'b', lastDiveFingerprint: 'theirs');

        final merged = mergedDiveComputer(survivor, [duplicate]);

        expect(merged.lastDownload, DateTime(2026, 2, 1));
        expect(merged.lastDiveFingerprint, 'mine');
      },
    );

    test(
      'adopts a duplicate fingerprint when the survivor has none at all',
      () {
        final survivor = _computer(id: 'a');
        final duplicate = _computer(id: 'b', lastDiveFingerprint: 'theirs');

        expect(
          mergedDiveComputer(survivor, [duplicate]).lastDiveFingerprint,
          'theirs',
        );
      },
    );

    test(
      'takes the newest recorded fingerprint when the newest download has none',
      () {
        // lastDownload and lastDiveFingerprint are written separately, so the
        // most recently downloaded record can hold no cursor at all. Falling
        // back to the survivor's would resume the next incremental download
        // from January and re-fetch everything the February record already had.
        final survivor = _computer(
          id: 'a',
          lastDownload: DateTime(2026, 1, 1),
          lastDiveFingerprint: 'january',
        );
        final duplicates = [
          _computer(
            id: 'b',
            lastDownload: DateTime(2026, 2, 1),
            lastDiveFingerprint: 'february',
          ),
          _computer(id: 'c', lastDownload: DateTime(2026, 3, 1)),
        ];

        final merged = mergedDiveComputer(survivor, duplicates);

        expect(merged.lastDownload, DateTime(2026, 3, 1));
        expect(merged.lastDiveFingerprint, 'february');
      },
    );

    test('ignores a blank fingerprint on the most recent download', () {
      final survivor = _computer(
        id: 'a',
        lastDownload: DateTime(2026, 1, 1),
        lastDiveFingerprint: 'january',
      );
      final duplicate = _computer(
        id: 'b',
        lastDownload: DateTime(2026, 2, 1),
        lastDiveFingerprint: '   ',
      );

      expect(
        mergedDiveComputer(survivor, [duplicate]).lastDiveFingerprint,
        'january',
      );
    });

    test('trims the descriptive fields it adopts', () {
      // A file import can register padded values. The survivor should not
      // inherit the padding along with the value, and the identity rules
      // compare through normalizeComputerIdentityPart, so the padded serial
      // still matched as a duplicate before reaching here.
      final survivor = _computer(
        id: 'a',
        manufacturer: '  ',
        model: '',
        serialNumber: null,
      );
      final duplicate = _computer(
        id: 'b',
        manufacturer: '  Shearwater ',
        model: ' Petrel 3',
        serialNumber: ' 3101949313 ',
        firmwareVersion: ' 93 ',
      );

      final merged = mergedDiveComputer(survivor, [duplicate]);

      expect(merged.manufacturer, 'Shearwater');
      expect(merged.model, 'Petrel 3');
      expect(merged.serialNumber, '3101949313');
      expect(merged.firmwareVersion, '93');
    });

    test('keeps the adopted gear twin id verbatim', () {
      // equipmentId is a foreign key into equipment.id, so it has to match
      // the stored row exactly rather than be normalised on the way through.
      final survivor = _computer(id: 'a', equipmentId: null);
      final duplicate = _computer(id: 'b', equipmentId: ' gear-b ');

      expect(mergedDiveComputer(survivor, [duplicate]).equipmentId, ' gear-b ');
    });

    test('appends distinct non-blank notes from duplicates', () {
      final survivor = _computer(id: 'a', notes: 'Primary');
      final dupes = [
        _computer(id: 'b', notes: 'Primary'),
        _computer(id: 'c', notes: '  '),
        _computer(id: 'd', notes: 'Bought 2024'),
      ];

      expect(
        mergedDiveComputer(survivor, dupes).notes,
        'Primary\n\nBought 2024',
      );
    });
  });

  group('issue #3106 duplicate cases', () {
    test('Shearwater file (hex, no manufacturer) and BLE (decimal)', () {
      final file = _computer(
        id: 'file',
        manufacturer: null,
        model: 'Perdix 2',
        serialNumber: 'A1B2C3D4',
      );
      final ble = _computer(
        id: 'ble',
        model: 'Perdix 2',
        serialNumber: '2712847316',
      );
      expect(duplicateCandidatesFor(ble, [file, ble]).map((c) => c.id), [
        'file',
      ]);
      expect(duplicateCandidatesFor(file, [file, ble]).map((c) => c.id), [
        'ble',
      ]);
      expect(serialNumbersConflict([file, ble]), isFalse);
    });

    test('Garmin FIT (no manufacturer) and Garmin Connect', () {
      final fit = _computer(
        id: 'fit',
        manufacturer: null,
        model: 'Descent Mk3',
        serialNumber: '3412345678',
      );
      final cloud = _computer(
        id: 'cloud',
        manufacturer: 'Garmin',
        model: 'Descent Mk3',
        serialNumber: '3412345678',
      );
      expect(duplicateCandidatesFor(cloud, [fit, cloud]).map((c) => c.id), [
        'fit',
      ]);
    });

    test('a brand folded into the model still agrees', () {
      final file = _computer(
        id: 'file',
        manufacturer: null,
        model: 'Shearwater Teric',
        serialNumber: '0A0B0C0D',
      );
      final ble = _computer(
        id: 'ble',
        model: 'Teric',
        serialNumber: '168496141',
      );
      expect(duplicateCandidatesFor(ble, [file, ble]).map((c) => c.id), [
        'file',
      ]);
    });

    test('two different Shearwater serials still conflict', () {
      final a = _computer(id: 'a', model: 'Perdix 2', serialNumber: 'A1B2C3D4');
      final b = _computer(
        id: 'b',
        model: 'Perdix 2',
        serialNumber: '2712847317',
      );
      expect(serialNumbersConflict([a, b]), isTrue);
    });
  });
}
