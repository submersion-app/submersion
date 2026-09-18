import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/searchable_filter_dropdown.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_filter_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Country/region dropdown coverage for the sites filter (issue #1373).
/// Before this, country and region were free-text fields the diver had to
/// type out fully; these drive the replacement dropdowns instead.
void main() {
  const sites = [
    DiveSite(id: '1', name: 'Blue Hole', country: 'Egypt', region: 'Sinai'),
    DiveSite(
      id: '2',
      name: 'Thistlegorm',
      // Differs only by case from site 1's country - the dropdown must show
      // one "Egypt" option, not two near-duplicates.
      country: 'egypt',
      region: 'Red Sea',
    ),
    DiveSite(
      id: '3',
      name: 'Similan Islands',
      country: 'Thailand',
      region: 'Phuket',
    ),
  ];

  Future<WidgetRef> openSheet(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(const AppSettings()),
          ),
          sitesProvider.overrideWith((ref) async => sites),
        ],
        child: MaterialApp(
          // Pinned: this suite drives the sheet by English label.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return Center(
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => SiteFilterSheet(ref: ref),
                    ),
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return capturedRef;
  }

  /// The filter field currently showing [label].
  Finder fieldShowing(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  /// Labels offered by the open suggestion list.
  Iterable<String> suggestions(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(searchableFilterOptionsKey),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data ?? '')
      .where((label) => label.isNotEmpty);

  Finder suggestion(String label) => find.descendant(
    of: find.byKey(searchableFilterOptionsKey),
    matching: find.widgetWithText(InkWell, label),
  );

  void useTallSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 2200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('country dropdown lists distinct, deduplicated countries', (
    tester,
  ) async {
    useTallSurface(tester);
    await openSheet(tester);

    await tester.tap(fieldShowing('All countries'));
    await tester.pumpAndSettle();

    expect(suggestions(tester), containsAll(<String>['Egypt', 'Thailand']));
    // Only one "Egypt" entry, not one per differently-cased site.
    expect(suggestions(tester).where((s) => s == 'Egypt'), hasLength(1));
  });

  testWidgets('selecting a country narrows the region dropdown to its sites', (
    tester,
  ) async {
    useTallSurface(tester);
    await openSheet(tester);

    await tester.tap(fieldShowing('All countries'));
    await tester.pumpAndSettle();
    await tester.tap(suggestion('Egypt'));
    await tester.pumpAndSettle();

    await tester.tap(fieldShowing('All regions'));
    await tester.pumpAndSettle();

    expect(suggestions(tester), containsAll(<String>['Red Sea', 'Sinai']));
    expect(suggestions(tester), isNot(contains('Phuket')));
  });

  testWidgets(
    'changing the country drops a region the new country does not have',
    (tester) async {
      useTallSurface(tester);
      await openSheet(tester);

      // Pick Egypt, then Sinai.
      await tester.tap(fieldShowing('All countries'));
      await tester.pumpAndSettle();
      await tester.tap(suggestion('Egypt'));
      await tester.pumpAndSettle();

      await tester.tap(fieldShowing('All regions'));
      await tester.pumpAndSettle();
      await tester.tap(suggestion('Sinai'));
      await tester.pumpAndSettle();

      expect(find.text('Sinai'), findsOneWidget);

      // Switching to Thailand, which has no "Sinai" region, must clear it.
      await tester.tap(fieldShowing('Egypt'));
      await tester.pumpAndSettle();
      await tester.tap(suggestion('Thailand'));
      await tester.pumpAndSettle();

      expect(find.text('Sinai'), findsNothing);
      expect(find.text('All regions'), findsOneWidget);
    },
  );

  testWidgets('clearing the country back to "All" restores every region', (
    tester,
  ) async {
    useTallSurface(tester);
    await openSheet(tester);

    await tester.tap(fieldShowing('All countries'));
    await tester.pumpAndSettle();
    await tester.tap(suggestion('Egypt'));
    await tester.pumpAndSettle();

    await tester.tap(fieldShowing('Egypt'));
    await tester.pumpAndSettle();
    await tester.tap(suggestion('All countries'));
    await tester.pumpAndSettle();

    await tester.tap(fieldShowing('All regions'));
    await tester.pumpAndSettle();

    expect(
      suggestions(tester),
      containsAll(<String>['Red Sea', 'Sinai', 'Phuket']),
    );
  });

  testWidgets(
    'reopening after apply and picking a different country still drops '
    'the stale region',
    (tester) async {
      useTallSurface(tester);
      final ref = await openSheet(tester);

      await tester.tap(fieldShowing('All countries'));
      await tester.pumpAndSettle();
      await tester.tap(suggestion('Egypt'));
      await tester.pumpAndSettle();

      await tester.tap(fieldShowing('All regions'));
      await tester.pumpAndSettle();
      await tester.tap(suggestion('Sinai'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(ref.read(siteFilterProvider).country, 'Egypt');
      expect(ref.read(siteFilterProvider).region, 'Sinai');

      // Reopen: a fresh SiteFilterSheet State seeds _country/_region from
      // the now-saved filter (initState), not from the closed instance's
      // fields.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Egypt'), findsOneWidget);
      expect(find.text('Sinai'), findsOneWidget);

      await tester.tap(fieldShowing('Egypt'));
      await tester.pumpAndSettle();
      await tester.tap(suggestion('Thailand'));
      await tester.pumpAndSettle();

      expect(find.text('Sinai'), findsNothing);
      expect(find.text('All regions'), findsOneWidget);
    },
  );

  testWidgets(
    'a country that is no longer offered resets to "All countries" instead '
    'of silently staying applied',
    (tester) async {
      useTallSurface(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith(
              (ref) => MockSettingsNotifier(const AppSettings()),
            ),
            sitesProvider.overrideWith((ref) async => sites),
            // "Nowhere" was never among the offered sites (renamed/deleted
            // between sessions) - the field must not silently show "All
            // countries" while still holding this on Apply.
            siteFilterProvider.overrideWith(
              (ref) => const SiteFilterState(country: 'Nowhere'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return Center(
                    child: ElevatedButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => SiteFilterSheet(ref: ref),
                      ),
                      child: const Text('Open'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Nowhere'), findsNothing);
      expect(find.text('All countries'), findsOneWidget);

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(capturedRef.read(siteFilterProvider).country, isNull);
    },
  );

  testWidgets('applying stores the chosen country and region', (tester) async {
    useTallSurface(tester);
    final ref = await openSheet(tester);

    await tester.tap(fieldShowing('All countries'));
    await tester.pumpAndSettle();
    await tester.tap(suggestion('Thailand'));
    await tester.pumpAndSettle();

    await tester.tap(fieldShowing('All regions'));
    await tester.pumpAndSettle();
    await tester.tap(suggestion('Phuket'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    final applied = ref.read(siteFilterProvider);
    expect(applied.country, 'Thailand');
    expect(applied.region, 'Phuket');
  });
}
