import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_picker.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('a failed trip load says so without the exception', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          allTripsProvider.overrideWith(
            (ref) => Future<List<Trip>>.error(StateError('database is locked')),
          ),
        ],
        child: TripPickerSheet(
          scrollController: scrollController,
          selectedTrip: null,
          onTripSelected: (_) {},
          onCreateNewTrip: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your trips."), findsOneWidget);
    expect(find.textContaining('database is locked'), findsNothing);
  });

  group('packed trips (issue #2654)', () {
    // The tile dates come from intl, which reads the process-wide
    // Intl.defaultLocale rather than the app's locale. Pin it, and restore it
    // so no other test file inherits it.
    late String? previousLocale;
    setUp(() {
      previousLocale = Intl.defaultLocale;
      Intl.defaultLocale = 'en';
    });
    tearDown(() => Intl.defaultLocale = previousLocale);

    final now = DateTime(2026, 10, 12);
    Trip trip(String id) => Trip(
      id: id,
      name: 'Trip $id',
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 7),
      createdAt: now,
      updatedAt: now,
    );

    Future<(AppLocalizations, List<Trip>)> pump(
      WidgetTester tester, {
      Set<String>? packedTripIds,
    }) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final picked = <Trip>[];
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            allTripsProvider.overrideWith(
              (ref) async => [trip('a'), trip('b')],
            ),
          ],
          child: packedTripIds == null
              ? TripPickerSheet(
                  scrollController: scrollController,
                  selectedTrip: null,
                  onTripSelected: picked.add,
                  onCreateNewTrip: () {},
                )
              : TripPickerSheet(
                  scrollController: scrollController,
                  selectedTrip: null,
                  packedTripIds: packedTripIds,
                  onTripSelected: picked.add,
                  onCreateNewTrip: () {},
                ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(TripPickerSheet)),
      );
      return (l10n, picked);
    }

    testWidgets('a packed trip says so and cannot be picked', (tester) async {
      final (l10n, picked) = await pump(tester, packedTripIds: {'a'});
      expect(find.text(l10n.trips_picker_alreadyPacked), findsOneWidget);
      final tile = find.ancestor(
        of: find.text('Trip a'),
        matching: find.byType(ListTile),
      );
      expect(tester.widget<ListTile>(tile).enabled, isFalse);
      expect(
        find.descendant(
          of: tile,
          matching: find.byIcon(Icons.luggage_outlined),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Trip a'));
      await tester.pumpAndSettle();
      expect(picked, isEmpty);
    });

    testWidgets('an unpacked trip beside it can still be picked', (
      tester,
    ) async {
      final (_, picked) = await pump(tester, packedTripIds: {'a'});
      await tester.tap(find.text('Trip b'));
      await tester.pumpAndSettle();
      expect(picked.map((t) => t.id), ['b']);
    });

    testWidgets('a packed trip reads as already packed', (tester) async {
      final handle = tester.ensureSemantics();
      // Disposed in finally: a leaked handle fails the test on its own and
      // buries a real mismatch.
      try {
        final (l10n, _) = await pump(tester, packedTripIds: {'a'});
        expect(
          // The tile's own text follows the label in the merged node.
          find.bySemanticsLabel(
            RegExp(
              '^${RegExp.escape(l10n.trips_picker_tileSemanticsPacked('Trip a', 'Nov 1, 2026', 'Nov 7, 2026'))}',
            ),
          ),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('with no packed trips given, nothing is marked', (
      tester,
    ) async {
      final (l10n, picked) = await pump(tester);
      expect(find.text(l10n.trips_picker_alreadyPacked), findsNothing);
      expect(find.byIcon(Icons.luggage_outlined), findsNothing);
      await tester.tap(find.text('Trip a'));
      await tester.pumpAndSettle();
      expect(picked.map((t) => t.id), ['a']);
    });
  });
}
