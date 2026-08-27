import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/weekday_filter_selector.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Drives the weekday axis through the sheet itself. The standalone
/// [WeekdayFilterSelector] tests cover the widget in isolation; what is only
/// reachable from here is the sheet's own wiring: the seeded selection, the
/// conditional "Clear weekdays" affordance, and the write-back on Apply.
void main() {
  // A test-owned filter provider so each test starts from a known state and
  // can assert what the sheet writes back.
  late StateProvider<DiveFilterState> filterProvider;

  setUp(() async {
    await setUpTestDatabase();
    filterProvider = StateProvider<DiveFilterState>(
      (ref) => const DiveFilterState(),
    );
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

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    // The sheet's ListView builds children lazily, so the weekday section is
    // not in the tree until it is scrolled near. Pass a PLAIN finder:
    // `evaluate()` on an index-qualified one throws "Bad state: No element"
    // when nothing has been built yet.
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        60.0,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
  }

  /// Only the weekday chips, so the tag chips further down the sheet cannot
  /// be picked up by a bare `find.byType(FilterChip)`.
  Finder weekdayChips() => find.descendant(
    of: find.byType(WeekdayFilterSelector),
    matching: find.byType(FilterChip),
  );

  Future<void> tapText(WidgetTester tester, String label) async {
    await scrollTo(tester, find.text(label));
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  testWidgets('a seeded weekday selection is shown and survives Apply', (
    tester,
  ) async {
    final ref = await openSheet(
      tester,
      initial: const DiveFilterState(weekdays: [DateTime.saturday]),
    );

    await scrollTo(tester, find.byType(WeekdayFilterSelector));

    // The seeded weekday arrives selected, and the clear affordance only
    // renders because something is selected.
    final chips = tester.widgetList<FilterChip>(weekdayChips());
    expect(chips.where((c) => c.selected).length, 1);
    expect(find.text('Clear weekdays'), findsOneWidget);

    await tapText(tester, 'Apply Filters');
    expect(ref.read(filterProvider).weekdays, [DateTime.saturday]);
  });

  testWidgets('tapping a chip adds its weekday to the applied filter', (
    tester,
  ) async {
    final ref = await openSheet(tester);

    await scrollTo(tester, find.byType(WeekdayFilterSelector));

    // Nothing is selected yet, so the clear affordance is absent.
    expect(find.text('Clear weekdays'), findsNothing);

    // en_US is Sunday-first, so the first chip is Sunday.
    await tester.tap(weekdayChips().first);
    await tester.pumpAndSettle();

    expect(find.text('Clear weekdays'), findsOneWidget);

    await tapText(tester, 'Apply Filters');
    expect(ref.read(filterProvider).weekdays, [DateTime.sunday]);
  });

  testWidgets('Clear weekdays empties the selection', (tester) async {
    final ref = await openSheet(
      tester,
      initial: const DiveFilterState(
        weekdays: [DateTime.monday, DateTime.wednesday, DateTime.friday],
      ),
    );

    await tapText(tester, 'Clear weekdays');

    // The affordance removes itself along with the selection it clears.
    expect(find.text('Clear weekdays'), findsNothing);
    final chips = tester.widgetList<FilterChip>(weekdayChips());
    expect(chips.where((c) => c.selected), isEmpty);

    await tapText(tester, 'Apply Filters');
    expect(ref.read(filterProvider).weekdays, isEmpty);
  });
}
