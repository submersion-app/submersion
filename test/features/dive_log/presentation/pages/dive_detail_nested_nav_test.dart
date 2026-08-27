import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('DiveDetailPage Nested Navigation Coverage', () {
    const diveId = 'dive-1';
    const siteId = 'site-1';
    const site = DiveSite(id: siteId, name: 'Test Site');
    final dive = Dive(
      id: diveId,
      diveNumber: 1,
      dateTime: DateTime(2023, 1, 1),
      site: site,
    );

    testWidgets('renders SiteDetailPage when embeddedSiteId is provided', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveProvider(diveId).overrideWith((ref) async => dive),
            siteProvider(siteId).overrideWith((ref) async => site),
            siteDiveCountProvider(siteId).overrideWith((ref) async => 0),
          ].cast<Override>(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DiveDetailPage(
              diveId: diveId,
              embedded: true,
              embeddedSiteId: siteId,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find SiteDetailPage (or its content)
      expect(find.byType(SiteDetailPage), findsOneWidget);
      // Use find.descendant or a more specific finder to avoid finding multiple site names
      // (one in the header, one in the basic info section).
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('Test Site'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'onCloseEmbeddedSite is called when back button is pressed in embedded SiteDetailPage',
      (tester) async {
        final overrides = await getBaseOverrides();
        bool closed = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              diveProvider(diveId).overrideWith((ref) async => dive),
              siteProvider(siteId).overrideWith((ref) async => site),
              siteDiveCountProvider(siteId).overrideWith((ref) async => 0),
            ].cast<Override>(),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DiveDetailPage(
                diveId: diveId,
                embedded: true,
                embeddedSiteId: siteId,
                onCloseEmbeddedSite: () => closed = true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final backButton = find.byIcon(Icons.arrow_back);
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        expect(closed, isTrue);
      },
    );
  });
}
