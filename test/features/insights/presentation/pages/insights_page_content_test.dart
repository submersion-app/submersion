import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/insights/presentation/pages/insights_page.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_list_content.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Coverage for the Insights category list/grid surfaces (issue #453): the
/// mobile grid ([InsightsMobileContent]), the master-detail list
/// ([InsightsListContent] with and without its own app bar), and the badged
/// filter buttons that open the shared [DiveFilterSheet] scoped to the
/// Insights filter.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Widget> wrap(Widget child) async {
    final overrides = await getBaseOverrides();
    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  testWidgets('InsightsMobileContent renders categories and opens the '
      'filter sheet', (tester) async {
    await tester.pumpWidget(await wrap(const InsightsMobileContent()));
    await tester.pumpAndSettle();

    // Every category tile is built (grid + tap closures).
    expect(find.byType(ListTile), findsWidgets);

    await tester.tap(find.byIcon(Icons.filter_list).first);
    await tester.pumpAndSettle();
    expect(find.byType(DiveFilterSheet), findsOneWidget);
  });

  testWidgets('InsightsListContent with app bar opens the filter sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      await wrap(const InsightsListContent(showAppBar: true)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);

    await tester.tap(find.byIcon(Icons.filter_list).first);
    await tester.pumpAndSettle();
    expect(find.byType(DiveFilterSheet), findsOneWidget);
  });

  testWidgets('InsightsListContent compact app bar (showAppBar:false) opens '
      'the filter sheet', (tester) async {
    await tester.pumpWidget(
      await wrap(const Scaffold(body: InsightsListContent(showAppBar: false))),
    );
    await tester.pumpAndSettle();

    // Compact header path (_buildCompactAppBar) is exercised; no Scaffold
    // AppBar in this branch.
    expect(find.byType(AppBar), findsNothing);

    await tester.tap(find.byIcon(Icons.filter_list).first);
    await tester.pumpAndSettle();
    expect(find.byType(DiveFilterSheet), findsOneWidget);
  });

  testWidgets('selecting a category tile invokes onItemSelected', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      await wrap(
        InsightsListContent(
          showAppBar: true,
          onItemSelected: (id) => selected = id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(selected, isNotNull);
  });
}
