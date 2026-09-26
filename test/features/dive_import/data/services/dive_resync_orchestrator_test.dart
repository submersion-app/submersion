import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/services/dive_resync_orchestrator.dart';
import 'package:submersion/features/dive_import/domain/dive_resync_failure.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';

class _FakeImportedFiles extends ImportedFileRepository {
  final Map<String, Uint8List> files;
  _FakeImportedFiles(this.files);

  @override
  Future<Uint8List?> read(String id) async => files[id];
}

class _FakeParser implements ImportParser {
  final ImportPayload payload;
  _FakeParser(this.payload);

  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.uddf];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async => payload;
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<String> seedDiveWithSource({
    required DateTime dateTime,
    required double maxDepth,
    required int bottomTimeSeconds,
    required String importedFileId,
    String sourceFileFormat = 'uddf',
    int? runtimeSeconds,
    String? sourceDiverKey,
  }) async {
    const diveId = 'dive-1';
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diveDateTime: dateTime.millisecondsSinceEpoch,
            maxDepth: Value(maxDepth),
            bottomTime: Value(bottomTimeSeconds),
            runtime: Value(runtimeSeconds),
            createdAt: dateTime.millisecondsSinceEpoch,
            updatedAt: dateTime.millisecondsSinceEpoch,
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-1',
            diveId: diveId,
            isPrimary: const Value(true),
            importedAt: dateTime,
            createdAt: dateTime,
            sourceFileFormat: Value(sourceFileFormat),
            importedFileId: Value(importedFileId),
            sourceDiverKey: Value(sourceDiverKey),
          ),
        );
    return diveId;
  }

  test('fails cleanly when the dive has no stored file', () async {
    const diveId = 'dive-none';
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diveDateTime: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    final orchestrator = DiveResyncOrchestrator(
      db: db,
      importedFiles: _FakeImportedFiles(const {}),
      parserFor: (_) => throw StateError('must not be called'),
    );

    final outcome = await orchestrator.resync(diveId);

    expect(outcome.succeeded, isFalse);
    expect(outcome.failureReason, DiveResyncFailure.noStoredFile);
  });

  test('fails cleanly for a dive that no longer exists', () async {
    final orchestrator = DiveResyncOrchestrator(
      db: db,
      importedFiles: _FakeImportedFiles(const {}),
      parserFor: (_) => throw StateError('must not be called'),
    );

    final outcome = await orchestrator.resync('does-not-exist');

    expect(outcome.succeeded, isFalse);
    expect(outcome.failureReason, DiveResyncFailure.diveMissing);
  });

  test(
    'fails cleanly when this device does not hold the stored file',
    () async {
      final dateTime = DateTime(2026, 9, 1, 9);
      final diveId = await seedDiveWithSource(
        dateTime: dateTime,
        maxDepth: 18.0,
        bottomTimeSeconds: 40 * 60,
        importedFileId: 'file-uddf',
      );

      final orchestrator = DiveResyncOrchestrator(
        db: db,
        importedFiles: _FakeImportedFiles(const {}),
        parserFor: (_) => throw StateError('must not be called'),
      );

      final outcome = await orchestrator.resync(diveId);

      expect(outcome.succeeded, isFalse);
      expect(outcome.failureReason, DiveResyncFailure.storedFileMissing);
    },
  );

  test('fails cleanly for a format resync does not support', () async {
    final dateTime = DateTime(2026, 9, 1, 9);
    final diveId = await seedDiveWithSource(
      dateTime: dateTime,
      maxDepth: 18.0,
      bottomTimeSeconds: 40 * 60,
      importedFileId: 'file-csv',
      sourceFileFormat: 'csv',
    );

    final orchestrator = DiveResyncOrchestrator(
      db: db,
      importedFiles: _FakeImportedFiles({'file-csv': Uint8List(0)}),
      parserFor: (_) => throw StateError('must not be called'),
    );

    final outcome = await orchestrator.resync(diveId);

    expect(outcome.succeeded, isFalse);
    expect(outcome.failureReason, DiveResyncFailure.unsupportedFormat);
  });

  test('fails cleanly when the stored format string is unrecognized', () async {
    final dateTime = DateTime(2026, 9, 1, 9);
    final diveId = await seedDiveWithSource(
      dateTime: dateTime,
      maxDepth: 18.0,
      bottomTimeSeconds: 40 * 60,
      importedFileId: 'file-bin',
      sourceFileFormat: 'someFutureFormatThatDoesNotExistYet',
    );

    final orchestrator = DiveResyncOrchestrator(
      db: db,
      importedFiles: _FakeImportedFiles({'file-bin': Uint8List(0)}),
      parserFor: (_) => throw StateError('must not be called'),
    );

    final outcome = await orchestrator.resync(diveId);

    expect(outcome.succeeded, isFalse);
    expect(outcome.failureReason, DiveResyncFailure.unsupportedFormat);
  });

  test('picks the matching dive out of a multi-dive stored file', () async {
    final dateTime = DateTime(2026, 9, 1, 9);
    final diveId = await seedDiveWithSource(
      dateTime: dateTime,
      maxDepth: 18.0,
      bottomTimeSeconds: 40 * 60,
      importedFileId: 'file-uddf',
    );

    final payload = ImportPayload(
      entities: {
        ImportEntityType.dives: [
          {
            'dateTime': dateTime.add(const Duration(days: 3)),
            'maxDepth': 30.0,
            'duration': const Duration(minutes: 35),
          },
          {
            'dateTime': dateTime,
            'maxDepth': 18.2,
            'duration': const Duration(minutes: 41),
          },
        ],
      },
    );

    final orchestrator = DiveResyncOrchestrator(
      db: db,
      importedFiles: _FakeImportedFiles({'file-uddf': Uint8List(0)}),
      parserFor: (_) => _FakeParser(payload),
    );

    final outcome = await orchestrator.resync(diveId);

    expect(outcome.succeeded, isTrue);
    final dive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals(diveId))).getSingle();
    expect(dive.maxDepth, 18.2); // matched index 1, not index 0
  });

  test('carries the preserved-profile signal out of the writer', () async {
    final dateTime = DateTime(2026, 9, 1, 9);
    final diveId = await seedDiveWithSource(
      dateTime: dateTime,
      maxDepth: 18.0,
      bottomTimeSeconds: 40 * 60,
      importedFileId: 'file-uddf',
    );
    // A second source makes the dive multi-source, so the writer refuses to
    // touch the profile strand and the caller has to be able to say so.
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-2',
            diveId: diveId,
            isPrimary: const Value(false),
            importedAt: dateTime,
            createdAt: dateTime,
          ),
        );

    final payload = ImportPayload(
      entities: {
        ImportEntityType.dives: [
          {
            'dateTime': dateTime,
            'maxDepth': 18.2,
            'duration': const Duration(minutes: 41),
          },
        ],
      },
    );

    final orchestrator = DiveResyncOrchestrator(
      db: db,
      importedFiles: _FakeImportedFiles({'file-uddf': Uint8List(0)}),
      parserFor: (_) => _FakeParser(payload),
    );

    final outcome = await orchestrator.resync(diveId);

    expect(outcome.succeeded, isTrue);
    expect(outcome.profilePreserved, isTrue);
  });

  test('fails when no parsed dive scores as a probable match', () async {
    final dateTime = DateTime(2026, 9, 1, 9);
    final diveId = await seedDiveWithSource(
      dateTime: dateTime,
      maxDepth: 18.0,
      bottomTimeSeconds: 40 * 60,
      importedFileId: 'file-uddf',
    );

    final payload = ImportPayload(
      entities: {
        ImportEntityType.dives: [
          {
            'dateTime': dateTime.add(const Duration(days: 30)),
            'maxDepth': 5.0,
            'duration': const Duration(minutes: 10),
          },
        ],
      },
    );

    final orchestrator = DiveResyncOrchestrator(
      db: db,
      importedFiles: _FakeImportedFiles({'file-uddf': Uint8List(0)}),
      parserFor: (_) => _FakeParser(payload),
    );

    final outcome = await orchestrator.resync(diveId);

    expect(outcome.succeeded, isFalse);
    expect(outcome.failureReason, DiveResyncFailure.noMatchingDive);
  });

  test('scores a candidate that carries runtime rather than duration', () async {
    // UDDF emits `runtime` and never `duration`, so reading only `duration`
    // drops the 20% duration weight entirely. With a depth the parser fix just
    // moved, time 0.50 + depth 0.10 is 0.60 -- under the 0.70 threshold -- so
    // the resync refuses the very match it exists to deliver.
    final dateTime = DateTime(2026, 9, 1, 9);
    final diveId = await seedDiveWithSource(
      dateTime: dateTime,
      maxDepth: 18.0,
      bottomTimeSeconds: 41 * 60,
      importedFileId: 'file-uddf',
    );

    final payload = ImportPayload(
      entities: {
        ImportEntityType.dives: [
          {
            'dateTime': dateTime,
            'maxDepth': 21.0,
            'runtime': const Duration(minutes: 41),
          },
        ],
      },
    );

    final orchestrator = DiveResyncOrchestrator(
      db: db,
      importedFiles: _FakeImportedFiles({'file-uddf': Uint8List(0)}),
      parserFor: (_) => _FakeParser(payload),
    );

    final outcome = await orchestrator.resync(diveId);

    expect(outcome.succeeded, isTrue);
    final dive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals(diveId))).getSingle();
    expect(dive.maxDepth, 21.0);
  });

  test('matches the very parser fix it exists to deliver', () async {
    // The reviewer's worked example. The stored dive was imported with an
    // ft/m depth bug, so the fixed parse reports a depth that scores 0; the
    // whole remaining margin is the duration weight, and it is only there if
    // like is compared with like. The stored bottom time excludes ascent and
    // stops, so scoring the candidate's total time against it spends the
    // margin on a difference that is not a disagreement at all.
    final dateTime = DateTime(2026, 9, 1, 9);
    final diveId = await seedDiveWithSource(
      dateTime: dateTime,
      maxDepth: 18.0,
      bottomTimeSeconds: 42 * 60,
      runtimeSeconds: 50 * 60,
      importedFileId: 'file-uddf',
    );

    final payload = ImportPayload(
      entities: {
        ImportEntityType.dives: [
          {
            'dateTime': dateTime,
            'maxDepth': 60.0,
            'runtime': const Duration(minutes: 50),
          },
        ],
      },
    );

    final orchestrator = DiveResyncOrchestrator(
      db: db,
      importedFiles: _FakeImportedFiles({'file-uddf': Uint8List(0)}),
      parserFor: (_) => _FakeParser(payload),
    );

    final outcome = await orchestrator.resync(diveId);

    expect(outcome.succeeded, isTrue, reason: outcome.failureReason?.name);
    final dive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals(diveId))).getSingle();
    expect(dive.maxDepth, 60.0);
  });

  test('falls back to the stored bottom time when the dive has no '
      'runtime', () async {
    // Dives imported before `runtime` was filled have only a bottom time, so
    // the comparison has to degrade to it rather than to zero.
    final dateTime = DateTime(2026, 9, 1, 9);
    final diveId = await seedDiveWithSource(
      dateTime: dateTime,
      maxDepth: 18.0,
      bottomTimeSeconds: 42 * 60,
      importedFileId: 'file-uddf',
    );

    final payload = ImportPayload(
      entities: {
        ImportEntityType.dives: [
          {
            'dateTime': dateTime,
            'maxDepth': 60.0,
            'runtime': const Duration(minutes: 42),
          },
        ],
      },
    );

    final orchestrator = DiveResyncOrchestrator(
      db: db,
      importedFiles: _FakeImportedFiles({'file-uddf': Uint8List(0)}),
      parserFor: (_) => _FakeParser(payload),
    );

    expect((await orchestrator.resync(diveId)).succeeded, isTrue);
  });

  test('reads runtime first when a parser fills both', () async {
    // macdiveXml fills both, and they mean different things: `duration` is the
    // bottom time, `runtime` the whole dive. The dive's own total time is what
    // the candidate is scored against, so `runtime` is the half of the pair
    // that belongs in the comparison -- pairing `duration` with the stored
    // bottom time is what this dive's numbers would defeat.
    final dateTime = DateTime(2026, 9, 1, 9);
    final diveId = await seedDiveWithSource(
      dateTime: dateTime,
      maxDepth: 18.0,
      bottomTimeSeconds: 30 * 60,
      runtimeSeconds: 95 * 60,
      importedFileId: 'file-uddf',
    );

    final payload = ImportPayload(
      entities: {
        ImportEntityType.dives: [
          {
            'dateTime': dateTime,
            'maxDepth': 60.0,
            'duration': const Duration(minutes: 41),
            'runtime': const Duration(minutes: 95),
          },
        ],
      },
    );

    final orchestrator = DiveResyncOrchestrator(
      db: db,
      importedFiles: _FakeImportedFiles({'file-uddf': Uint8List(0)}),
      parserFor: (_) => _FakeParser(payload),
    );

    expect((await orchestrator.resync(diveId)).succeeded, isTrue);
  });

  group('a logbook shared by several divers (#1921)', () {
    // Two divers logging the same buddy dive: same start, near-identical
    // depth and time, so both score as a probable match for either diver's
    // copy. The depths differ just enough to tell which one was replayed.
    final dateTime = DateTime(2026, 9, 1, 9);
    Map<String, dynamic> diveBy(
      String diverKey, {
      double maxDepth = 18.0,
      Duration offset = Duration.zero,
    }) => {
      'dateTime': dateTime.add(offset),
      'maxDepth': maxDepth,
      'duration': const Duration(minutes: 40),
      SourceDiver.mapKey: diverKey,
    };

    Future<Dive> resyncAgainst(
      List<Map<String, dynamic>> candidates, {
      String? storedKey,
      void Function(DiveResyncOutcome)? expectOutcome,
    }) async {
      final diveId = await seedDiveWithSource(
        dateTime: dateTime,
        maxDepth: 18.0,
        bottomTimeSeconds: 40 * 60,
        importedFileId: 'file-macdive',
        sourceFileFormat: 'macdiveXml',
        sourceDiverKey: storedKey,
      );
      final orchestrator = DiveResyncOrchestrator(
        db: db,
        importedFiles: _FakeImportedFiles({'file-macdive': Uint8List(0)}),
        parserFor: (_) => _FakeParser(
          ImportPayload(entities: {ImportEntityType.dives: candidates}),
        ),
      );

      expectOutcome?.call(await orchestrator.resync(diveId));
      return (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();
    }

    test('replays the stored diver\'s dive even when the buddy\'s copy '
        'scores higher', () async {
      final dive = await resyncAgainst(
        [
          // The buddy's copy matches this dive exactly, so an unfiltered
          // scorer picks it.
          diveBy('name:Bo Ray', maxDepth: 18.0),
          diveBy('name:Ann Lee', maxDepth: 18.4),
        ],
        storedKey: 'name:Ann Lee',
        expectOutcome: (o) => expect(o.succeeded, isTrue),
      );

      expect(dive.maxDepth, 18.4);
    });

    test('fails rather than fall back to the buddy when the stored diver '
        'has no matching dive left', () async {
      final dive = await resyncAgainst(
        [diveBy('name:Bo Ray', maxDepth: 18.2)],
        storedKey: 'name:Ann Lee',
        expectOutcome: (o) {
          expect(o.succeeded, isFalse);
          expect(o.failureReason, DiveResyncFailure.noMatchingDive);
        },
      );

      expect(dive.maxDepth, 18.0);
    });

    test('treats dives the file attributes to no one as a diver of their '
        'own', () async {
      final dive = await resyncAgainst(
        [
          diveBy('name:Bo Ray', maxDepth: 18.0),
          diveBy(SourceDiver.unownedKey, maxDepth: 18.4),
        ],
        storedKey: SourceDiver.unownedKey,
        expectOutcome: (o) => expect(o.succeeded, isTrue),
      );

      expect(dive.maxDepth, 18.4);
    });

    group('with no stored key (imported before it was recorded)', () {
      test('refuses when two divers each have a matching dive', () async {
        final dive = await resyncAgainst(
          [
            diveBy('name:Bo Ray', maxDepth: 18.2),
            diveBy('name:Ann Lee', maxDepth: 18.4),
          ],
          expectOutcome: (o) {
            expect(o.succeeded, isFalse);
            expect(o.failureReason, DiveResyncFailure.ambiguousDiver);
          },
        );

        expect(dive.maxDepth, 18.0);
      });

      test('resyncs when only one diver has a matching dive', () async {
        final dive = await resyncAgainst([
          diveBy(
            'name:Bo Ray',
            maxDepth: 30.0,
            offset: const Duration(days: 2),
          ),
          diveBy('name:Ann Lee', maxDepth: 18.4),
        ], expectOutcome: (o) => expect(o.succeeded, isTrue));

        expect(dive.maxDepth, 18.4);
      });

      test('resyncs when every matching dive is the same diver\'s', () async {
        final dive = await resyncAgainst([
          diveBy('name:Ann Lee', maxDepth: 18.4),
          diveBy(
            'name:Ann Lee',
            maxDepth: 18.2,
            offset: const Duration(minutes: 5),
          ),
        ], expectOutcome: (o) => expect(o.succeeded, isTrue));

        expect(dive.maxDepth, 18.4);
      });
    });
  });
}
