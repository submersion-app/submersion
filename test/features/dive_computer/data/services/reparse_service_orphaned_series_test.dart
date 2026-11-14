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

/// Issue #4529: a re-parse replaces the series its source wrote even when a
/// computer delete stripped that series' computer, and keeps an edit that
/// lost its source live whichever source re-parses.
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
            sourceFormat: const Value('dive_computer'),
            rawData: Value(Uint8List.fromList([1, 2, 3])),
            importedAt: Value(now),
            createdAt: Value(now),
          ),
        );
  }

  Future<String> insertSeries({
    String? sourceId,
    String? computerId,
    required bool isPrimary,
    bool? isEdit,
    double depth = 30.0,
    int now = 1000,
  }) => profileSeries.insertSeries(
    diveId: 'dive-1',
    sourceId: sourceId,
    computerId: computerId,
    isPrimary: isPrimary,
    isEdit: isEdit,
    samples: [
      const ProfileSample(timestamp: 0, depth: 0.0),
      ProfileSample(timestamp: 60, depth: depth),
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

  Future<void> reparse(String sourceRowId) => service.applyParsedUpdate(
    diveId: 'dive-1',
    sourceRowId: sourceRowId,
    parsed: parsedDive(),
    descriptorVendor: 'Shearwater',
    descriptorProduct: 'Perdix',
    descriptorModel: 42,
    libdivecomputerVersion: '0.8.0',
  );

  Future<Map<String, ({String? sourceId, String? computerId, bool isPrimary})>>
  seriesById() async {
    final rows = await profileSeries.getIdentitiesForDive('dive-1');
    return {
      for (final r in rows)
        r.id: (
          sourceId: r.sourceId,
          computerId: r.computerId,
          isPrimary: r.isPrimary,
        ),
    };
  }

  group('a series that names the re-parsed source but lost its computer', () {
    // Computer A was deleted and set up again: its source is linked once
    // more, its series is not. The dive also carries computer B's download.
    Future<void> twoComputerDive() async {
      await insertDive();
      await insertComputer('comp-a');
      await insertComputer('comp-b');
      await insertSource(id: 'src-a', computerId: 'comp-a', isPrimary: true);
      await insertSource(id: 'src-b', computerId: 'comp-b', isPrimary: false);
    }

    for (final isEdit in [false, null]) {
      test('is replaced, leaving one series of the source '
          '(is_edit $isEdit)', () async {
        await twoComputerDive();
        final orphan = await insertSeries(
          sourceId: 'src-a',
          isPrimary: true,
          isEdit: isEdit,
        );
        final other = await insertSeries(
          sourceId: 'src-b',
          computerId: 'comp-b',
          isPrimary: false,
          isEdit: isEdit,
        );

        await reparse('src-a');

        final after = await seriesById();
        expect(after.containsKey(orphan), isFalse);
        expect(after[other], (
          sourceId: 'src-b',
          computerId: 'comp-b',
          isPrimary: false,
        ));
        final mine = after.values.where((v) => v.sourceId == 'src-a');
        expect(mine.single, (
          sourceId: 'src-a',
          computerId: 'comp-a',
          isPrimary: true,
        ));
      });
    }

    test('is kept when it is the live edit of the source, the fresh parse '
        'landing beneath it', () async {
      // saveEditedProfile writes an edit live with the source and no
      // computer, over the generation it corrects. Written before the mark,
      // only that generation beneath says it is an edit.
      await twoComputerDive();
      final edit = await insertSeries(sourceId: 'src-a', isPrimary: true);
      final generation = await insertSeries(
        sourceId: 'src-a',
        computerId: 'comp-a',
        isPrimary: false,
        now: 500,
      );

      await reparse('src-a');

      final after = await seriesById();
      expect(after[edit], (
        sourceId: 'src-a',
        computerId: null,
        isPrimary: true,
      ));
      expect(after.containsKey(generation), isFalse);
      final fresh = after.entries.where(
        (e) => e.key != edit && e.value.sourceId == 'src-a',
      );
      expect(fresh.single.value.isPrimary, isFalse);
      expect(after.values.where((v) => v.isPrimary), hasLength(1));
    });

    test(
      'is kept when it is a marked edit demoted beneath the original',
      () async {
        await twoComputerDive();
        final original = await insertSeries(
          sourceId: 'src-a',
          computerId: 'comp-a',
          isPrimary: true,
          isEdit: false,
        );
        final edit = await insertSeries(
          sourceId: 'src-a',
          isPrimary: false,
          isEdit: true,
        );

        await reparse('src-a');

        final after = await seriesById();
        expect(after.containsKey(original), isFalse);
        expect(after[edit], (
          sourceId: 'src-a',
          computerId: null,
          isPrimary: false,
        ));
        final fresh = after.entries.where(
          (e) => e.key != edit && e.value.sourceId == 'src-a',
        );
        expect(fresh.single.value.isPrimary, isTrue);
      },
    );
  });

  group('an edit that lost its source', () {
    // A file import with an edited profile was the dive's primary; removing
    // it made the downloaded computer source primary and left the edit live
    // with no source and no computer.
    for (final isEdit in [true, null]) {
      test('stays the live profile when a computer source re-parses '
          '(is_edit $isEdit)', () async {
        await insertDive();
        await insertComputer('comp-c');
        await insertSource(id: 'src-c', computerId: 'comp-c', isPrimary: true);
        final edit = await insertSeries(
          isPrimary: true,
          isEdit: isEdit,
          depth: 25.0,
        );
        final recording = await insertSeries(
          sourceId: 'src-c',
          computerId: 'comp-c',
          isPrimary: false,
          now: 500,
        );

        await reparse('src-c');

        final after = await seriesById();
        expect(after[edit], (
          sourceId: null,
          computerId: null,
          isPrimary: true,
        ));
        expect(after.containsKey(recording), isFalse);
        final fresh = after.values.where((v) => v.sourceId == 'src-c');
        expect(fresh.single, (
          sourceId: 'src-c',
          computerId: 'comp-c',
          isPrimary: false,
        ));
        expect(after.values.where((v) => v.isPrimary), hasLength(1));
        final dive = await (db.select(
          db.dives,
        )..where((t) => t.id.equals('dive-1'))).getSingle();
        expect(dive.maxDepth, 25.0);
      });
    }
  });
}
