import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_search_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/searchable_filter_dropdown.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Type-ahead coverage for the advanced search page's entity dropdowns
/// (issue #1575). The dive list filter sheet links here, and these lists grow
/// the same way, so they narrow as the diver types too.
void main() {
  final now = DateTime(2026, 6, 1);
  const diverId = 'diver-1';
  const customFieldKeys = ['Boat name', 'Guide', 'Surface interval'];

  const sites = [
    DiveSite(id: 'site-1', name: 'Blue Hole', country: 'Egypt'),
    DiveSite(id: 'site-2', name: 'Coral Garden', country: 'Mexico'),
  ];

  final trips = <Trip>[
    Trip(
      id: 'trip-1',
      name: 'Summer week',
      location: 'Sharm el-Sheikh',
      startDate: now,
      endDate: now.add(const Duration(days: 7)),
      createdAt: now,
      updatedAt: now,
    ),
    Trip(
      id: 'trip-2',
      name: 'Winter break',
      startDate: DateTime(2026, 1, 5),
      endDate: DateTime(2026, 1, 12),
      createdAt: now,
      updatedAt: now,
    ),
  ];

  final centers = [
    DiveCenter(
      id: 'dc-1',
      name: 'Reef Divers',
      city: 'Dahab',
      country: 'Egypt',
      createdAt: now,
      updatedAt: now,
    ),
    DiveCenter(
      id: 'dc-2',
      name: 'Blue Planet',
      city: 'Cozumel',
      country: 'Mexico',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> openSection(WidgetTester tester, String title) async {
    final overrides = await getBaseOverrides();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          sitesProvider.overrideWith((ref) async => sites),
          allTripsProvider.overrideWith((ref) async => trips),
          allDiveCentersProvider.overrideWith((ref) async => centers),
          customFieldKeySuggestionsProvider(
            diverId,
          ).overrideWith((ref) async => customFieldKeys),
        ].cast(),
        child: MaterialApp(
          // Pinned: this suite drives the page by English label.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const DiveSearchPage();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The shared base overrides seed no current diver, and the custom field
    // suggestions are keyed by one.
    await capturedRef
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver(diverId);
    await tester.pumpAndSettle();

    // The page builds its sections lazily, so a section near the bottom is
    // not in the tree until it is scrolled to.
    final header = find.text(title);
    if (header.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        header,
        100,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(header.first);
    await tester.pumpAndSettle();
    await tester.tap(header.first);
    await tester.pumpAndSettle();
  }

  /// The field currently showing [label] as its value.
  Finder fieldShowing(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  Iterable<String> suggestions(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(searchableFilterOptionsKey),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data ?? '')
      .where((label) => label.isNotEmpty);

  testWidgets('typing narrows the dive site list', (tester) async {
    await openSection(tester, 'Location');
    await tester.ensureVisible(find.text('All sites').first);
    await tester.pumpAndSettle();

    await tester.tap(fieldShowing('All sites'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldShowing('All sites'), 'coral');
    await tester.pumpAndSettle();

    expect(suggestions(tester), contains('Coral Garden'));
    expect(suggestions(tester), isNot(contains('Blue Hole')));
  });

  testWidgets('a trip is found by where it went', (tester) async {
    await openSection(tester, 'Location');
    await tester.ensureVisible(find.text('All trips').first);
    await tester.pumpAndSettle();

    await tester.tap(fieldShowing('All trips'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldShowing('All trips'), 'sharm');
    await tester.pumpAndSettle();

    expect(suggestions(tester), contains('Summer week'));
    expect(suggestions(tester), isNot(contains('Winter break')));
  });

  // The PR claims a centre is findable by where it is, not only by the name it
  // was saved under, so that claim needs a test.
  testWidgets('a dive center is found by its city', (tester) async {
    await openSection(tester, 'Location');
    await tester.ensureVisible(find.text('All centers').first);
    await tester.pumpAndSettle();

    await tester.tap(fieldShowing('All centers'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldShowing('All centers'), 'cozumel');
    await tester.pumpAndSettle();

    expect(suggestions(tester), contains('Blue Planet'));
    expect(suggestions(tester), isNot(contains('Reef Divers')));
  });

  testWidgets('typing narrows the custom field keys', (tester) async {
    await openSection(tester, 'Custom Field Key');
    await tester.ensureVisible(find.byIcon(Icons.extension).last);
    await tester.pumpAndSettle();

    final field = find.ancestor(
      of: find.byIcon(Icons.extension).last,
      matching: find.byType(TextField),
    );
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'guide');
    await tester.pumpAndSettle();

    expect(suggestions(tester), contains('Guide'));
    expect(suggestions(tester), isNot(contains('Boat name')));
  });
}
