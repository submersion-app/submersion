import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';

void main() {
  Widget buildTestWidget({
    required double width,
    Widget? infoCard,
    Widget? floatingActionButton,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Scaffold(
            body: MapListScaffold(
              sectionKey: 'test',
              title: 'Test Map',
              listPane: const Text('List Content'),
              mapPane: Container(color: Colors.blue, child: const Text('Map')),
              infoCard: infoCard,
              floatingActionButton: floatingActionButton,
              actions: const [Icon(Icons.settings)],
              onBackPressed: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows split layout on desktop (>=1100px)', (tester) async {
    await tester.pumpWidget(buildTestWidget(width: 1200));
    await tester.pumpAndSettle();

    // Both list and map should be visible
    expect(find.text('List Content'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
  });

  testWidgets('shows only map on mobile (<1100px)', (tester) async {
    await tester.pumpWidget(buildTestWidget(width: 800));
    await tester.pumpAndSettle();

    // Only map should be visible
    expect(find.text('List Content'), findsNothing);
    expect(find.text('Map'), findsOneWidget);
  });

  testWidgets('shows info card when provided', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        width: 1200,
        infoCard: const Card(child: Text('Info Card')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Info Card'), findsOneWidget);
  });

  testWidgets('shows FAB when provided', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        width: 1200,
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('shows app bar with title', (tester) async {
    await tester.pumpWidget(buildTestWidget(width: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Test Map'), findsOneWidget);
  });

  testWidgets('shows app bar actions', (tester) async {
    await tester.pumpWidget(buildTestWidget(width: 1200));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
