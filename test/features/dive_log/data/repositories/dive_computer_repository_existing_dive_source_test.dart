import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

/// Issue #2002: a profile attached to an EXISTING dive must leave a
/// dive_data_sources row (so a re-download is caught by the fingerprint
/// pass and the series has an owning source), and planned dives must be
/// invisible to the fuzzy and contained-segment matches.
void main() {
  late AppDatabase db;
  late DiveComputerRepository repository;
  late ProfileSeriesRepository profileSeries;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerRepository();
    profileSeries = ProfileSeriesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<String> insertComputer({String id = 'computer-1'}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: const Value('Perdix'),
            manufacturer: const Value('Shearwater'),
            model: const Value('Perdix'),
            serialNumber: Value('SN-$id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  Future<String> insertDive({
    required DateTime start,
    bool isPlanned = false,
    String? computerId,
  }) async {
    final id = 'dive-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(start.millisecondsSinceEpoch),
            entryTime: Value(start.millisecondsSinceEpoch),
            bottomTime: const Value(600),
            maxDepth: const Value(10),
            computerId: Value(computerId),
            isPlanned: Value(isPlanned),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  List<ProfilePointData> flatProfile() => [
    for (var t = 0; t <= 600; t += 10)
      ProfilePointData(timestamp: t, depth: 10),
  ];

  group('attach to existing dive', () {
    test('inserts a primary data source with the fingerprint', () async {
      final computerId = await insertComputer();
      final diveId = await insertDive(start: DateTime(2026, 6, 1, 9));
      final fingerprint = Uint8List.fromList([1, 2, 3]);

      final returned = await repository.importProfile(
        computerId: computerId,
        profileStartTime: DateTime(2026, 6, 1, 9, 2),
        points: flatProfile(),
        durationSeconds: 600,
        maxDepth: 10,
        rawFingerprint: fingerprint,
      );

      expect(returned, diveId);
      final sources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(sources, hasLength(1));
      expect(sources.single.isPrimary, isTrue);
      expect(sources.single.computerId, computerId);
      expect(sources.single.rawFingerprint, fingerprint);
      final series = await profileSeries.getRowsForDives([diveId]);
      expect(series.single.sourceId, sources.single.id);
    });

    test('a re-download is found by the fingerprint pass', () async {
      final computerId = await insertComputer();
      final diveId = await insertDive(start: DateTime(2026, 6, 1, 9));
      await repository.importProfile(
        computerId: computerId,
        profileStartTime: DateTime(2026, 6, 1, 9, 2),
        points: flatProfile(),
        durationSeconds: 600,
        maxDepth: 10,
        rawFingerprint: Uint8List.fromList([1, 2, 3]),
      );
      final keys = await DiveRepository().getSourceKeysByDiveId();
      expect(keys[diveId], contains('010203'));
    });

    test('a dive that already has a primary source gets a secondary', () async {
      final a = await insertComputer(id: 'computer-a');
      final b = await insertComputer(id: 'computer-b');
      final diveId = await repository.importProfile(
        computerId: a,
        profileStartTime: DateTime(2026, 6, 1, 9),
        points: flatProfile(),
        durationSeconds: 600,
        maxDepth: 10,
        forceNew: true,
      );
      await repository.importProfile(
        computerId: b,
        profileStartTime: DateTime(2026, 6, 1, 9, 1),
        points: flatProfile(),
        durationSeconds: 600,
        maxDepth: 10,
      );
      final sources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(sources, hasLength(2));
      final byComputer = {for (final s in sources) s.computerId: s.isPrimary};
      expect(byComputer[a], isTrue);
      expect(byComputer[b], isFalse);
    });

    test('a summary-only source is demoted, leaving one primary', () async {
      // A UDDF-imported dive carries a primary source row and no samples.
      // The download becomes the dive's profile, so it takes the primary
      // flag and the older row must lose it: readers take the first
      // primary row they find.
      final computerId = await insertComputer();
      final diveId = await insertDive(start: DateTime(2026, 6, 1, 9));
      final now = DateTime.now();
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

      await repository.importProfile(
        computerId: computerId,
        profileStartTime: DateTime(2026, 6, 1, 9, 2),
        points: flatProfile(),
        durationSeconds: 600,
        maxDepth: 10,
      );

      final sources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      final primaries = sources.where((s) => s.isPrimary).toList();
      expect(primaries, hasLength(1));
      expect(primaries.single.computerId, computerId);
    });

    test('a second import from the same computer adds no second row', () async {
      final computerId = await insertComputer();
      final diveId = await insertDive(start: DateTime(2026, 6, 1, 9));
      for (var i = 0; i < 2; i++) {
        await repository.importProfile(
          computerId: computerId,
          profileStartTime: DateTime(2026, 6, 1, 9, 2),
          points: flatProfile(),
          durationSeconds: 600,
          maxDepth: 10,
        );
      }
      final sources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(sources, hasLength(1));
    });
  });

  group('planned dives are invisible to matching', () {
    test('findMatchingDiveWithScore skips a planned dive', () async {
      await insertDive(start: DateTime(2026, 6, 1, 9), isPlanned: true);
      final match = await repository.findMatchingDiveWithScore(
        profileStartTime: DateTime(2026, 6, 1, 9, 1),
        durationSeconds: 600,
        maxDepth: 10,
      );
      expect(match, isNull);
    });

    test('findMatchingDiveWithScore still finds a logged dive', () async {
      final diveId = await insertDive(start: DateTime(2026, 6, 1, 9));
      final match = await repository.findMatchingDiveWithScore(
        profileStartTime: DateTime(2026, 6, 1, 9, 1),
        durationSeconds: 600,
        maxDepth: 10,
      );
      expect(match?.diveId, diveId);
    });

    test('findComputerDivesContainingTime skips a planned dive', () async {
      final computerId = await insertComputer();
      final diveId = await insertDive(
        start: DateTime(2026, 6, 1, 9),
        isPlanned: true,
        computerId: computerId,
      );
      await profileSeries.insertSeries(
        diveId: diveId,
        computerId: computerId,
        samples: [
          for (var t = 0; t <= 1800; t += 30)
            ProfileSample(timestamp: t, depth: 10.0),
        ],
      );
      final hits = await repository.findComputerDivesContainingTime(
        computerId: computerId,
        time: DateTime(2026, 6, 1, 9, 5),
      );
      expect(hits, isEmpty);
    });
  });
}
