import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_responsive_header_row.dart';

Widget _host(double width, {double? minRowWidth}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: width,
      child: BlenderResponsiveHeaderRow(
        leading: const Text('Title'),
        trailing: const Text('Action'),
        minRowWidth: minRowWidth ?? 320,
      ),
    ),
  ),
);

void main() {
  testWidgets('lays leading and trailing out in a row when there is room', (
    tester,
  ) async {
    await tester.pumpWidget(_host(400));

    expect(find.byType(Row), findsOneWidget);
    expect(find.byType(Column), findsNothing);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);
  });

  testWidgets('stacks leading above trailing on a narrow width', (
    tester,
  ) async {
    await tester.pumpWidget(_host(250));

    expect(find.byType(Column), findsOneWidget);
    expect(find.byType(Row), findsNothing);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);
  });

  testWidgets('a too-wide trailing shortens instead of overflowing the row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: BlenderResponsiveHeaderRow(
              leading: const TextField(),
              trailing: TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(
                  'A label far wider than the whole row ' * 4,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(TextButton)).width,
      lessThanOrEqualTo(240),
    );
    expect(tester.getSize(find.byType(TextField)).width, greaterThan(100));
  });

  testWidgets('switches from row to column exactly at minRowWidth', (
    tester,
  ) async {
    await tester.pumpWidget(_host(200, minRowWidth: 200));
    expect(find.byType(Row), findsOneWidget);

    await tester.pumpWidget(_host(199.9, minRowWidth: 200));
    expect(find.byType(Column), findsOneWidget);
  });
}
