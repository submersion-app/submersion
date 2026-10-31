import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/sql/dive_weight_sql.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// `recordedWeightKgSql` and `Dive.recordedWeightKg` spell one rule in two
/// languages. Issue #3914 was what drift between such spellings looks like:
/// a dive page and Insights giving different answers for the same dive.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  const cases = <String, ({List<double> rows, double? scalar, double? kg})>{
    'nothing recorded': (rows: [], scalar: null, kg: null),
    'scalar only': (rows: [], scalar: 6, kg: 6),
    'zero scalar': (rows: [], scalar: 0, kg: null),
    'negative scalar': (rows: [], scalar: -1, kg: null),
    'rows only': (rows: [4, 2], scalar: null, kg: 6),
    'rows beside a scalar': (rows: [4, 2], scalar: 9, kg: 6),
    'rows totalling zero beside a scalar': (rows: [0], scalar: 9, kg: 0),
  };

  for (final MapEntry(key: name, value: c) in cases.entries) {
    test('SQL and Dart agree: $name', () async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value('d'),
              diveDateTime: const Value(0),
              weightAmount: Value(c.scalar),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
      final weights = [
        for (final (i, kg) in c.rows.indexed)
          domain.DiveWeight(
            id: 'w$i',
            diveId: 'd',
            weightType: WeightType.belt,
            amountKg: kg,
          ),
      ];
      for (final w in weights) {
        await db
            .into(db.diveWeights)
            .insert(
              DiveWeightsCompanion(
                id: Value(w.id),
                diveId: Value(w.diveId),
                weightType: Value(w.weightType.name),
                amountKg: Value(w.amountKg),
                createdAt: const Value(0),
              ),
            );
      }

      final row = await db
          .customSelect(
            'SELECT ${recordedWeightKgSql('d')} AS kg '
            "FROM dives d WHERE d.id = 'd'",
          )
          .getSingle();
      final dive = domain.Dive(
        id: 'd',
        dateTime: DateTime.utc(2026),
        weightAmount: c.scalar,
        weights: weights,
      );

      expect(row.read<double?>('kg'), c.kg);
      expect(dive.recordedWeightKg, c.kg);
    });
  }
}
