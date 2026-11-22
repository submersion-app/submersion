import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/services/hand_set_fields.dart';

import '../../../../helpers/test_database.dart';

/// The computer-written values a diver set by hand (issue #4909).
void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<Dive> insertDive({
    double? maxDepth = 30,
    double? waterTemp = 24,
    int? bottomTime = 2700,
    String? handSetFields,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 1000,
            entryTime: const Value(1000),
            exitTime: const Value(3001000),
            runtime: const Value(3000),
            maxDepth: Value(maxDepth),
            waterTemp: Value(waterTemp),
            bottomTime: Value(bottomTime),
            handSetFields: Value(handSetFields),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    return (db.select(db.dives)..where((t) => t.id.equals('d1'))).getSingle();
  }

  group('HandSetMarks', () {
    test('reads nothing from null, empty and unreadable text', () {
      expect(HandSetMarks.decode(null), isEmpty);
      expect(HandSetMarks.decode(''), isEmpty);
      expect(HandSetMarks.decode('not json'), isEmpty);
      expect(HandSetMarks.decode('{"a": 1}'), isEmpty);
    });

    test('round-trips sorted, and writes null for none', () {
      final text = HandSetMarks.encode({'waterTemp', 'bottomTime'});
      expect(text, '["bottomTime","waterTemp"]');
      expect(HandSetMarks.decode(text), {'bottomTime', 'waterTemp'});
      expect(HandSetMarks.encode(const {}), isNull);
    });

    test('keeps a key this version does not know, from a newer peer', () {
      final marks = HandSetMarks.decode('["waterTemp","heartRate"]');
      expect(marks, {'waterTemp', 'heartRate'});
      expect(
        HandSetMarks.encode(marks.union({'bottomTime'})),
        '["bottomTime","heartRate","waterTemp"]',
      );
    });
  });

  group('changedHandSetFields', () {
    test('names each field whose columns differ', () async {
      final before = await insertDive();
      final after = before.copyWith(
        waterTemp: const Value(26),
        entryTime: const Value(2000),
        diveDateTime: 2000,
        notes: 'changed notes are not a computer value',
      );
      expect(changedHandSetFields(before, after), {
        HandSetField.waterTemp,
        HandSetField.entryTime,
      });
    });

    test('a value cleared by hand counts', () async {
      final before = await insertDive();
      expect(
        changedHandSetFields(
          before,
          before.copyWith(maxDepth: const Value(null)),
        ),
        {HandSetField.maxDepth},
      );
    });

    test('a diluent read back with its helium filled in is no change, nor '
        'is an unknown mode read back as open circuit', () async {
      // The dive page reads a missing helium as 0 and an unknown mode as
      // open circuit, and writes them back on any Save.
      final before = (await insertDive()).copyWith(
        diluentO2: const Value(21),
        diveMode: 'future-mode',
      );
      expect(
        changedHandSetFields(
          before,
          before.copyWith(diluentHe: const Value(0), diveMode: 'oc'),
        ),
        isEmpty,
      );
    });

    test('a diluent is one field of two columns', () async {
      final before = (await insertDive()).copyWith(diluentO2: const Value(10));
      expect(
        changedHandSetFields(
          before,
          before.copyWith(diluentHe: const Value(35)),
        ),
        {HandSetField.diluent},
      );
    });
  });

  group('keepHandSetFields', () {
    const parse = DivesCompanion(
      maxDepth: Value(31.5),
      waterTemp: Value(22),
      bottomTime: Value(2650),
      runtime: Value(3000),
    );

    test('leaves a dive with nothing marked to the parse', () async {
      final stored = await insertDive();
      final guarded = keepHandSetFields(parse, stored);
      expect(guarded.companion, parse);
      expect(guarded.kept, isEmpty);
    });

    test('keeps a marked value the parse would change, and says so', () async {
      final stored = await insertDive(
        handSetFields: '["waterTemp","bottomTime"]',
      );
      final guarded = keepHandSetFields(parse, stored);
      expect(guarded.companion.waterTemp.present, isFalse);
      expect(guarded.companion.bottomTime.present, isFalse);
      expect(guarded.companion.maxDepth, const Value(31.5));
      expect(guarded.companion.handSetFields.present, isFalse);
      expect(
        [for (final c in guarded.kept) (c.field, c.storedValue, c.parsedValue)],
        [
          (HandSetField.bottomTime, 2700, 2650),
          (HandSetField.waterTemp, 24.0, 22.0),
        ],
      );
    });

    test('a marked value the parse agrees with is not listed', () async {
      final stored = await insertDive(handSetFields: '["runtime"]');
      final guarded = keepHandSetFields(parse, stored);
      expect(guarded.kept, isEmpty);
      expect(guarded.companion.runtime.present, isFalse);
    });

    test('a marked value the parse leaves out is not listed', () async {
      final stored = await insertDive(handSetFields: '["maxDepth"]');
      final guarded = keepHandSetFields(
        const DivesCompanion(waterTemp: Value(22)),
        stored,
      );
      expect(guarded.kept, isEmpty);
    });

    test('a kept start moves the parse\'s exit with it', () async {
      // Stored: start 1000, runtime 3000 s. The diver moved the start.
      final stored = await insertDive(handSetFields: '["entryTime"]');
      final guarded = keepHandSetFields(
        const DivesCompanion(
          entryTime: Value(500),
          diveDateTime: Value(500),
          runtime: Value(2000),
          exitTime: Value(500 + 2000 * 1000),
        ),
        stored,
      );
      expect(guarded.companion.entryTime.present, isFalse);
      expect(guarded.companion.exitTime, const Value(1000 + 2000 * 1000));
    });

    test('a kept runtime keeps the exit at start plus runtime', () async {
      final stored = await insertDive(handSetFields: '["runtime"]');
      final guarded = keepHandSetFields(
        const DivesCompanion(runtime: Value(2000), exitTime: Value(2001000)),
        stored,
      );
      expect(guarded.companion.exitTime, const Value(1000 + 3000 * 1000));
    });

    test('a kept exit stays as the diver set it', () async {
      final stored = await insertDive(
        handSetFields: '["entryTime","exitTime"]',
      );
      final guarded = keepHandSetFields(
        const DivesCompanion(entryTime: Value(500), exitTime: Value(9)),
        stored,
      );
      expect(guarded.companion.exitTime.present, isFalse);
    });

    test(
      'a replacement whose value changed since the preview is kept',
      () async {
        // The diver saw 20 degrees and chose the parse; meanwhile a sync
        // brought their newer 24 degrees, which they never saw.
        final stored = await insertDive(handSetFields: '["waterTemp"]');
        final guarded = keepHandSetFields(
          parse,
          stored,
          replace: const [
            HandSetChange(
              field: HandSetField.waterTemp,
              storedValue: 20.0,
              parsedValue: 22.0,
            ),
          ],
        );
        expect(guarded.companion.waterTemp.present, isFalse);
        expect(guarded.companion.handSetFields.present, isFalse);
        expect(
          [for (final c in guarded.kept) c.field],
          [HandSetField.waterTemp],
        );
      },
    );

    test('every marked field keeps all of its columns', () async {
      final stored = await insertDive(
        handSetFields: HandSetMarks.encode({
          for (final field in HandSetField.values) field.name,
        }),
      );
      final guarded = keepHandSetFields(
        const DivesCompanion(
          maxDepth: Value(1),
          avgDepth: Value(1),
          runtime: Value(1),
          entryTime: Value(1),
          diveDateTime: Value(1),
          exitTime: Value(1),
          bottomTime: Value(1),
          waterTemp: Value(1),
          diveMode: Value('ccr'),
          gradientFactorLow: Value(1),
          gradientFactorHigh: Value(1),
          decoAlgorithm: Value('vpm'),
          decoConservatism: Value(1),
          diluentO2: Value(1),
          diluentHe: Value(1),
          updatedAt: Value(5),
        ),
        stored,
      );
      expect(guarded.companion, const DivesCompanion(updatedAt: Value(5)));
    });

    test('a kept start with no runtime leaves the parse\'s exit', () async {
      await insertDive(handSetFields: '["entryTime"]');
      await db.customStatement('UPDATE dives SET runtime = NULL');
      final row = await db.select(db.dives).getSingle();
      final guarded = keepHandSetFields(
        const DivesCompanion(exitTime: Value(42)),
        row,
      );
      expect(guarded.companion.exitTime, const Value(42));
    });

    test('replace takes the parse and clears only that mark', () async {
      final stored = await insertDive(
        handSetFields: '["bottomTime","heartRate","waterTemp"]',
      );
      final guarded = keepHandSetFields(
        parse,
        stored,
        replace: const [
          HandSetChange(
            field: HandSetField.waterTemp,
            storedValue: 24.0,
            parsedValue: 22.0,
          ),
        ],
      );
      expect(guarded.companion.waterTemp, const Value(22.0));
      expect(guarded.companion.bottomTime.present, isFalse);
      expect(
        guarded.companion.handSetFields,
        const Value('["bottomTime","heartRate"]'),
      );
      expect(
        [for (final c in guarded.kept) c.field],
        [HandSetField.bottomTime],
      );
    });
  });

  // Merge and split (issue #4909): a mark follows the value it marked.
  group('carryHandSetMarks', () {
    Future<Dive> row(String id) =>
        (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

    Future<void> insertTarget({
      double? waterTemp = 24,
      int? runtime = 3000,
      String? handSetFields,
    }) => db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 't1',
            diveDateTime: 1000,
            runtime: Value(runtime),
            waterTemp: Value(waterTemp),
            handSetFields: Value(handSetFields),
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    test('a marked value the new dive took keeps its mark; a recomputed '
        'one loses it', () async {
      final source = await insertDive(handSetFields: '["runtime","waterTemp"]');
      await insertTarget(runtime: 5400);

      await carryHandSetMarks(db, 't1', [source]);

      expect((await row('t1')).handSetFields, '["waterTemp"]');
    });

    test('marks come from whichever source the value came from', () async {
      final marked = await insertDive(handSetFields: '["waterTemp"]');
      final unmarked = marked.copyWith(
        id: 'd2',
        waterTemp: const Value(21),
        handSetFields: const Value(null),
      );
      await insertTarget(waterTemp: 21);

      await carryHandSetMarks(db, 't1', [marked, unmarked]);

      expect((await row('t1')).handSetFields, isNull);
    });

    test('a key this version does not know is carried as it is', () async {
      final source = await insertDive(handSetFields: '["heartRate"]');
      await insertTarget();

      await carryHandSetMarks(db, 't1', [source]);

      expect((await row('t1')).handSetFields, '["heartRate"]');
    });

    test('the new dive\'s own marks are replaced by what carries', () async {
      final source = await insertDive(handSetFields: '["runtime"]');
      await insertTarget(runtime: 5400, handSetFields: '["runtime"]');

      await carryHandSetMarks(db, 't1', [source]);

      expect((await row('t1')).handSetFields, isNull);
    });
  });
}
