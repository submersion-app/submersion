import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/entry_exit_suggestion.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(tearDownTestDatabase);

  final divers = [
    Diver(
      id: 'd1',
      name: 'One',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    ),
  ];

  const suggestion = EntryExitSuggestion(
    entry: EntryMethod.boat,
    exit: EntryMethod.ladder,
    count: 14,
  );

  Future<void> pumpSiteEdit(
    WidgetTester tester, {
    required DiveSite site,
    EntryExitSuggestion? suggested = suggestion,
  }) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => divers),
          shareByDefaultProvider.overrideWith((_) async => false),
          siteProvider(site.id).overrideWith((_) async => site),
          siteEntryExitSuggestionProvider(
            site.id,
          ).overrideWith((_) async => suggested),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteEditPage(siteId: site.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expandAccess(WidgetTester tester) async {
    final header = find.text('Access & safety');
    await tester.scrollUntilVisible(
      header,
      50.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(header);
    await tester.pumpAndSettle();
  }

  testWidgets('the chip appears when both fields are empty', (tester) async {
    await pumpSiteEdit(
      tester,
      site: const DiveSite(id: 'site-1', name: 'Blue Hole'),
    );
    await expandAccess(tester);

    expect(
      find.text('Your 14 dives here: Boat Entry in, Ladder out'),
      findsOneWidget,
    );
  });

  testWidgets('the chip is absent when entry method is already set', (
    tester,
  ) async {
    // The circularity guard: dives that inherited the site's value must never
    // come back to "confirm" it.
    await pumpSiteEdit(
      tester,
      site: const DiveSite(
        id: 'site-1',
        name: 'Blue Hole',
        entryMethod: EntryMethod.shore,
      ),
    );
    await expandAccess(tester);

    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('the chip is absent when there is no suggestion', (tester) async {
    await pumpSiteEdit(
      tester,
      site: const DiveSite(id: 'site-1', name: 'Blue Hole'),
      suggested: null,
    );
    await expandAccess(tester);

    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('tapping the chip fills both fields', (tester) async {
    await pumpSiteEdit(
      tester,
      site: const DiveSite(id: 'site-1', name: 'Blue Hole'),
    );
    await expandAccess(tester);

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();

    expect(find.text('Boat Entry'), findsOneWidget);
    expect(find.text('Ladder'), findsOneWidget);
    // Filling both fields retires the chip.
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('an exit-less suggestion uses the entry-only phrasing', (
    tester,
  ) async {
    await pumpSiteEdit(
      tester,
      site: const DiveSite(id: 'site-1', name: 'Blue Hole'),
      suggested: const EntryExitSuggestion(
        entry: EntryMethod.shore,
        exit: null,
        count: 3,
      ),
    );
    await expandAccess(tester);

    expect(find.text('Your 3 dives here: Shore Entry'), findsOneWidget);
  });
}
