import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';

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
