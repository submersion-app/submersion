import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/overview/trip_prepare_overview.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tabs.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// The Overview before departure (#2845).
void main() {
  final now = DateTime.now();

  Trip trip({String notes = ''}) => Trip(
    id: 't1',
    name: 'Bonaire',
    startDate: DateTime(now.year, now.month, now.day + 12),
    endDate: DateTime(now.year, now.month, now.day + 19),
    notes: notes,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  TripChecklistItem todo(String id, {bool done = false}) => TripChecklistItem(
    id: id,
    tripId: 't1',
    title: id,
    isDone: done,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  /// Pumps the overview as the page does: inside a DefaultTabController,
  /// with no row handler, so rows switch the real tabs.
  Future<void> pump(
    WidgetTester tester,
    Trip t, {
    List<TripChecklistItem> checklist = const [],
  }) async {
    final story = buildTripStory(
      trip: t,
      dives: const [],
      itineraryDays: const [],
      mediaByDiveId: const {},
      sightingsByDiveId: const {},
      checklistItems: checklist,
      today: now,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          tripChecklistProvider('t1').overrideWith((ref) async => checklist),
          tripGearProvider('t1').overrideWith((ref) async => const []),
          tripCylinderStatesProvider(
            't1',
          ).overrideWith((ref) async => const []),
          tripServiceAlertsProvider('t1').overrideWith((ref) async => const []),
          itineraryDaysProvider('t1').overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DefaultTabController(
            length: TripDetailTab.values.length,
            child: Scaffold(body: TripPrepareOverview(story: story)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the notes when the trip has them', (tester) async {
    await pump(tester, trip(notes: 'Truck rental booked.'));
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Truck rental booked.'), findsOneWidget);
  });

  testWidgets('shows no notes card for a trip without notes', (tester) async {
    await pump(tester, trip());
    expect(find.text('Notes'), findsNothing);
  });

  testWidgets('a row switches the page tab when no handler is given', (
    tester,
  ) async {
    await pump(tester, trip());
    final controller = DefaultTabController.of(
      tester.element(find.byType(TripPrepareOverview)),
    );
    expect(controller.index, TripDetailTab.overview.index);
    await tester.tap(find.text('Gear'));
    await tester.pumpAndSettle();
    expect(controller.index, TripDetailTab.gear.index);
  });

  testWidgets('shows the checklist progress once, in the Checklist row '
      '(#2881)', (tester) async {
    await pump(tester, trip(), checklist: [todo('a', done: true), todo('b')]);
    expect(find.text('1 of 2 done'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
