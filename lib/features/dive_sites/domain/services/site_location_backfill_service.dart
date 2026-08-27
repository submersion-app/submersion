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

/// Fills empty country, region, town and body of water for every site that
/// has coordinates (issue #1187). Only empty columns are ever written; the
/// rule itself lives in `mergeMissingLocationDetails` behind
/// [SiteRepository.fillMissingLocationDetails]. Request spacing is the
/// location service's concern.
class SiteLocationBackfillService {
  SiteLocationBackfillService({
    required SiteRepository sites,
    required LocationService location,
    required String languageCode,
  }) : _sites = sites,
       _location = location,
       _languageCode = languageCode;

  final SiteRepository _sites;
  final LocationService _location;
  final String _languageCode;
  static final _log = LoggerService.forClass(SiteLocationBackfillService);

  /// A site the run would look up: coordinates present and at least one of
  /// the four fields blank.
  static bool needsLookup(DiveSite site) =>
      site.location != null &&
      (_isBlank(site.country) ||
          _isBlank(site.region) ||
          _isBlank(site.city) ||
          _isBlank(site.bodyOfWater));

  Future<List<DiveSite>> candidates({String? diverId}) async {
    final all = await _sites.getAllSites(diverId: diverId);
    return all.where(needsLookup).toList(growable: false);
  }

  Future<BackfillSummary> run({
    String? diverId,
    required void Function(int done, int total) onProgress,
    required bool Function() isCancelled,
  }) async {
    final targets = await candidates(diverId: diverId);
    final total = targets.length;
    var updated = 0;
    var unchanged = 0;
    var failed = 0;
    var done = 0;
    onProgress(done, total);

    for (final site in targets) {
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
        } else if (await _sites.fillMissingLocationDetails(site.id, lookup)) {
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
