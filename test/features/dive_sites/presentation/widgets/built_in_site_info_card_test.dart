import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_info_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _osm = CatalogueSource(
  key: 'osm',
  name: 'OpenStreetMap',
  licence: 'ODbL-1.0',
  credit: 'OpenStreetMap contributors',
);

const _full = CatalogueSite(
  id: 'osm_node_1',
  name: 'Salt Pier',
  location: GeoPoint(12.08, -68.28),
  country: 'Caribbean Netherlands',
  island: 'Bonaire',
  minDepth: 5,
  maxDepth: 15,
  typeIds: ['reef'],
  entryMethods: [EntryMethod.shore],
  hazards: 'Boat traffic',
  description: 'Pillars covered in sponges.',
  website: 'https://example.org/salt-pier',
  source: 'osm',
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  AppSettings settings = const AppSettings(),
  CatalogueSource? source = _osm,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        unitFormatterProvider.overrideWithValue(UnitFormatter(settings)),
        catalogueSourceProvider.overrideWith((ref, key) async => source),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows what the catalogue knows about the site', (tester) async {
    await _pump(
      tester,
      BuiltInSiteInfoCard(
        site: _full,
        actionLabel: 'Add to my sites',
        onAction: () async {},
      ),
    );

    expect(find.text('Salt Pier'), findsOneWidget);
    expect(find.text('Bonaire, Caribbean Netherlands'), findsOneWidget);
    expect(find.text('5m–15m'), findsOneWidget);
    expect(find.text('Reef'), findsOneWidget);
    expect(find.text('Shore'), findsOneWidget);
    expect(find.text('Boat traffic'), findsOneWidget);
    expect(find.text('Pillars covered in sponges.'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text('Source: OpenStreetMap contributors'), findsOneWidget);
    expect(find.text('Add to my sites'), findsOneWidget);
  });

  testWidgets('shows depths in the diver\'s unit', (tester) async {
    await _pump(
      tester,
      BuiltInSiteInfoCard(
        site: _full,
        actionLabel: 'Add to my sites',
        onAction: () async {},
      ),
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );

    expect(find.text('16ft–49ft'), findsOneWidget);
    expect(find.text('5m–15m'), findsNothing);
  });

  testWidgets('a site with only a name shows only that and the action', (
    tester,
  ) async {
    await _pump(
      tester,
      BuiltInSiteInfoCard(
        site: const CatalogueSite(id: 'x', name: 'Blue Hole', source: 'osm'),
        actionLabel: 'Use this site',
        onAction: () async {},
      ),
      source: null,
    );

    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.text('Use this site'), findsOneWidget);
    expect(find.text('Website'), findsNothing);
    expect(find.textContaining('Source:'), findsNothing);
    expect(find.byIcon(Icons.warning_amber_outlined), findsNothing);
  });

  testWidgets('a website that is not a web address shows no button', (
    tester,
  ) async {
    await _pump(
      tester,
      BuiltInSiteInfoCard(
        site: const CatalogueSite(
          id: 'x',
          name: 'Blue Hole',
          website: 'tel:+15551234',
          source: 'osm',
        ),
        actionLabel: 'Use this site',
        onAction: () async {},
      ),
    );

    expect(find.text('Website'), findsNothing);
  });

  testWidgets('the action runs once while it is in flight', (tester) async {
    var calls = 0;
    final gate = Completer<void>();
    await _pump(
      tester,
      BuiltInSiteInfoCard(
        site: _full,
        actionLabel: 'Add to my sites',
        onAction: () {
          calls++;
          return gate.future;
        },
      ),
    );

    await tester.tap(find.text('Add to my sites'));
    await tester.pump();
    await tester.tap(find.text('Add to my sites'), warnIfMissed: false);
    await tester.pump();

    expect(calls, 1);

    gate.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to my sites'));
    await tester.pump();
    expect(calls, 2);
  });

  testWidgets('the action comes back after a failure', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      BuiltInSiteInfoCard(
        site: _full,
        actionLabel: 'Add to my sites',
        onAction: () async {
          calls++;
          if (calls == 1) throw StateError('offline');
        },
      ),
    );

    await tester.tap(find.text('Add to my sites'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isStateError);

    await tester.tap(find.text('Add to my sites'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('the details sheet closes, then runs the action', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showCatalogueSiteDetails(
            context,
            site: _full,
            actionLabel: 'Use this site',
            onAction: () async => calls++,
          ),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Salt Pier'), findsOneWidget);
    expect(find.text('Pillars covered in sponges.'), findsOneWidget);

    await tester.tap(find.text('Use this site'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Salt Pier'), findsNothing);
  });
}
