import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';

void main() {
  final names = NameIndex.fromRefs(const {
    QuerySubject.sites: [RefValue('s1', 'Salt Pier')],
  });
  SavedQuery saved(String json, {String subject = 'dives'}) => SavedQuery(
    id: 'q',
    subject: subject,
    name: 'n',
    queryJson: json,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  String encode(QueryNode n) => jsonEncode(queryNodeToJson(n));
  final depth = ConditionNode(
    FieldPath(['depth']),
    QueryOp.gt,
    const NumberValue(30, null),
  );

  test('a clean tree loads with no problem', () {
    final load = loadSavedQuery(saved(encode(depth)), appQueryRegistry, names);
    expect(load.node, depth);
    expect(load.problem, isNull);
    expect(load.isApplicable, isTrue);
  });

  test('a newer JSON version is unreadable, not a crash', () {
    final load = loadSavedQuery(
      saved('{"version":99,"node":{}}'),
      appQueryRegistry,
      names,
    );
    expect(load.node, isNull);
    expect(load.problem, SavedQueryProblem.unreadable);
    expect(load.detail, isNotEmpty);
    expect(load.isApplicable, isFalse);
  });

  test('corrupt text is unreadable', () {
    final load = loadSavedQuery(saved('not json'), appQueryRegistry, names);
    expect(load.problem, SavedQueryProblem.unreadable);
    final array = loadSavedQuery(saved('[1, 2]'), appQueryRegistry, names);
    expect(array.problem, SavedQueryProblem.unreadable);
  });

  test('a tree naming a field this build lacks is invalid', () {
    final ghost = ConditionNode(
      FieldPath(['warpFactor']),
      QueryOp.gt,
      const NumberValue(9, null),
    );
    final load = loadSavedQuery(saved(encode(ghost)), appQueryRegistry, names);
    expect(load.node, isNull);
    expect(load.problem, SavedQueryProblem.invalid);
    expect(load.detail, contains('warpFactor'));
  });

  test('an unknown subject is flagged', () {
    final load = loadSavedQuery(
      saved(encode(depth), subject: 'starships'),
      appQueryRegistry,
      names,
    );
    expect(load.problem, SavedQueryProblem.unknownSubject);
    expect(load.isApplicable, isFalse);
  });

  test('an unresolved ref flags the load but keeps the tree', () {
    final gone = AndNode([
      depth,
      ConditionNode(
        FieldPath(['site']),
        QueryOp.eq,
        const RefValue('s-gone', 'Old Wall'),
      ),
    ]);
    final load = loadSavedQuery(saved(encode(gone)), appQueryRegistry, names);
    expect(load.node, gone);
    expect(load.problem, SavedQueryProblem.unresolvedRef);
    expect(load.isApplicable, isTrue);
    expect(
      unresolvedRefPaths(
        gone,
        appQueryRegistry.entityFor(QuerySubject.dives),
        appQueryRegistry,
        names,
      ),
      [
        FieldPath(['site']),
      ],
    );
  });

  test('refs inside a scoped group and a list are checked too', () {
    final tree = ScopedNode(
      FieldPath(['buddies']),
      ConditionNode(
        FieldPath(['certifications']),
        QueryOp.inList,
        ListValue([const RefValue('c-gone', 'Rescue')]),
      ),
    );
    final paths = unresolvedRefPaths(
      tree,
      appQueryRegistry.entityFor(QuerySubject.dives),
      appQueryRegistry,
      names,
    );
    expect(paths, [
      FieldPath(['buddies', 'certifications']),
    ]);
  });

  test('a renamed ref shows its current name once loaded', () {
    final stored = ConditionNode(
      FieldPath(['site']),
      QueryOp.eq,
      const RefValue('s1', 'Old Pier'),
    );
    final load = loadSavedQuery(saved(encode(stored)), appQueryRegistry, names);
    expect(load.problem, isNull);
    expect(
      load.node,
      ConditionNode(
        FieldPath(['site']),
        QueryOp.eq,
        const RefValue('s1', 'Salt Pier'),
      ),
    );
  });

  test('labels refresh inside NOT, lists and scoped groups; a missing ref '
      'keeps its stored name', () {
    final index = NameIndex.fromRefs(const {
      QuerySubject.sites: [RefValue('s1', 'Salt Pier')],
      QuerySubject.certifications: [RefValue('c1', 'Rescue Diver')],
    });
    QueryNode tree(String siteLabel, String certLabel) => AndNode([
      NotNode(
        ConditionNode(
          FieldPath(['site']),
          QueryOp.inList,
          ListValue([
            RefValue('s1', siteLabel),
            const RefValue('s-gone', 'Old Wall'),
          ]),
        ),
      ),
      ScopedNode(
        FieldPath(['buddies']),
        ConditionNode(
          FieldPath(['certifications']),
          QueryOp.eq,
          RefValue('c1', certLabel),
        ),
      ),
    ]);
    final refreshed = refreshRefLabels(
      tree('Old Pier', 'Rescue'),
      appQueryRegistry.entityFor(QuerySubject.dives),
      appQueryRegistry,
      index,
    );
    expect(refreshed, tree('Salt Pier', 'Rescue Diver'));
  });
}
