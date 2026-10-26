import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';

import '../../../../helpers/test_database.dart';

/// Tissue state a dive computer reports for the whole dive (Suunto SML
/// `StartTissue` / `EndTissue`) travels with the download and lands on
/// `dives.computer_tissue_json`. The dive's primary reading owns it: a
/// re-import of that reading writes its own value, none included, so a
/// snapshot a parser no longer emits does not outlive it (issue #2556). A
/// download that takes the primary role from a UDDF source replaces the
/// snapshot only with one of its own. A second computer matched onto the dive
/// never replaces one; it only fills a dive that has none.
void main() {
  late DiveComputerRepository repository;
  late AppDatabase db;

  const computerId = 'suunto-eon-core';
  const secondComputerId = 'suunto-d5';
  const points = [
    ProfilePointData(timestamp: 0, depth: 1.0),
    ProfilePointData(timestamp: 600, depth: 18.0),
    ProfilePointData(timestamp: 1200, depth: 6.0),
  ];
  const snapshot = ComputerTissueSnapshot(
    start: ComputerTissueState(n2Bar: [0.79, 0.79, 0.79]),
    end: ComputerTissueState(n2Bar: [0.89665, 0.97105, 1.16432]),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerRepository();

    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: computerId,
            name: 'Suunto EON Core',
            manufacturer: const Value('Suunto'),
            model: const Value('EON Core'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: secondComputerId,
            name: 'Suunto D5',
            manufacturer: const Value('Suunto'),
            model: const Value('D5'),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<ComputerTissueSnapshot?> storedTissueFor(String diveId) async {
    final row = await (db.select(
      db.dives,
    )..where((t) => t.id.equals(diveId))).getSingle();
    return ComputerTissueSnapshot.tryDecode(row.computerTissueJson);
  }

  Future<String> importWith(
    ComputerTissueSnapshot? computerTissue, {
    bool forceNew = false,
    bool isPrimary = false,
    String fromComputer = computerId,
  }) {
    return repository.importProfile(
      computerId: fromComputer,
      isPrimary: isPrimary,
      profileStartTime: DateTime(2026, 5, 1, 9, 0),
      points: points,
      durationSeconds: 1800,
      maxDepth: 18.0,
      decoAlgorithm: 'rgbm',
      computerTissue: computerTissue,
      forceNew: forceNew,
    );
  }

  group('new dive', () {
    test('stores the snapshot on the dive row', () async {
      final diveId = await importWith(snapshot, forceNew: true);

      expect(await storedTissueFor(diveId), snapshot);
    });

    test('leaves the column null when the computer reported none', () async {
      final diveId = await importWith(null, forceNew: true);

      expect(await storedTissueFor(diveId), isNull);
    });
  });

  group('existing dive', () {
    test('a re-import with a new snapshot replaces the stored one', () async {
      final diveId = await importWith(snapshot, forceNew: true);
      await repository.clearSourceAndProfiles(
        diveId: diveId,
        computerId: computerId,
      );
      const updated = ComputerTissueSnapshot(
        end: ComputerTissueState(n2Bar: [1.0, 1.0, 1.0]),
      );

      final reimportedId = await importWith(updated);

      expect(reimportedId, diveId);
      expect(await storedTissueFor(diveId), updated);
    });

    test('a re-import without a snapshot clears the stored one', () async {
      final diveId = await importWith(snapshot, forceNew: true);
      await repository.clearSourceAndProfiles(
        diveId: diveId,
        computerId: computerId,
      );

      final reimportedId = await importWith(null);

      expect(reimportedId, diveId);
      expect(await storedTissueFor(diveId), isNull);
    });

    test('a re-import of the primary without a snapshot clears the stored one '
        'on a dive a second computer also recorded', () async {
      final diveId = await importWith(snapshot, forceNew: true);
      await importWith(null, fromComputer: secondComputerId);
      // As the replace-source path does: the cleared reading takes back the
      // primary role it held.
      final wasPrimary = await repository.clearSourceAndProfiles(
        diveId: diveId,
        computerId: computerId,
      );

      final reimportedId = await importWith(null, isPrimary: wasPrimary);

      expect(wasPrimary, isTrue);
      expect(reimportedId, diveId);
      expect(await storedTissueFor(diveId), isNull);
    });

    test(
      'a second computer with its own snapshot keeps the primary one',
      () async {
        final diveId = await importWith(snapshot, forceNew: true);
        const secondary = ComputerTissueSnapshot(
          end: ComputerTissueState(n2Bar: [1.0, 1.0, 1.0]),
        );

        final matchedId = await importWith(
          secondary,
          fromComputer: secondComputerId,
        );

        expect(matchedId, diveId);
        expect(await storedTissueFor(diveId), snapshot);
      },
    );

    test(
      'a second computer fills a snapshot the primary did not report',
      () async {
        final diveId = await importWith(null, forceNew: true);

        final matchedId = await importWith(
          snapshot,
          fromComputer: secondComputerId,
        );

        expect(matchedId, diveId);
        expect(await storedTissueFor(diveId), snapshot);
      },
    );

    test('a second computer without a snapshot keeps the stored one', () async {
      final diveId = await importWith(snapshot, forceNew: true);

      final matchedId = await importWith(null, fromComputer: secondComputerId);

      expect(matchedId, diveId);
      expect(await storedTissueFor(diveId), snapshot);
    });

    test('a re-import of the second computer without a snapshot keeps the '
        'stored one', () async {
      final diveId = await importWith(snapshot, forceNew: true);
      await importWith(null, fromComputer: secondComputerId);
      await repository.clearSourceAndProfiles(
        diveId: diveId,
        computerId: secondComputerId,
      );

      final reimportedId = await importWith(
        null,
        fromComputer: secondComputerId,
      );

      expect(reimportedId, diveId);
      expect(await storedTissueFor(diveId), snapshot);
    });

    test('a download taking the primary role from a UDDF source keeps the '
        'snapshot that source stored', () async {
      // A UDDF import writes the dive with its snapshot and a summary-only
      // primary source row, and no samples.
      final start = DateTime(2026, 5, 1, 9, 0).millisecondsSinceEpoch;
      final now = DateTime.now();
      const diveId = 'uddf-dive';
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value(diveId),
              diveDateTime: Value(start),
              entryTime: Value(start),
              maxDepth: const Value(18),
              computerTissueJson: Value(snapshot.encode()),
              createdAt: Value(now.millisecondsSinceEpoch),
              updatedAt: Value(now.millisecondsSinceEpoch),
            ),
          );
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion.insert(
              id: 'uddf-source',
              diveId: diveId,
              isPrimary: const Value(true),
              sourceFileFormat: const Value('uddf'),
              importedAt: now,
              createdAt: now,
            ),
          );

      final matchedId = await importWith(null);

      expect(matchedId, diveId);
      expect(await storedTissueFor(diveId), snapshot);
    });
  });
}
