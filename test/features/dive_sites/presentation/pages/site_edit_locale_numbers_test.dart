import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

import '../../../../helpers/test_database.dart';

/// The form chrome renders row labels outside the text field, so resolve the
/// field through the [SuggestionFormRow] that carries the label.
Finder _rowField(String label) => find.descendant(
  of: find.ancestor(
    of: find.text(label),
    matching: find.byType(SuggestionFormRow),
  ),
  matching: find.byType(TextFormField),
);

void main() {
  late SharedPreferences prefs;
  late String? previousLocale;

  setUp(() async {
    previousLocale = Intl.defaultLocale;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(() async {
    Intl.defaultLocale = previousLocale;
    await tearDownTestDatabase();
  });

  Widget harness(Widget page, {DiveSite? site}) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      allDiversProvider.overrideWith((_) async => const <Diver>[]),
      shareByDefaultProvider.overrideWith((_) async => false),
      // A null diver id keeps the nullable diverId column FK-free, so the save
      // commits without a seeded Divers row.
      validatedCurrentDiverIdProvider.overrideWith((_) async => null),
      if (site != null) siteProvider(site.id).overrideWith((_) async => site),
    ],
    child: MaterialApp(
      // The app chrome stays English so 'Save' and the field labels resolve;
      // Intl.defaultLocale is what governs number parsing.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: page),
    ),
  );

  testWidgets('comma decimals typed into the depth fields are stored (fr)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    Intl.defaultLocale = 'fr';

    String? savedId;
    await tester.pumpWidget(
      harness(
        SiteEditPage(
          embedded: true,
          onSaved: (id) => savedId = id,
          onCancel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_rowField('Site Name *'), 'Calanque');
    await tester.enterText(_rowField('Minimum Depth (m)'), '12,5');
    await tester.enterText(_rowField('Maximum Depth (m)'), '30,5');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(savedId, isNotNull);
    final saved = await SiteRepository().getSiteById(savedId!);
    expect(saved!.minDepth, closeTo(12.5, 0.001));
    expect(saved.maxDepth, closeTo(30.5, 0.001));
  });

  testWidgets(
    'saving an untouched site under a grouping-dot locale changes nothing (de)',
    (tester) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      Intl.defaultLocale = 'de';

      final repo = SiteRepository();
      final seeded = await repo.createSite(
        const DiveSite(
          id: '',
          name: 'Walchensee',
          minDepth: 12.5,
          maxDepth: 30,
          altitude: 1500,
        ),
      );

      await tester.pumpWidget(
        harness(
          SiteEditPage(
            siteId: seeded.id,
            embedded: true,
            onSaved: (_) {},
            onCancel: () {},
          ),
          site: seeded,
        ),
      );
      await tester.pumpAndSettle();

      // The seed itself must be locale-formatted, or the parse half would read
      // "12.5" as 125 under de. Both summaries render the raw field text.
      expect(find.textContaining('12,5'), findsWidgets);
      expect(find.textContaining('1500 m'), findsWidgets);

      // Save without touching a single field.
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final saved = await repo.getSiteById(seeded.id);
      expect(saved!.minDepth, closeTo(12.5, 0.001));
      expect(saved.maxDepth, closeTo(30, 0.001));
      expect(saved.altitude, closeTo(1500, 0.001));
    },
  );
}
