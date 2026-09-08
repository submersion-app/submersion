import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Outcome of one backfill run.
class BackfillSummary {
  const BackfillSummary({
    required this.total,
    required this.updated,
    required this.unchanged,
    required this.failed,
    this.cancelled = false,
    this.offline = false,
  });

  final int total;
  final int updated;
  final int unchanged;
  final int failed;
  final bool cancelled;

  /// The geocoder could not be reached on the first request, so the run
  /// stopped before collecting one failure per site.
  final bool offline;
}

bool _isBlank(String? value) => value == null || value.trim().isEmpty;

/// What a run writes to the sites it looks up (issue #1187).
enum SiteLocationLookupMode {
  /// Only blank country, region, town and body of water are filled, so a
  /// hand-typed or deliberately cleared value survives.
  fillMissing,

  /// Every site with coordinates is looked up again and a differing value is
  /// replaced, which brings a database geocoded in more than one place name
  /// language back to a single language.
  refreshAll,
}

/// Looks up country, region, town and body of water for every site that has
/// coordinates (issue #1187). What is written depends on [mode]; the rule
/// itself lives in `mergeLocationDetails` behind
/// [SiteRepository.applyLocationDetails]. Request spacing is the location
/// service's concern.
class SiteLocationBackfillService {
  SiteLocationBackfillService({
    required SiteRepository sites,
    required LocationService location,
    required String languageCode,
    required this.mode,
  }) : _sites = sites,
       _location = location,
       _languageCode = languageCode;

  final SiteRepository _sites;
  final LocationService _location;
  final String _languageCode;

  /// What this run writes to the sites it looks up.
  final SiteLocationLookupMode mode;
  static final _log = LoggerService.forClass(SiteLocationBackfillService);

  /// A site a [SiteLocationLookupMode.fillMissing] run would look up:
  /// coordinates present and at least one of the four fields blank.
  static bool needsLookup(DiveSite site) =>
      site.location != null &&
      (_isBlank(site.country) ||
          _isBlank(site.region) ||
          _isBlank(site.city) ||
          _isBlank(site.bodyOfWater));

  /// Whether [mode] would look this site up. A refresh asks about every
  /// site that has coordinates, however complete it already looks, because
  /// a filled field may hold a name in the wrong language.
  static bool wants(DiveSite site, SiteLocationLookupMode mode) =>
      mode == SiteLocationLookupMode.refreshAll
      ? site.location != null
      : needsLookup(site);

  Future<List<DiveSite>> candidates({String? diverId}) async {
    final all = await _sites.getAllSites(diverId: diverId);
    return all.where((site) => wants(site, mode)).toList(growable: false);
  }

  /// Runs the lookup over [targets], or over [candidates] when the caller
  /// has none to hand. A caller that already listed the candidates (to
  /// confirm on their count, say) passes them here so the database is not
  /// scanned and mapped a second time.
  Future<BackfillSummary> run({
    String? diverId,
    List<DiveSite>? targets,
    required void Function(int done, int total) onProgress,
    required bool Function() isCancelled,
  }) async {
    final sites = targets ?? await candidates(diverId: diverId);
    final total = sites.length;
    var updated = 0;
    var unchanged = 0;
    var failed = 0;
    var done = 0;
    onProgress(done, total);

    for (final site in sites) {
      if (isCancelled()) {
        return BackfillSummary(
          total: total,
          updated: updated,
          unchanged: unchanged,
          failed: failed,
          cancelled: true,
        );
      }
      final point = site.location!;
      try {
        final lookup = await _location.reverseGeocode(
          point.latitude,
          point.longitude,
          languageCode: _languageCode,
        );
        if (lookup.networkFailed) {
          if (done == 0) {
            return BackfillSummary(
              total: total,
              updated: updated,
              unchanged: unchanged,
              failed: failed,
              offline: true,
            );
          }
          failed++;
        } else if (await _sites.applyLocationDetails(
          site.id,
          lookup,
          overwrite: mode == SiteLocationLookupMode.refreshAll,
        )) {
          updated++;
        } else {
          unchanged++;
        }
      } catch (e, stackTrace) {
        _log.warning(
          'Backfill failed for site ${site.id}: $e',
          error: e,
          stackTrace: stackTrace,
        );
        failed++;
      }
      done++;
      onProgress(done, total);
    }

    return BackfillSummary(
      total: total,
      updated: updated,
      unchanged: unchanged,
      failed: failed,
    );
  }
}
