import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_weight_entry_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DiverWeightEntryRepository repository;

  const diverId = 'diver-1';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // SyncRepository resolves the DatabaseService singleton for HLC stamping
    // and deletion tombstones; point it at the same in-memory db.
    DatabaseService.instance.setTestDatabase(db);
    repository = DiverWeightEntryRepository(db);
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: const Value(diverId),
            name: const Value('Eric'),
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  });

  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    await db.close();
  });

  DiverWeightEntry entry(DateTime measuredAt, double weightKg) =>
      DiverWeightEntry(
        id: '',
        diverId: diverId,
        measuredAt: measuredAt,
        weightKg: weightKg,
        createdAt: measuredAt,
        updatedAt: measuredAt,
      );

  test(
    'createEntry persists and getEntriesForDiver orders newest first',
    () async {
      await repository.createEntry(entry(DateTime(2025, 1, 1), 80.0));
      await repository.createEntry(entry(DateTime(2026, 1, 1), 82.0));
      await repository.createEntry(entry(DateTime(2024, 1, 1), 78.0));

      final entries = await repository.getEntriesForDiver(diverId);
      expect(entries, hasLength(3));
      expect(entries.map((e) => e.weightKg).toList(), [82.0, 80.0, 78.0]);
      expect(entries.first.diverId, diverId);
    },
  );

  test('createEntry stamps an hlc via markRecordPending', () async {
    final created = await repository.createEntry(
      entry(DateTime(2026, 1, 1), 82.0),
    );
    final row = await db
        .customSelect(
          'SELECT hlc FROM diver_weight_entries WHERE id = ?',
          variables: [Variable.withString(created.id)],
        )
        .getSingle();
    expect(row.read<String?>('hlc'), isNotNull);
  });

  test('latestEntry returns newest by measuredAt', () async {
    await repository.createEntry(entry(DateTime(2025, 6, 1), 81.0));
    await repository.createEntry(entry(DateTime(2026, 6, 1), 83.5));
    final latest = await repository.latestEntry(diverId);
    expect(latest!.weightKg, 83.5);
  });

  test('latestEntry returns null with no entries', () async {
    expect(await repository.latestEntry(diverId), isNull);
  });

  test('entryNearest picks the closest-dated entry on both sides', () async {
    await repository.createEntry(entry(DateTime(2024, 1, 1), 78.0));
    await repository.createEntry(entry(DateTime(2026, 1, 1), 84.0));

    final nearEarly = await repository.entryNearest(
      diverId,
      DateTime(2024, 6, 1),
    );
    expect(nearEarly!.weightKg, 78.0);

    final nearLate = await repository.entryNearest(
      diverId,
      DateTime(2025, 12, 1),
    );
    expect(nearLate!.weightKg, 84.0);
  });

  test('updateEntry rewrites values', () async {
    final created = await repository.createEntry(
      entry(DateTime(2026, 1, 1), 82.0),
    );
    await repository.updateEntry(
      created.copyWith(weightKg: 79.5, heightCm: 181.0),
    );
    final entries = await repository.getEntriesForDiver(diverId);
    expect(entries.single.weightKg, 79.5);
    expect(entries.single.heightCm, 181.0);
  });

  test('createEntry preserves an explicit id', () async {
    final created = await repository.createEntry(
      entry(DateTime(2026, 1, 1), 82.0).copyWith(id: 'fixed-id'),
    );
    expect(created.id, 'fixed-id');
  });

  test('createEntry surfaces FK violations for unknown divers', () async {
    expect(
      () => repository.createEntry(
        entry(DateTime(2026, 1, 1), 82.0).copyWith(diverId: 'nobody'),
      ),
      throwsA(anything),
    );
  });

  test('deleteEntry removes the row and writes a deletion tombstone', () async {
    final created = await repository.createEntry(
      entry(DateTime(2026, 1, 1), 82.0),
    );
    await repository.deleteEntry(created.id);

    expect(await repository.getEntriesForDiver(diverId), isEmpty);
    final tombstones = await db
        .customSelect(
          'SELECT * FROM deletion_log WHERE record_id = ?',
          variables: [Variable.withString(created.id)],
        )
        .get();
    expect(tombstones, isNotEmpty);
  });
}
