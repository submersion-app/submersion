// Uint8List comes from the drift import below, which re-exports it.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';

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
    String? computerId,
    DateTime? createdAt,
  }) async {
    if (computerId != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: Value(computerId),
              name: Value(computerId),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    final stamp = createdAt ?? DateTime(2019, 6, 2, 18, 41, 7);
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            isPrimary: Value(isPrimary),
            computerId: Value(computerId),
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

  /// Each source's series of 'dive-1' as start timestamps, by source id.
  Future<Map<String, List<int>>> exportedSeries() async {
    final sources = await repository.getSourcesForExport(['dive-1']);
    return {
      for (final source in sources)
        source.id: [
          for (final s in source.profileSeries)
            const ProfileSeriesCodec().decode(s.blob).first.timestamp,
        ],
    };
  }

  Future<String> insertSeries({
    required int at,
    String? sourceId,
    String? computerId,
    bool isPrimary = true,
    int? activatedAt,
    double depth = 5,
  }) => ProfileSeriesRepository().insertSeries(
    diveId: 'dive-1',
    sourceId: sourceId,
    computerId: computerId,
    isPrimary: isPrimary,
    activatedAt: Value(activatedAt),
    samples: [ProfileSample(timestamp: at, depth: depth)],
  );

  group('profileSeries (issue #3965)', () {
    setUp(() => insertDive('dive-1'));

    test('a lone source carries none', () async {
      await insertSource('src-1', 'dive-1', isPrimary: true);
      await insertSeries(at: 0, sourceId: 'src-1');

      expect(await exportedSeries(), {'src-1': <int>[]});
    });

    test('each source of a dive carries the series it owns', () async {
      await insertSource('src-1', 'dive-1', isPrimary: true);
      await insertSource('src-2', 'dive-1');
      await insertSeries(at: 0, sourceId: 'src-1');
      await insertSeries(at: 10, sourceId: 'src-2', isPrimary: false);

      expect(await exportedSeries(), {
        'src-1': [0],
        'src-2': [10],
      });
    });

    test('a series naming no source goes where the read puts it', () async {
      await insertSource(
        'src-1',
        'dive-1',
        isPrimary: true,
        computerId: 'comp-1',
      );
      await insertSource('src-2', 'dive-1', computerId: 'comp-2');
      await insertSeries(at: 0);
      await insertSeries(at: 10, computerId: 'comp-2', isPrimary: false);

      expect(await exportedSeries(), {
        'src-1': [0],
        'src-2': [10],
      });
      final sources = await repository.getSourcesForExport(['dive-1']);
      // Held by a row, but a restore must not make that row its owner.
      expect(sources[0].profileSeries.single.sourceId, isNull);
      expect(sources[1].profileSeries.single.sourceId, isNull);
    });

    test('leaves out the originals a saved edit superseded', () async {
      await insertSource(
        'src-1',
        'dive-1',
        isPrimary: true,
        computerId: 'comp-1',
      );
      await insertSource('src-2', 'dive-1', computerId: 'comp-2');
      await insertSeries(
        at: 0,
        sourceId: 'src-1',
        computerId: 'comp-1',
        isPrimary: false,
      );
      await insertSeries(at: 1, sourceId: 'src-1');
      await insertSeries(
        at: 10,
        sourceId: 'src-2',
        computerId: 'comp-2',
        isPrimary: false,
      );

      expect(await exportedSeries(), {
        'src-1': [1],
        'src-2': [10],
      });
    });

    test('keeps only the live generation of a demoted source', () async {
      await insertSource('src-1', 'dive-1', isPrimary: true);
      await insertSource('src-2', 'dive-1');
      await insertSeries(at: 0, sourceId: 'src-1');
      await insertSeries(
        at: 10,
        sourceId: 'src-2',
        isPrimary: false,
        activatedAt: 100,
        depth: 7,
      );
      await insertSeries(
        at: 10,
        sourceId: 'src-2',
        isPrimary: false,
        activatedAt: 200,
        depth: 9,
      );

      final sources = await repository.getSourcesForExport(['dive-1']);

      final series = sources[1].profileSeries.single;
      expect(const ProfileSeriesCodec().decode(series.blob).single.depth, 9);
    });

    test('passes a series through without decoding it', () async {
      await insertSource('src-1', 'dive-1', isPrimary: true);
      await insertSource('src-2', 'dive-1');
      await insertSeries(at: 0, sourceId: 'src-1');
      final unreadable = await insertSeries(
        at: 10,
        sourceId: 'src-2',
        isPrimary: false,
      );
      // Not a blob this build can read, which a newer peer can sync here.
      final bytes = Uint8List.fromList([1, 2, 3]);
      await (db.update(db.diveProfileSeries)
            ..where((t) => t.id.equals(unreadable)))
          .write(DiveProfileSeriesCompanion(samples: Value(bytes)));

      final sources = await repository.getSourcesForExport(['dive-1']);

      expect(sources[1].profileSeries.single.blob, bytes);
    });

    test('a row that collapsed into a chip keeps its own series', () async {
      await insertSource(
        'src-1',
        'dive-1',
        mergeSourceSlot: 0,
        createdAt: DateTime(2019, 6, 2, 10),
      );
      await insertSource(
        'src-2',
        'dive-1',
        mergeSourceSlot: 0,
        createdAt: DateTime(2019, 6, 2, 11),
      );
      await insertSeries(at: 0, sourceId: 'src-1', isPrimary: false);
      await insertSeries(at: 100, sourceId: 'src-2', isPrimary: false);

      expect(await exportedSeries(), {
        'src-1': [0],
        'src-2': [100],
      });
    });
  });

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

  test('returns each dive once even if an id repeats across chunks', () async {
    // A single IN clause already ignores a repeated id, so a duplicate only
    // bites once the list is chunked: the same id in two chunks fetches its
    // rows twice, and the ordinals then count the duplicates, exporting the
    // dive's sources more than once. The repeat therefore has to land in a
    // LATER chunk than the original for this to test anything.
    const spanning = kSeriesIdChunkSize + 5;
    for (var i = 0; i < spanning; i++) {
      final id = 'dive-${i.toString().padLeft(5, '0')}';
      await insertDive(id);
      await insertSource('src-$id', id, isPrimary: true);
    }

    final ids = [
      for (var i = 0; i < spanning; i++) 'dive-${i.toString().padLeft(5, '0')}',
      // Chunk 0 holds the first 900 ids, so this copy falls into chunk 1.
      'dive-00000',
    ];
    expect(
      ids.length ~/ kSeriesIdChunkSize,
      greaterThanOrEqualTo(1),
      reason: 'sanity: the repeat must not share a chunk with the original',
    );

    final sources = await repository.getSourcesForExport(ids);

    expect(sources, hasLength(spanning));
    expect(
      sources.where((s) => s.diveId == 'dive-00000'),
      hasLength(1),
      reason: 'the repeated id must not fetch its rows a second time',
    );
    expect(sources.every((s) => s.ordinal == 0), isTrue);
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
