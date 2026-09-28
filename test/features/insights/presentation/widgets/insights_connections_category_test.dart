import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';
import 'package:submersion/features/insights/presentation/pages/insights_page.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_list_content.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Connections is an Insights category that opens its own full page rather
/// than filling the Insights detail pane.
void main() {
  testWidgets('the Connections category opens the full explorer', (
    tester,
  ) async {
    final selected = <String?>[];
    final router = GoRouter(
      initialLocation: '/insights',
      routes: [
        GoRoute(
          path: '/insights',
          builder: (_, _) => Scaffold(
            body: InsightsListContent(
              onItemSelected: selected.add,
              showAppBar: false,
            ),
          ),
        ),
        GoRoute(
          path: '/insights/connections',
          builder: (_, _) => const Scaffold(body: Text('CONNECTIONS PAGE')),
        ),
      ],
    );
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Connections'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Connections'));
    await tester.pumpAndSettle();
    expect(find.text('CONNECTIONS PAGE'), findsOneWidget);
    expect(selected, isEmpty, reason: 'it does not fill the detail pane');
  });

  Future<List<InsightsCategory>> categoriesIn(
    WidgetTester tester, {
    ThemeData? theme,
  }) async {
    late List<InsightsCategory> categories;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            categories = insightsCategoriesOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return categories;
  }

  InsightsCategory connectionsOf(List<InsightsCategory> categories) =>
      categories.singleWhere((c) => c.id == 'connections');

  testWidgets('Connections sits right below Overview', (tester) async {
    final ids = (await categoriesIn(tester)).map((c) => c.id);
    expect(ids.take(2), ['overview', 'connections']);
  });

  testWidgets('the tile takes the theme\'s Connections accent', (tester) async {
    const custom = Color(0xFF123456);
    final themed = await categoriesIn(
      tester,
      theme: ThemeData(
        brightness: Brightness.dark,
        extensions: const [
          FeatureAccentColors(colors: {'connections': custom}),
        ],
      ),
    );
    expect(connectionsOf(themed).color, custom);

    // A dark theme without the extension still gets the dark accent, which
    // stays legible on a dark surface.
    final dark = await categoriesIn(
      tester,
      theme: ThemeData(brightness: Brightness.dark),
    );
    expect(
      connectionsOf(dark).color,
      FeatureAccentColors.dark.of('connections'),
    );
  });

  testWidgets('each category knows where it opens', (tester) async {
    final categories = await categoriesIn(tester);
    expect(connectionsOf(categories).location, kConnectionsLocation);
    expect(
      categories.singleWhere((c) => c.id == 'gas').location,
      '/insights/gas',
    );
  });

  testWidgets('the phone list opens Connections as its own page', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/insights',
      routes: [
        GoRoute(
          path: '/insights',
          builder: (_, _) => const InsightsMobileContent(),
        ),
        GoRoute(
          path: kConnectionsLocation,
          builder: (_, _) => const Scaffold(body: Text('CONNECTIONS PAGE')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: await getBaseOverrides(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connections'));
    await tester.pumpAndSettle();
    expect(find.text('CONNECTIONS PAGE'), findsOneWidget);
  });
}
