import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';

import '../../../../helpers/test_database.dart';

/// Tissue state a dive computer reports for the whole dive (Suunto SML
/// `StartTissue` / `EndTissue`) travels with the download and lands on
/// `dives.computer_tissue_json`; a re-import that carries none must not
/// blank what an earlier import stored.
void main() {
  late DiveComputerRepository repository;
  late AppDatabase db;

  const computerId = 'suunto-eon-core';
  const points = [
    ProfilePointData(timestamp: 0, depth: 1.0),
    ProfilePointData(timestamp: 600, depth: 18.0),
    ProfilePointData(timestamp: 1200, depth: 6.0),
  ];
  const snapshot = ComputerTissueSnapshot(
    algorithm: 'Suunto Fused2 RGBM',
    start: ComputerTissueState(n2Bar: [0.79, 0.79, 0.79]),
    end: ComputerTissueState(
      n2Bar: [0.89665, 0.97105, 1.16432],
      cnsPercent: 13.2,
      otu: 35.57,
    ),
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
  }) {
    return repository.importProfile(
      computerId: computerId,
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
        algorithm: 'Suunto Fused2 RGBM',
        end: ComputerTissueState(n2Bar: [1.0, 1.0, 1.0]),
      );

      final reimportedId = await importWith(updated);

      expect(reimportedId, diveId);
      expect(await storedTissueFor(diveId), updated);
    });

    test('a re-import without a snapshot keeps the stored one', () async {
      final diveId = await importWith(snapshot, forceNew: true);
      await repository.clearSourceAndProfiles(
        diveId: diveId,
        computerId: computerId,
      );

      final reimportedId = await importWith(null);

      expect(reimportedId, diveId);
      expect(await storedTissueFor(diveId), snapshot);
    });
  });
}
