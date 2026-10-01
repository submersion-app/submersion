import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/services/itinerary_day_numbers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// Repository provider for liveaboard details
final liveaboardDetailsRepositoryProvider =
    Provider<LiveaboardDetailsRepository>((ref) {
      return LiveaboardDetailsRepository();
    });

/// Repository provider for itinerary days
final itineraryDayRepositoryProvider = Provider<ItineraryDayRepository>((ref) {
  return ItineraryDayRepository();
});

/// Liveaboard details for a specific trip
final liveaboardDetailsProvider =
    FutureProvider.family<LiveaboardDetails?, String>((ref, tripId) async {
      final repository = ref.watch(liveaboardDetailsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchLiveaboardChanges());
      return repository.getByTripId(tripId);
    });

/// Itinerary days for a specific trip
final itineraryDaysProvider = FutureProvider.family<List<ItineraryDay>, String>(
  (ref, tripId) async {
    final repository = ref.watch(itineraryDayRepositoryProvider);
    ref.invalidateSelfWhen(repository.watchItineraryChanges());
    return repository.getByTripId(tripId);
  },
);

/// A trip's itinerary as the itinerary tab lists it: in date order, each day
/// numbered from its date the way the trip story numbers it, so the numbers
/// follow the trip's dates however they moved (#2664).
final numberedItineraryDaysProvider =
    FutureProvider.family<List<ItineraryDay>, String>((ref, tripId) async {
      final days = await ref.watch(itineraryDaysProvider(tripId).future);
      final trip = await ref.watch(tripByIdProvider(tripId).future);
      if (trip == null) return days;
      final dives = await ref.watch(divesForTripProvider(tripId).future);
      return numberItineraryDays(trip: trip, dives: dives, itineraryDays: days);
    });
