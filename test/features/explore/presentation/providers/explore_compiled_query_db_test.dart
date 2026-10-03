import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

import '../../../../helpers/test_database.dart';

/// Queries the Explore compiler builds from a sentence (what Ask applies,
/// #2773), run against a real database, so the SQL they compile to is
/// actually executed.
void main() {
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  test(
    'query-tree clauses from the compiler run against the database',
    () async {
      // The fields with no plain filter axis compile to query-tree
      // conditions; this runs them as SQL, including the hop through the
      // types junction to a dive type's name.
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value('match'),
              diveDateTime: Value(now),
              createdAt: Value(now),
              updatedAt: Value(now),
              avgDepth: const Value(18),
              diveMode: const Value('ccr'),
            ),
          );
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value('other'),
              diveDateTime: Value(now),
              createdAt: Value(now),
              updatedAt: Value(now),
              avgDepth: const Value(9),
              diveMode: const Value('ccr'),
            ),
          );
      await db
          .into(db.diveTypes)
          .insert(
            DiveTypesCompanion(
              id: const Value('custom-cavern'),
              name: const Value('Cavern Tour'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      for (final dive in ['match', 'other']) {
        await db
            .into(db.diveDiveTypes)
            .insert(
              DiveDiveTypesCompanion(
                id: Value('j-$dive'),
                diveId: Value(dive),
                diveTypeId: const Value('custom-cavern'),
                createdAt: Value(now),
              ),
            );
      }
      final compiled = ExploreCompiler.compile(
        ParsedQuery.fromJson({
          'schemaVersion': kQuerySchemaVersion,
          'subject': 'dives',
          'clauses': [
            {'field': 'avgDepth', 'op': 'gt', 'value': 15, 'text': 'avg'},
            {'field': 'diveMode', 'op': 'eq', 'value': 'ccr', 'text': 'ccr'},
            {
              'field': 'diveType',
              'op': 'eq',
              'value': ['wreck penetration', 'CAVERN TOUR'],
              'text': 'cavern',
            },
          ],
        }),
        ExploreCompilerContext(
          units: const UnitPrefs(
            depth: DepthUnit.meters,
            temperature: TemperatureUnit.celsius,
            pressure: PressureUnit.bar,
            weight: WeightUnit.kilograms,
            volume: VolumeUnit.liters,
          ),
          names: NameIndex.empty,
          now: DateTime(2026, 9, 28),
        ),
      );
      expect(compiled.unplaced, isEmpty);
      final results = await DiveRepository().getDiveSummaries(
        filter: DiveFilterState(query: compiled.query),
        limit: 100,
      );
      expect(results.map((s) => s.id), ['match']);
    },
  );

  test('a not clause keeps dives with the field unrecorded', () async {
    for (final (id, current) in [
      ('strong', 'strong'),
      ('light', 'light'),
      ('blank', null),
    ]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: Value(id),
              diveDateTime: Value(now),
              createdAt: Value(now),
              updatedAt: Value(now),
              currentStrength: Value(current),
            ),
          );
    }
    final compiled = ExploreCompiler.compile(
      ParsedQuery.fromJson({
        'schemaVersion': kQuerySchemaVersion,
        'subject': 'dives',
        'clauses': [
          {
            'field': 'currentStrength',
            'op': 'not',
            'value': ['strong'],
            'text': 'not strong current',
          },
        ],
      }),
      ExploreCompilerContext(
        units: const UnitPrefs(
          depth: DepthUnit.meters,
          temperature: TemperatureUnit.celsius,
          pressure: PressureUnit.bar,
          weight: WeightUnit.kilograms,
          volume: VolumeUnit.liters,
        ),
        names: NameIndex.empty,
        now: DateTime(2026, 9, 28),
      ),
    );
    final results = await DiveRepository().getDiveSummaries(
      filter: DiveFilterState(query: compiled.query),
      limit: 100,
    );
    expect(results.map((s) => s.id).toSet(), {'light', 'blank'});
  });
}
