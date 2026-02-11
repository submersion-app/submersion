import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';

void main() {
  Widget buildTestWidget({
    required double width,
    Widget? infoCard,
    Widget? floatingActionButton,
    VoidCallback? onBackPressed,
  }) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: MapListScaffold(
            sectionKey: 'test',
            title: 'Test Map',
            listPane: const Text('List Content'),
            mapPane: Container(color: Colors.blue, child: const Text('Map')),
            infoCard: infoCard,
            floatingActionButton: floatingActionButton,
            actions: const [Icon(Icons.settings)],
            onBackPressed: onBackPressed ?? () {},
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

  testWidgets('back button triggers onBackPressed callback', (tester) async {
    var wasCalled = false;
    await tester.pumpWidget(
      buildTestWidget(width: 1200, onBackPressed: () => wasCalled = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(wasCalled, isTrue);
  });

  testWidgets('collapse button hides list and shows expand in app bar', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(width: 1200));
    await tester.pumpAndSettle();

    // List should be visible initially
    expect(find.text('List Content'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    // Find and tap collapse button (chevron_left)
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    // Expand button should now appear in app bar
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('expand button in app bar restores list', (tester) async {
    await tester.pumpWidget(buildTestWidget(width: 1200));
    await tester.pumpAndSettle();

    // Collapse the list first
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    // Tap expand button in app bar
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    // List should be visible again, expand button gone
    expect(find.text('List Content'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });
}
