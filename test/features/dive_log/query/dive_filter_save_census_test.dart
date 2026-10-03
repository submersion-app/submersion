import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';

/// Spec 5.4: Save writes toQuery() of the whole search and loading shows it
/// as text. Every axis must survive the saved JSON, relabelling from the
/// name index, printing and re-parsing, or a saved search would come back
/// different from what the diver saved.
void main() {
  const labels = {
    QuerySubject.sites: {'Salt Pier': 's1', 'Bari Reef': 's2'},
    QuerySubject.trips: {'Bonaire 2025': 't1'},
    QuerySubject.centers: {'Buddy Dive': 'c1'},
    QuerySubject.computers: {'Perdix': 'k1'},
    QuerySubject.diveTypes: {'Shore': 'shore'},
    QuerySubject.tags: {'Night': 'g1', 'Wreck': 'g2'},
    QuerySubject.equipment: {'Reg A': 'e1'},
    QuerySubject.buddies: {'Ana Lee': 'b1'},
    QuerySubject.species: {'Turtle': 'sp1'},
  };
  final samples = <String, DiveFilterState>{
    'startDate': DiveFilterState(startDate: DateTime(2025, 1, 1)),
    'endDate': DiveFilterState(endDate: DateTime(2025, 6, 30)),
    'diveTypeId': const DiveFilterState(diveTypeId: 'shore'),
    'siteId': const DiveFilterState(siteId: 's1'),
    'tripId': const DiveFilterState(tripId: 't1'),
    'diveCenterId': const DiveFilterState(diveCenterId: 'c1'),
    'minDepth': const DiveFilterState(minDepth: 10),
    'maxDepth': const DiveFilterState(maxDepth: 30.5),
    'favoritesOnly': const DiveFilterState(favoritesOnly: true),
    'excludedFromStatsOnly': const DiveFilterState(excludedFromStatsOnly: true),
    'decoOnly': const DiveFilterState(decoOnly: false),
    'noBuddyOnly': const DiveFilterState(noBuddyOnly: true),
    'tagIds': const DiveFilterState(tagIds: ['g1', 'g2']),
    'weekdays': const DiveFilterState(weekdays: [1, 6]),
    'equipmentIds': const DiveFilterState(equipmentIds: ['e1']),
    'buddyNameFilter': const DiveFilterState(buddyNameFilter: 'Ana'),
    'buddyId': const DiveFilterState(buddyId: 'b1'),
    'diveIds': const DiveFilterState(diveIds: ['d1', 'd2']),
    'minO2Percent': const DiveFilterState(minO2Percent: 28),
    'maxO2Percent': const DiveFilterState(maxO2Percent: 36),
    'minRating': const DiveFilterState(minRating: 4),
    'minBottomTimeMinutes': const DiveFilterState(minBottomTimeMinutes: 30),
    'maxBottomTimeMinutes': const DiveFilterState(maxBottomTimeMinutes: 60),
    'computerId': const DiveFilterState(computerId: 'k1'),
    'customFieldKey': const DiveFilterState(customFieldKey: 'Guide'),
    'customFieldValue': const DiveFilterState(
      customFieldKey: 'Guide',
      customFieldValue: 'Sam',
    ),
    'equipmentAttrConditions': const DiveFilterState(
      equipmentAttrConditions: [
        EquipmentAttrCondition(key: 'hose_type', choices: {'hp', 'lpi'}),
      ],
    ),
    'minWaterTemp': const DiveFilterState(minWaterTemp: 18),
    'maxWaterTemp': const DiveFilterState(maxWaterTemp: 26),
    'minVisibility': const DiveFilterState(minVisibility: 5),
    'maxVisibility': const DiveFilterState(maxVisibility: 20),
    'waterTypes': const DiveFilterState(waterTypes: [WaterType.salt]),
    'speciesIds': const DiveFilterState(speciesIds: ['sp1']),
    'siteIds': const DiveFilterState(siteIds: ['s1', 's2']),
    'query': DiveFilterState(query: TextNode(['manta'])),
  };

  test('every DiveFilterState field has a sample', () {
    final state = File(
      p.join(
        'lib',
        'features',
        'dive_log',
        'domain',
        'models',
        'dive_filter_state.dart',
      ),
    ).readAsStringSync();
    final fields =
        RegExp(
            r'^  final [\w<>?, ]+ (\w+);',
            multiLine: true,
          ).allMatches(state).map((m) => m[1]!).toSet()
          // Not a search axis: it switches the others off (spec 5.3).
          ..remove('axesSuspended');
    expect(fields.difference(samples.keys.toSet()), isEmpty);
  });

  for (final (unitName, prefs) in [
    ('metric', kMetricPrefs),
    (
      'imperial',
      const UnitPrefs(
        depth: DepthUnit.feet,
        temperature: TemperatureUnit.fahrenheit,
        pressure: PressureUnit.psi,
        weight: WeightUnit.pounds,
        volume: VolumeUnit.cubicFeet,
      ),
    ),
  ]) {
    final ctx = QueryEditorContext(
      registry: appQueryRegistry,
      root: diveQueryEntity,
      prefs: prefs,
      names: const MapNameResolver(labels),
      labels: const MapQueryLabels(),
      now: () => DateTime(2026, 9, 25),
    );
    final index = NameIndex([
      for (final MapEntry(key: subject, value: byLabel) in labels.entries)
        for (final MapEntry(key: label, value: id) in byLabel.entries)
          NameEntry(
            subject: subject,
            label: label,
            ids: [id],
            target: rowTargetFor(subject),
            primary: true,
          ),
    ]);
    for (final MapEntry(key: name, value: filter) in samples.entries) {
      test('$name survives save and reload ($unitName)', () {
        // As saveQueryFromEditor stores it: a group of one is flattened.
        final saved = flattenOneChildGroups(normalizeQuery(filter.toQuery())!);
        final reloaded = queryNodeFromJson(
          (jsonDecode(jsonEncode(queryNodeToJson(saved))) as Map)
              .cast<String, Object?>(),
        );
        expect(reloaded, saved, reason: 'JSON');
        final shown = refreshRefLabels(
          reloaded,
          diveQueryEntity,
          appQueryRegistry,
          index,
        );
        final text = ctx.printer.print(shown);
        final reparsed = switch (ctx.parser.parse(text)) {
          ParseOk(:final node) => normalizeQuery(node),
          ParseFailure(:final error) => fail('"$text": ${error.message}'),
        };
        expect(
          jsonEncode(queryNodeToJson(_idsOnly(reparsed!))),
          jsonEncode(queryNodeToJson(_idsOnly(saved))),
          reason: text,
        );
      });
    }
  }
}

/// [node] with every ref label dropped and numbers to a thousandth, so a
/// tree compares by what it selects: the saved query stores ids and
/// relabels them on load, and the printer rounds in the diver's unit.
QueryNode _idsOnly(QueryNode node) => switch (node) {
  AndNode(:final children) => AndNode([for (final c in children) _idsOnly(c)]),
  OrNode(:final children) => OrNode([for (final c in children) _idsOnly(c)]),
  NotNode(:final child) => NotNode(_idsOnly(child)),
  ScopedNode(:final path, :final inner) => ScopedNode(path, _idsOnly(inner)),
  ConditionNode(:final path, :final op, :final value) => ConditionNode(
    path,
    op,
    _valueIdsOnly(value),
  ),
  TextNode() => node,
};

QueryValue? _valueIdsOnly(QueryValue? v) => switch (v) {
  RefValue(:final id) => RefValue(id, ''),
  // Printing keeps four decimals in the diver's unit, so a bound typed in
  // feet or Fahrenheit re-reads within a thousandth of the stored value.
  NumberValue(:final value) => NumberValue((value * 1000).round() / 1000, null),
  ListValue(:final items) => ListValue([
    for (final i in items) _valueIdsOnly(i)!,
  ]),
  _ => v,
};
