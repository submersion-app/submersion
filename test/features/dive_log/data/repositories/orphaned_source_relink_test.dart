import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart'
    as domain;

import '../../../../helpers/test_database.dart';
import '../../../../helpers/unique_ids.dart';

/// Downloaded data sources that lost their computer link when the computer
/// was deleted get it back once that hardware is set up again (issue #4465),
/// including the ones saved before the computer knew its serial.
void main() {
  late DiveComputerRepository repository;
  late ProfileSeriesRepository profileSeries;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerRepository();
    profileSeries = ProfileSeriesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<String> insertComputer({
    required String id,
    String? manufacturer = 'Shearwater',
    String? model = 'Perdix',
    String? serialNumber,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value('$model $id'),
            manufacturer: Value(manufacturer),
            model: Value(model),
            serialNumber: Value(serialNumber),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  Future<String> insertDive({String? computerId}) async {
    final diveId = uniqueTestId('dive');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(now),
            computerId: Value(computerId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return diveId;
  }

  /// A downloaded source as `_downloadSourceCompanion` writes it: the model
  /// snapshot, the serial the computer held at the time, and the descriptor
  /// libdivecomputer reported.
  Future<String> insertDownloadedSource({
    required String diveId,
    String? computerId,
    bool isPrimary = true,
    String? computerModel = 'Shearwater Perdix',
    String? computerSerial,
    String? vendor = 'Shearwater',
    String? product = 'Perdix',
  }) async {
    final id = uniqueTestId('ds');
    final now = DateTime.now();
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            computerModel: Value(computerModel),
            computerSerial: Value(computerSerial),
            sourceFormat: const Value('dive_computer'),
            descriptorVendor: Value(vendor),
            descriptorProduct: Value(product),
            importedAt: Value(now),
            createdAt: Value(now),
          ),
        );
    return id;
  }

  domain.DiveComputer newComputer({
    String? serialNumber = 'SN-12345',
    String model = 'Perdix',
  }) {
    final now = DateTime.now();
    return domain.DiveComputer(
      id: '',
      name: 'My $model',
      manufacturer: 'Shearwater',
      model: model,
      serialNumber: serialNumber,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<DiveDataSourcesData> sourceRow(String id) => (db.select(
    db.diveDataSources,
  )..where((t) => t.id.equals(id))).getSingle();

  Future<Dive> diveRow(String id) =>
      (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

  Future<bool> isPending(String entityType, String recordId) async =>
      (await (db.select(db.syncRecords)..where(
                (r) =>
                    r.entityType.equals(entityType) &
                    r.recordId.equals(recordId),
              ))
              .get())
          .isNotEmpty;

  group('deleteComputer', () {
    test('copies the computer serial onto a source that lacked it', () async {
      final computerId = await insertComputer(
        id: 'old',
        serialNumber: 'SN-12345',
      );
      final diveId = await insertDive(computerId: computerId);
      final sourceId = await insertDownloadedSource(
        diveId: diveId,
        computerId: computerId,
      );

      await repository.deleteComputer(computerId);

      final source = await sourceRow(sourceId);
      expect(source.computerId, isNull);
      expect(source.computerSerial, 'SN-12345');
      // The dive's own copy is left alone: the delete does not stage the
      // dive, so filling it here would never reach the diver's other
      // devices.
      expect((await diveRow(diveId)).diveComputerSerial, isNull);
    });
  });

  group('createComputer', () {
    test('relinks a source saved before the old computer had a serial, '
        'once that serial was given before the delete', () async {
      final oldId = await insertComputer(id: 'old');
      final diveId = await insertDive(computerId: oldId);
      final sourceId = await insertDownloadedSource(
        diveId: diveId,
        computerId: oldId,
      );
      // The serial arrives after the download, by direct write so that no
      // heal of the save path copies it first.
      await db.customStatement(
        "UPDATE dive_computers SET serial_number = 'SN-12345' WHERE id = ?",
        [oldId],
      );
      await repository.deleteComputer(oldId);
      // A second Perdix rules out the serial-less fallback: only the serial
      // the delete copied onto the source can link it.
      await insertComputer(id: 'other', serialNumber: 'XYZ999');

      final created = await repository.createComputer(newComputer());

      expect((await sourceRow(sourceId)).computerId, created.id);
      expect((await diveRow(diveId)).computerId, created.id);
    });

    test('relinks a serial-less source to the only computer of its model, '
        'with its dive and profile', () async {
      // The case of the issue: the old entry never had a serial, so nothing
      // but the model identifies the source.
      final oldId = await insertComputer(id: 'old');
      final diveId = await insertDive(computerId: oldId);
      final sourceId = await insertDownloadedSource(
        diveId: diveId,
        computerId: oldId,
      );
      final seriesId = await profileSeries.insertSeries(
        diveId: diveId,
        computerId: oldId,
        samples: const [ProfileSample(timestamp: 0, depth: 10.0)],
        now: 1000,
      );
      await repository.deleteComputer(oldId);
      await db.customStatement('DELETE FROM sync_records');

      final created = await repository.createComputer(newComputer());

      final source = await sourceRow(sourceId);
      expect(source.computerId, created.id);
      // Takes the new computer's serial, so a later delete keeps it.
      expect(source.computerSerial, 'SN-12345');
      expect((await diveRow(diveId)).computerId, created.id);
      final series = (await profileSeries.getRowsForDives([
        diveId,
      ])).firstWhere((r) => r.id == seriesId);
      expect(series.computerId, created.id);
      expect(await isPending('diveDataSources', sourceId), isTrue);
      expect(await isPending('dives', diveId), isTrue);
    });

    test('gives the source\'s tanks and tank pressure series their computer '
        'back', () async {
      // The delete clears both links but leaves each its source_id, which
      // says exactly whose they were.
      final oldId = await insertComputer(id: 'old', serialNumber: 'SN-12345');
      final diveId = await insertDive(computerId: oldId);
      final sourceId = await insertDownloadedSource(
        diveId: diveId,
        computerId: oldId,
        computerSerial: 'SN-12345',
      );
      await db.customStatement(
        'INSERT INTO dive_tanks (id, dive_id, computer_id, source_id) '
        "VALUES ('tank-1', ?, ?, ?)",
        [diveId, oldId, sourceId],
      );
      // A hand-added tank on the same dive: no source, so it stays the
      // primary source's.
      await db.customStatement(
        "INSERT INTO dive_tanks (id, dive_id) VALUES ('tank-2', ?)",
        [diveId],
      );
      await db.customStatement(
        'INSERT INTO tank_pressure_series (id, dive_id, tank_id, source_id, '
        'computer_id, sample_count, start_timestamp, end_timestamp, '
        'codec_version, samples, created_at, updated_at) '
        "VALUES ('tp-1', ?, 'tank-1', ?, ?, 0, 0, 0, 1, x'', 1, 1)",
        [diveId, sourceId, oldId],
      );
      await repository.deleteComputer(oldId);
      await db.customStatement('DELETE FROM sync_records');

      final created = await repository.createComputer(newComputer());

      Future<String?> computerOf(String table, String id) async =>
          (await db
                  .customSelect(
                    'SELECT computer_id FROM $table WHERE id = ?',
                    variables: [Variable<String>(id)],
                  )
                  .getSingle())
              .read<String?>('computer_id');
      expect(await computerOf('dive_tanks', 'tank-1'), created.id);
      expect(await computerOf('dive_tanks', 'tank-2'), isNull);
      expect(await computerOf('tank_pressure_series', 'tp-1'), created.id);
      expect(await isPending('diveTanks', 'tank-1'), isTrue);
      expect(await isPending('diveTanks', 'tank-2'), isFalse);
    });

    test('does not relink a serial-less source when another computer of its '
        'model exists', () async {
      await insertComputer(id: 'other-teric', serialNumber: 'XYZ999');
      final diveId = await insertDive();
      final sourceId = await insertDownloadedSource(diveId: diveId);

      await repository.createComputer(newComputer());

      expect((await sourceRow(sourceId)).computerId, isNull);
      expect((await diveRow(diveId)).computerId, isNull);
    });

    test(
      'relinks a decimal Shearwater serial snapshot to the hex computer',
      () async {
        final diveId = await insertDive();
        // 0x8629AC48 is 2250878024 in decimal.
        final sourceId = await insertDownloadedSource(
          diveId: diveId,
          computerModel: 'Shearwater Teric',
          computerSerial: '2250878024',
          product: 'Teric',
        );

        final created = await repository.createComputer(
          newComputer(model: 'Teric', serialNumber: '8629AC48'),
        );

        expect((await sourceRow(sourceId)).computerId, created.id);
      },
    );
  });

  group('when the relink fails', () {
    test('creating the computer still succeeds, and the relink leaves '
        'nothing half done', () async {
      final diveId = await insertDive();
      final sourceId = await insertDownloadedSource(
        diveId: diveId,
        computerSerial: 'SN-12345',
      );
      // Fails the relink's own write: linking a source.
      await db.customStatement(
        'CREATE TRIGGER fail_relink BEFORE UPDATE OF computer_id '
        'ON dive_data_sources '
        "BEGIN SELECT RAISE(ABORT, 'relink failed'); END",
      );

      final created = await repository.createComputer(newComputer());

      expect(await repository.getComputerById(created.id), isNotNull);
      expect((await sourceRow(sourceId)).computerId, isNull);
      expect((await diveRow(diveId)).computerId, isNull);
    });

    test('a failed serial copy keeps the links', () async {
      await insertComputer(id: 'perdix', serialNumber: 'SN-12345');
      final diveId = await insertDive();
      final sourceId = await insertDownloadedSource(diveId: diveId);
      // Fails only the best-effort step after linking: filling the empty
      // serial copy.
      await db.customStatement(
        'CREATE TRIGGER fail_serial_copy BEFORE UPDATE OF computer_serial '
        'ON dive_data_sources '
        "BEGIN SELECT RAISE(ABORT, 'serial copy failed'); END",
      );

      expect(await repository.relinkOrphanedSources(), 1);

      final source = await sourceRow(sourceId);
      expect(source.computerId, 'perdix');
      expect(source.computerSerial, isNull);
    });
  });

  group('updateComputer', () {
    test('relinks orphaned sources once the computer gains a serial', () async {
      final diveId = await insertDive();
      final sourceId = await insertDownloadedSource(
        diveId: diveId,
        computerSerial: 'SN-12345',
      );
      await insertComputer(id: 'live');
      // A second Perdix keeps the serial-less fallback out of this test.
      await insertComputer(id: 'other', serialNumber: 'XYZ999');
      final live = (await repository.getComputerById('live'))!;

      await repository.updateComputer(live.copyWith(serialNumber: 'SN-12345'));

      expect((await sourceRow(sourceId)).computerId, 'live');
      expect((await diveRow(diveId)).computerId, 'live');
    });

    test(
      'does not relink on a save that leaves the identity as it was',
      () async {
        // A rename, or the save after every download: nothing a source is
        // matched on changed, so the computer's routine saves never guess.
        final diveId = await insertDive();
        final sourceId = await insertDownloadedSource(diveId: diveId);
        await insertComputer(id: 'live', serialNumber: 'SN-12345');
        final live = (await repository.getComputerById('live'))!;

        await repository.updateComputer(live.copyWith(name: 'Renamed'));

        expect((await sourceRow(sourceId)).computerId, isNull);
      },
    );
  });

  group('relinkOrphanedSources', () {
    test('relinks across the library and reports how many it linked', () async {
      await insertComputer(id: 'perdix', serialNumber: 'SN-12345');
      await insertComputer(id: 'teric-a', model: 'Teric', serialNumber: 'A1');
      await insertComputer(id: 'teric-b', model: 'Teric', serialNumber: 'B2');
      final perdixDive = await insertDive();
      final perdixSource = await insertDownloadedSource(diveId: perdixDive);
      final tericDive = await insertDive();
      final tericSource = await insertDownloadedSource(
        diveId: tericDive,
        computerModel: 'Shearwater Teric',
        computerSerial: 'B2',
        product: 'Teric',
      );
      final ambiguousDive = await insertDive();
      final ambiguousSource = await insertDownloadedSource(
        diveId: ambiguousDive,
        computerModel: 'Shearwater Teric',
        product: 'Teric',
      );

      final linked = await repository.relinkOrphanedSources();

      expect(linked, 2);
      expect((await sourceRow(perdixSource)).computerId, 'perdix');
      expect((await sourceRow(tericSource)).computerId, 'teric-b');
      expect((await sourceRow(ambiguousSource)).computerId, isNull);
      expect((await diveRow(perdixDive)).computerId, 'perdix');
      expect((await diveRow(ambiguousDive)).computerId, isNull);
    });

    test('leaves the profile of a dive read by two computers unattributed, '
        'whichever is linked first', () async {
      // Profiles carry no serial of their own, so with two computer sources
      // on the dive neither may claim them, however the run is ordered.
      await insertComputer(id: 'a-perdix', serialNumber: 'SN-12345');
      await insertComputer(id: 'b-teric', model: 'Teric', serialNumber: 'T1');
      final diveId = await insertDive();
      final secondary = await insertDownloadedSource(
        diveId: diveId,
        isPrimary: false,
        computerSerial: 'SN-12345',
      );
      final primary = await insertDownloadedSource(
        diveId: diveId,
        computerModel: 'Shearwater Teric',
        computerSerial: 'T1',
        product: 'Teric',
      );
      final seriesId = await profileSeries.insertSeries(
        diveId: diveId,
        samples: const [ProfileSample(timestamp: 0, depth: 10.0)],
        now: 1000,
      );

      expect(await repository.relinkOrphanedSources(), 2);

      expect((await sourceRow(secondary)).computerId, 'a-perdix');
      expect((await sourceRow(primary)).computerId, 'b-teric');
      expect((await diveRow(diveId)).computerId, 'b-teric');
      final series = (await profileSeries.getRowsForDives([
        diveId,
      ])).firstWhere((r) => r.id == seriesId);
      expect(series.computerId, isNull);
    });

    test('gives the series of a dive read by two computers the computer of '
        'the source each names (issue #4529)', () async {
      // A series that names its source says exactly whose it is, as a tank
      // does, so the second computer on the dive does not make it ambiguous.
      await insertComputer(id: 'a-perdix', serialNumber: 'SN-12345');
      await insertComputer(id: 'b-teric', model: 'Teric', serialNumber: 'T1');
      final diveId = await insertDive();
      final perdix = await insertDownloadedSource(
        diveId: diveId,
        computerSerial: 'SN-12345',
      );
      final teric = await insertDownloadedSource(
        diveId: diveId,
        isPrimary: false,
        computerModel: 'Shearwater Teric',
        computerSerial: 'T1',
        product: 'Teric',
      );
      Future<String> series(String sourceId, {required bool isPrimary}) =>
          profileSeries.insertSeries(
            diveId: diveId,
            sourceId: sourceId,
            isPrimary: isPrimary,
            samples: const [ProfileSample(timestamp: 0, depth: 10.0)],
            now: 1000,
          );
      final perdixSeries = await series(perdix, isPrimary: true);
      final tericSeries = await series(teric, isPrimary: false);

      expect(await repository.relinkOrphanedSources(), 2);

      final rows = await profileSeries.getRowsForDives([diveId]);
      String? computerOf(String id) =>
          rows.firstWhere((r) => r.id == id).computerId;
      expect(computerOf(perdixSeries), 'a-perdix');
      expect(computerOf(tericSeries), 'b-teric');
    });

    test(
      'leaves the edit of a source on a two-computer dive unattributed',
      () async {
        // The edit names its source and has no computer, the shape a delete
        // leaves on the recording too. Stamping it would hand it to the next
        // re-parse, which replaces what its source owns.
        await insertComputer(id: 'a-perdix', serialNumber: 'SN-12345');
        await insertComputer(id: 'b-teric', model: 'Teric', serialNumber: 'T1');
        final diveId = await insertDive();
        final perdix = await insertDownloadedSource(
          diveId: diveId,
          computerSerial: 'SN-12345',
        );
        await insertDownloadedSource(
          diveId: diveId,
          isPrimary: false,
          computerModel: 'Shearwater Teric',
          computerSerial: 'T1',
          product: 'Teric',
        );
        const samples = [ProfileSample(timestamp: 0, depth: 10.0)];
        final unmarkedEdit = await profileSeries.insertSeries(
          diveId: diveId,
          sourceId: perdix,
          isPrimary: true,
          samples: samples,
          now: 1000,
        );
        final generation = await profileSeries.insertSeries(
          diveId: diveId,
          sourceId: perdix,
          isPrimary: false,
          samples: samples,
          now: 500,
        );
        final markedEdit = await profileSeries.insertSeries(
          diveId: diveId,
          sourceId: perdix,
          isPrimary: false,
          isEdit: true,
          samples: samples,
          now: 400,
        );

        expect(await repository.relinkOrphanedSources(), 2);

        final rows = await profileSeries.getRowsForDives([diveId]);
        String? computerOf(String id) =>
            rows.firstWhere((r) => r.id == id).computerId;
        expect(computerOf(unmarkedEdit), isNull);
        expect(computerOf(markedEdit), isNull);
        expect(computerOf(generation), 'a-perdix');
      },
    );

    test('a second run links nothing', () async {
      await insertComputer(id: 'perdix', serialNumber: 'SN-12345');
      await insertDownloadedSource(diveId: await insertDive());

      expect(await repository.relinkOrphanedSources(), 1);
      expect(await repository.relinkOrphanedSources(), 0);
    });

    test('leaves a dive attributed to another computer as it is', () async {
      await insertComputer(id: 'perdix', serialNumber: 'SN-12345');
      final otherId = await insertComputer(
        id: 'teric',
        model: 'Teric',
        serialNumber: 'T1',
      );
      final diveId = await insertDive(computerId: otherId);
      final sourceId = await insertDownloadedSource(diveId: diveId);

      await repository.relinkOrphanedSources();

      expect((await sourceRow(sourceId)).computerId, 'perdix');
      expect((await diveRow(diveId)).computerId, otherId);
    });
  });
}
