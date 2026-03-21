import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SharedPreferences prefs;
  late SiteRepository siteRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    siteRepository = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('merge mode initializes with first non-empty values and cycles', (
    tester,
  ) async {
    final site1 = await siteRepository.createSite(
      const DiveSite(id: 'site-1', name: 'Siet'),
    );
    final site2 = await siteRepository.createSite(
      const DiveSite(
        id: 'site-2',
        name: 'Site',
        country: 'Belize',
        region: 'Turneffe',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          siteRepositoryProvider.overrideWithValue(siteRepository),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteEditPage(mergeSiteIds: [site1.id, site2.id]),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Merge Sites'), findsOneWidget);

    final nameField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(nameField.controller!.text, equals('Siet'));

    await tester.tap(find.byIcon(Icons.arrow_drop_down_circle_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Site: Site').last);
    await tester.pumpAndSettle();

    final updatedNameField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(updatedNameField.controller!.text, equals('Site'));
    expect(find.textContaining('From Site'), findsWidgets);
  });
}
