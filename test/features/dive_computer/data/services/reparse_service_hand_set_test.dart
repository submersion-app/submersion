import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_log/data/services/hand_set_fields.dart';

/// A re-parse keeps the values the diver set by hand, unless the diver
/// chooses the parse's value for one (issue #4909).
void main() {
  late AppDatabase db;
  late ReparseService service;

  final nowMs = DateTime.utc(2026, 1, 15, 10, 0).millisecondsSinceEpoch;
  final storedStartMs = DateTime.utc(2025, 6, 1, 9, 30).millisecondsSinceEpoch;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    service = ReparseService(db: db);
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(storedStartMs),
            entryTime: Value(storedStartMs),
            maxDepth: const Value(30),
            runtime: const Value(2880),
            bottomTime: const Value(2400),
            // The diver corrected the computer's 22 degrees to 26.
            waterTemp: const Value(26),
            handSetFields: const Value('["waterTemp"]'),
            notes: const Value(''),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
    for (final (id, primary) in [('src-1', true), ('src-2', false)]) {
      final importedAt = DateTime.fromMillisecondsSinceEpoch(nowMs);
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: Value(id),
              diveId: const Value('dive-1'),
              isPrimary: Value(primary),
              sourceFormat: const Value('dive_computer'),
              descriptorVendor: const Value('Mares'),
              descriptorProduct: const Value('Smart'),
              descriptorModel: const Value(16),
              rawData: Value(Uint8List.fromList([1, 2, 3])),
              importedAt: Value(importedAt),
              createdAt: Value(importedAt),
            ),
          );
    }
  });

  tearDown(() => db.close());

  final parse = pigeon.ParsedDive(
    fingerprint: 'fp',
    dateTimeYear: 0,
    dateTimeMonth: 0,
    dateTimeDay: 0,
    dateTimeHour: 0,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 31.5,
    avgDepthMeters: 0,
    durationSeconds: 2880,
    minTemperatureCelsius: 22,
    samples: [
      pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0),
      pigeon.ProfileSample(timeSeconds: 600, depthMeters: 31.5),
      pigeon.ProfileSample(timeSeconds: 2880, depthMeters: 0),
    ],
    tanks: const [],
    gasMixes: const [],
    events: const [],
  );

  Future<({Dive row, List<HandSetChange> kept})> apply({
    String source = 'src-1',
    Iterable<HandSetChange> replace = const [],
  }) async {
    final outcome = await service.applyParsedUpdate(
      diveId: 'dive-1',
      sourceRowId: source,
      parsed: parse,
      descriptorVendor: 'Mares',
      descriptorProduct: 'Smart',
      descriptorModel: 16,
      libdivecomputerVersion: null,
      replaceHandSet: replace,
    );
    final row = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('dive-1'))).getSingle();
    return (row: row, kept: outcome.handSetKept);
  }

  test('keeps a hand-set value and writes the rest of the parse', () async {
    final result = await apply();
    expect(result.row.waterTemp, 26);
    expect(result.row.maxDepth, 31.5);
    expect(result.row.handSetFields, '["waterTemp"]');
    expect(
      [for (final c in result.kept) (c.field, c.storedValue, c.parsedValue)],
      [(HandSetField.waterTemp, 26.0, 22.0)],
    );
  });

  test('replace takes the parse and clears the mark', () async {
    final result = await apply(
      replace: const [
        HandSetChange(
          field: HandSetField.waterTemp,
          storedValue: 26.0,
          parsedValue: 22.0,
        ),
      ],
    );
    expect(result.row.waterTemp, 22);
    expect(result.row.handSetFields, isNull);
    expect(result.kept, isEmpty);
  });

  test('a secondary source writes none of the dive values', () async {
    final result = await apply(source: 'src-2');
    expect(result.row.waterTemp, 26);
    expect(result.kept, isEmpty);
  });

  group('previewHandSetChanges', () {
    Future<List<HandSetChange>> preview(String source) =>
        service.previewHandSetChanges(
          diveId: 'dive-1',
          sourceRowId: source,
          parsed: parse,
          descriptorVendor: 'Mares',
        );

    test('lists what the parse would replace and writes nothing', () async {
      final changes = await preview('src-1');
      expect(
        [for (final c in changes) (c.field, c.storedValue, c.parsedValue)],
        [(HandSetField.waterTemp, 26.0, 22.0)],
      );
      final row = await (db.select(db.dives)).getSingle();
      expect(row.maxDepth, 30);
      final source = await (db.select(
        db.diveDataSources,
      )..where((t) => t.id.equals('src-1'))).getSingle();
      expect(source.lastParsedAt, isNull);
    });

    test('a secondary source would replace nothing', () async {
      expect(await preview('src-2'), isEmpty);
    });

    test('an empty parse would replace nothing', () async {
      final empty = await service.previewHandSetChanges(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: pigeon.ParsedDive(
          fingerprint: 'fp',
          dateTimeYear: 0,
          dateTimeMonth: 0,
          dateTimeDay: 0,
          dateTimeHour: 0,
          dateTimeMinute: 0,
          dateTimeSecond: 0,
          maxDepthMeters: 0,
          avgDepthMeters: 0,
          durationSeconds: 0,
          samples: const [],
          tanks: const [],
          gasMixes: const [],
          events: const [],
        ),
        descriptorVendor: 'Mares',
      );
      expect(empty, isEmpty);
    });

    test('a dive with nothing marked would lose nothing', () async {
      await db.customStatement('UPDATE dives SET hand_set_fields = NULL');
      expect(await preview('src-1'), isEmpty);
    });
  });
}
