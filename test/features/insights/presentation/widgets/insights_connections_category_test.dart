import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
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

  testWidgets('Connections sits right below Overview', (tester) async {
    late List<String> ids;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            ids = insightsCategoriesOf(context).map((c) => c.id).toList();
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(ids.take(2), ['overview', 'connections']);
  });
}
