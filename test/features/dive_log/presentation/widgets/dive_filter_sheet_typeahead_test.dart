import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/searchable_filter_dropdown.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Type-ahead coverage for the dive type, site and computer filters
/// (issue #1575). With a long site list the only way to reach a site was to
/// scroll a plain dropdown and recognise the name; these drive the filters by
/// typing instead.
void main() {
  late StateProvider<DiveFilterState> filterProvider;

  final now = DateTime(2026, 6, 1);

  final diveTypes = [
    DiveTypeEntity(id: 'wreck', name: 'Wreck', createdAt: now, updatedAt: now),
    DiveTypeEntity(id: 'reef', name: 'Reef', createdAt: now, updatedAt: now),
  ];

  const sites = [
    DiveSite(id: 'site-1', name: 'Blue Hole', country: 'Egypt'),
    DiveSite(id: 'site-2', name: 'Coral Garden', country: 'Mexico'),
    DiveSite(id: 'site-3', name: 'Thistlegorm', country: 'Egypt'),
  ];

  final computers = [
    DiveComputer(
      id: 'c1',
      // Renamed by the diver, so the make and model are not on the label.
      name: 'Backup unit',
      manufacturer: 'Shearwater',
      model: 'Perdix',
      createdAt: now,
      updatedAt: now,
    ),
    DiveComputer(id: 'c2', name: 'Teric', createdAt: now, updatedAt: now),
  ];

  setUp(() async {
    await setUpTestDatabase();
    filterProvider = StateProvider<DiveFilterState>(
      (ref) => const DiveFilterState(),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<WidgetRef> openSheet(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          filterProvider.overrideWith((ref) => const DiveFilterState()),
          diveTypesProvider.overrideWith((ref) async => diveTypes),
          sitesProvider.overrideWith((ref) async => sites),
          allDiveComputersProvider.overrideWith((ref) async => computers),
        ].cast(),
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
                      builder: (_) => DiveFilterSheet(
                        ref: ref,
                        filterProvider: filterProvider,
                      ),
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

  Finder sheetScrollable() => find.byType(Scrollable).first;

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        60.0,
        scrollable: sheetScrollable(),
      );
    }
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
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

  /// The suggestion row offering [label], scoped to the suggestion list so a
  /// button elsewhere on the surface cannot stand in for it.
  Finder suggestion(String label) => find.descendant(
    of: find.byKey(searchableFilterOptionsKey),
    matching: find.widgetWithText(InkWell, label),
  );

  Future<void> tapText(WidgetTester tester, String label) async {
    await scrollTo(tester, find.text(label));
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  // Regression: the field lives inside the sheet's scrolling list, and
  // focusing it scrolls the caret into view. A dropdown whose menu closes on
  // ancestor scroll opened and shut again in the same gesture, so the diver
  // had to tap twice to see anything.
  testWidgets('one tap opens the suggestion list inside the scrolling sheet', (
    tester,
  ) async {
    await openSheet(tester);
    await scrollTo(tester, find.text('All sites'));

    await tester.tap(fieldShowing('All sites'));
    await tester.pumpAndSettle();

    expect(
      suggestions(tester),
      containsAll(<String>['Blue Hole', 'Coral Garden', 'Thistlegorm']),
    );
  });

  testWidgets('typing a site name narrows the list and applies the site', (
    tester,
  ) async {
    final ref = await openSheet(tester);
    await scrollTo(tester, find.text('All sites'));

    await tester.tap(fieldShowing('All sites'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldShowing('All sites'), 'coral');
    await tester.pumpAndSettle();

    expect(suggestions(tester), contains('Coral Garden'));
    expect(suggestions(tester), isNot(contains('Blue Hole')));

    await tester.tap(suggestion('Coral Garden'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Apply Filters');

    expect(ref.read(filterProvider).siteId, 'site-2');
  });

  testWidgets('typing a country finds the sites in it', (tester) async {
    await openSheet(tester);
    await scrollTo(tester, find.text('All sites'));

    await tester.tap(fieldShowing('All sites'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldShowing('All sites'), 'egypt');
    await tester.pumpAndSettle();

    expect(
      suggestions(tester),
      containsAll(<String>['Blue Hole', 'Thistlegorm']),
    );
    expect(suggestions(tester), isNot(contains('Coral Garden')));
  });

  testWidgets('typing a dive type name applies that type', (tester) async {
    final ref = await openSheet(tester);
    await scrollTo(tester, find.text('All types'));

    await tester.tap(fieldShowing('All types'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldShowing('All types'), 'wre');
    await tester.pumpAndSettle();

    await tester.tap(suggestion('Wreck'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Apply Filters');

    expect(ref.read(filterProvider).diveTypeId, 'wreck');
  });

  // A diver who renamed a computer still knows what it says on the case.
  testWidgets('a renamed computer is found by its make and model', (
    tester,
  ) async {
    final ref = await openSheet(tester);
    await scrollTo(tester, find.text('All computers'));

    await tester.tap(fieldShowing('All computers'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldShowing('All computers'), 'perdix');
    await tester.pumpAndSettle();

    expect(suggestions(tester), contains('Backup unit'));
    expect(suggestions(tester), isNot(contains('Teric')));

    await tester.tap(suggestion('Backup unit'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Apply Filters');

    expect(ref.read(filterProvider).computerId, 'c1');
  });
}
