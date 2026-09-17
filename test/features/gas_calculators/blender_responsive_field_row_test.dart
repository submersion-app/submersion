import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_responsive_field_row.dart';

Widget _host(double width, List<Widget> fields) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: width,
      child: BlenderResponsiveFieldRow(fields: fields),
    ),
  ),
);

void main() {
  testWidgets('lays three fields out in a row when there is room', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(600, const [Text('one'), Text('two'), Text('three')]),
    );

    expect(find.byType(Row), findsOneWidget);
    expect(find.byType(Column), findsNothing);
  });

  testWidgets('stacks the same three fields on a narrow width', (tester) async {
    await tester.pumpWidget(
      _host(300, const [Text('one'), Text('two'), Text('three')]),
    );

    expect(find.byType(Column), findsOneWidget);
    expect(find.byType(Row), findsNothing);
  });

  testWidgets('a single field renders as-is, no layout wrapper', (
    tester,
  ) async {
    await tester.pumpWidget(_host(600, const [Text('solo')]));

    expect(find.text('solo'), findsOneWidget);
    expect(find.byType(Row), findsNothing);
    expect(find.byType(Column), findsNothing);
  });
}
