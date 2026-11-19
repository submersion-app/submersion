import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_sites/domain/models/new_site_seed.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_routes.dart';

/// Where a new site opens (issue #4527, phase 2, plan 6): the site page,
/// unlocked, with the switch on; the form, as today, with it off.
void main() {
  test('the new site address opens the page with the switch on', () {
    final page = newSitePage(null, unlockEditing: true);
    expect(page, isA<SiteDetailPage>());
    expect((page as SiteDetailPage).newSite, isNotNull);
    expect(page.embedded, isFalse);

    final duplicate = newSitePage(
      null,
      duplicateOfId: 's1',
      unlockEditing: true,
    );
    expect((duplicate as SiteDetailPage).newSite?.duplicateOfId, 's1');

    final named = newSitePage(
      const NewSiteSeed(name: 'Blue Hole'),
      unlockEditing: true,
    );
    expect((named as SiteDetailPage).newSite?.seed?.name, 'Blue Hole');

    final form = newSitePage(
      const NewSiteSeed(name: 'Blue Hole'),
      unlockEditing: false,
    );
    expect(form, isA<SiteEditPage>());
    expect((form as SiteEditPage).initialName, 'Blue Hole');
  });

  testWidgets('the pane\'s new site is the page with the switch on', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    void onSaved(String _) {}
    void onCancel() {}

    final pane = newSitePane(context, onSaved, onCancel, unlockEditing: true);
    expect(pane, isA<SiteDetailPage>());
    final page = pane as SiteDetailPage;
    expect(page.embedded, isTrue);
    expect(page.newSite, isNotNull);
    expect(page.onCreated, same(onSaved));
    expect(page.onCreateCancelled, same(onCancel));

    expect(
      newSitePane(context, onSaved, onCancel, unlockEditing: false),
      isA<SiteEditPage>(),
    );
  });

  /// A list whose Add opens the new site through [openNewSite], and a new
  /// site page that is created as soon as it opens.
  Future<GoRouter> pumpOpener(
    WidgetTester tester, {
    required bool unlockEditing,
  }) async {
    final router = GoRouter(
      initialLocation: '/list',
      routes: [
        GoRoute(
          path: '/list',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  openNewSite(context, unlockEditing: unlockEditing),
              child: const Text('Add'),
            ),
          ),
        ),
        GoRoute(
          path: '/sites/new',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop('n1'),
              child: const Text('Save'),
            ),
          ),
        ),
        GoRoute(
          path: '/sites/:id',
          builder: (_, state) =>
              Scaffold(body: Text('site ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('Add opens the new site once created, with the switch on', (
    tester,
  ) async {
    await pumpOpener(tester, unlockEditing: true);

    expect(find.text('site n1'), findsOneWidget);
  });

  testWidgets('Add returns to the list as today, with the switch off', (
    tester,
  ) async {
    await pumpOpener(tester, unlockEditing: false);

    expect(find.text('Add'), findsOneWidget);
    expect(find.text('site n1'), findsNothing);
  });
}
