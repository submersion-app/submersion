import 'dart:async';

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

  /// Pumps the host page and opens the filter sheet on it, returning the
  /// launching page's ref so a test can read the applied filter back.
  ///
  /// [extraOverrides] seed a saved filter; [sitesFuture] lets a test hold the
  /// site list unresolved while the sheet is already open, in which case
  /// [settle] must be false - an unresolved list leaves an indeterminate
  /// progress indicator running, which never settles.
  Future<WidgetRef> openSheet(
    WidgetTester tester, {
    List<Override> extraOverrides = const [],
    Future<List<DiveSite>>? sitesFuture,
    bool settle = true,
  }) async {
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
          sitesProvider.overrideWith(
            (ref) => sitesFuture ?? Future.value(sites),
          ),
          ...extraOverrides,
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
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Past the sheet's entrance animation without waiting for the
      // never-ending progress indicator.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
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
      // "Nowhere" was never among the offered sites (renamed/deleted between
      // sessions) - the field must not silently show "All countries" while
      // still holding this on Apply.
      final ref = await openSheet(
        tester,
        extraOverrides: [
          siteFilterProvider.overrideWith(
            (ref) => const SiteFilterState(country: 'Nowhere'),
          ),
        ],
      );

      expect(find.text('Nowhere'), findsNothing);
      expect(find.text('All countries'), findsOneWidget);

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(ref.read(siteFilterProvider).country, isNull);
    },
  );

  testWidgets(
    'a saved country differing only in case or spacing keeps filtering, '
    'under the offered spelling',
    (tester) async {
      useTallSurface(tester);
      // What the free-text field this replaces could leave behind: the same
      // country as the "Egypt" option, loosely typed. It still selects
      // exactly the same sites, so the dropdown adopts the offered spelling
      // rather than treating the value as stale and dropping the filter.
      final ref = await openSheet(
        tester,
        extraOverrides: [
          siteFilterProvider.overrideWith(
            (ref) =>
                const SiteFilterState(country: '  eGyPt  ', region: 'sinai'),
          ),
        ],
      );

      expect(fieldShowing('Egypt'), findsOneWidget);
      expect(fieldShowing('Sinai'), findsOneWidget);
      expect(find.text('All countries'), findsNothing);
      expect(find.text('All regions'), findsNothing);

      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      final applied = ref.read(siteFilterProvider);
      expect(applied.country, 'Egypt');
      expect(applied.region, 'Sinai');
    },
  );

  testWidgets(
    'the dropdowns appear when the site list resolves after the sheet is '
    'already open',
    (tester) async {
      useTallSurface(tester);
      // The sheet lives in its own modal route, so it only leaves the
      // loading state if the option providers are watched through the
      // sheet's own ref; a watch registered on the launching page's ref
      // rebuilds that page and leaves the sheet on its progress indicators.
      final sitesReady = Completer<List<DiveSite>>();
      await openSheet(tester, sitesFuture: sitesReady.future, settle: false);

      expect(find.text('All countries'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));

      sitesReady.complete(sites);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(fieldShowing('All countries'), findsOneWidget);
      expect(fieldShowing('All regions'), findsOneWidget);
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
