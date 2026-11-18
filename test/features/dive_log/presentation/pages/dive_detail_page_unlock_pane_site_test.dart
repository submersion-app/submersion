import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';

import '../../../../helpers/fake_hosts.dart';
import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// The list pane showing a site in the dive's place ends the dive's
/// sitting: the hero's link to the site asks first when there are unsaved
/// changes, and a clean sitting locks (issue #4527, plan 7).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    // The hero is a link only over its map, and the site page has one too:
    // the tile server answers 404 at once, as it would with no network.
    serveFakeHost('tile.openstreetmap.org', const FakeResponse(404));
  });
  tearDown(tearDownTestDatabase);

  const pane = Size(1200, 1000);
  const reef = DiveSite(
    id: 'reef',
    name: 'Blue Corner',
    location: GeoPoint(7.1, 134.2),
  );

  Future<({GoRouter router, FakeSave save})> pumpPane(WidgetTester tester) =>
      pumpPage(
        tester,
        embedded: true,
        size: pane,
        siteInPane: true,
        stored: dive.copyWith(site: reef),
        extra: [siteProvider(reef.id).overrideWith((ref) async => reef)],
      );

  Future<void> tapSiteLink(WidgetTester tester) async {
    final link = find.ancestor(
      of: find.byType(DiveLocationsMap),
      matching: find.byWidgetPredicate((w) => w is InkWell && w.onTap != null),
    );
    expect(link, findsOneWidget);
    await tester.tap(link);
    await settle(tester);
  }

  Future<void> change(WidgetTester tester) async {
    await openNotes(tester);
    await tester.enterText(find.byType(TextField).first, 'Choppy');
    await settle(tester);
  }

  Finder saveAction() =>
      find.byWidgetPredicate((w) => w is AppBarTextAction && w.label == 'Save');

  testWidgets('with unsaved changes the hero\'s site link asks: Keep editing '
      'stays on the dive, Discard shows the site', (tester) async {
    final page = await pumpPane(tester);
    await unlock(tester);
    await change(tester);

    await tapSiteLink(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await settle(tester);

    expect(location(page.router), '/home/dive');
    expect(find.byType(SiteDetailPage), findsNothing);
    expect(action(tester, 'Save').onPressed, isNotNull);

    await tapSiteLink(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);

    expect(location(page.router), '/home/dive?site=reef');
    expect(find.byType(SiteDetailPage), findsOneWidget);
    expect(page.save.calls, isEmpty);
  });

  // The pane's edit mode (`mode=edit`, the old form's address) opens the
  // dive unlocked; its site link shows the site, not the site's edit form
  // the list builds for `mode=edit&site=` (issue #4527, plan 11).
  testWidgets('from the pane\'s edit mode the link drops mode=edit', (
    tester,
  ) async {
    final page = await pumpPage(
      tester,
      embedded: true,
      size: pane,
      siteInPane: true,
      openUnlocked: true,
      initialLocation: '/home/dive?mode=edit',
      stored: dive.copyWith(site: reef),
      extra: [siteProvider(reef.id).overrideWith((ref) async => reef)],
    );
    expect(saveAction(), findsOneWidget);

    await tapSiteLink(tester);

    expect(location(page.router), '/home/dive?site=reef');
  });

  testWidgets('with no changes the link shows the site at once, and the '
      'sitting is locked', (tester) async {
    final page = await pumpPane(tester);
    await unlock(tester);
    expect(saveAction(), findsOneWidget);

    await tapSiteLink(tester);

    expect(find.text('Discard changes?'), findsNothing);
    expect(location(page.router), '/home/dive?site=reef');
    expect(find.byType(SiteDetailPage), findsOneWidget);

    // Back on the dive, the pane is locked.
    page.router.go('/home/dive');
    await settle(tester);

    expect(find.byType(SiteDetailPage), findsNothing);
    expect(saveAction(), findsNothing);
    expect(find.byTooltip('Unlock to edit').hitTestable(), findsOneWidget);
    expect(page.save.calls, isEmpty);
  });
}
