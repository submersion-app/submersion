import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_empty_parse.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';

/// A re-parse rewrites the profile the stored safety review graded, so it
/// must drop that review for the next view to recompute (issue #1641).
void main() {
  late AppDatabase db;
  late ReparseService service;
  late SafetyFindingsRepository reviews;

  final nowMs = DateTime.utc(2026, 1, 15, 10, 0).millisecondsSinceEpoch;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    service = ReparseService(db: db);
    reviews = SafetyFindingsRepository(
      db: db,
      syncRepository: SyncRepository(database: db),
    );

    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: const Value('comp-1'),
            name: const Value('Test Computer'),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
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
    final importedAt = DateTime.fromMillisecondsSinceEpoch(nowMs);
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: const Value('src-1'),
            diveId: const Value('dive-1'),
            computerId: const Value('comp-1'),
            isPrimary: const Value(true),
            sourceFormat: const Value('dive_computer'),
            importedAt: Value(importedAt),
            createdAt: Value(importedAt),
          ),
        );
    await reviews.saveReview(
      SafetyReview(
        diveId: 'dive-1',
        engineVersion: SafetyReviewService.engineVersion,
        reviewedAt: importedAt,
        inputsHash: 'graded-the-old-profile',
        findings: const [],
      ),
    );
  });

  tearDown(() => db.close());

  pigeon.ParsedDive parsed(List<pigeon.ProfileSample> samples) {
    return pigeon.ParsedDive(
      fingerprint: 'fp',
      dateTimeYear: 0,
      dateTimeMonth: 0,
      dateTimeDay: 0,
      dateTimeHour: 0,
      dateTimeMinute: 0,
      dateTimeSecond: 0,
      maxDepthMeters: samples.isEmpty ? 0 : 18.0,
      avgDepthMeters: 0,
      durationSeconds: samples.isEmpty ? 0 : 1200,
      samples: samples,
      tanks: const [],
      gasMixes: const [],
      events: const [],
    );
  }

  Future<void> reparse(pigeon.ParsedDive dive) => service.applyParsedUpdate(
    diveId: 'dive-1',
    sourceRowId: 'src-1',
    parsed: dive,
    descriptorVendor: null,
    descriptorProduct: null,
    descriptorModel: null,
    libdivecomputerVersion: null,
  );

  test('a re-parse drops the stored review so it recomputes', () async {
    expect(await reviews.getReview('dive-1'), isNotNull);

    await reparse(
      parsed([
        pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0),
        pigeon.ProfileSample(timeSeconds: 300, depthMeters: 18),
        pigeon.ProfileSample(timeSeconds: 1200, depthMeters: 0),
      ]),
    );

    expect(
      await reviews.getReview('dive-1'),
      isNull,
      reason: 'the stored review graded the profile the re-parse replaced',
    );
    final deletions = await (db.select(
      db.deletionLog,
    )..where((t) => t.entityType.equals('diveSafetyReviews'))).get();
    expect(
      deletions.map((d) => d.recordId),
      contains('dive-1'),
      reason: 'peers must drop their copy of the stale review too',
    );
  });

  test(
    'keeps the review when the re-parse rewrites nothing it graded',
    () async {
      // A combined dive with no primary row: the source owns no strand and is
      // not primary, so the profile, tanks, gas switches and dive row are all
      // left as they were, and so is the review graded on them.
      await (db.update(db.diveDataSources)..where((t) => t.id.equals('src-1')))
          .write(const DiveDataSourcesCompanion(isPrimary: Value(false)));

      await reparse(
        parsed([
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0),
          pigeon.ProfileSample(timeSeconds: 300, depthMeters: 18),
          pigeon.ProfileSample(timeSeconds: 1200, depthMeters: 0),
        ]),
      );

      expect(await reviews.getReview('dive-1'), isNotNull);
      final deletions = await (db.select(
        db.deletionLog,
      )..where((t) => t.entityType.equals('diveSafetyReviews'))).get();
      expect(deletions, isEmpty, reason: 'peers keep their copy too');
    },
  );

  test('an empty parse writes nothing and keeps the review', () async {
    await expectLater(
      reparse(parsed(const [])),
      throwsA(isA<EmptyParseException>()),
    );

    expect(await reviews.getReview('dive-1'), isNotNull);
  });
}
