import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/catalogue_site_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'site_picker_built_in_harness.dart';

/// The picker's section for register records: charted wrecks and reef
/// deployments. There are many times more of them than dive sites, so
/// they are kept out of "More sites near" and shown as a count until the
/// diver opens them.

const _showThree = 'Show charted wrecks and reefs (3)';

/// Two dive sites and three charted wrecks around Salt Pier.
final _mixed = [
  builtInSite('s1', 'Windsock', north: 500),
  builtInSite('s2', 'Cliff', north: 3000),
  registerSite('w3', 'Zulu Trader', north: 200),
  registerSite('w1', 'Alpha Barge', north: 4000),
  registerSite('w2', 'Mike Tug', north: 1500),
];

Future<void> _open(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('"More sites" lists dive sites only, and the register records '
      'are a closed count below it', (tester) async {
    await pumpPicker(tester, catalogueSites: _mixed, diveLocation: saltPier);

    expect(find.text('More sites nearby'), findsOneWidget);
    expect(find.text('Wrecks and reefs nearby'), findsOneWidget);
    expect(find.text(_showThree), findsOneWidget);
    // Closed: no register row is built.
    expect(builtInTitles(tester), ['Windsock', 'Cliff']);

    // The section sits below "More sites".
    final titles = pickerRowTitles(tester);
    expect(titles.indexOf(_showThree), greaterThan(titles.indexOf('Cliff')));
  });

  testWidgets('with no register record in range there is no such section', (
    tester,
  ) async {
    final h = await pumpPicker(
      tester,
      catalogueSites: [
        builtInSite('s1', 'Windsock', north: 500),
        // 80 km away: outside the picker's 50 km.
        registerSite('w1', 'Far Wreck', north: 80000),
      ],
      diveLocation: saltPier,
    );

    expect(find.textContaining('Wrecks and reefs'), findsNothing);
    expect(find.textContaining('charted wrecks'), findsNothing);
    expect(h.catalogue.countNearCalls, greaterThan(0));
  });

  testWidgets('opened, it lists them nearest first with distances', (
    tester,
  ) async {
    await pumpPicker(tester, catalogueSites: _mixed, diveLocation: saltPier);

    await _open(tester, _showThree);

    expect(find.text(_showThree), findsNothing);
    expect(builtInTitles(tester), [
      'Windsock',
      'Cliff',
      'Zulu Trader',
      'Mike Tug',
      'Alpha Barge',
    ]);
    final near = const UnitFormatter(AppSettings()).formatGeoDistance(200);
    expect(find.text('$near away'), findsOneWidget);
  });

  testWidgets('for an inferred area it is named for the place and goes by '
      'name, with no distances', (tester) async {
    await pumpPicker(
      tester,
      catalogueSites: _mixed,
      areaAnchor: inferredBonaire,
    );

    expect(find.text('Wrecks and reefs near Bonaire'), findsOneWidget);
    await _open(tester, _showThree);

    expect(builtInTitles(tester), [
      'Cliff',
      'Windsock',
      'Alpha Barge',
      'Mike Tug',
      'Zulu Trader',
    ]);
    expect(find.textContaining(' away'), findsNothing);
  });

  testWidgets('it holds the nearest 200 and says how to reach the rest', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      catalogueSites: [
        for (var i = 0; i < 250; i++)
          registerSite(
            'w$i',
            'Wreck ${i.toString().padLeft(3, '0')}',
            north: 100.0 + i * 10,
          ),
      ],
      diveLocation: saltPier,
    );

    await _open(tester, 'Show charted wrecks and reefs (250)');

    // The list is lazy; scroll to its end and read the last row.
    await tester.scrollUntilVisible(
      find.text('Showing the nearest 200. Search to find the rest.'),
      2000,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Wreck 199'), findsOneWidget);
    expect(find.text('Wreck 200'), findsNothing);
  });

  testWidgets('a record the diver adopted, and one beside a site of theirs, '
      'are not listed', (tester) async {
    await pumpPicker(
      tester,
      catalogueSites: _mixed,
      diveLocation: saltPier,
      sites: [
        // Adopted from the catalogue.
        DiveSite(
          id: 'mine-1',
          name: 'Zulu Trader',
          location: _mixed[2].location,
          catalogueId: 'w3',
        ),
        // Made by hand, 50 m from Mike Tug.
        DiveSite(
          id: 'mine-2',
          name: 'My Tug',
          location: GeoPoint(
            _mixed[4].location!.latitude + 50 / 111194.93,
            _mixed[4].location!.longitude,
          ),
        ),
      ],
    );

    await _open(tester, _showThree);

    expect(builtInTitles(tester), ['Windsock', 'Cliff', 'Alpha Barge']);
    expect(builtInTitles(tester), isNot(contains('Zulu Trader')));
    expect(builtInTitles(tester), isNot(contains('Mike Tug')));
  });

  testWidgets('tapping a register row adopts it once and picks it', (
    tester,
  ) async {
    final h = await pumpPicker(
      tester,
      catalogueSites: _mixed,
      diveLocation: saltPier,
    );
    await _open(tester, _showThree);

    await tester.ensureVisible(find.text('Mike Tug'));
    await tester.tap(find.text('Mike Tug'));
    await tester.pumpAndSettle();

    expect(h.adoptions.adopted.map((s) => s.id), ['w2']);
    expect(h.picked.single.catalogueId, 'w2');
  });

  testWidgets('a search shows one list of both kinds and no register '
      'section', (tester) async {
    await pumpPicker(
      tester,
      catalogueSites: [
        builtInSite('s1', 'Coral Reef', north: 500),
        registerSite('w1', 'Reef Runner', north: 200),
      ],
      diveLocation: saltPier,
    );

    await tester.enterText(find.byType(TextField), 'reef');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Built-in sites'), findsOneWidget);
    expect(find.textContaining('Wrecks and reefs'), findsNothing);
    expect(builtInTitles(tester), ['Coral Reef', 'Reef Runner']);
  });

  testWidgets('clearing a search brings the section back as it was', (
    tester,
  ) async {
    await pumpPicker(tester, catalogueSites: _mixed, diveLocation: saltPier);
    await _open(tester, _showThree);

    await tester.enterText(find.byType(TextField), 'zulu');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    expect(find.text('Wrecks and reefs nearby'), findsOneWidget);
    expect(builtInTitles(tester), contains('Mike Tug'));
  });

  testWidgets('with only register records nearby, the section still shows', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      catalogueSites: [registerSite('w1', 'Lone Wreck', north: 200)],
      diveLocation: saltPier,
    );

    expect(find.text('More sites nearby'), findsNothing);
    expect(find.text('Wrecks and reefs nearby'), findsOneWidget);
    expect(find.text('Show charted wrecks and reefs (1)'), findsOneWidget);
  });

  testWidgets('with the flag off nothing is counted or shown', (tester) async {
    final h = await pumpPicker(
      tester,
      catalogueSites: _mixed,
      showBuiltIn: false,
      diveLocation: saltPier,
    );

    expect(find.textContaining('Wrecks and reefs'), findsNothing);
    expect(h.catalogue.countNearCalls, 0);
    expect(h.catalogue.nearCalls, 0);
  });

  testWidgets('with no anchor there is no section', (tester) async {
    final h = await pumpPicker(tester, catalogueSites: _mixed);

    expect(find.textContaining('Wrecks and reefs'), findsNothing);
    expect(h.catalogue.countNearCalls, 0);
  });

  testWidgets('a site linked to a record the catalogue no longer holds '
      'is listed as the diver\'s own and nothing breaks', (tester) async {
    await pumpPicker(
      tester,
      catalogueSites: _mixed,
      diveLocation: saltPier,
      sites: const [
        DiveSite(
          id: 'mine',
          name: 'Old Favourite',
          location: saltPier,
          catalogueId: 'osm_node_gone',
        ),
      ],
    );

    // Among the diver's nearby sites and again in their grouped list.
    expect(find.text('Old Favourite'), findsWidgets);
    expect(find.text(_showThree), findsOneWidget);
    expect(find.byType(CatalogueSiteTile), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('only dive sites are asked for by the section above', (
    tester,
  ) async {
    await pumpPicker(tester, catalogueSites: _mixed, diveLocation: saltPier);

    // Before the section is opened no register record has been read.
    expect(
      builtInTitles(
        tester,
      ).toSet().intersection({'Zulu Trader', 'Mike Tug', 'Alpha Barge'}),
      isEmpty,
    );
    expect(_mixed.where((s) => s.kind == CatalogueKind.register), hasLength(3));
  });
}
