import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();

    final now = DateTime.now().millisecondsSinceEpoch;

    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    for (final (id, name) in [
      ('dc-a', 'Kiyans Teric'),
      ('dc-b', 'Erics Teric'),
    ]) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: Value(id),
              name: Value(name),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('getDataSources returns one row per computer, even when more than one '
      'dive_data_sources row shares a computerId', () async {
    // Mirrors what a same-computer sequential merge produces
    // (dive_merge_service.dart step 10 carries over every original dive's
    // data source row as provenance; two originals logged by the same
    // physical computer both had their own row).
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-primary'),
            diveId: const Value('dive-1'),
            computerId: const Value('dc-a'),
            isPrimary: const Value(true),
            importedAt: Value(DateTime(2026, 1, 1)),
            createdAt: Value(DateTime(2026, 1, 1)),
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-dup'),
            diveId: const Value('dive-1'),
            computerId: const Value('dc-a'),
            isPrimary: const Value(false),
            importedAt: Value(DateTime(2026, 1, 2)),
            createdAt: Value(DateTime(2026, 1, 2)),
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-b'),
            diveId: const Value('dive-1'),
            computerId: const Value('dc-b'),
            isPrimary: const Value(false),
            importedAt: Value(DateTime(2026, 1, 3)),
            createdAt: Value(DateTime(2026, 1, 3)),
          ),
        );

    final sources = await repository.getDataSources('dive-1');

    expect(sources.map((s) => s.id).toList(), ['src-primary', 'src-b']);
  });

  test(
    'getDataSources keeps every source when no two share a computerId',
    () async {
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-a'),
              diveId: const Value('dive-1'),
              computerId: const Value('dc-a'),
              isPrimary: const Value(true),
              importedAt: Value(DateTime(2026, 1, 1)),
              createdAt: Value(DateTime(2026, 1, 1)),
            ),
          );
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-b'),
              diveId: const Value('dive-1'),
              computerId: const Value('dc-b'),
              isPrimary: const Value(false),
              importedAt: Value(DateTime(2026, 1, 2)),
              createdAt: Value(DateTime(2026, 1, 2)),
            ),
          );

      final sources = await repository.getDataSources('dive-1');

      expect(sources.map((s) => s.id).toList(), ['src-a', 'src-b']);
    },
  );

  // Issue #1451: a Combine of two file/cloud imports carries two provenance
  // rows with no computerId to collide on. Before merge_source_slot existed
  // they stayed two selectable sources, and the chart drew only one half of
  // the dive.
  test('getDataSources collapses merge provenance rows that share a slot, '
      'even with no computerId', () async {
    for (final (id, day) in [('src-first', 1), ('src-second', 2)]) {
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: Value(id),
              diveId: const Value('dive-1'),
              isPrimary: const Value(false),
              mergeSourceSlot: const Value(0),
              importedAt: Value(DateTime(2026, 1, day)),
              createdAt: Value(DateTime(2026, 1, day)),
            ),
          );
    }

    final sources = await repository.getDataSources('dive-1');

    expect(sources.map((s) => s.id).toList(), ['src-first']);
    expect(await repository.hasMultipleDataSources('dive-1'), isFalse);
  });

  test('getDataSources keeps one source per slot, so a consolidated dive that '
      'was then combined still shows both computers', () async {
    // Two segments, each contributing a primary (slot 0) and a folded-in
    // secondary (slot 1). Four rows, two strands.
    var day = 1;
    for (final slot in [0, 1, 0, 1]) {
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: Value('src-$day'),
              diveId: const Value('dive-1'),
              isPrimary: const Value(false),
              mergeSourceSlot: Value(slot),
              importedAt: Value(DateTime(2026, 1, day)),
              createdAt: Value(DateTime(2026, 1, day)),
            ),
          );
      day++;
    }

    final sources = await repository.getDataSources('dive-1');

    expect(sources.map((s) => s.id).toList(), ['src-1', 'src-2']);
    expect(await repository.hasMultipleDataSources('dive-1'), isTrue);
  });

  test(
    'a slot never collapses a row against a source that has a computer',
    () async {
      // A merged dive later consolidated with a computer download: the carried
      // halves are one strand, the download is its own.
      for (final (id, day) in [('src-half-a', 1), ('src-half-b', 2)]) {
        await db
            .into(db.diveDataSources)
            .insert(
              DiveDataSourcesCompanion(
                id: Value(id),
                diveId: const Value('dive-1'),
                isPrimary: const Value(false),
                mergeSourceSlot: const Value(0),
                importedAt: Value(DateTime(2026, 1, day)),
                createdAt: Value(DateTime(2026, 1, day)),
              ),
            );
      }
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-computer'),
              diveId: const Value('dive-1'),
              computerId: const Value('dc-a'),
              isPrimary: const Value(false),
              importedAt: Value(DateTime(2026, 1, 3)),
              createdAt: Value(DateTime(2026, 1, 3)),
            ),
          );

      final sources = await repository.getDataSources('dive-1');

      expect(sources.map((s) => s.id).toList(), ['src-half-a', 'src-computer']);
      expect(await repository.hasMultipleDataSources('dive-1'), isTrue);
    },
  );

  // Issue #3654: one Perdix 2 download stored twice with no computer, once
  // as 'Shearwater Perdix 2' with no serial and once as 'Perdix 2' with the
  // serial the computer shows, beside a second computer's recording.
  group('rows of one recording with no computer', () {
    Future<void> insertSource(
      String id, {
      required bool isPrimary,
      required String model,
      String? serial,
      required int duration,
      required int day,
      String? sourceFileName,
    }) => db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: const Value('dive-1'),
            isPrimary: Value(isPrimary),
            computerModel: Value(model),
            computerSerial: Value(serial),
            entryTime: Value(DateTime.utc(2026, 7, 1, 9, 30, 12)),
            duration: Value(duration),
            maxDepth: const Value(6.2),
            sourceFileName: Value(sourceFileName),
            importedAt: Value(DateTime(2026, 1, day)),
            createdAt: Value(DateTime(2026, 1, day)),
          ),
        );

    test('show as one source', () async {
      await insertSource(
        'src-vendor',
        isPrimary: true,
        model: 'Shearwater Perdix 2',
        duration: 440,
        day: 1,
      );
      await insertSource(
        'src-bare',
        isPrimary: false,
        model: 'Perdix 2',
        serial: 'A5433DEA',
        duration: 440,
        day: 2,
      );

      final sources = await repository.getDataSources('dive-1');

      expect(sources.map((s) => s.id).toList(), ['src-vendor']);
      expect(await repository.hasMultipleDataSources('dive-1'), isFalse);
    });

    test('collapse onto whichever of them is primary, beside another '
        'computer', () async {
      await insertSource(
        'src-vendor',
        isPrimary: false,
        model: 'Shearwater Perdix 2',
        duration: 440,
        day: 1,
      );
      await insertSource(
        'src-bare',
        isPrimary: true,
        model: 'Perdix 2',
        serial: 'A5433DEA',
        duration: 440,
        day: 2,
      );
      await insertSource(
        'src-petrel',
        isPrimary: false,
        model: 'Petrel 3',
        duration: 2481,
        day: 3,
      );

      final sources = await repository.getDataSources('dive-1');

      expect(sources.map((s) => s.id).toList(), ['src-bare', 'src-petrel']);
      expect(await repository.hasMultipleDataSources('dive-1'), isTrue);
    });

    test('stay two sources, in the count too, when one import of one file '
        'wrote both', () async {
      for (final (id, primary) in [('src-one', true), ('src-two', false)]) {
        await insertSource(
          id,
          isPrimary: primary,
          model: 'Perdix 2',
          duration: 440,
          day: 1,
          sourceFileName: 'log.ssrf',
        );
      }

      expect(await repository.getDataSources('dive-1'), hasLength(2));
      expect(await repository.hasMultipleDataSources('dive-1'), isTrue);
    });

    test('hand a collapsed row\'s samples to its own chip, not to the '
        'primary computer', () async {
      await insertSource(
        'src-petrel',
        isPrimary: true,
        model: 'Petrel 3',
        duration: 2481,
        day: 1,
      );
      await insertSource(
        'src-vendor',
        isPrimary: false,
        model: 'Shearwater Perdix 2',
        duration: 440,
        day: 2,
      );
      await insertSource(
        'src-bare',
        isPrimary: false,
        model: 'Perdix 2',
        serial: 'A5433DEA',
        duration: 440,
        day: 3,
      );
      final series = ProfileSeriesRepository();
      for (final (sourceId, depth) in [
        ('src-petrel', 30.0),
        ('src-bare', 6.2),
      ]) {
        await series.insertSeries(
          diveId: 'dive-1',
          sourceId: sourceId,
          isPrimary: sourceId == 'src-petrel',
          samples: [
            const ProfileSample(timestamp: 0, depth: 0),
            ProfileSample(timestamp: 60, depth: depth),
          ],
        );
      }

      final profiles = await repository.getProfilesByDataSource('dive-1');

      expect(profiles.keys.toList(), ['src-petrel', 'src-vendor']);
      expect(profiles['src-petrel']!.points.map((p) => p.depth), [0, 30.0]);
      expect(profiles['src-vendor']!.points.map((p) => p.depth), [0, 6.2]);
    });
  });
}
