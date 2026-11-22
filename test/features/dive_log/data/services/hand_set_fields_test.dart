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

    test('replace takes the parse and clears only that mark', () async {
      final stored = await insertDive(
        handSetFields: '["bottomTime","heartRate","waterTemp"]',
      );
      final guarded = keepHandSetFields(
        parse,
        stored,
        replace: {HandSetField.waterTemp},
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
}
