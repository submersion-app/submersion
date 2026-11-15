import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_import_site_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<void> _pump(WidgetTester tester, CatalogueSite site) =>
    tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: CatalogueImportSiteCard(
            site: site,
            isImported: false,
            units: const UnitFormatter(AppSettings()),
            onImport: () {},
            onOpen: () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('a researched record is marked Not verified beside its name', (
    tester,
  ) async {
    await _pump(
      tester,
      const CatalogueSite(
        id: 'research_id_usat_liberty',
        name: 'USAT Liberty',
        country: 'Indonesia',
        source: 'research',
        trust: CatalogueTrust.researched,
      ),
    );

    expect(find.text('USAT Liberty'), findsOneWidget);
    expect(find.text('Not verified'), findsOneWidget);
  });

  testWidgets('a verified record is not marked', (tester) async {
    await _pump(
      tester,
      const CatalogueSite(id: 'osm_node_1', name: 'Salt Pier', source: 'osm'),
    );

    expect(find.text('Not verified'), findsNothing);
  });
}
