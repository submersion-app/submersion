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
        FieldPath(['notes']),
        QueryOp.contains,
        const StringValue('manta'),
      ),
    );
    final q = f.toQuery() as AndNode;
    expect(
      q.children,
      containsAll(<QueryNode>[
        ConditionNode(
          FieldPath(['date']),
          QueryOp.gte,
          DateValue(DateTime(2025, 1, 1)),
        ),
        ConditionNode(
          FieldPath(['date']),
          QueryOp.lte,
          DateValue(DateTime(2025, 12, 31)),
        ),
        ConditionNode(
          FieldPath(['weekday']),
          QueryOp.inList,
          ListValue([const EnumValue('monday'), const EnumValue('sunday')]),
        ),
        ConditionNode(
          FieldPath(['types']),
          QueryOp.eq,
          const RefValue('dt1', 'dt1'),
        ),
        ConditionNode(
          FieldPath(['site']),
          QueryOp.eq,
          const RefValue('s1', 's1'),
        ),
        ConditionNode(
          FieldPath(['trip']),
          QueryOp.eq,
          const RefValue('t1', 't1'),
        ),
        ConditionNode(
          FieldPath(['center']),
          QueryOp.eq,
          const RefValue('c1', 'c1'),
        ),
        ConditionNode(
          FieldPath(['computer']),
          QueryOp.eq,
          const RefValue('pc1', 'pc1'),
        ),
        ConditionNode(
          FieldPath(['depth']),
          QueryOp.gte,
          const NumberValue(18, null),
        ),
        ConditionNode(
          FieldPath(['depth']),
          QueryOp.lte,
          const NumberValue(30, null),
        ),
        ScopedNode(
          FieldPath(['tanks']),
          AndNode([
            ConditionNode(
              FieldPath(['o2']),
              QueryOp.gte,
              const NumberValue(30, null),
            ),
            ConditionNode(
              FieldPath(['o2']),
              QueryOp.lte,
              const NumberValue(36, null),
            ),
          ]),
        ),
        ConditionNode(
          FieldPath(['rating']),
          QueryOp.gte,
          const NumberValue(4, null),
        ),
        ConditionNode(
          FieldPath(['bottomTime']),
          QueryOp.gte,
          const NumberValue(20, null),
        ),
        ConditionNode(
          FieldPath(['bottomTime']),
          QueryOp.lte,
          const NumberValue(60, null),
        ),
        ConditionNode(
          FieldPath(['favorite']),
          QueryOp.eq,
          const BoolValue(true),
        ),
        ConditionNode(
          FieldPath(['excludedFromStats']),
          QueryOp.eq,
          const BoolValue(true),
        ),
        ConditionNode(FieldPath(['deco']), QueryOp.eq, const BoolValue(false)),
        ConditionNode(FieldPath(['buddies']), QueryOp.isEmpty, null),
        ConditionNode(
          FieldPath(['tags']),
          QueryOp.inList,
          ListValue([
            const RefValue('tag1', 'tag1'),
            const RefValue('tag2', 'tag2'),
          ]),
        ),
        ConditionNode(
          FieldPath(['gear']),
          QueryOp.inList,
          ListValue([const RefValue('g1', 'g1')]),
        ),
        ConditionNode(
          FieldPath(['id']),
          QueryOp.inList,
          ListValue([const StringValue('d1'), const StringValue('d2')]),
        ),
        ConditionNode(
          FieldPath(['buddies']),
          QueryOp.eq,
          const RefValue('b1', 'b1'),
        ),
        ScopedNode(
          FieldPath(['customFields']),
          AndNode([
            ConditionNode(
              FieldPath(['key']),
              QueryOp.eq,
              const StringValue('Exposure'),
            ),
            ConditionNode(
              FieldPath(['value']),
              QueryOp.contains,
              const StringValue('dry'),
            ),
          ]),
        ),
        ConditionNode(
          FieldPath(['notes']),
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
            FieldPath(['buddies']),
            ConditionNode(
              FieldPath(['name']),
              QueryOp.contains,
              const StringValue('ana'),
            ),
          ),
          ConditionNode(
            FieldPath(['legacyBuddy']),
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
          FieldPath(['gear']),
          AndNode([
            ConditionNode(
              FieldPath(['type']),
              QueryOp.inList,
              ListValue([
                const EnumValue('drysuit'),
                const EnumValue('wetsuit'),
              ]),
            ),
            ScopedNode(
              FieldPath(['attributes']),
              AndNode([
                ConditionNode(
                  FieldPath(['key']),
                  QueryOp.eq,
                  const StringValue('thickness_mm'),
                ),
                ConditionNode(
                  FieldPath(['custom']),
                  QueryOp.eq,
                  const BoolValue(false),
                ),
                ConditionNode(
                  FieldPath(['valueNum']),
                  QueryOp.gte,
                  const NumberValue(5, null),
                ),
                ConditionNode(
                  FieldPath(['valueNum']),
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
        FieldPath(['noSuchField']),
        QueryOp.eq,
        const StringValue('x'),
      ),
    );
    // The notifiers compute this inside listeners; the SQL path reports the
    // error through AsyncValue, this must not throw before it gets there.
    expect(diveFilterTablesTouched(broken), {'dives'});
    // A tree that resolves but is structurally wrong (a text value on a
    // bool field) must not escape either: the compiler's cast would throw
    // a TypeError, not a QueryCompileError.
    final wrongType = DiveFilterState(
      query: ConditionNode(
        FieldPath(['favorite']),
        QueryOp.eq,
        const StringValue('x'),
      ),
    );
    expect(diveFilterTablesTouched(wrongType), {'dives'});
  });
}
