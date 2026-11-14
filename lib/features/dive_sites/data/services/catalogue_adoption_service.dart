import 'dart:async';

import 'package:submersion/core/services/geocoding/sea_area_index.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_mapping.dart';

const _log = LoggerService('CatalogueAdoption');

/// The language the catalogue names seas in: the sea table's own default,
/// which is what the import asks it for.
const _catalogueSeaLanguage = 'en';

/// What adopting a catalogue site came to: the diver's site, and whether
/// this call made it.
///
/// [created] is false when the diver already had the site. Callers run the
/// diver's "after creating by hand" rules only on a site that was created:
/// re-running them on a site the diver has since edited would undo that.
class CatalogueAdoption {
  const CatalogueAdoption({required this.site, required this.created});

  final DiveSite site;
  final bool created;
}

/// Makes one of the diver's sites from a built-in catalogue record.
///
/// The one path every screen that offers built-in sites goes through: the
/// site picker, GPS matching, the import page and the map. So a site
/// adopted anywhere carries the same details and the same link.
class CatalogueAdoptionService {
  CatalogueAdoptionService({
    required SiteRepository siteRepository,
    this.fetchElevation,
    this.loadSeas,
    this.placeNameLanguage,
  }) : _siteRepository = siteRepository;

  final SiteRepository _siteRepository;

  /// Altitude for a point, or null when unknown. Absent in tests and
  /// wherever the caller fills altitudes itself.
  final Future<double?> Function(GeoPoint point)? fetchElevation;

  /// The sea table, or null when it cannot be read. With
  /// [placeNameLanguage], an adopted site's sea is named in the diver's
  /// place-name language. Absent in tests that are not about that.
  final Future<SeaAreaIndex?> Function()? loadSeas;

  /// The diver's place-name language code, read when a site is adopted.
  final String Function()? placeNameLanguage;

  /// Adoptions under way, by diver and catalogue id. "Has the diver this
  /// site?" and "create it" are two steps, so two callers asking at once
  /// (the map and the picker, two taps on two screens) would both create
  /// it; the second waits for the first here instead.
  final Map<String, Future<CatalogueAdoption>> _inFlight = {};

  /// The diver's site for [site], creating it if they have none.
  ///
  /// A diver who already adopted this record gets that site back, so a
  /// second tap, or a stale list, never makes a second site. Two devices
  /// that each adopt the same record before they sync still end with two
  /// sites: nothing local can see the other device's write.
  ///
  /// With [fillAltitude], a new site's altitude is then looked up in the
  /// background: the returned site does not wait for it, and a failed
  /// lookup leaves the altitude empty. Pass false from inside a
  /// transaction, where the caller fills altitudes after it commits.
  Future<CatalogueAdoption> adopt(
    CatalogueSite site, {
    required String? diverId,
    bool fillAltitude = true,
  }) async {
    final key = '${diverId ?? ''}|${site.id}';
    final running = _inFlight[key];
    if (running != null) {
      // The other caller is the one that creates it.
      final first = await running;
      return CatalogueAdoption(site: first.site, created: false);
    }
    final adoption = _adopt(site, diverId: diverId, fillAltitude: fillAltitude);
    _inFlight[key] = adoption;
    try {
      return await adoption;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<CatalogueAdoption> _adopt(
    CatalogueSite site, {
    required String? diverId,
    required bool fillAltitude,
  }) async {
    final existing = await _siteRepository.getSiteByCatalogueId(
      site.id,
      diverId: diverId,
    );
    if (existing != null) {
      return CatalogueAdoption(site: existing, created: false);
    }

    final created = await _siteRepository.createSite(
      catalogueSiteToDiveSite(
        site,
        diverId: diverId,
      ).copyWith(bodyOfWater: await _seaInDiversLanguage(site)),
      classification: catalogueSiteClassification(site),
    );
    _log.info('Adopted catalogue site ${site.id} as ${created.id}');

    final location = created.location;
    final fetch = fetchElevation;
    if (fillAltitude && location != null && fetch != null) {
      unawaited(_fillAltitude(created.id, location, fetch));
    }
    return CatalogueAdoption(site: created, created: true);
  }

  /// [site]'s sea in the diver's place-name language, or null to keep the
  /// catalogue's own text.
  ///
  /// The catalogue names seas in English, from the sea table. Every other
  /// route that names a site's sea asks that table in the diver's language,
  /// so an adopted site does too: one column must not hold "Red Sea" on one
  /// site and "Rotes Meer" on the next. Only a name the sea table gave is
  /// translated; a record that came with its own body of water keeps it.
  /// Never fails an adoption: without the table the catalogue's name stands.
  Future<String?> _seaInDiversLanguage(CatalogueSite site) async {
    final location = site.location;
    final catalogueName = site.bodyOfWater;
    final load = loadSeas;
    final language = placeNameLanguage;
    if (location == null ||
        catalogueName == null ||
        load == null ||
        language == null) {
      return null;
    }
    // The catalogue's names are English already. Most divers stop here,
    // and the sea table (over a megabyte to read and index) stays unread.
    final languageCode = language();
    if (languageCode == _catalogueSeaLanguage) return null;
    try {
      final seas = await load();
      if (seas == null) return null;
      final english = seas.nameAt(location.latitude, location.longitude);
      if (english != catalogueName) return null;
      return seas.nameAt(
        location.latitude,
        location.longitude,
        languageCode: languageCode,
      );
    } catch (error, stackTrace) {
      _log.warning(
        'Could not name the sea of ${site.id} in the place-name language',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
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
