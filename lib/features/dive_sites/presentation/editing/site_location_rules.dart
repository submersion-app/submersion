import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_merge.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The site's location and altitude rules, as functions of a site's sitting
/// (issue #4527, phase 2): each keeps the behaviour the site edit form had,
/// and a value one of them sets is a change of the card that owns it.

/// Writes [lookup]'s place names into the sitting: only empty ones, or with
/// [overwrite] also those that differ ([mergeLocationDetails] decides). A
/// written country keeps its code. Returns whether anything changed.
bool applyPlaceLookup(
  EditSession<DiveSite> session,
  PlaceLookup lookup, {
  required bool overwrite,
}) {
  final merged = mergeLocationDetails(
    current: sittingPlaceNames(session),
    found: lookup,
    overwrite: overwrite,
  );
  if (merged == null) return false;
  var changed = false;
  void put(EditField<DiveSite, String?> field, String? value) {
    if (value == null || session.valueOf(field) == value) return;
    session.set(field, value);
    changed = true;
  }

  put(siteCountryField, merged.country);
  if (merged.clearCountryCode) {
    if (session.valueOf(siteCountryCodeField) != null) {
      session.set(siteCountryCodeField, null);
      changed = true;
    }
  } else {
    put(siteCountryCodeField, merged.countryCode);
  }
  put(siteRegionField, merged.region);
  put(siteCityField, merged.city);
  put(siteBodyOfWaterField, merged.bodyOfWater);
  return changed;
}

/// The place names [lookup] found that differ from [current], by the label
/// of their field: what Look up asks about before replacing them, on the
/// Location card and on the merge page alike.
Map<String, String> differingPlaceValues(
  SiteLocationDetails current,
  PlaceLookup lookup,
  AppLocalizations l10n,
) {
  final out = <String, String>{};
  void compare(String label, String? shown, String? found) {
    if (found == null || found.trim().isEmpty) return;
    if ((shown ?? '').trim() == found.trim()) return;
    out[label] = found.trim();
  }

  compare(
    l10n.diveSites_edit_field_country_label,
    current.country,
    lookup.country,
  );
  compare(
    l10n.diveSites_edit_field_region_label,
    current.region,
    lookup.region,
  );
  compare(l10n.diveSites_edit_field_city_label, current.city, lookup.locality);
  compare(
    l10n.diveSites_edit_field_bodyOfWater_label,
    current.bodyOfWater,
    lookup.bodyOfWater,
  );
  return out;
}

/// The sitting's place names, as [differingPlaceValues] and
/// [mergeLocationDetails] compare them.
SiteLocationDetails sittingPlaceNames(EditSession<DiveSite> session) =>
    SiteLocationDetails(
      country: session.valueOf(siteCountryField),
      countryCode: session.valueOf(siteCountryCodeField),
      region: session.valueOf(siteRegionField),
      city: session.valueOf(siteCityField),
      bodyOfWater: session.valueOf(siteBodyOfWaterField),
    );

/// Moves the site to [point], as Use my location and Pick from map do, and
/// fills the empty place names from [place].
void moveSiteTo(
  EditSession<DiveSite> session,
  GeoPoint point, {
  PlaceLookup? place,
}) {
  session.set(siteLocationField, point);
  if (place != null) applyPlaceLookup(session, place, overwrite: false);
}

const _moveKey = 'site.altitude.move';
const _foundAskedKey = 'site.altitude.found';
const _foundKey = 'site.altitude.found.value';

/// After [delay], looks up the elevation of the sitting's position and fills
/// an empty altitude with it, as the form does a second after the diver
/// changes the coordinates. Tracked, so Save waits for it. A later call
/// replaces a pending one; an answer for a position the site has since left,
/// or for an altitude the diver has since typed, fills nothing.
void scheduleAltitudeAfterMove(
  EditSession<DiveSite> session,
  Future<double?> Function(GeoPoint point) fetch, {
  Duration delay = const Duration(seconds: 1),
}) {
  final ask = Object();
  session.remember(_moveKey, ask);
  bool current() =>
      !session.isDisposed &&
      !session.isFrozen &&
      identical(session.recall<Object>(_moveKey), ask);
  final work = () async {
    await Future<void>.delayed(delay);
    if (!current()) return;
    final point = session.valueOf(siteLocationField);
    if (point == null || session.valueOf(siteAltitudeField) != null) return;
    final metres = await fetch(point);
    // Below sea level is no altitude the site can hold: the form refused
    // one under 0.
    if (metres == null || metres < 0 || !current()) return;
    if (session.valueOf(siteLocationField) != point) return;
    if (session.valueOf(siteAltitudeField) != null) return;
    session.set(siteAltitudeField, metres);
  }();
  session.track(work);
}

/// The elevation found for a site whose stored position is set and whose
/// altitude is not: what the Altitude card offers as a suggestion, while the
/// site is still there. None below sea level. Asked
/// once per sitting; it changes nothing in the sitting. Null when there is
/// nothing to ask or nothing was found.
Future<double?> foundAltitude(
  EditSession<DiveSite> session,
  Future<double?> Function(GeoPoint point) fetch,
) {
  final stored = session.stored;
  final point = stored.location;
  if (point == null || stored.altitude != null) return Future.value();
  if (session.firstTime(_foundAskedKey)) {
    // Below sea level is nothing to offer: the form refused an altitude
    // under 0.
    final work = fetch(point).then((m) => m == null || m < 0 ? null : m);
    session.remember(_foundKey, work);
    return work;
  }
  return session.recall<Future<double?>>(_foundKey) ?? Future.value();
}

/// The elevation of [point], from the app's elevation service.
Future<double?> fetchSiteElevation(
  ProviderContainer container,
  GeoPoint point,
) => container
    .read(elevationServiceProvider)
    .fetchElevation(latitude: point.latitude, longitude: point.longitude);
