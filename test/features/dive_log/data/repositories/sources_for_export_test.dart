// Uint8List comes from the drift import below, which re-exports it.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;

  // DiveRepository takes no database argument: it resolves
  // DatabaseService.instance, which setUpTestDatabase points at an in-memory
  // database.
  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> insertDive(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertSource(
    String id,
    String diveId, {
    Uint8List? rawData,
    bool isPrimary = false,
    int? mergeSourceSlot,
    DateTime? createdAt,
  }) async {
    final stamp = createdAt ?? DateTime(2019, 6, 2, 18, 41, 7);
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            isPrimary: Value(isPrimary),
            rawData: rawData == null ? const Value.absent() : Value(rawData),
            mergeSourceSlot: mergeSourceSlot == null
                ? const Value.absent()
                : Value(mergeSourceSlot),
            descriptorVendor: const Value('Shearwater'),
            descriptorProduct: const Value('Perdix'),
            descriptorModel: const Value(5),
            importedAt: Value(stamp),
            createdAt: Value(stamp),
          ),
        );
  }

  test('returns raw bytes byte identical to what was written', () async {
    // The load bearing assertion. Under issue #227 raw_data carries a Drift
    // TypeConverter; customSelect skips converters, so a raw SQL version of
    // getSourcesForExport would hand back SRD1 framed zlib and this fails.
    final raw = Uint8List.fromList(
      List<int>.generate(4096, (i) => (i * 31) % 256),
    );
    await insertDive('dive-1');
    await insertSource('src-1', 'dive-1', rawData: raw, isPrimary: true);

    final sources = await repository.getSourcesForExport(['dive-1']);

    expect(sources, hasLength(1));
    expect(sources.single.rawData, equals(raw));
    expect(sources.single.hasDump, isTrue);
    expect(sources.single.descriptorVendor, 'Shearwater');
    expect(sources.single.descriptorModel, 5);
  });

  test('returns rows without raw data too, marked as having no dump', () async {
    await insertDive('dive-1');
    await insertSource('src-1', 'dive-1', isPrimary: true);

    final sources = await repository.getSourcesForExport(['dive-1']);

    expect(sources, hasLength(1));
    expect(sources.single.rawData, isNull);
    expect(sources.single.hasDump, isFalse);
  });

  test('does not collapse rows sharing a merge slot', () async {
    // getDataSources collapses these into one display source. Each row is the
    // only copy of its half's rawData, so the export must see both.
    final a = Uint8List.fromList([1, 2, 3]);
    final b = Uint8List.fromList([4, 5, 6]);
    await insertDive('dive-1');
    await insertSource(
      'src-a',
      'dive-1',
      rawData: a,
      isPrimary: true,
      mergeSourceSlot: 0,
      createdAt: DateTime(2019, 6, 2),
    );
    await insertSource(
      'src-b',
      'dive-1',
      rawData: b,
      mergeSourceSlot: 0,
      createdAt: DateTime(2019, 6, 3),
    );

    final sources = await repository.getSourcesForExport(['dive-1']);

    expect(sources, hasLength(2));
    expect(sources.map((s) => s.rawData), containsAll([a, b]));
  });

  test('numbers ordinals per dive, primary first then createdAt', () async {
    await insertDive('dive-1');
    await insertDive('dive-2');
    await insertSource('src-late', 'dive-1', createdAt: DateTime(2019, 6, 4));
    await insertSource(
      'src-primary',
      'dive-1',
      isPrimary: true,
      createdAt: DateTime(2019, 6, 5),
    );
    await insertSource('src-other', 'dive-2', isPrimary: true);

    final sources = await repository.getSourcesForExport(['dive-1', 'dive-2']);

    final diveOne = sources.where((s) => s.diveId == 'dive-1').toList();
    expect(diveOne.map((s) => s.id), ['src-primary', 'src-late']);
    expect(diveOne.map((s) => s.ordinal), [0, 1]);

    final diveTwo = sources.where((s) => s.diveId == 'dive-2').toList();
    expect(diveTwo.single.ordinal, 0);
  });

  test('returns an empty list for an empty id list without querying', () async {
    expect(await repository.getSourcesForExport(const []), isEmpty);
  });

  test('handles an id list longer than one bound-variable chunk', () async {
    // A full logbook export passes every dive in the library, and this binds
    // one SQL variable per id, so the query has to chunk like its siblings.
    const count = kSeriesIdChunkSize + 25;
    for (var i = 0; i < count; i++) {
      final id = 'dive-${i.toString().padLeft(5, '0')}';
      await insertDive(id);
      await insertSource('src-$id', id, isPrimary: true);
    }

    final ids = [
      for (var i = 0; i < count; i++) 'dive-${i.toString().padLeft(5, '0')}',
    ];
    final sources = await repository.getSourcesForExport(ids);

    expect(sources, hasLength(count));
    expect(
      sources.map((s) => s.diveId).toSet(),
      hasLength(count),
      reason: 'every dive must appear exactly once across the chunks',
    );
    expect(
      sources.every((s) => s.ordinal == 0),
      isTrue,
      reason: 'each dive has one source, so every ordinal restarts at zero',
    );
  });
}
