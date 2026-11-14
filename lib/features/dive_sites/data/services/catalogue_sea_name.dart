import 'package:submersion/core/services/geocoding/sea_area_index.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';

const _log = LoggerService('CatalogueSeaName');

/// The language the catalogue names seas in: the sea table's own default,
/// which is what the import asks it for.
const _catalogueSeaLanguage = 'en';

/// [site]'s sea in the diver's place-name language, or null to keep the
/// catalogue's own text.
///
/// The catalogue names seas in English, from the sea table. Every other
/// route that names a site's sea asks that table in the diver's language,
/// so a site that takes its sea from the catalogue does too: one column
/// must not hold "Red Sea" on one site and "Rotes Meer" on the next. Only
/// a name the sea table gave is translated; a record that came with its
/// own body of water keeps it. Never throws: without the table the
/// catalogue's name stands.
Future<String?> catalogueSeaInDiversLanguage(
  CatalogueSite site, {
  required Future<SeaAreaIndex?> Function()? loadSeas,
  required String Function()? placeNameLanguage,
}) async {
  final location = site.location;
  final catalogueName = site.bodyOfWater;
  if (location == null ||
      catalogueName == null ||
      loadSeas == null ||
      placeNameLanguage == null) {
    return null;
  }
  // The catalogue's names are English already. Most divers stop here,
  // and the sea table (over a megabyte to read and index) stays unread.
  final languageCode = placeNameLanguage();
  if (languageCode == _catalogueSeaLanguage) return null;
  try {
    final seas = await loadSeas();
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
