import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/catalogue_site_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _site = CatalogueSite(
  id: 'a',
  name: 'Salt Pier',
  island: 'Bonaire',
  maxDepth: 15,
  typeIds: ['reef'],
  entryMethods: [EntryMethod.shore],
  source: 'osm',
);

Future<void> _pump(
  WidgetTester tester,
  Widget tile, {
  AppSettings settings = const AppSettings(),
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      unitFormatterProvider.overrideWithValue(UnitFormatter(settings)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: tile),
    ),
  ),
);

const _researched = CatalogueSite(
  id: 'research_id_usat_liberty',
  name: 'USAT Liberty',
  maxDepth: 30,
  typeIds: ['wreck'],
  entryMethods: [EntryMethod.shore],
  source: 'research',
  trust: CatalogueTrust.researched,
);

void main() {
  group('the Not verified label', () {
    testWidgets('shows for a researched record', (tester) async {
      await _pump(
        tester,
        CatalogueSiteTile(
          site: _researched,
          distanceText: '40 m away',
          onTap: () {},
          onDetails: () {},
        ),
      );

      expect(find.text('Not verified'), findsOneWidget);
      // Read with the row, not as a separate stop.
      final semantics = tester.ensureSemantics();
      final label = tester.getSemantics(find.byType(ListTile)).label;
      expect(label, contains('USAT Liberty'));
      expect(label, contains('Not verified'));
      semantics.dispose();
    });

    testWidgets('shows nothing for a verified record', (tester) async {
      await _pump(
        tester,
        CatalogueSiteTile(
          site: _site,
          distanceText: null,
          onTap: () {},
          onDetails: () {},
        ),
      );

      expect(find.text('Not verified'), findsNothing);
    });

    testWidgets('shows for a researched record with no summary', (
      tester,
    ) async {
      await _pump(
        tester,
        CatalogueSiteTile(
          site: const CatalogueSite(
            id: 'r',
            name: 'Bare',
            source: 'research',
            trust: CatalogueTrust.researched,
          ),
          distanceText: null,
          onTap: () {},
          onDetails: () {},
        ),
      );

      expect(find.text('Not verified'), findsOneWidget);
    });

    testWidgets('a long name at large text on a narrow screen does not '
        'overflow, and the label stays', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pump(
        tester,
        CatalogueSiteTile(
          site: const CatalogueSite(
            id: 'r',
            name: 'The Very Long Name Of A Coral Garden Off The Point',
            maxDepth: 30,
            typeIds: ['wreck', 'reef'],
            entryMethods: [EntryMethod.shore],
            island: 'Bali',
            source: 'research',
            trust: CatalogueTrust.researched,
          ),
          distanceText: '1.2 km away',
          onTap: () {},
          onDetails: () {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Not verified'), findsOneWidget);
    });
  });

  testWidgets('shows the name, a one-line summary and the distance', (
    tester,
  ) async {
    await _pump(
      tester,
      CatalogueSiteTile(
        site: _site,
        distanceText: '500 m away',
        onTap: () {},
        onDetails: () {},
      ),
    );

    expect(find.text('Salt Pier'), findsOneWidget);
    expect(find.text('Bonaire · Shore · 15m · Reef'), findsOneWidget);
    expect(find.text('500 m away'), findsOneWidget);
  });

  testWidgets("the summary's depth follows the diver's unit", (tester) async {
    await _pump(
      tester,
      CatalogueSiteTile(
        site: _site,
        distanceText: null,
        onTap: () {},
        onDetails: () {},
      ),
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );

    expect(find.text('Bonaire · Shore · 49ft · Reef'), findsOneWidget);
  });

  testWidgets('a site that is only a name has no subtitle', (tester) async {
    await _pump(
      tester,
      CatalogueSiteTile(
        site: const CatalogueSite(id: 'b', name: 'Bare', source: 'osm'),
        distanceText: null,
        onTap: () {},
        onDetails: () {},
      ),
    );

    expect(tester.widget<ListTile>(find.byType(ListTile)).subtitle, isNull);
  });

  testWidgets('the details button calls onDetails, not onTap', (tester) async {
    var taps = 0;
    var details = 0;
    await _pump(
      tester,
      CatalogueSiteTile(
        site: _site,
        distanceText: null,
        onTap: () => taps++,
        onDetails: () => details++,
      ),
    );

    await tester.tap(find.byTooltip('Site details'));
    await tester.pump();

    expect(details, 1);
    expect(taps, 0);
    expect(
      tester.widget<ListTile>(find.byType(ListTile)).trailing,
      isA<IconButton>(),
    );
  });

  testWidgets('a null onDetails disables the details button', (tester) async {
    await _pump(
      tester,
      const CatalogueSiteTile(
        site: _site,
        distanceText: null,
        onTap: null,
        onDetails: null,
      ),
    );

    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
  });

  testWidgets('tapping the row calls onTap', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      CatalogueSiteTile(
        site: _site,
        distanceText: null,
        onTap: () => taps++,
        onDetails: () {},
      ),
    );

    await tester.tap(find.text('Salt Pier'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('a null onTap disables the row but not its details', (
    tester,
  ) async {
    var details = 0;
    await _pump(
      tester,
      CatalogueSiteTile(
        site: _site,
        distanceText: null,
        onTap: null,
        onDetails: () => details++,
      ),
    );

    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
    await tester.tap(find.byTooltip('Site details'));
    expect(details, 1);
  });
}
