import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_import/data/services/dive_reimport_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show DiveProfilePoint;

import '../../../../helpers/test_database.dart';

/// Issue #3931: a saved profile edit outlives a fresh parse of the recording
/// beneath it, so the depth summary the dive stores has to keep describing the
/// edit. The source row is the place for what the recording itself reports.
///
/// Every path that can leave an edit live while writing the dive's summary
/// runs here against the real services: a computer re-parse, a file resync,
/// and a primary swap that brings the edit back.
void main() {
  late AppDatabase db;
  late DiveRepository repository;

  const now = 1750000000000;
  const diveId = 'dive-1';

  // The recording, 30 m flat, and the correction of it, 20 m flat.
  const recorded = [(0, 0.0), (60, 30.0), (120, 30.0), (180, 0.0)];
  const edited = [
    DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 60, depth: 20),
    DiveProfilePoint(timestamp: 120, depth: 20),
    DiveProfilePoint(timestamp: 180, depth: 0),
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(now),
            maxDepth: Value(30),
            avgDepth: Value(15),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  /// A source row and its recording. [computerId] null is a file import.
  Future<void> seedSource(
    String id, {
    String? computerId,
    bool isPrimary = true,
    double maxDepth = 30,
    double avgDepth = 15,
    bool withSeries = true,
    Uint8List? rawData,
  }) async {
    if (computerId != null) {
      await db
          .into(db.diveComputers)
          .insertOnConflictUpdate(
            DiveComputersCompanion(
              id: Value(computerId),
              name: Value('Computer $computerId'),
              createdAt: const Value(now),
              updatedAt: const Value(now),
            ),
          );
    }
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: const Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            sourceFormat: Value(computerId == null ? 'uddf' : 'dive_computer'),
            maxDepth: Value(maxDepth),
            avgDepth: Value(avgDepth),
            rawData: Value(rawData),
            importedAt: Value(DateTime(2026, 1, 1)),
            createdAt: Value(DateTime(2026, 1, 1)),
          ),
        );
    if (!withSeries) return;
    await ProfileSeriesRepository().insertSeries(
      diveId: diveId,
      computerId: computerId,
      sourceId: id,
      isPrimary: isPrimary,
      samples: [
        for (final (timestamp, depth) in recorded)
          ProfileSample(timestamp: timestamp, depth: depth * (maxDepth / 30)),
      ],
      now: now,
    );
  }

  Future<Dive> diveRow() =>
      (db.select(db.dives)..where((t) => t.id.equals(diveId))).getSingle();

  Future<DiveDataSourcesData> sourceRow(String id) => (db.select(
    db.diveDataSources,
  )..where((t) => t.id.equals(id))).getSingle();

  Future<List<double>> liveDepths() async => [
    for (final point in await repository.getDiveProfile(diveId)) point.depth,
  ];

  Future<void> saveEdit() => repository.saveEditedProfile(diveId, edited);

  void expectDepths(Dive dive, double maxDepth, double avgDepth) {
    expect(dive.maxDepth, maxDepth);
    expect(dive.avgDepth, avgDepth);
  }

  group('liveEditIds', () {
    Future<Set<String>> editIds() =>
        ProfileSeriesRepository().liveEditIds(diveId);

    Future<String> liveSeriesId() async => (await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.isPrimary.equals(true))).getSingle()).id;

    test('finds an edit of a computer source', () async {
      await seedSource('src-a', computerId: 'dc-a');
      await saveEdit();

      expect(await editIds(), {await liveSeriesId()});
    });

    test('finds an edit of a file source', () async {
      await seedSource('src-file');
      await saveEdit();

      expect(await editIds(), {await liveSeriesId()});
    });

    test('finds an edit that lost its source', () async {
      await seedSource('src-a', computerId: 'dc-a');
      await seedSource('src-file', isPrimary: false);
      await saveEdit();
      final series = ProfileSeriesRepository();
      await series.deleteByComputer(diveId, 'dc-a');
      await series.clearSource('src-a');

      expect(await editIds(), {await liveSeriesId()});
    });

    test('finds nothing under an unedited computer series', () async {
      await seedSource('src-a', computerId: 'dc-a');
      await seedSource('src-b', computerId: 'dc-b', isPrimary: false);

      expect(await editIds(), isEmpty);
    });

    test('finds nothing in an unedited file over a second computer', () async {
      await seedSource('src-file');
      await seedSource('src-b', computerId: 'dc-b', isPrimary: false);

      expect(await editIds(), isEmpty);
    });

    test('finds nothing in a file with nothing beneath it', () async {
      await seedSource('src-file');

      expect(await editIds(), isEmpty);
    });
  });

  group('a computer re-parse', () {
    pigeon.ParsedDive parsedRecording({
      double maxDepth = 30,
      double avgDepth = 15,
    }) => pigeon.ParsedDive(
      fingerprint: 'test-fp',
      dateTimeYear: 2026,
      dateTimeMonth: 1,
      dateTimeDay: 15,
      dateTimeHour: 10,
      dateTimeMinute: 0,
      dateTimeSecond: 0,
      maxDepthMeters: maxDepth,
      avgDepthMeters: avgDepth,
      durationSeconds: 180,
      samples: [
        for (final (timestamp, depth) in recorded)
          pigeon.ProfileSample(
            timeSeconds: timestamp,
            depthMeters: depth * (maxDepth / 30),
          ),
      ],
      tanks: const [],
      gasMixes: const [],
      events: const [],
    );

    Future<bool> reparse(pigeon.ParsedDive parsed) async {
      final result = await ReparseService(db: db).applyParsedUpdate(
        diveId: diveId,
        sourceRowId: 'src-a',
        parsed: parsed,
        descriptorVendor: 'Shearwater',
        descriptorProduct: 'Perdix',
        descriptorModel: 42,
        libdivecomputerVersion: '0.8.0',
      );
      return result.profilePreserved;
    }

    test('leaves the depth summary of a live edit alone', () async {
      await seedSource('src-a', computerId: 'dc-a');
      await saveEdit();
      expectDepths(await diveRow(), 20, 10);

      await reparse(parsedRecording());

      expectDepths(await diveRow(), 20, 10);
      expect(await liveDepths(), [0, 20, 20, 0]);
    });

    test('still records what the recording reports on the source', () async {
      await seedSource('src-a', computerId: 'dc-a');
      await saveEdit();

      await reparse(parsedRecording(maxDepth: 31, avgDepth: 16));

      final source = await sourceRow('src-a');
      expect(source.maxDepth, 31);
      expect(source.avgDepth, 16);
    });

    test('puts back a summary an earlier re-parse already reset', () async {
      await seedSource('src-a', computerId: 'dc-a');
      await saveEdit();
      await (db.update(db.dives)..where((t) => t.id.equals(diveId))).write(
        const DivesCompanion(maxDepth: Value(30), avgDepth: Value(15)),
      );

      await reparse(parsedRecording());

      expectDepths(await diveRow(), 20, 10);
    });

    test(
      'reads the edit once a stale primary series beside it is gone',
      () async {
        // A re-parse before #3189 inserted the recording primary beside the edit.
        await seedSource('src-a', computerId: 'dc-a');
        await saveEdit();
        await ProfileSeriesRepository().insertSeries(
          diveId: diveId,
          computerId: 'dc-a',
          sourceId: 'src-a',
          samples: [
            for (final (timestamp, depth) in recorded)
              ProfileSample(timestamp: timestamp, depth: depth),
          ],
          now: now,
        );

        await reparse(parsedRecording());

        expect(await liveDepths(), [0, 20, 20, 0]);
        expectDepths(await diveRow(), 20, 10);
      },
    );

    test('keeps the edit\'s summary when it does not own the strand', () async {
      await seedSource('src-a', computerId: 'dc-a');
      await seedSource(
        'src-a2',
        computerId: 'dc-a',
        isPrimary: false,
        withSeries: false,
        rawData: Uint8List.fromList([1]),
      );
      await saveEdit();

      expect(await reparse(parsedRecording()), isTrue);

      expectDepths(await diveRow(), 20, 10);
    });

    test('writes the parse\'s summary to an unedited dive', () async {
      await seedSource('src-a', computerId: 'dc-a');

      await reparse(parsedRecording(maxDepth: 31, avgDepth: 16));

      expectDepths(await diveRow(), 31, 16);
    });

    test('writes the parse\'s summary once the edit is undone', () async {
      await seedSource('src-a', computerId: 'dc-a');
      await saveEdit();
      await repository.restoreOriginalProfile(diveId);

      await reparse(parsedRecording(maxDepth: 31, avgDepth: 16));

      expectDepths(await diveRow(), 31, 16);
    });
  });

  group('a file resync', () {
    Map<String, dynamic> parsedFile({
      double maxDepth = 30,
      double avgDepth = 15,
      bool withProfile = true,
    }) => {
      'maxDepth': maxDepth,
      'avgDepth': avgDepth,
      if (withProfile)
        'profile': [
          for (final (timestamp, depth) in recorded)
            {'timestamp': timestamp, 'depth': depth * (maxDepth / 30)},
        ],
    };

    Future<void> resync(Map<String, dynamic> diveData) => DiveReimportService(
      db: db,
    ).applyReimport(diveId: diveId, diveData: diveData, now: DateTime(2026, 9));

    test('leaves the depth summary of a live edit alone', () async {
      await seedSource('src-file');
      await saveEdit();

      await resync(parsedFile());

      expectDepths(await diveRow(), 20, 10);
      expect(await liveDepths(), [0, 20, 20, 0]);
    });

    test('still records what the file reports on the source', () async {
      await seedSource('src-file');
      await saveEdit();

      await resync(parsedFile(maxDepth: 31, avgDepth: 16));

      final source = await sourceRow('src-file');
      expect(source.maxDepth, 31);
      expect(source.avgDepth, 16);
    });

    test('keeps the edit\'s summary when the file has no profile', () async {
      await seedSource('src-file');
      await saveEdit();

      await resync(parsedFile(withProfile: false));

      expectDepths(await diveRow(), 20, 10);
      expect(await liveDepths(), [0, 20, 20, 0]);
    });

    test('keeps the edit\'s summary on a dive with no source row', () async {
      await ProfileSeriesRepository().insertSeries(
        diveId: diveId,
        samples: [
          for (final (timestamp, depth) in recorded)
            ProfileSample(timestamp: timestamp, depth: depth),
        ],
        now: now,
      );
      await saveEdit();

      await resync(parsedFile());

      expectDepths(await diveRow(), 20, 10);
    });

    test('keeps the edit\'s summary on a multi-source dive', () async {
      await seedSource('src-file');
      await seedSource(
        'src-b',
        computerId: 'dc-b',
        isPrimary: false,
        maxDepth: 28,
      );
      await saveEdit();

      await resync(parsedFile());

      expectDepths(await diveRow(), 20, 10);
    });

    test(
      'keeps an edit through a file that comes back with no samples',
      () async {
        // Each resync of this file must still recognise the edit, and undoing
        // it must still have the recording to go back to.
        await seedSource('src-file');
        await saveEdit();
        final emptyProfile = {...parsedFile(), 'profile': const <Object>[]};

        await resync(emptyProfile);
        await resync(emptyProfile);

        expect(await liveDepths(), [0, 20, 20, 0]);
        expectDepths(await diveRow(), 20, 10);

        await repository.restoreOriginalProfile(diveId);
        expect(await liveDepths(), [0, 30, 30, 0]);
      },
    );

    test(
      'stores what the dive shows with a stale series beside the edit',
      () async {
        await seedSource('src-file');
        await saveEdit();
        await ProfileSeriesRepository().insertSeries(
          diveId: diveId,
          sourceId: 'src-file',
          samples: [
            for (final (timestamp, depth) in recorded)
              ProfileSample(timestamp: timestamp, depth: depth),
          ],
          now: now,
        );

        await resync(parsedFile());

        final shown = await liveDepths();
        final dive = await diveRow();
        expect(dive.maxDepth, shown.reduce((a, b) => a > b ? a : b));
        expect(dive.avgDepth, shown.reduce((a, b) => a + b) / shown.length);
      },
    );

    test('keeps an edit that lost its source', () async {
      // Replace Source clears the source of the edit it leaves behind, which
      // can then sit over a demoted series that does name its source.
      final series = ProfileSeriesRepository();
      await seedSource('src-a', computerId: 'dc-a');
      await seedSource('src-file', isPrimary: false);
      await saveEdit();
      await series.deleteByComputer(diveId, 'dc-a');
      await series.clearSource('src-a');
      await (db.delete(
        db.diveDataSources,
      )..where((t) => t.id.equals('src-a'))).go();
      await (db.update(db.diveDataSources)
            ..where((t) => t.id.equals('src-file')))
          .write(const DiveDataSourcesCompanion(isPrimary: Value(true)));

      await resync(parsedFile());

      expect(await liveDepths(), [0, 20, 20, 0]);
      expectDepths(await diveRow(), 20, 10);
    });

    test('writes the parse\'s summary to an unedited dive', () async {
      await seedSource('src-file');

      await resync(parsedFile(maxDepth: 31, avgDepth: 16));

      expectDepths(await diveRow(), 31, 16);
    });

    test(
      'reads a second computer beneath an unedited file as no edit',
      () async {
        // The shape an edit leaves too: a primary series with no computer over
        // a demoted one. Only the demoted series' owner tells them apart.
        await seedSource('src-file');
        await seedSource(
          'src-b',
          computerId: 'dc-b',
          isPrimary: false,
          maxDepth: 28,
        );

        await resync(parsedFile(maxDepth: 31, avgDepth: 16));

        expectDepths(await diveRow(), 31, 16);
      },
    );
  });

  group('a primary swap', () {
    Future<void> makePrimary(String sourceId) => repository
        .setPrimaryDataSource(diveId: diveId, computerReadingId: sourceId);

    test('brings an edit back with its own summary', () async {
      await seedSource('src-a', computerId: 'dc-a');
      await seedSource(
        'src-b',
        computerId: 'dc-b',
        isPrimary: false,
        maxDepth: 28,
        avgDepth: 14,
      );
      await saveEdit();

      await makePrimary('src-b');
      expectDepths(await diveRow(), 28, 14);
      expect(await liveDepths(), [0, 28, 28, 0]);

      await makePrimary('src-a');
      expect(await liveDepths(), [0, 20, 20, 0]);
      expectDepths(await diveRow(), 20, 10);
    });

    test('brings a file source\'s edit back with its own summary', () async {
      await seedSource('src-file');
      await seedSource(
        'src-b',
        computerId: 'dc-b',
        isPrimary: false,
        maxDepth: 28,
        avgDepth: 14,
      );
      await saveEdit();

      await makePrimary('src-b');
      await makePrimary('src-file');

      expect(await liveDepths(), [0, 20, 20, 0]);
      expectDepths(await diveRow(), 20, 10);
    });

    test(
      'keeps a live edit\'s summary over a source with no samples',
      () async {
        await seedSource('src-a', computerId: 'dc-a');
        await seedSource(
          'src-b',
          computerId: 'dc-b',
          isPrimary: false,
          maxDepth: 28,
          avgDepth: 14,
          withSeries: false,
        );
        await saveEdit();

        await makePrimary('src-b');

        expect(await liveDepths(), [0, 20, 20, 0]);
        expectDepths(await diveRow(), 20, 10);
      },
    );

    test('keeps the summary a source reports when nothing is edited', () async {
      // 14.5 m is the computer's own time-weighted average; the mean of these
      // four samples is 14.
      await seedSource('src-a', computerId: 'dc-a');
      await seedSource(
        'src-b',
        computerId: 'dc-b',
        isPrimary: false,
        maxDepth: 28,
        avgDepth: 14.5,
      );

      await makePrimary('src-b');

      expectDepths(await diveRow(), 28, 14.5);
    });

    test('keeps an unedited file source\'s summary over a computer', () async {
      await seedSource('src-a', computerId: 'dc-a');
      await seedSource(
        'src-file',
        isPrimary: false,
        maxDepth: 28,
        avgDepth: 14.5,
      );

      await makePrimary('src-file');

      expectDepths(await diveRow(), 28, 14.5);
    });
  });

  group('a split', () {
    Future<Dive> diveRowOf(String id) =>
        (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

    Future<List<double>> liveDepthsOf(String id) async => [
      for (final point in await repository.getDiveProfile(id)) point.depth,
    ];

    Future<String> splitOut(String sourceId) =>
        DiveSplitService(repository).split(diveId: diveId, sourceId: sourceId);

    test('gives the new dive the summary of the edit it took', () async {
      await seedSource('src-a', computerId: 'dc-a');
      await seedSource(
        'src-b',
        computerId: 'dc-b',
        isPrimary: false,
        maxDepth: 28,
        avgDepth: 14,
      );
      await saveEdit();

      final newDiveId = await splitOut('src-a');

      expect(await liveDepthsOf(newDiveId), [0, 20, 20, 0]);
      expectDepths(await diveRowOf(newDiveId), 20, 10);
      expect(await liveDepthsOf(diveId), [0, 28, 28, 0]);
      expectDepths(await diveRowOf(diveId), 28, 14);
    });

    test('leaves the summary of an edit that stays on the dive', () async {
      // A source with no computer leaves its live edit behind.
      await seedSource('src-file');
      await seedSource(
        'src-b',
        computerId: 'dc-b',
        isPrimary: false,
        maxDepth: 28,
        avgDepth: 14,
      );
      await saveEdit();

      await splitOut('src-file');

      expect(await liveDepthsOf(diveId), [0, 20, 20, 0]);
      expectDepths(await diveRowOf(diveId), 20, 10);
    });

    test(
      'keeps the promoted source\'s summary over its own live series',
      () async {
        await seedSource('src-a', computerId: 'dc-a');
        await seedSource(
          'src-b',
          computerId: 'dc-b',
          isPrimary: false,
          maxDepth: 28,
          avgDepth: 14.5,
        );
        await (db.update(db.diveProfileSeries)
              ..where((t) => t.sourceId.equals('src-b')))
            .write(const DiveProfileSeriesCompanion(isPrimary: Value(true)));

        await splitOut('src-a');

        expectDepths(await diveRowOf(diveId), 28, 14.5);
      },
    );

    test(
      'keeps the promoted source\'s summary over an unedited file',
      () async {
        // A source with no computer leaves its own primary series behind too,
        // edited or not. Only an edit takes the summary with it.
        await seedSource('src-file');
        await seedSource(
          'src-b',
          computerId: 'dc-b',
          isPrimary: false,
          maxDepth: 28,
          avgDepth: 14.5,
        );

        await splitOut('src-file');

        expectDepths(await diveRowOf(diveId), 28, 14.5);
      },
    );

    test('keeps the source\'s summary when nothing is edited', () async {
      await seedSource('src-a', computerId: 'dc-a', avgDepth: 15.5);
      await seedSource(
        'src-b',
        computerId: 'dc-b',
        isPrimary: false,
        maxDepth: 28,
        avgDepth: 14.5,
      );

      final newDiveId = await splitOut('src-a');

      expectDepths(await diveRowOf(newDiveId), 30, 15.5);
      expectDepths(await diveRowOf(diveId), 28, 14.5);
    });
  });
}
