import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/domain/services/altitude_resolver.dart';

/// Fills a newly imported or downloaded dive's altitude from its GPS fixes
/// or linked site. Best-effort like `DiveEquipmentDefaulter`: any failure is
/// swallowed so enrichment can never abort an import that has already
/// persisted the dive. Create ONE instance per import run -- the resolver
/// cache dedupes lookups for a batch of dives at the same location.
class DiveAltitudeEnricher {
  DiveAltitudeEnricher({
    ElevationService? elevationService,
    DiveRepository? diveRepository,
    SiteRepository? siteRepository,
  }) : _resolver = AltitudeResolver(
         elevationService: elevationService ?? ElevationService(),
         cache: <String, double?>{},
       ),
       _dives = diveRepository ?? DiveRepository(),
       _sites = siteRepository ?? SiteRepository();

  final AltitudeResolver _resolver;
  final DiveRepository _dives;
  final SiteRepository _sites;

  /// Enrich a file-imported dive (domain entity in hand). Returns true when
  /// an altitude was written.
  Future<bool> applyForImportedDive(Dive dive) async {
    if (dive.altitude != null) return false;
    if (DatabaseService.instance.databaseOrNull == null) return false;
    try {
      final resolution = await _resolver.resolve(
        entryLocation: dive.entryLocation,
        exitLocation: dive.exitLocation,
        site: dive.site,
      );
      final writeBack = resolution.siteAltitudeWriteBack;
      if (writeBack != null) {
        await _sites.updateSiteAltitude(
          writeBack.siteId,
          writeBack.altitudeMeters,
        );
      }
      final meters = resolution.altitudeMeters;
      if (meters == null) return false;
      await _dives.updateDive(dive.copyWith(altitude: meters));
      return true;
    } catch (_) {
      // Best-effort: never let altitude enrichment fail the dive operation.
      return false;
    }
  }

  /// Enrich a dive persisted by the dive computer download path, where only
  /// the id and the entry/exit GPS fixes are in hand.
  Future<bool> applyForDownloadedDive({
    required String diveId,
    required List<GeoPoint> points,
  }) async {
    if (points.isEmpty) return false;
    if (DatabaseService.instance.databaseOrNull == null) return false;
    try {
      final resolution = await _resolver.resolve(entryLocation: points.first);
      final meters = resolution.altitudeMeters;
      if (meters == null) return false;
      final dive = await _dives.getDiveById(diveId);
      if (dive == null || dive.altitude != null) return false;
      await _dives.updateDive(dive.copyWith(altitude: meters));
      return true;
    } catch (_) {
      // Best-effort: never let altitude enrichment fail the dive operation.
      return false;
    }
  }
}
