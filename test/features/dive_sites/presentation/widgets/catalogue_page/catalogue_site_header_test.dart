import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_site_header.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<void> _pump(WidgetTester tester, CatalogueSite site) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: CatalogueSiteHeader(site: site)),
      ),
    ),
  );
}

void main() {
  testWidgets('a researched record is marked Not verified on its kind line', (
    tester,
  ) async {
    await _pump(
      tester,
      const CatalogueSite(
        id: 'research_id_usat_liberty',
        name: 'USAT Liberty',
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

    expect(find.text('Salt Pier'), findsOneWidget);
    expect(find.text('Not verified'), findsNothing);
  });
}
