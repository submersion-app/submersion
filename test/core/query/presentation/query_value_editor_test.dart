import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_builder_strings.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/presentation/query_value_editor.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

const kTestBuilderStrings = QueryBuilderStrings(
  allOf: 'All of',
  anyOf: 'Any of',
  addCondition: 'Add condition',
  addGroup: 'Add group',
  negate: 'Not',
  remove: 'Remove',
  pickField: 'Choose a field',
  pickFieldSearch: 'Search fields',
  useRelation: 'Use {name} itself',
  fieldsOf: 'Fields of {name}',
  pickRef: 'Choose {name}',
  pickRefSearch: 'Search',
  done: 'Done',
  unresolvedRef: 'No longer exists',
  scopedRow: 'Group over {name}: edit in the Text tab',
  textRow: 'Text search',
  betweenAnd: 'and',
  valueTrue: 'Yes',
  valueFalse: 'No',
);

void main() {
  const imperial = UnitPrefs(
    depth: DepthUnit.feet,
    temperature: TemperatureUnit.fahrenheit,
    pressure: PressureUnit.psi,
    weight: WeightUnit.pounds,
    volume: VolumeUnit.cubicFeet,
  );
  QueryEditorContext ctx([UnitPrefs prefs = kMetricPrefs]) =>
      QueryEditorContext(
        registry: fixtureRegistry,
        root: fixtureDives,
        prefs: prefs,
        names: const MapNameResolver({
          QuerySubject.sites: {'Salt Pier': 's1'},
        }),
        labels: const MapQueryLabels(
          enums: {
            'waterType': {'salt': 'Salt water', 'fresh': 'Fresh water'},
          },
        ),
        now: () => DateTime(2026, 9, 25),
      );
  PathResolution target(String path) =>
      resolvePath(fixtureRegistry, fixtureDives, FieldPath(path.split('.')));

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  test('opsFor follows the target type and the none ambiguity rule', () {
    expect(opsFor(target('depth')), [
      QueryOp.eq,
      QueryOp.neq,
      QueryOp.lt,
      QueryOp.lte,
      QueryOp.gt,
      QueryOp.gte,
      QueryOp.between,
      QueryOp.isEmpty,
      QueryOp.isSet,
    ]);
    expect(opsFor(target('notes')), [
      QueryOp.eq,
      QueryOp.neq,
      QueryOp.contains,
      QueryOp.isEmpty,
      QueryOp.isSet,
    ]);
    expect(opsFor(target('favorite')), [QueryOp.eq]);
    expect(opsFor(target('waterType')), [
      QueryOp.eq,
      QueryOp.neq,
      QueryOp.inList,
      QueryOp.isEmpty,
      QueryOp.isSet,
    ]);
    // `current` stores a value named none: no :none / :any.
    expect(opsFor(target('current')), [
      QueryOp.eq,
      QueryOp.neq,
      QueryOp.inList,
    ]);
    expect(opsFor(target('date')), [
      QueryOp.eq,
      QueryOp.neq,
      QueryOp.lt,
      QueryOp.lte,
      QueryOp.gt,
      QueryOp.gte,
      QueryOp.inList,
      QueryOp.between,
      QueryOp.isEmpty,
      QueryOp.isSet,
    ]);
    expect(opsFor(target('site')), [
      QueryOp.eq,
      QueryOp.neq,
      QueryOp.inList,
      QueryOp.isEmpty,
      QueryOp.isSet,
    ]);
  });

  test('defaultValueFor gives a usable value or null for a ref', () {
    final c = ctx();
    expect(
      defaultValueFor(target('depth'), QueryOp.gt, c),
      const NumberValue(0, null),
    );
    expect(defaultValueFor(target('depth'), QueryOp.isEmpty, c), isNull);
    expect(
      defaultValueFor(target('waterType'), QueryOp.eq, c),
      const EnumValue('salt'),
    );
    expect(
      defaultValueFor(target('waterType'), QueryOp.inList, c),
      ListValue([const EnumValue('salt')]),
    );
    expect(
      defaultValueFor(target('favorite'), QueryOp.eq, c),
      const BoolValue(true),
    );
    expect(
      defaultValueFor(target('notes'), QueryOp.contains, c),
      const StringValue(''),
    );
    expect(
      defaultValueFor(target('date'), QueryOp.eq, c),
      DateValue(DateTime(2026, 9, 25)),
    );
    expect(
      defaultValueFor(target('date'), QueryOp.inList, c),
      DateRangeValue(DateTime(2026, 1, 1), DateTime(2026, 9, 25)),
    );
    expect(
      defaultValueFor(target('depth'), QueryOp.between, c),
      ListValue([const NumberValue(0, null), const NumberValue(0, null)]),
    );
    expect(defaultValueFor(target('site'), QueryOp.eq, c), isNull);
  });

  testWidgets('a number field shows the diver unit and stores storage units', (
    tester,
  ) async {
    QueryValue? out;
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: ctx(imperial),
          target: target('depth'),
          op: QueryOp.gt,
          value: const NumberValue(30.48, null),
          onChanged: (v) => out = v,
          strings: kTestBuilderStrings,
        ),
      ),
    );
    expect(find.text('ft'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '100',
    );
    await tester.enterText(find.byType(TextField), '50');
    await tester.pump();
    expect((out! as NumberValue).value, closeTo(15.24, 0.001));
    expect((out! as NumberValue).typedUnit, isNull);
  });

  testWidgets('an enum field offers localized values and stores the name', (
    tester,
  ) async {
    QueryValue? out;
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: ctx(),
          target: target('waterType'),
          op: QueryOp.eq,
          value: const EnumValue('salt'),
          onChanged: (v) => out = v,
          strings: kTestBuilderStrings,
        ),
      ),
    );
    await tester.tap(find.text('Salt water'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fresh water').last);
    await tester.pumpAndSettle();
    expect(out, const EnumValue('fresh'));
  });

  testWidgets('an enum in-list uses chips', (tester) async {
    QueryValue? out;
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: ctx(),
          target: target('waterType'),
          op: QueryOp.inList,
          value: ListValue([const EnumValue('salt')]),
          onChanged: (v) => out = v,
          strings: kTestBuilderStrings,
        ),
      ),
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Fresh water'));
    await tester.pump();
    expect(out, ListValue([const EnumValue('salt'), const EnumValue('fresh')]));
  });

  testWidgets('a bool field is a yes/no toggle', (tester) async {
    QueryValue? out;
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: ctx(),
          target: target('favorite'),
          op: QueryOp.eq,
          value: const BoolValue(true),
          onChanged: (v) => out = v,
          strings: kTestBuilderStrings,
        ),
      ),
    );
    await tester.tap(find.text('No'));
    await tester.pump();
    expect(out, const BoolValue(false));
  });

  testWidgets('a ref shows its label, flags an unknown id, opens the picker', (
    tester,
  ) async {
    QueryValue? out;
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: ctx(),
          target: target('site'),
          op: QueryOp.eq,
          value: const RefValue('gone', 'Old Wall'),
          onChanged: (v) => out = v,
          strings: kTestBuilderStrings,
        ),
      ),
    );
    expect(find.text('Old Wall'), findsOneWidget);
    expect(find.byTooltip('No longer exists'), findsOneWidget);
    await tester.tap(find.text('Old Wall'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salt Pier'));
    await tester.pumpAndSettle();
    expect(out, const RefValue('s1', 'Salt Pier'));
  });

  testWidgets('an op without a value renders nothing', (tester) async {
    await tester.pumpWidget(
      host(
        QueryValueEditor(
          context: ctx(),
          target: target('depth'),
          op: QueryOp.isEmpty,
          value: null,
          onChanged: (_) {},
          strings: kTestBuilderStrings,
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
  });
}
