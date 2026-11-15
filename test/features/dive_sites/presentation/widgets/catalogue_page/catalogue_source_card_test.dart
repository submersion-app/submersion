import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_source_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/recording_url_launcher.dart';

const _osm = CatalogueSource(
  key: 'osm',
  name: 'OpenStreetMap',
  licence: 'ODbL-1.0',
  licenceUrl: 'https://example.org/licence',
  credit: 'OpenStreetMap contributors',
);

/// A source that names its licence and gives no address for it.
const _unlinked = CatalogueSource(
  key: 'club',
  name: 'Club list',
  licence: 'Own terms',
  credit: 'The club',
);

const _site = CatalogueSite(
  id: 'osm_node_1',
  name: 'Salt Pier',
  location: GeoPoint(12.08, -68.28),
  website: 'https://example.org/salt-pier',
  source: 'osm',
  sourceRef: 'https://example.org/node/1',
);

Future<void> _pump(
  WidgetTester tester,
  CatalogueSite site,
  CatalogueSource? source,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: CatalogueSourceCard(site: site, source: source),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _researched = CatalogueSite(
  id: 'research_id_usat_liberty',
  name: 'USAT Liberty',
  source: 'research',
  trust: CatalogueTrust.researched,
);

const _explanation =
    'Gathered from published sources, not from a survey. Check the '
    'position locally before you rely on it.';

void main() {
  testWidgets('a researched record explains its mark', (tester) async {
    await _pump(tester, _researched, null);

    expect(find.text(_explanation), findsOneWidget);
    expect(CatalogueSourceCard.hasContent(_researched, null), isTrue);
  });

  testWidgets('a verified record does not', (tester) async {
    await _pump(tester, _site, _osm);

    expect(find.text(_explanation), findsNothing);
  });

  testWidgets('each link opens its own address, outside the app', (
    tester,
  ) async {
    final launcher = useRecordingUrlLauncher();
    await _pump(tester, _site, _osm);

    await tester.tap(find.byKey(const ValueKey('catalogueLicenceLink')));
    await tester.tap(find.byKey(const ValueKey('catalogueSourceLink')));
    await tester.tap(find.byKey(const ValueKey('catalogueWebsiteLink')));
    await tester.pump();

    expect(launcher.launched, [
      'https://example.org/licence',
      'https://example.org/node/1',
      'https://example.org/salt-pier',
    ]);
    // In the browser, never in a web view inside the app: the addresses
    // come from sources anyone can edit.
    expect(
      launcher.modes,
      everyElement(PreferredLaunchMode.externalApplication),
    );
  });

  testWidgets('a licence with no address of its own is named and is not a '
      'link', (tester) async {
    final launcher = useRecordingUrlLauncher();
    await _pump(tester, _site, _unlinked);

    expect(find.text('Licence: Own terms'), findsOneWidget);
    expect(find.byKey(const ValueKey('catalogueLicenceLink')), findsNothing);

    await tester.tap(find.text('Licence: Own terms'));
    await tester.pump();
    expect(launcher.launched, isEmpty);
  });
}
