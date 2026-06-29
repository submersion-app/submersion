import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_info_card.dart';

void main() {
  testWidgets(
    'shows the site name and calls onAdd when the add button is tapped',
    (tester) async {
      var addCalls = 0;
      const site = ExternalDiveSite(
        externalId: 'x',
        name: 'Blue Hole',
        country: 'Belize',
        latitude: 17.3,
        longitude: -87.5,
        source: 't',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BuiltInSiteInfoCard(
              site: site,
              onAdd: () async => addCalls++,
            ),
          ),
        ),
      );

      expect(find.text('Blue Hole'), findsOneWidget);
      await tester.tap(find.text('Add to my sites'));
      await tester.pump();
      expect(addCalls, 1);
    },
  );
}
