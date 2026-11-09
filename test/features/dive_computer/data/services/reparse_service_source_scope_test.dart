import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

/// Issue #4367: a re-parse replaces only the series its own source wrote.
/// Before the fix the delete matched `computer_id IS NULL` for a source with
/// no computer, so re-parsing one took every other null-computer source's
/// series with it, the dive's primary included.
void main() {
  late AppDatabase db;
  late ReparseService service;
  late ProfileSeriesRepository profileSeries;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    service = ReparseService(db: db);
    profileSeries = ProfileSeriesRepository(
      database: db,
      syncRepository: SyncRepository(database: db),
    );
  });

  tearDown(() => db.close());

  final nowMs = DateTime.utc(2026, 1, 15, 10, 0).millisecondsSinceEpoch;

  Future<void> insertDive() async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(nowMs),
            notes: const Value(''),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
  }

  Future<void> insertComputer(String id) async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value('Test Computer $id'),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
  }

  Future<void> insertSource({
    required String id,
    String? computerId,
    required bool isPrimary,
    String sourceFormat = 'dive_computer',
    bool withRawData = false,
    int? mergeSourceSlot,
  }) async {
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: const Value('dive-1'),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            sourceFormat: Value(sourceFormat),
            rawData: Value(withRawData ? Uint8List.fromList([1, 2, 3]) : null),
            mergeSourceSlot: Value(mergeSourceSlot),
            importedAt: Value(now),
            createdAt: Value(now),
          ),
        );
  }

  Future<String> insertSeries({
    String? sourceId,
    String? computerId,
    required bool isPrimary,
    double depth = 30.0,
    int start = 0,
    int now = 1000,
  }) => profileSeries.insertSeries(
    diveId: 'dive-1',
    sourceId: sourceId,
    computerId: computerId,
    isPrimary: isPrimary,
    samples: [
      ProfileSample(timestamp: start, depth: 0.0),
      ProfileSample(timestamp: start + 60, depth: depth),
    ],
    now: now,
  );

  pigeon.ParsedDive parsedDive() => pigeon.ParsedDive(
    fingerprint: 'test-fp',
    dateTimeYear: 2026,
    dateTimeMonth: 1,
    dateTimeDay: 15,
    dateTimeHour: 10,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 12.0,
    avgDepthMeters: 8.0,
    durationSeconds: 3000,
    samples: [
      pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
      pigeon.ProfileSample(timeSeconds: 30, depthMeters: 12.0),
    ],
    tanks: [],
    gasMixes: [],
    events: [],
  );

  Future<({bool profilePreserved})> reparse(String sourceRowId) =>
      service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: sourceRowId,
        parsed: parsedDive(),
        descriptorVendor: 'Shearwater',
        descriptorProduct: 'Perdix',
        descriptorModel: 42,
        libdivecomputerVersion: '0.8.0',
      );

  Future<Map<String, ({String? sourceId, bool isPrimary})>> seriesById() async {
    final rows = await profileSeries.getIdentitiesForDive('dive-1');
    return {
      for (final r in rows)
        r.id: (sourceId: r.sourceId, isPrimary: r.isPrimary),
    };
  }

  test('re-parsing a null-computer source keeps another null-computer '
      "source's series, the dive's primary among them", () async {
    // The reported shape: a UDDF primary with no computer and no raw data,
    // and a downloaded computer whose computer row was deleted (FK setNull).
    await insertDive();
    await insertSource(id: 'uddf', isPrimary: true, sourceFormat: 'uddf');
    await insertSource(id: 'comp-a', isPrimary: false, withRawData: true);
    final uddfLive = await insertSeries(sourceId: 'uddf', isPrimary: true);
    final uddfOlder = await insertSeries(
      sourceId: 'uddf',
      isPrimary: false,
      depth: 28.0,
      now: 500,
    );

    final outcome = await reparse('comp-a');

    expect(outcome.profilePreserved, isFalse);
    final after = await seriesById();
    expect(after[uddfLive], (sourceId: 'uddf', isPrimary: true));
    expect(after[uddfOlder], (sourceId: 'uddf', isPrimary: false));
    final fresh = after.entries.where((e) => e.value.sourceId == 'comp-a');
    expect(fresh, hasLength(1));
    expect(fresh.single.value.isPrimary, isFalse);
    expect(await db.select(db.deletionLog).get(), isEmpty);
  });

  test(
    'a null-computer re-parse replaces its own series and nothing else',
    () async {
      await insertDive();
      await insertSource(id: 'uddf', isPrimary: true, sourceFormat: 'uddf');
      await insertSource(id: 'comp-a', isPrimary: false, withRawData: true);
      final uddfLive = await insertSeries(sourceId: 'uddf', isPrimary: true);
      final stale = await insertSeries(sourceId: 'comp-a', isPrimary: false);

      await reparse('comp-a');

      final after = await seriesById();
      expect(after.containsKey(stale), isFalse);
      expect(after[uddfLive], (sourceId: 'uddf', isPrimary: true));
      expect(after.values.where((v) => v.sourceId == 'comp-a'), hasLength(1));
      final tombstones = await db.select(db.deletionLog).get();
      expect(tombstones.map((t) => t.recordId).toList(), [stale]);
    },
  );

  test("a computer re-parse leaves another source's series on the same "
      'computer alone', () async {
    await insertDive();
    await insertComputer('comp-b');
    await insertSource(id: 'primary', isPrimary: true, computerId: 'comp-b');
    await insertSource(
      id: 'file',
      isPrimary: false,
      computerId: 'comp-b',
      sourceFormat: 'uddf',
    );
    final mine = await insertSeries(
      sourceId: 'primary',
      computerId: 'comp-b',
      isPrimary: true,
    );
    final theirs = await insertSeries(
      sourceId: 'file',
      computerId: 'comp-b',
      isPrimary: false,
    );

    await reparse('primary');

    final after = await seriesById();
    expect(after.containsKey(mine), isFalse);
    expect(after[theirs], (sourceId: 'file', isPrimary: false));
  });

  test('a non-primary source whose series is the live one keeps the dive '
      'with a primary series', () async {
    // The diver chose this source's reading as the live profile, so its
    // series is primary although the source row is not.
    await insertDive();
    await insertSource(id: 'uddf', isPrimary: true, sourceFormat: 'uddf');
    await insertSource(id: 'comp-a', isPrimary: false, withRawData: true);
    await insertSeries(sourceId: 'uddf', isPrimary: false);
    final live = await insertSeries(sourceId: 'comp-a', isPrimary: true);

    await reparse('comp-a');

    final after = await seriesById();
    expect(after.containsKey(live), isFalse);
    final fresh = after.values.where((v) => v.sourceId == 'comp-a');
    expect(fresh.single.isPrimary, isTrue);
    expect(await profileSeries.hasPrimarySeries('dive-1'), isTrue);
  });

  group("a null-computer source's manual edit", () {
    // saveEditedProfile writes the edit live with no computer over the
    // demoted generation it corrects. A source with no computer shares that
    // null strand, so only the generation beneath tells the edit apart.
    test('is kept, the fresh parse landing beneath it', () async {
      await insertDive();
      await insertSource(id: 'comp-a', isPrimary: true, withRawData: true);
      final edit = await insertSeries(sourceId: 'comp-a', isPrimary: true);
      final generation = await insertSeries(
        sourceId: 'comp-a',
        isPrimary: false,
        now: 500,
      );

      await reparse('comp-a');

      final after = await seriesById();
      expect(after[edit], (sourceId: 'comp-a', isPrimary: true));
      expect(after.containsKey(generation), isFalse);
      final fresh = after.entries.where(
        (e) => e.key != edit && e.value.sourceId == 'comp-a',
      );
      expect(fresh.single.value.isPrimary, isFalse);
    });

    test("keeps the edit's depths on the dive row", () async {
      // The edit stays live, so the summary reads from it rather than from
      // the recording (issue #3931), as it does for a source with a computer.
      await insertDive();
      await insertSource(id: 'comp-a', isPrimary: true, withRawData: true);
      await insertSeries(sourceId: 'comp-a', isPrimary: true, depth: 25.0);
      await insertSeries(sourceId: 'comp-a', isPrimary: false, now: 500);

      await reparse('comp-a');

      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('dive-1'))).getSingle();
      expect(dive.maxDepth, 25.0);
    });

    test('of a non-primary source is kept too', () async {
      await insertDive();
      await insertSource(id: 'uddf', isPrimary: true, sourceFormat: 'uddf');
      await insertSource(id: 'comp-a', isPrimary: false, withRawData: true);
      final edit = await insertSeries(sourceId: 'comp-a', isPrimary: true);
      await insertSeries(sourceId: 'comp-a', isPrimary: false, now: 500);

      await reparse('comp-a');

      final after = await seriesById();
      expect(after[edit], (sourceId: 'comp-a', isPrimary: true));
      expect(
        after.entries
            .where((e) => e.key != edit && e.value.sourceId == 'comp-a')
            .single
            .value
            .isPrimary,
        isFalse,
      );
    });
  });

  group('legacy series with no source', () {
    test(
      'are replaced when the re-parsed source is alone on its computer',
      () async {
        await insertDive();
        await insertComputer('comp-b');
        await insertSource(
          id: 'primary',
          isPrimary: true,
          computerId: 'comp-b',
        );
        await insertSource(id: 'uddf', isPrimary: false, sourceFormat: 'uddf');
        final legacy = await insertSeries(
          computerId: 'comp-b',
          isPrimary: true,
        );
        final uddf = await insertSeries(sourceId: 'uddf', isPrimary: false);

        await reparse('primary');

        final after = await seriesById();
        expect(after.containsKey(legacy), isFalse);
        expect(after.containsKey(uddf), isTrue);
        expect(
          after.values.where((v) => v.sourceId == 'primary'),
          hasLength(1),
        );
      },
    );

    test('on a null strand are nobody\'s, so a re-parse keeps them', () async {
      // seriesSourceOwner, the rule the timeline shift reads ownership by: a
      // row with no source belongs to the one source on its computer, and a
      // null computer names none. Two file imports carry no computer, and a
      // guess between them would delete another recording.
      await insertDive();
      await insertSource(id: 'uddf', isPrimary: true, sourceFormat: 'uddf');
      await insertSource(id: 'comp-a', isPrimary: false, withRawData: true);
      final legacy = await insertSeries(isPrimary: true);

      await reparse('comp-a');

      final after = await seriesById();
      expect(after[legacy], (sourceId: null, isPrimary: true));
      final fresh = after.values.where((v) => v.sourceId == 'comp-a');
      expect(fresh.single.isPrimary, isFalse);
    });

    test('on a computer two sources share are nobody\'s', () async {
      await insertDive();
      await insertComputer('comp-b');
      await insertSource(id: 'primary', isPrimary: true, computerId: 'comp-b');
      await insertSource(
        id: 'second',
        isPrimary: false,
        computerId: 'comp-b',
        sourceFormat: 'uddf',
      );
      final legacy = await insertSeries(computerId: 'comp-b', isPrimary: false);

      await reparse('primary');

      final after = await seriesById();
      expect(after[legacy], (sourceId: null, isPrimary: false));
    });
  });

  test('a strand a combine carried keeps its re-based samples once the dive '
      'has a primary again', () async {
    // The reported dive's computer B: a sequential combine re-based its
    // samples 60 s along the merged timeline and recorded no offset, and a
    // later consolidation gave the dive a primary row. Re-parsing B must not
    // put its samples back at 0 s.
    await insertDive();
    await insertComputer('comp-b');
    await insertSource(id: 'uddf', isPrimary: true, sourceFormat: 'uddf');
    await insertSource(
      id: 'comp-b',
      isPrimary: false,
      computerId: 'comp-b',
      withRawData: true,
      mergeSourceSlot: 1,
    );
    await insertSeries(sourceId: 'uddf', isPrimary: true);
    final rebased = await insertSeries(
      sourceId: 'comp-b',
      computerId: 'comp-b',
      isPrimary: false,
      start: 60,
    );

    final outcome = await reparse('comp-b');

    expect(outcome.profilePreserved, isTrue);
    final series = await profileSeries.getSeriesById(rebased);
    expect(series?.samples.first.timestamp, 60);
  });
}
