import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

import '../../../../helpers/test_database.dart';

Finder _rowField(String label) => find.descendant(
  of: find.ancestor(
    of: find.text(label),
    matching: find.byType(SuggestionFormRow),
  ),
  matching: find.byType(TextFormField),
);

void main() {
  late SharedPreferences prefs;
  final diver = Diver(
    id: 'd',
    name: 'Ray',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  const site = DiveSite(
    id: 's',
    name: 'Blue',
    hazards: 'old',
    sharedLibraryId: 'L',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    await DiverRepository().createDiver(diver);
    final store = SharedLibraryStore();
    await store.upsertLibrary(
      const SharedLibrary(
        id: 'L',
        name: 'Reef Survey',
        connectedAccountId: 'a',
        prefix: 'p',
      ),
    );
    await store.upsertMembership(
      const SharedLibraryMembership(
        id: 'ms',
        diverId: 'd',
        libraryId: 'L',
        memberId: 'r',
        displayName: 'Ray',
        libraryName: 'Reef Survey',
        backendKind: 's3',
      ),
    );
    await SiteRepository().createSite(site);
  });

  tearDown(tearDownTestDatabase);

  Future<void> pump(
    WidgetTester tester, {
    required bool suggest,
    bool pushed = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => [diver, diver]),
          shareByDefaultProvider.overrideWith((_) async => false),
          validatedCurrentDiverIdProvider.overrideWith((_) async => 'd'),
          siteProvider('s').overrideWith((_) async => site),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: pushed
              ? Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              SiteEditPage(siteId: 's', suggest: suggest),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                )
              : SiteEditPage(siteId: 's', suggest: suggest),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'suggest mode shows the note field and Send, never writes the site',
    (tester) async {
      await pump(tester, suggest: true);
      expect(find.text('Suggest changes'), findsWidgets);
      expect(find.text('Send'), findsOneWidget);
      expect(find.text('Edit Site'), findsNothing);

      // The Access & safety group rests collapsed; expand it to reach the
      // hazards field.
      await tester.scrollUntilVisible(
        find.text('Access & safety').first,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Access & safety').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Hazards').first,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(_rowField('Hazards'), 'new');
      await tester.scrollUntilVisible(
        find.byKey(const Key('suggestion-note')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const Key('suggestion-note')),
        'please',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect((await SiteRepository().getSiteById('s'))!.hazards, 'old');
      final suggestions = await SharedLibraryStore().suggestions('L');
      expect(suggestions, hasLength(1));
      expect(suggestions.single.fields, {'hazards': 'new'});
      expect(suggestions.single.note, 'please');
    },
  );

  testWidgets('sending a suggestion leaves without asking to discard', (
    tester,
  ) async {
    await pump(tester, suggest: true, pushed: true);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('suggestion-note')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const Key('suggestion-note')), 'x');
    await tester.scrollUntilVisible(
      find.text('Site Name *').first,
      -100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(_rowField('Site Name *'), 'Bluer');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byType(SiteEditPage), findsNothing);
    expect(await SharedLibraryStore().suggestions('L'), hasLength(1));
  });

  testWidgets('a library site hides the Share with all profiles toggle', (
    tester,
  ) async {
    await pump(tester, suggest: false);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(
      find.byTooltip('Delete Site'),
      findsNothing,
      reason: 'a library site is deleted through its role-gated action',
    );
  });

  testWidgets('a reader reaching the plain edit route still only suggests', (
    tester,
  ) async {
    // A deep link to /sites/s/edit without ?suggest=1.
    await pump(tester, suggest: false);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Edit Site'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Access & safety').first,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Access & safety').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Hazards').first,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(_rowField('Hazards'), 'from a reader');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect((await SiteRepository().getSiteById('s'))!.hazards, 'old');
    expect((await SharedLibraryStore().suggestions('L')).single.fields, {
      'hazards': 'from a reader',
    });
  });

  testWidgets('a reader keeps their own notes without suggesting them', (
    tester,
  ) async {
    await pump(tester, suggest: true);
    await tester.scrollUntilVisible(
      find.text('Life & notes').first,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Life & notes').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      _rowField('General Notes'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(_rowField('General Notes'), 'only mine');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect((await SiteRepository().getSiteById('s'))!.notes, 'only mine');
    expect(await SharedLibraryStore().suggestions('L'), isEmpty);
    expect(find.text('Your notes and rating are saved.'), findsOneWidget);
  });

  testWidgets('an editor reaching the edit route edits the site', (
    tester,
  ) async {
    await SharedLibraryStore().setLibraryStatus(
      'L',
      roles: const SharedLibraryRoles(editors: {'r'}),
    );
    await pump(tester, suggest: false);
    expect(find.text('Edit Site'), findsWidgets);
    expect(find.text('Send'), findsNothing);
  });

  testWidgets('without the library on this device nothing is queued', (
    tester,
  ) async {
    // The membership synced here; the library itself is not connected.
    await SharedLibraryStore().deleteLibrary('L');
    await pump(tester, suggest: true);
    await tester.scrollUntilVisible(
      find.byKey(const Key('suggestion-note')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const Key('suggestion-note')), 'hi');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Not connected on this device'), findsOneWidget);
    expect(await SharedLibraryStore().suggestions('L'), isEmpty);
  });
}
