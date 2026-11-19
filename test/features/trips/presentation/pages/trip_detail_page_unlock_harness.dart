import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/data/services/trip_edit_save_service.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/scrubber_margin_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_day_weather_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The trip the page shows, as stored: a shore trip in 2030, still to come,
/// so the Overview is the prepare page, with notes.
final redSea = Trip(
  id: 't1',
  diverId: 'd1',
  name: 'Red Sea',
  startDate: DateTime(2030, 6, 1),
  endDate: DateTime(2030, 6, 8),
  location: 'Hurghada',
  notes: 'Bring the reef hook',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Records each save the page asks for, stores its result where the page
/// reads the trip from, and can fail.
class FakeTripSave implements TripEditSaveService {
  FakeTripSave(this.stored);

  final StateController<Trip?> stored;

  final calls = <({Trip after, Set<String> cards})>[];
  bool fail = false;

  /// Whether to run the held writes a save is given, as the real one does
  /// inside its transaction.
  bool runHeld = true;

  /// Holds the write until completed.
  Completer<void>? gate;

  @override
  Future<({Trip before, Trip after})?> save({
    required String tripId,
    required Trip Function(Trip stored) apply,
    required Iterable<String> changedCardIds,
    required String? actingDiverId,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) async {
    if (fail) throw StateError('the save failed');
    await gate?.future;
    final before = stored.state!;
    final after = apply(before);
    calls.add((after: after, cards: changedCardIds.toSet()));
    if (runHeld) await alsoWrite?.call();
    stored.state = after;
    return (before: before, after: after);
  }
}

/// A trip list that records deletes and hides, and writes nothing.
class FakeTripList extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  FakeTripList() : super(const AsyncValue.data([]));

  final deleted = <String>[];

  @override
  Future<bool> deleteTrip(String id) async {
    deleted.add(id);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TripPageHarness {
  TripPageHarness(this.save, this.stored, this.trips);

  final FakeTripSave save;
  final StateController<Trip?> stored;
  final FakeTripList trips;
}

final _storedProvider = StateProvider<Trip?>((ref) => redSea);

/// Pumps the trip page with the phase 3 switch on (unless [unlockEditing]
/// is false), at phone width, or as the list's pane when [embedded].
/// [vessel], [days] and [dives] stand in for what the page reads besides
/// the trip.
Future<TripPageHarness> pumpTripPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Trip? trip,
  bool unlockEditing = true,
  bool openUnlocked = false,
  bool embedded = false,
  Size size = const Size(600, 1600),
  VoidCallback? onSittingEnded,
  VoidCallback? onDeleted,
  LiveaboardDetails? vessel,
  List<ItineraryDay> days = const [],
  List<Dive> dives = const [],
  List<Object> extraOverrides = const [],
  Widget Function(Widget page)? wrap,
}) async {
  final shown = trip ?? redSea;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final trips = FakeTripList();
  late TripPageHarness harness;
  final page = TripDetailPage(
    tripId: shown.id,
    unlockEditing: unlockEditing,
    openUnlocked: openUnlocked,
    embedded: embedded,
    onSittingEnded: onSittingEnded,
    onDeleted: onDeleted,
  );
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...overrides,
        _storedProvider.overrideWith((ref) => shown),
        tripByIdProvider(
          shown.id,
        ).overrideWith((ref) async => ref.watch(_storedProvider)),
        tripWithStatsProvider(shown.id).overrideWith(
          (ref) async =>
              TripWithStats(trip: ref.watch(_storedProvider)!, diveCount: 0),
        ),
        tripStoryProvider(shown.id).overrideWith(
          (ref) async => buildTripStory(
            trip: ref.watch(_storedProvider)!,
            dives: dives,
            itineraryDays: days,
            mediaByDiveId: const {},
            sightingsByDiveId: const {},
            checklistItems: const [],
            today: DateTime.now(),
          ),
        ),
        diveIdsForTripProvider(
          shown.id,
        ).overrideWith((ref) async => [for (final d in dives) d.id]),
        divesForTripProvider(shown.id).overrideWith((ref) async => dives),
        itineraryDaysProvider(shown.id).overrideWith((ref) async => days),
        numberedItineraryDaysProvider(
          shown.id,
        ).overrideWith((ref) async => days),
        liveaboardDetailsProvider(shown.id).overrideWith((ref) async => vessel),
        tripDayWeatherProvider(shown.id).overrideWith((ref) async => const {}),
        tripDayWeatherBackfillProvider(shown.id).overrideWith((ref) async {}),
        tripGearProvider(shown.id).overrideWith((ref) async => const []),
        tripCylinderStatesProvider(
          shown.id,
        ).overrideWith((ref) async => const []),
        tripServiceAlertsProvider(
          shown.id,
        ).overrideWith((ref) async => const []),
        tripScrubberMarginsProvider(
          shown.id,
        ).overrideWith((ref) async => const <ScrubberMargin>[]),
        tripFillForecastProvider(shown.id).overrideWith((ref) async => null),
        tripChecklistsProvider(shown.id).overrideWith((ref) async => const []),
        tripChecklistAllItemsProvider(
          shown.id,
        ).overrideWith((ref) async => const []),
        tripChecklistCombinedProgressProvider(
          shown.id,
        ).overrideWith((ref) async => (done: 0, total: 0)),
        tripListNotifierProvider.overrideWith((ref) => trips),
        tripEditSaveServiceProvider.overrideWith((ref) {
          final save = FakeTripSave(ref.watch(_storedProvider.notifier));
          harness = TripPageHarness(
            save,
            ref.watch(_storedProvider.notifier),
            trips,
          );
          return save;
        }),
        ...extraOverrides,
      ],
      child: Theme(
        data: AppThemeRegistry.resolveTheme(
          AppThemeRegistry.presets.first,
          brightness,
        ),
        child: wrap?.call(page) ?? (embedded ? Scaffold(body: page) : page),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(TripDetailPage)),
  );
  container.read(tripEditSaveServiceProvider);
  return harness;
}

/// A liveaboard of [redSea]'s dates.
final liveaboard = redSea.copyWith(tripType: TripType.liveaboard);

/// The active profile is [redSea]'s owner, the only one, so the menu offers
/// Delete.
final List<Object> ownerOverrides = [
  validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
  allDiversProvider.overrideWith((ref) async => const []),
  isHiddenProvider.overrideWith((ref, key) async => false),
  itemSharingProvider.overrideWith((ref, key) async => ItemSharing.none),
];
