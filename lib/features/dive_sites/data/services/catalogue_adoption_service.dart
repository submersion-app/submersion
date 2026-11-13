import 'dart:async';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_mapping.dart';

const _log = LoggerService('CatalogueAdoption');

/// Makes one of the diver's sites from a built-in catalogue record.
///
/// The one path every screen that offers built-in sites goes through: the
/// site picker, GPS matching, the import page and the map. So a site
/// adopted anywhere carries the same details and the same link.
class CatalogueAdoptionService {
  CatalogueAdoptionService({
    required SiteRepository siteRepository,
    this.fetchElevation,
  }) : _siteRepository = siteRepository;

  final SiteRepository _siteRepository;

  /// Altitude for a point, or null when unknown. Absent in tests and
  /// wherever the caller fills altitudes itself.
  final Future<double?> Function(GeoPoint point)? fetchElevation;

  /// The diver's site for [site], creating it if they have none.
  ///
  /// A diver who already adopted this record gets that site back, so a
  /// second tap, or a stale list, never makes a second site.
  ///
  /// With [fillAltitude], a new site's altitude is then looked up in the
  /// background: the returned site does not wait for it, and a failed
  /// lookup leaves the altitude empty. Pass false from inside a
  /// transaction, where the caller fills altitudes after it commits.
  Future<DiveSite> adopt(
    CatalogueSite site, {
    required String? diverId,
    bool fillAltitude = true,
  }) async {
    final existing = await _siteRepository.getSiteByCatalogueId(
      site.id,
      diverId: diverId,
    );
    if (existing != null) return existing;

    final created = await _siteRepository.createSite(
      catalogueSiteToDiveSite(site, diverId: diverId),
      classification: catalogueSiteClassification(site),
    );
    _log.info('Adopted catalogue site ${site.id} as ${created.id}');

    final location = created.location;
    final fetch = fetchElevation;
    if (fillAltitude && location != null && fetch != null) {
      unawaited(_fillAltitude(created.id, location, fetch));
    }
    return created;
  }

  Future<void> _fillAltitude(
    String siteId,
    GeoPoint location,
    Future<double?> Function(GeoPoint point) fetch,
  ) async {
    try {
      final meters = await fetch(location);
      if (meters != null) {
        await _siteRepository.updateSiteAltitude(siteId, meters);
      }
    } catch (error, stackTrace) {
      _log.warning(
        'Altitude lookup failed for adopted site $siteId',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
