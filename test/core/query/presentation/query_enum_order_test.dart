import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/presentation/query_value_editor.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/syntax/query_parse_context.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import 'query_value_editor_test.dart' show kTestBuilderStrings;

// Its own entity, so the shared fixture's field lists stay as other tests
// expect them. gearType is declared out of label order on purpose.
const _gear = QueryEntity(
  subject: QuerySubject.equipment,
  table: 'equipment',
  fields: [
    QueryField(
      key: 'gearType',
      type: FieldType.enumName,
      sql: '{r}.type',
      emptySql: '{r}.type IS NULL',
      labelKey: 'x',
      enumValues: ['bcd', 'tank', 'computer', 'transmitter'],
      enumOrder: EnumOrder.byLabel,
    ),
    QueryField(
      key: 'waterType',
      type: FieldType.enumName,
      sql: '{r}.water_type',
      emptySql: '{r}.water_type IS NULL',
      labelKey: 'x',
      enumValues: ['salt', 'fresh', 'brackish'],
    ),
  ],
);
final _registry = QueryRegistry([_gear]);

/// The order the builder offers an enum's values in (#4244).
void main() {
  // French labels, so the order depends on accent folding: a raw code unit
  // sort files "Emetteur" with an acute accent after "Stab".
  final ctx = QueryEditorContext(
    registry: _registry,
    root: _gear,
    prefs: kMetricPrefs,
    names: const MapNameResolver({}),
    labels: const MapQueryLabels(
      enums: {
        'gearType': {
          'bcd': 'Stab',
          'tank': 'Bouteille',
          'computer': 'Ordinateur',
          'transmitter': 'Émetteur',
        },
        'waterType': {'salt': 'Salt water', 'fresh': 'Fresh water'},
      },
    ),
    now: () => DateTime(2026, 9, 25),
  );
  PathResolution target(String path) =>
      resolvePath(_registry, _gear, FieldPath(path.split('.')));

  const byLabel = ['tank', 'transmitter', 'computer', 'bcd'];

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  Future<List<String?>> dropdownValues(WidgetTester tester, String path) async {
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: ctx,
          target: target(path),
          op: QueryOp.eq,
          value: null,
          onChanged: (_) {},
          strings: kTestBuilderStrings,
        ),
      ),
    );
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    return [for (final item in dropdown.items!) item.value];
  }

  test('enumOptions sorts a byLabel field by folded label', () {
    expect(enumOptions(target('gearType').field!, ctx.labels), byLabel);
  });

  test('enumOptions keeps a declared-order field as declared', () {
    expect(enumOptions(target('waterType').field!, ctx.labels), [
      'salt',
      'fresh',
      'brackish',
    ]);
  });

  test('a fresh byLabel row starts on the first value it lists', () {
    expect(
      defaultValueFor(target('gearType'), QueryOp.eq, ctx),
      const EnumValue('tank'),
    );
    expect(
      defaultValueFor(target('gearType'), QueryOp.inList, ctx),
      ListValue([const EnumValue('tank')]),
    );
  });

  testWidgets('the dropdown lists a byLabel field by label', (tester) async {
    expect(await dropdownValues(tester, 'gearType'), byLabel);
  });

  testWidgets('the dropdown keeps a declared-order field as declared', (
    tester,
  ) async {
    expect(await dropdownValues(tester, 'waterType'), [
      'salt',
      'fresh',
      'brackish',
    ]);
  });

  testWidgets('the chips list a byLabel field by label', (tester) async {
    QueryValue? out;
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: ctx,
          target: target('gearType'),
          op: QueryOp.inList,
          value: ListValue([const EnumValue('bcd')]),
          onChanged: (v) => out = v,
          strings: kTestBuilderStrings,
        ),
      ),
    );
    final labels = [
      for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip)))
        (chip.label as Text).data,
    ];
    expect(labels, ['Bouteille', 'Émetteur', 'Ordinateur', 'Stab']);

    await tester.tap(find.widgetWithText(FilterChip, 'Bouteille'));
    await tester.pump();
    expect(out, ListValue([const EnumValue('tank'), const EnumValue('bcd')]));
  });
}
