import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/domain/entities/compare_column.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/compare_table.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

const _planned = CompareColumn(
  id: 'planned',
  kind: CompareLineKind.planned,
  maxDepthMeters: 40,
  bottomTimeSeconds: 1500,
  ndl: CompareDecoAt(900),
  decoRequiredSeconds: 720,
  runtimeSeconds: 2520,
  surfaceGf: 70,
);

const _dived = CompareColumn(
  id: 'dived',
  kind: CompareLineKind.asDived,
  maxDepthMeters: 41.5,
  bottomTimeSeconds: 1500,
  ndl: CompareDecoAt(840),
  decoRequiredSeconds: 780,
  decoDoneSeconds: 840,
  runtimeSeconds: 2640,
  surfaceGf: 68,
);

const _blank = CompareColumn(id: 'dived', kind: CompareLineKind.asDived);

Finder _cell(String column, CompareRow row) =>
    find.byKey(ValueKey('compareCell_${column}_${row.name}'));

String _text(WidgetTester tester, String column, CompareRow row) =>
    tester.widget<Text>(_cell(column, row)).data ?? '';

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<CompareColumn> columns, {
    Size size = const Size(420, 800),
    Locale locale = const Locale('en'),
    UnitFormatter units = const UnitFormatter(AppSettings()),
    void Function(CompareColumn)? onOpen,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        locale: locale,
        child: Align(
          alignment: Alignment.topLeft,
          child: CompareTable(
            columns: columns,
            units: units,
            onOpenColumn: onOpen,
          ),
        ),
      ),
    );
  }

  testWidgets('reads each row in the diver\'s units', (tester) async {
    await pump(tester, const [_planned, _dived]);

    expect(_text(tester, 'planned', CompareRow.maxDepth), '40.0m');
    expect(_text(tester, 'planned', CompareRow.bottomTime), '25′');
    expect(_text(tester, 'planned', CompareRow.ndl), 'Deco at 15:00');
    expect(_text(tester, 'planned', CompareRow.deco), '12′');
    expect(_text(tester, 'planned', CompareRow.runtime), '42′');
    expect(_text(tester, 'planned', CompareRow.surfaceGf), '70%');
    expect(_text(tester, 'dived', CompareRow.deco), '13′, 14′ done');
  });

  testWidgets('reads depth in feet for an imperial diver', (tester) async {
    await pump(tester, const [
      _planned,
    ], units: const UnitFormatter(AppSettings(depthUnit: DepthUnit.feet)));

    expect(_text(tester, 'planned', CompareRow.maxDepth), contains('ft'));
  });

  testWidgets('shows the minutes left on a no-deco line', (tester) async {
    await pump(tester, const [
      CompareColumn(
        id: 'planned',
        kind: CompareLineKind.planned,
        ndl: CompareNdlLeft(754),
        decoRequiredSeconds: 0,
      ),
    ]);

    expect(_text(tester, 'planned', CompareRow.ndl), '12 min left');
    expect(_text(tester, 'planned', CompareRow.deco), 'None');
  });

  testWidgets('a value the line cannot supply is blank', (tester) async {
    await pump(tester, const [_planned, _blank]);

    for (final row in CompareRow.values) {
      expect(_text(tester, 'dived', row), isEmpty);
    }
  });

  testWidgets('tints a dived value past the plan and no other', (tester) async {
    await pump(tester, const [_planned, _dived]);

    final error = Theme.of(
      tester.element(find.byType(CompareTable)),
    ).colorScheme.error;
    Color? colorOf(String column, CompareRow row) =>
        tester.widget<Text>(_cell(column, row)).style?.color;

    expect(colorOf('dived', CompareRow.maxDepth), error);
    expect(colorOf('dived', CompareRow.runtime), error);
    expect(colorOf('dived', CompareRow.bottomTime), isNot(error));
    expect(colorOf('planned', CompareRow.maxDepth), isNot(error));
  });

  testWidgets('a what-if header opens that what-if', (tester) async {
    final opened = <String>[];
    await pump(tester, const [
      _dived,
      CompareColumn(id: 'sc', kind: CompareLineKind.whatIf, title: 'Slow'),
    ], onOpen: (c) => opened.add(c.id));

    await tester.tap(find.text('Slow'));
    await tester.tap(find.text('As dived'));

    expect(opened, ['sc']);
  });

  testWidgets('five columns on a German phone scroll and do not overflow', (
    tester,
  ) async {
    final overflows = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = overflows.add;
    addTearDown(() => FlutterError.onError = previous);

    await pump(
      tester,
      [
        _planned,
        _dived,
        for (var i = 0; i < 3; i++)
          CompareColumn(
            id: 'sc$i',
            kind: CompareLineKind.whatIf,
            title: 'Was wäre wenn bei einem Gasverlust $i',
            decoRequiredSeconds: 780,
            decoDoneSeconds: 840,
          ),
      ],
      size: const Size(360, 800),
      locale: const Locale('de'),
    );
    await tester.pump();
    FlutterError.onError = previous;

    expect(overflows, isEmpty);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(CompareTable),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(scrollable.axisDirection, AxisDirection.right);
  });
}
