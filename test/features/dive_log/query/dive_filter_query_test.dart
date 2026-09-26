import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';

void main() {
  test('an empty filter lowers to null', () {
    expect(const DiveFilterState().toQuery(), isNull);
    expect(compileDiveFilter(const DiveFilterState()).isEmpty, isTrue);
  });

  test('every axis lowers to the documented condition', () {
    final f = DiveFilterState(
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 12, 31),
      weekdays: const [1, 7],
      diveTypeId: 'dt1',
      siteId: 's1',
      tripId: 't1',
      diveCenterId: 'c1',
      computerId: 'pc1',
      minDepth: 18,
      maxDepth: 30,
      minO2Percent: 30,
      maxO2Percent: 36,
      minRating: 4,
      minBottomTimeMinutes: 20,
      maxBottomTimeMinutes: 60,
      favoritesOnly: true,
      excludedFromStatsOnly: true,
      decoOnly: false,
      noBuddyOnly: true,
      tagIds: const ['tag1', 'tag2'],
      equipmentIds: const ['g1'],
      diveIds: const ['d1', 'd2'],
      buddyNameFilter: 'ana, cid',
      buddyId: 'b1',
      customFieldKey: 'Exposure',
      customFieldValue: 'dry',
      equipmentAttrConditions: [
        EquipmentAttrCondition.suitThickness(min: 5, max: 7),
      ],
      query: ConditionNode(
        const FieldPath(['notes']),
        QueryOp.contains,
        const StringValue('manta'),
      ),
    );
    final q = f.toQuery() as AndNode;
    expect(
      q.children,
      containsAll(<QueryNode>[
        ConditionNode(
          const FieldPath(['date']),
          QueryOp.gte,
          DateValue(DateTime(2025, 1, 1)),
        ),
        ConditionNode(
          const FieldPath(['date']),
          QueryOp.lte,
          DateValue(DateTime(2025, 12, 31)),
        ),
        ConditionNode(
          const FieldPath(['weekday']),
          QueryOp.inList,
          const ListValue([EnumValue('monday'), EnumValue('sunday')]),
        ),
        ConditionNode(
          const FieldPath(['types']),
          QueryOp.eq,
          const RefValue('dt1', 'dt1'),
        ),
        ConditionNode(
          const FieldPath(['site']),
          QueryOp.eq,
          const RefValue('s1', 's1'),
        ),
        ConditionNode(
          const FieldPath(['trip']),
          QueryOp.eq,
          const RefValue('t1', 't1'),
        ),
        ConditionNode(
          const FieldPath(['center']),
          QueryOp.eq,
          const RefValue('c1', 'c1'),
        ),
        ConditionNode(
          const FieldPath(['computer']),
          QueryOp.eq,
          const RefValue('pc1', 'pc1'),
        ),
        ConditionNode(
          const FieldPath(['depth']),
          QueryOp.gte,
          const NumberValue(18, null),
        ),
        ConditionNode(
          const FieldPath(['depth']),
          QueryOp.lte,
          const NumberValue(30, null),
        ),
        ScopedNode(
          const FieldPath(['tanks']),
          AndNode([
            ConditionNode(
              const FieldPath(['o2']),
              QueryOp.gte,
              const NumberValue(30, null),
            ),
            ConditionNode(
              const FieldPath(['o2']),
              QueryOp.lte,
              const NumberValue(36, null),
            ),
          ]),
        ),
        ConditionNode(
          const FieldPath(['rating']),
          QueryOp.gte,
          const NumberValue(4, null),
        ),
        ConditionNode(
          const FieldPath(['bottomTime']),
          QueryOp.gte,
          const NumberValue(20, null),
        ),
        ConditionNode(
          const FieldPath(['bottomTime']),
          QueryOp.lte,
          const NumberValue(60, null),
        ),
        ConditionNode(
          const FieldPath(['favorite']),
          QueryOp.eq,
          const BoolValue(true),
        ),
        ConditionNode(
          const FieldPath(['excludedFromStats']),
          QueryOp.eq,
          const BoolValue(true),
        ),
        ConditionNode(
          const FieldPath(['deco']),
          QueryOp.eq,
          const BoolValue(false),
        ),
        ConditionNode(const FieldPath(['buddies']), QueryOp.isEmpty, null),
        ConditionNode(
          const FieldPath(['tags']),
          QueryOp.inList,
          const ListValue([RefValue('tag1', 'tag1'), RefValue('tag2', 'tag2')]),
        ),
        ConditionNode(
          const FieldPath(['gear']),
          QueryOp.inList,
          const ListValue([RefValue('g1', 'g1')]),
        ),
        ConditionNode(
          const FieldPath(['id']),
          QueryOp.inList,
          const ListValue([StringValue('d1'), StringValue('d2')]),
        ),
        ConditionNode(
          const FieldPath(['buddies']),
          QueryOp.eq,
          const RefValue('b1', 'b1'),
        ),
        ScopedNode(
          const FieldPath(['customFields']),
          AndNode([
            ConditionNode(
              const FieldPath(['key']),
              QueryOp.eq,
              const StringValue('Exposure'),
            ),
            ConditionNode(
              const FieldPath(['value']),
              QueryOp.contains,
              const StringValue('dry'),
            ),
          ]),
        ),
        ConditionNode(
          const FieldPath(['notes']),
          QueryOp.contains,
          const StringValue('manta'),
        ),
      ]),
    );
    // The buddy-name filter: each comma part must match a linked buddy OR
    // the legacy text, and the parts AND.
    expect(
      q.children,
      contains(
        OrNode([
          ScopedNode(
            const FieldPath(['buddies']),
            ConditionNode(
              const FieldPath(['name']),
              QueryOp.contains,
              const StringValue('ana'),
            ),
          ),
          ConditionNode(
            const FieldPath(['legacyBuddy']),
            QueryOp.contains,
            const StringValue('ana'),
          ),
        ]),
      ),
    );
    // The suit-thickness condition: a suit whose thickness_mm row is in
    // range.
    expect(
      q.children,
      contains(
        ScopedNode(
          const FieldPath(['gear']),
          AndNode([
            ConditionNode(
              const FieldPath(['type']),
              QueryOp.inList,
              const ListValue([EnumValue('drysuit'), EnumValue('wetsuit')]),
            ),
            ScopedNode(
              const FieldPath(['attributes']),
              AndNode([
                ConditionNode(
                  const FieldPath(['key']),
                  QueryOp.eq,
                  const StringValue('thickness_mm'),
                ),
                ConditionNode(
                  const FieldPath(['custom']),
                  QueryOp.eq,
                  const BoolValue(false),
                ),
                ConditionNode(
                  const FieldPath(['valueNum']),
                  QueryOp.gte,
                  const NumberValue(5, null),
                ),
                ConditionNode(
                  const FieldPath(['valueNum']),
                  QueryOp.lte,
                  const NumberValue(7, null),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  });

  test('a blank buddy-name filter lowers to nothing', () {
    expect(const DiveFilterState(buddyNameFilter: ' , ').toQuery(), isNull);
  });

  test('the compiled filter names the tables it reads', () {
    expect(
      diveFilterTablesTouched(const DiveFilterState(noBuddyOnly: true)),
      containsAll(['dives', 'buddies', 'dive_buddies']),
    );
    expect(
      diveFilterTablesTouched(const DiveFilterState(decoOnly: true)),
      containsAll(['dive_profile_series', 'dive_profile_events']),
    );
    expect(diveFilterTablesTouched(const DiveFilterState()), {'dives'});
  });

  test('an invalid advanced query never throws out of the tick lookup', () {
    final broken = DiveFilterState(
      query: ConditionNode(
        const FieldPath(['noSuchField']),
        QueryOp.eq,
        const StringValue('x'),
      ),
    );
    // The notifiers compute this inside listeners; the SQL path reports the
    // error through AsyncValue, this must not throw before it gets there.
    expect(diveFilterTablesTouched(broken), {'dives'});
  });
}
