import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/insights/presentation/insights_saved_group.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';

void main() {
  final names = NameIndex.fromRefs(const {
    QuerySubject.tags: [
      RefValue('t-dry', 'Drysuit'),
      RefValue('t-wet', 'Wetsuit'),
    ],
    QuerySubject.diveTypes: [RefValue('dt-cave', 'Cave')],
  });

  SavedQuery row(String name, String json) => SavedQuery(
    id: name,
    subject: 'dives',
    name: name,
    queryJson: json,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  /// [filter] as the app stores it and reads it back: what Save writes, then
  /// the load path, which replaces each ref's id with its current name.
  SavedQueryLoad savedAs(String name, DiveFilterState filter) {
    final stored = flattenOneChildGroups(insightsFilterQuery(filter)!);
    return loadSavedQuery(
      row(name, jsonEncode(queryNodeToJson(stored))),
      appQueryRegistry,
      names,
    );
  }

  group('activeSavedGroup', () {
    test('no filter is no group', () {
      final cold = savedAs('Cold', const DiveFilterState(maxWaterTemp: 15));

      expect(activeSavedGroup(const DiveFilterState(), [cold]), isNull);
    });

    test('a filter set in the panel matches the group saved from it', () {
      const filter = DiveFilterState(maxWaterTemp: 15);
      final cold = savedAs('Cold', filter);

      expect(activeSavedGroup(filter, [cold])?.saved.name, 'Cold');
    });

    test('a tag group matches though loading renamed its ref', () {
      // The ref is lowered as (id, id) and loaded as (id, name), so comparing
      // them as they stand would miss every tag and dive type group.
      const filter = DiveFilterState(tagIds: ['t-dry']);
      final dry = savedAs('Drysuit dives', filter);

      expect(activeSavedGroup(filter, [dry])?.saved.name, 'Drysuit dives');
    });

    test('a dive type group matches though loading renamed its ref', () {
      const filter = DiveFilterState(diveTypeId: 'dt-cave');
      final cave = savedAs('Caves', filter);

      expect(activeSavedGroup(filter, [cave])?.saved.name, 'Caves');
    });

    test('a group of several axes matches', () {
      const filter = DiveFilterState(tagIds: ['t-dry'], maxWaterTemp: 15);
      final group = savedAs('Cold drysuit', filter);

      expect(activeSavedGroup(filter, [group])?.saved.name, 'Cold drysuit');
    });

    test('a picked group still matches itself', () {
      final dry = savedAs(
        'Drysuit dives',
        const DiveFilterState(tagIds: ['t-dry']),
      );

      expect(
        activeSavedGroup(DiveFilterState(query: dry.node), [dry])?.saved.name,
        'Drysuit dives',
      );
    });

    test('a group refined further is no longer that group', () {
      final dry = savedAs(
        'Drysuit dives',
        const DiveFilterState(tagIds: ['t-dry']),
      );

      expect(
        activeSavedGroup(DiveFilterState(query: dry.node, minRating: 4), [dry]),
        isNull,
      );
    });

    test('another tag is another group', () {
      final dry = savedAs(
        'Drysuit dives',
        const DiveFilterState(tagIds: ['t-dry']),
      );

      expect(
        activeSavedGroup(const DiveFilterState(tagIds: ['t-wet']), [dry]),
        isNull,
      );
    });

    test('picks the matching group out of several', () {
      final dry = savedAs(
        'Drysuit dives',
        const DiveFilterState(tagIds: ['t-dry']),
      );
      final wet = savedAs(
        'Wetsuit dives',
        const DiveFilterState(tagIds: ['t-wet']),
      );

      expect(
        activeSavedGroup(const DiveFilterState(tagIds: ['t-wet']), [
          dry,
          wet,
        ])?.saved.name,
        'Wetsuit dives',
      );
    });

    group('ignores ref labels however deep they sit', () {
      ConditionNode tag(String id) => ConditionNode(
        FieldPath(const ['tags']),
        QueryOp.inList,
        ListValue([RefValue(id, id)]),
      );

      test('in an OR group', () {
        final filter = DiveFilterState(
          query: OrNode([tag('t-dry'), tag('t-wet')]),
        );
        final group = savedAs('Any suit', filter);

        expect(activeSavedGroup(filter, [group])?.saved.name, 'Any suit');
      });

      test('under a NOT', () {
        final filter = DiveFilterState(query: NotNode(tag('t-dry')));
        final group = savedAs('Not drysuit', filter);

        expect(activeSavedGroup(filter, [group])?.saved.name, 'Not drysuit');
      });

      test('in a scoped condition', () {
        final filter = DiveFilterState(
          equipmentAttrConditions: [
            EquipmentAttrCondition.suitThickness(min: 7),
          ],
        );
        final group = savedAs('Thick suit', filter);

        expect(activeSavedGroup(filter, [group])?.saved.name, 'Thick suit');
      });
    });

    test('a group whose tag was deleted still matches', () {
      const filter = DiveFilterState(tagIds: ['t-gone']);
      final gone = savedAs('Gone', filter);

      expect(gone.problem, SavedQueryProblem.unresolvedRef);
      expect(activeSavedGroup(filter, [gone])?.saved.name, 'Gone');
    });

    test('a query this build cannot read matches nothing', () {
      final broken = loadSavedQuery(
        row('Broken', 'not json'),
        appQueryRegistry,
        names,
      );

      expect(
        activeSavedGroup(const DiveFilterState(maxWaterTemp: 15), [broken]),
        isNull,
      );
    });
  });

  group('insightsFilterQuery', () {
    test('is null for no filter', () {
      expect(insightsFilterQuery(const DiveFilterState()), isNull);
    });

    test('is what Save stores for a filter', () {
      expect(
        insightsFilterQuery(const DiveFilterState(maxWaterTemp: 15)),
        isA<ConditionNode>(),
      );
    });
  });
}
