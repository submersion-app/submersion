import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Where the detail page's Duplicate action (issue #3575) opens the form
/// from, and where the saved copy shows: the opener knows where it is.
enum _Opener {
  /// The phone page, pushed over the list.
  phonePage,

  /// The Sites list's own side pane on desktop (list or table view).
  sitesPane,

  /// A site shown in the Dives section's side pane on desktop.
  divesPane,
}

void main() {
  const site = DiveSite(id: 'site-1', name: 'Salt Pier');

  Widget pane(String label) => Scaffold(
    body: Row(
      children: [
        SizedBox(
          width: 300,
          child: Consumer(
            builder: (context, ref, _) {
              final state = GoRouterState.of(context);
              return Column(
                children: [
                  Text(label),
                  Text('selected ${state.uri.queryParameters['selected']}'),
                  Text('highlighted ${ref.watch(highlightedSiteIdProvider)}'),
                ],
              );
            },
          ),
        ),
        const Expanded(child: SiteDetailPage(siteId: 'site-1', embedded: true)),
      ],
    ),
  );

  Future<GoRouter> pumpDetail(WidgetTester tester, _Opener opener) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = opener == _Opener.phonePage
        ? const Size(400, 900)
        : const Size(1400, 900);
    addTearDown(tester.view.reset);

    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: switch (opener) {
        _Opener.phonePage => '/other',
        _Opener.sitesPane => '/sites?selected=site-1',
        _Opener.divesPane => '/dives',
      },
      routes: [
        GoRoute(
          path: '/other',
          builder: (context, state) => Scaffold(
            body: ElevatedButton(
              onPressed: () => context.push('/sites/site-1'),
              child: const Text('GO'),
            ),
          ),
        ),
        GoRoute(path: '/dives', builder: (context, state) => pane('dives')),
        GoRoute(
          path: '/sites',
          builder: (context, state) => pane('sites'),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => Scaffold(
                body: ElevatedButton(
                  // Stands in for the form: Save pops the copy's id.
                  onPressed: () => context.pop('copy-1'),
                  child: Text(
                    'save copy of ${state.uri.queryParameters['duplicateOf']}',
                  ),
                ),
              ),
            ),
            GoRoute(
              path: ':siteId',
              builder: (context, state) {
                final id = state.pathParameters['siteId']!;
                return id == 'site-1'
                    ? const SiteDetailPage(siteId: 'site-1')
                    : Scaffold(body: Text('detail $id'));
              },
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          siteListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
          siteProvider(site.id).overrideWith((ref) async => site),
          siteDiveCountProvider(site.id).overrideWith((ref) async => 0),
        ].cast<Override>(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (opener == _Opener.phonePage) {
      // Pushed, so the phone page does not redirect into the list.
      await tester.tap(find.text('GO'));
      await tester.pumpAndSettle();
    }
    return router;
  }

  /// Chooses Duplicate, checks the form opened for this site, and saves it.
  Future<void> duplicateAndSave(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.copy), findsOneWidget);
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('save copy of site-1'));
    await tester.pumpAndSettle();
  }

  testWidgets('on a phone the saved copy opens over the original', (
    tester,
  ) async {
    final router = await pumpDetail(tester, _Opener.phonePage);

    await duplicateAndSave(tester);

    expect(find.text('detail copy-1'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(SiteDetailPage), findsOneWidget);
  });

  testWidgets('in the Sites pane the saved copy is selected and highlighted', (
    tester,
  ) async {
    await pumpDetail(tester, _Opener.sitesPane);

    await duplicateAndSave(tester);

    // The list view follows the URL; the table view lights the
    // highlighted row.
    expect(find.text('selected copy-1'), findsOneWidget);
    expect(find.text('highlighted copy-1'), findsOneWidget);
  });

  testWidgets('from a dive\'s site pane the saved copy opens over the dives, '
      'which Back returns to', (tester) async {
    final router = await pumpDetail(tester, _Opener.divesPane);

    await duplicateAndSave(tester);

    expect(find.text('detail copy-1'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('dives'), findsOneWidget);
    expect(find.text('highlighted null'), findsOneWidget);
  });

  testWidgets('cancelling the form leaves the original where it was', (
    tester,
  ) async {
    final router = await pumpDetail(tester, _Opener.sitesPane);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('selected site-1'), findsOneWidget);
    expect(find.text('highlighted null'), findsOneWidget);
  });
}
