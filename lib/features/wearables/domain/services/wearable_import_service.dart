import 'package:submersion/features/wearables/domain/entities/wearable_dive.dart';

/// Abstract interface for importing dives from wearable devices.
///
/// Implementations handle platform-specific APIs:
/// - [HealthKitService] for Apple Watch (iOS/macOS)
/// - Future: GarminService, SuuntoService
abstract class WearableImportService {
  /// Check if this wearable service is available on the current platform.
  ///
  /// Returns true if the underlying health API is accessible.
  Future<bool> isAvailable();

  /// Request necessary permissions to read dive data.
  ///
  /// Returns true if all required permissions were granted.
  Future<bool> requestPermissions();

  /// Check if permissions have already been granted.
  ///
  /// Returns true if we can read dive data without prompting.
  Future<bool> hasPermissions();

  /// Fetch dives within the specified date range.
  ///
  /// [startDate] - Beginning of the date range (inclusive)
  /// [endDate] - End of the date range (inclusive)
  ///
  /// Returns a list of [WearableDive] objects with summary data.
  /// Call [fetchDiveProfile] to get detailed profile samples.
  Future<List<WearableDive>> fetchDives({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Fetch the detailed profile samples for a specific dive.
  ///
  /// [sourceId] - The unique identifier from [WearableDive.sourceId]
  ///
  /// Returns detailed profile samples including depth, temperature, HR.
  Future<List<WearableProfileSample>> fetchDiveProfile(String sourceId);

  /// Get the wearable source type for this service.
  WearableSource get source;
}
