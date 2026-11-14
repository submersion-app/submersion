import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/catalogue_site_tile.dart';

import 'site_picker_built_in_harness.dart';

/// Picking a built-in site in the picker: the adoption it starts, what the
/// caller gets back, and what a failure leaves on screen.
void main() {
  group('adopting', () {
    testWidgets('tapping a built-in row adopts once and returns the site', (
      tester,
    ) async {
      final h = await pumpPicker(tester, areaAnchor: inferredBonaire);
      h.adoptions.gate = Completer<void>();

      await tester.tap(find.text('Angel City'));
      await tester.pump();
      await tester.tap(find.text('Angel City'), warnIfMissed: false);
      await tester.tap(find.text('Bari Reef'), warnIfMissed: false);
      await tester.pump();
      h.adoptions.gate!.complete();
      await tester.pumpAndSettle();

      expect(h.adoptions.adopted.map((s) => s.id), ['c1']);
      expect(h.picked.single.catalogueId, 'c1');
      expect(h.picked.single.id, 'adopted-c1');
    });

    testWidgets('the after-create rules run before the site is returned', (
      tester,
    ) async {
      final h = await pumpPicker(
        tester,
        areaAnchor: inferredBonaire,
        withRules: true,
      );

      await tester.tap(find.text('Angel City'));
      await tester.pumpAndSettle();

      expect(h.adoptions.order, ['adopt', 'rules', 'read']);
      // The dive form gets the site as the rules left it.
      expect(h.picked.single.name, 'Renamed By A Rule');
    });

    testWidgets('a site the diver already had runs no rules', (tester) async {
      final h = await pumpPicker(
        tester,
        areaAnchor: inferredBonaire,
        withRules: true,
      );
      // The list was stale: the site arrived by sync a moment ago.
      h.adoptions.created = false;

      await tester.tap(find.text('Angel City'));
      await tester.pumpAndSettle();

      expect(h.adoptions.order, ['adopt', 'read']);
      expect(h.picked.single.catalogueId, 'c1');
    });

    testWidgets('while a site is being adopted nothing else can be picked', (
      tester,
    ) async {
      final h = await pumpPicker(
        tester,
        areaAnchor: inferredBonaire,
        sites: [
          DiveSite(
            id: 'mine',
            name: 'My House Reef',
            location: GeoPoint(saltPier.latitude + 0.2, saltPier.longitude),
          ),
        ],
      );
      h.adoptions.gate = Completer<void>();

      await tester.tap(find.text('Angel City'));
      await tester.pump();
      // Their own site, and another site's details, while it is in flight.
      await tester.tap(find.text('My House Reef').first, warnIfMissed: false);
      await tester.tap(
        find.byTooltip('Site details').at(1),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(h.picked, isEmpty);
      expect(find.text('Use this site'), findsNothing);

      h.adoptions.gate!.complete();
      await tester.pumpAndSettle();

      // Exactly the adopted site was handed back.
      expect(h.picked.map((s) => s.id), ['adopted-c1']);
    });

    testWidgets('the failure stays said when the list empties under it', (
      tester,
    ) async {
      final h = await pumpPicker(tester, areaAnchor: inferredBonaire);
      h.adoptions.fail = true;
      await tester.tap(find.text('Angel City'));
      await tester.pumpAndSettle();
      expect(find.text('Could not add this site'), findsOneWidget);

      // The catalogue is replaced by an import that offers nothing here.
      h.catalogue.sites = const [];
      h.container.read(siteCatalogueRevisionProvider.notifier).state++;
      await tester.pumpAndSettle();

      expect(find.byType(CatalogueSiteTile), findsNothing);
      expect(find.text('Could not add this site'), findsOneWidget);
    });

    testWidgets('a failed adoption keeps the picker open and says so', (
      tester,
    ) async {
      final h = await pumpPicker(tester, areaAnchor: inferredBonaire);
      h.adoptions.fail = true;

      await tester.tap(find.text('Angel City'));
      await tester.pumpAndSettle();

      expect(h.picked, isEmpty);
      expect(find.text('Could not add this site'), findsOneWidget);
      expect(find.text('Angel City'), findsOneWidget);

      // And it can be tried again.
      h.adoptions.fail = false;
      await tester.tap(find.text('Angel City'));
      await tester.pumpAndSettle();
      expect(h.picked.single.catalogueId, 'c1');
      expect(find.text('Could not add this site'), findsNothing);
    });

    testWidgets('the details button opens the card, whose action adopts', (
      tester,
    ) async {
      final h = await pumpPicker(tester, areaAnchor: inferredBonaire);

      await tester.tap(find.byTooltip('Site details').first);
      await tester.pumpAndSettle();

      expect(find.text('Use this site'), findsOneWidget);
      // The card shows the depth the row had no room to explain.
      expect(find.text('30m'), findsWidgets);
      expect(h.adoptions.adopted, isEmpty);

      await tester.tap(find.text('Use this site'));
      await tester.pumpAndSettle();

      expect(h.adoptions.adopted.map((s) => s.id), ['c1']);
      expect(h.picked.single.catalogueId, 'c1');
    });
  });

  testWidgets('a catalogue that is not open behaves like an empty one', (
    tester,
  ) async {
    LocalCacheDatabaseService.instance.resetForTesting();
    addTearDown(LocalCacheDatabaseService.instance.resetForTesting);

    await pumpPicker(
      tester,
      withCatalogue: false,
      areaAnchor: inferredBonaire,
      sites: const [DiveSite(id: 'mine', name: 'My Reef', location: saltPier)],
    );
    await tester.enterText(find.byType(TextField), 'my');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Under Nearby and again in the grouped list.
    expect(find.text('My Reef'), findsWidgets);
    expect(find.byType(CatalogueSiteTile), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
