import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';

/// What the platform health API will tell us about read access.
///
/// Apple deliberately refuses to disclose whether *read* access was granted,
/// so on iOS the answer is almost always [undetermined]. Treating that as
/// "denied" is what broke Apple Watch import: the only honest reading of
/// [undetermined] is "try the query and see what comes back".
enum HealthPermissionStatus {
  /// No health API on this platform, or it is unusable on this device.
  unsupported,

  /// The platform confirms we may read the data we asked for.
  granted,

  /// The platform confirms we may not read the data we asked for.
  denied,

  /// The platform will not say. Either access has never been requested, or
  /// (iOS read access) the API refuses to disclose the answer by design.
  undetermined,
}

/// Whether it is worth issuing a read query for this status.
extension HealthPermissionStatusX on HealthPermissionStatus {
  /// True unless the platform has definitively ruled a read out.
  ///
  /// [HealthPermissionStatus.undetermined] counts as readable: on iOS it is
  /// the normal answer for a granted read, and a query on a genuinely
  /// unauthorized type simply comes back empty.
  bool get canAttemptRead =>
      this != HealthPermissionStatus.unsupported &&
      this != HealthPermissionStatus.denied;
}

/// Abstract interface for importing dives from platform health APIs.
///
/// Implementations handle platform-specific APIs:
/// - `HealthKitService` for Apple Watch, iOS only. The `health` package
///   declares android and ios platforms and nothing else, so there is no
///   macOS path to support however capable the Mac is.
/// - Future: GarminService, SuuntoService
abstract class HealthImportService {
  /// Check if this health import service is available on the current platform.
  ///
  /// Reports platform capability only — whether a health API exists here at
  /// all. It says nothing about permissions; use [permissionStatus] for that.
  Future<bool> isAvailable();

  /// Request necessary permissions to read dive data.
  ///
  /// Returns true if the request completed. On iOS a completed request does
  /// not imply the user granted anything: Apple will not disclose read access.
  /// Requesting again once the user has decided is a silent no-op, so callers
  /// may call this on every visit rather than gating it behind a check.
  Future<bool> requestPermissions();

  /// What the platform will tell us about read access.
  Future<HealthPermissionStatus> permissionStatus();

  /// Whether the platform *confirms* read access has been granted.
  ///
  /// This is [permissionStatus] narrowed to [HealthPermissionStatus.granted],
  /// so it is false whenever the platform declines to answer. Never use it to
  /// gate a read — use [HealthPermissionStatusX.canAttemptRead].
  Future<bool> hasPermissions();

  /// Fetch dives within the specified date range.
  ///
  /// [startDate] - Beginning of the date range (inclusive)
  /// [endDate] - End of the date range (inclusive)
  ///
  /// Returns a list of [ImportedDive] objects with summary data.
  /// Call [fetchDiveProfile] to get detailed profile samples.
  Future<List<ImportedDive>> fetchDives({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Fetch the detailed profile samples for a specific dive.
  ///
  /// [sourceId] - The unique identifier from [ImportedDive.sourceId]
  ///
  /// Returns detailed profile samples including depth, temperature, HR.
  Future<List<ImportedProfileSample>> fetchDiveProfile(String sourceId);

  /// Get the import source type for this service.
  ImportSource get source;
}
