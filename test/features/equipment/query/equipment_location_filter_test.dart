import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/query/equipment_filter_query.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['reg', 'bcd', 'fins']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    // Names differ from ids: the filter and the typed field both work on
    // the name the diver sees.
    for (final (id, name) in [('shop', "Joe's Scuba"), ('garage', 'Garage')]) {
      await db
          .into(db.equipmentLocations)
          .insert(
            EquipmentLocationsCompanion.insert(
              id: id,
              name: name,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    Future<void> move(String id, String e, String? l, int at) => db
        .into(db.equipmentLocationMoves)
        .insert(
          EquipmentLocationMovesCompanion.insert(
            id: id,
            equipmentId: e,
            locationId: Value(l),
            movedAt: at,
            createdAt: at,
          ),
        );
    // reg went to the garage, then the shop; bcd is in the garage; fins
    // never moved.
    await move('1', 'reg', 'garage', 1);
    await move('2', 'reg', 'shop', 2);
    await move('3', 'bcd', 'garage', 1);
  });

  tearDown(tearDownTestDatabase);

  Future<Set<String>> ids(EquipmentFilterState f) =>
      QueryIdSetRunner(db).ids(compileEquipmentFilter(f));

  test('filters by current place, not past ones', () async {
    expect(await ids(const EquipmentFilterState(locationNames: {'Garage'})), {
      'bcd',
    });
    expect(
      await ids(const EquipmentFilterState(locationNames: {"Joe's Scuba"})),
      {'reg'},
    );
  });

  test('No location matches items never moved, ORed with places', () async {
    expect(await ids(const EquipmentFilterState(noLocation: true)), {'fins'});
    expect(
      await ids(
        const EquipmentFilterState(
          locationNames: {"Joe's Scuba"},
          noLocation: true,
        ),
      ),
      {'reg', 'fins'},
    );
  });

  test('a place name matches whatever its case', () async {
    expect(await ids(const EquipmentFilterState(locationNames: {'garage'})), {
      'bcd',
    });
  });

  test(
    'typing a place name in the advanced builder finds the gear there',
    () async {
      final typed = EquipmentFilterState(
        query: ConditionNode(
          FieldPath(['location']),
          QueryOp.eq,
          const StringValue("Joe's Scuba"),
        ),
      );
      expect(await ids(typed), {'reg'});
    },
  );

  test('the field reads the moves table, so the list refreshes on a move', () {
    final compiled = compileEquipmentFilter(
      const EquipmentFilterState(locationNames: {"Joe's Scuba"}),
    );
    expect(compiled.tablesTouched, contains('equipment_location_moves'));
  });

  test('the location axis counts as an active filter and clears', () {
    const filtered = EquipmentFilterState(
      locationNames: {"Joe's Scuba"},
      noLocation: true,
    );
    expect(filtered.hasActiveFilters, isTrue);
    final cleared = filtered.copyWith(clearLocation: true);
    expect(cleared.locationNames, isEmpty);
    expect(cleared.noLocation, isFalse);
    expect(cleared.hasActiveFilters, isFalse);
    expect(
      filtered,
      const EquipmentFilterState(
        locationNames: {"Joe's Scuba"},
        noLocation: true,
      ),
    );
  });
}
