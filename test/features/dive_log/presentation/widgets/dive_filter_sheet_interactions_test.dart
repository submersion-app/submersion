import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide DiveSite, DiveComputer;
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Interaction coverage for the extracted [DiveFilterSheet] (issue #453). The
/// two existing sheet tests only cover the favorites toggle and one date
/// preset; this drives every remaining control (presets, date pickers, the
/// three dropdowns, depth/duration/buddy text fields, tag chips, gas-mix and
/// rating selectors) plus the Clear All / Apply actions.
void main() {
  // A test-owned filter provider so each test starts from a known state and
  // asserts what the sheet writes back.
  late StateProvider<DiveFilterState> filterProvider;

  final now = DateTime(2026, 6, 1);

  final diveTypes = [
    DiveTypeEntity(id: 'wreck', name: 'Wreck', createdAt: now, updatedAt: now),
    DiveTypeEntity(id: 'reef', name: 'Reef', createdAt: now, updatedAt: now),
  ];

  const sites = [
    DiveSite(id: 'site-1', name: 'Blue Hole'),
    DiveSite(id: 'site-2', name: 'Coral Garden'),
  ];

  final computers = [
    DiveComputer(
      id: 'c1',
      name: 'Perdix',
      serialNumber: 'SN123',
      createdAt: now,
      updatedAt: now,
    ),
    DiveComputer(
      id: 'c2',
      name: 'Teric',
      serialNumber: 'SN456',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    filterProvider = StateProvider<DiveFilterState>(
      (ref) => const DiveFilterState(),
    );
    // Seed two tags so the Tags section renders its non-empty (FilterChip)
    // branch. getAllTags(diverId: null) returns every row on an empty DB.
    for (final (id, name) in [('t1', 'Night'), ('t2', 'Deep')]) {
      await db
          .into(db.tags)
          .insert(
            TagsCompanion(
              id: Value(id),
              name: Value(name),
              createdAt: Value(now.millisecondsSinceEpoch),
              updatedAt: Value(now.millisecondsSinceEpoch),
            ),
          );
    }
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// Pumps a scaffold with a button that opens the sheet in a modal bottom
  /// sheet (so the sheet's Navigator.pop closes it cleanly), returning the
  /// captured [WidgetRef] for reading the filter provider afterwards.
  Future<WidgetRef> openSheet(
    WidgetTester tester, {
    DiveFilterState initial = const DiveFilterState(),
  }) async {
    final overrides = await getBaseOverrides();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          filterProvider.overrideWith((ref) => initial),
          diveTypesProvider.overrideWith((ref) async => diveTypes),
          sitesProvider.overrideWith((ref) async => sites),
          allDiveComputersProvider.overrideWith((ref) async => computers),
        ].cast(),
        child: MaterialApp(
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

  Finder scrollable() => find.byType(Scrollable).first;

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    // The sheet's ListView builds children lazily, so a deep target may not be
    // in the tree yet; scroll it in. Targets already present (e.g. the preset
    // chips near the top) are skipped to avoid a needless scroll.
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 60.0, scrollable: scrollable());
    }
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String label) async {
    await scrollTo(tester, find.text(label));
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  testWidgets('date presets and clear-dates affordance', (tester) async {
    final ref = await openSheet(tester);

    // The preset chips all live in one Wrap at the top of the sheet, so they
    // are visible without scrolling. Tapping each runs its own setState
    // closure.
    Future<void> tapChip(String label) async {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
    }

    await tapChip('This year');
    await tapChip('Last year');
    await tapChip('Last 12 months');

    // Dates are now set, so the "Clear dates" button is shown.
    await tapChip('Clear dates');

    // This year sets a range; All time then resets both bounds.
    await tapChip('This year');
    await tapChip('All time');

    await tapText(tester, 'Apply Filters');
    // All time was applied last, so both bounds are null.
    expect(ref.read(filterProvider).startDate, isNull);
    expect(ref.read(filterProvider).endDate, isNull);
  });

  testWidgets('start and end date pickers write the range', (tester) async {
    final ref = await openSheet(tester);

    await scrollTo(tester, find.text('Start Date'));
    await tester.tap(find.text('Start Date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('End Date'));
    await tester.tap(find.text('End Date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tapText(tester, 'Apply Filters');
    expect(ref.read(filterProvider).startDate, isNotNull);
    expect(ref.read(filterProvider).endDate, isNotNull);
  });

  testWidgets('dive type, site and computer dropdowns write selections', (
    tester,
  ) async {
    // Prefill a stale computer serial so the "reset unknown serial to null"
    // branch runs before selection.
    final ref = await openSheet(
      tester,
      initial: const DiveFilterState(computerSerial: 'GHOST'),
    );

    Future<void> selectFrom(String hint, String option) async {
      await scrollTo(tester, find.text(hint).first);
      await tester.tap(find.text(hint).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    await selectFrom('All types', 'Wreck');
    await selectFrom('All sites', 'Blue Hole');
    await selectFrom('All computers', 'Perdix');

    await tapText(tester, 'Apply Filters');
    final applied = ref.read(filterProvider);
    expect(applied.diveTypeId, 'wreck');
    expect(applied.siteId, 'site-1');
    expect(applied.computerSerial, 'SN123');
  });

  testWidgets('depth, buddy and duration text fields write values', (
    tester,
  ) async {
    final ref = await openSheet(tester);

    final depthFields = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.suffixText == 'm',
    );
    final durationFields = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.suffixText == 'min',
    );

    await scrollTo(tester, find.text('Depth Range (meters)'));
    await tester.enterText(depthFields.first, '12');
    await tester.enterText(depthFields.last, '30');
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byType(TextField).at(2));
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Buddy Name',
      ),
      'Alex',
    );
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Duration (minutes)'));
    await tester.enterText(durationFields.first, '20');
    await tester.enterText(durationFields.last, '60');
    await tester.pumpAndSettle();

    await tapText(tester, 'Apply Filters');
    final applied = ref.read(filterProvider);
    expect(applied.minDepth, 12);
    expect(applied.maxDepth, 30);
    expect(applied.buddyNameFilter, 'Alex');
    expect(applied.minBottomTimeMinutes, 20);
    expect(applied.maxBottomTimeMinutes, 60);
  });

  testWidgets('favorites, tags, gas-mix and rating selectors', (tester) async {
    final ref = await openSheet(tester);

    await tapText(tester, 'Favorites Only');

    // Tag chips: select then deselect exercises both onSelected arms.
    await tapText(tester, 'Night');
    await tapText(tester, 'Deep');
    await tapText(tester, 'Deep');

    // Gas-mix choice chips. 'All' is selected by default, so tap another
    // first to deselect it before tapping 'All' (its onSelected body only
    // runs when it becomes selected). End on 'Air' for the assertion below.
    await tapText(tester, 'Nitrox (>21%)');
    await tapText(tester, 'All');
    await tapText(tester, 'Air (21%)');

    // Rating: set, tap the same star to clear, set again, then use the
    // Clear rating filter button.
    await scrollTo(tester, find.text('Minimum Rating'));
    final stars = find.byIcon(Icons.star_border);
    await tester.tap(stars.at(3));
    await tester.pumpAndSettle();
    // Now four stars are filled; tapping the 4th filled star clears it.
    await tester.tap(find.byIcon(Icons.star).at(3));
    await tester.pumpAndSettle();
    // Set again then clear via the button.
    await tester.tap(find.byIcon(Icons.star_border).at(1));
    await tester.pumpAndSettle();
    await tapText(tester, 'Clear rating filter');

    await tapText(tester, 'Apply Filters');
    final applied = ref.read(filterProvider);
    expect(applied.favoritesOnly, true);
    expect(applied.tagIds, contains('t1'));
    expect(applied.tagIds, isNot(contains('t2')));
    // Air (21%) was the last gas-mix selection.
    expect(applied.minO2Percent, 20);
    expect(applied.maxO2Percent, 22);
    expect(applied.minRating, isNull);
  });

  testWidgets('Clear All resets the filter and closes the sheet', (
    tester,
  ) async {
    final ref = await openSheet(
      tester,
      initial: const DiveFilterState(favoritesOnly: true, minDepth: 10),
    );
    expect(ref.read(filterProvider).hasActiveFilters, true);

    await tapText(tester, 'Clear All');
    expect(ref.read(filterProvider).hasActiveFilters, false);
    expect(find.byType(DiveFilterSheet), findsNothing);
  });

  testWidgets('close button dismisses the sheet', (tester) async {
    await openSheet(tester);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(DiveFilterSheet), findsNothing);
  });
}
