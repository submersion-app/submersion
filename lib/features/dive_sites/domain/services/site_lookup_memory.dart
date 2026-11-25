import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The location fields a lookup can fill, by the names a [SiteLookupNote]
/// stores them under.
enum SiteLocationField { country, region, city, bodyOfWater }

bool _isBlank(String? value) => value == null || value.trim().isEmpty;

/// The fields of [site] that are still empty.
Set<SiteLocationField> blankLocationFields(DiveSite site) => {
  if (_isBlank(site.country)) SiteLocationField.country,
  if (_isBlank(site.region)) SiteLocationField.region,
  if (_isBlank(site.city)) SiteLocationField.city,
  if (_isBlank(site.bodyOfWater)) SiteLocationField.bodyOfWater,
};

/// What one finished lookup left empty on a site, and where the site was
/// when it was asked (issue #4992).
///
/// OpenStreetMap has no answer for some fields at some places: no body of
/// water for a pool or a cenote, no town for a point offshore. Without a
/// note those sites were offered again on every run and came back
/// "unchanged" every time.
class SiteLookupNote {
  const SiteLookupNote({
    required this.latitude,
    required this.longitude,
    required this.blank,
  });

  /// The note for [site] as it stands after the lookup that answered
  /// [found], or null when there is nothing to remember: no coordinates, or
  /// no field that is empty on the site because OpenStreetMap had nothing.
  ///
  /// A field counts only when it is empty on the site *and* in [found]. A
  /// field the lookup did answer but that was not written (a library site this
  /// profile may not edit, say) is not OpenStreetMap's gap, and a body of
  /// water or an address whose lookup failed was never really asked.
  static SiteLookupNote? of(DiveSite site, PlaceLookup found) {
    final point = site.location;
    if (point == null) return null;
    final blank = {
      for (final field in blankLocationFields(site))
        if (_unanswered(field, found)) field,
    };
    if (blank.isEmpty) return null;
    return SiteLookupNote(
      latitude: point.latitude,
      longitude: point.longitude,
      blank: blank,
    );
  }

  static bool _unanswered(
    SiteLocationField field,
    PlaceLookup found,
  ) => switch (field) {
    SiteLocationField.country =>
      _isBlank(found.country) && !found.addressUnknown,
    SiteLocationField.region => _isBlank(found.region) && !found.addressUnknown,
    SiteLocationField.city => _isBlank(found.locality) && !found.addressUnknown,
    SiteLocationField.bodyOfWater =>
      _isBlank(found.bodyOfWater) && !found.bodyOfWaterUnknown,
  };

  final double latitude;
  final double longitude;

  /// The fields the lookup could not fill.
  final Set<SiteLocationField> blank;

  /// Whether asking again about [site] would ask nothing new: it has not
  /// moved, and every field empty now was already empty after this lookup.
  /// A site moved, or a field cleared since, is asked about again.
  bool covers(DiveSite site) {
    final point = site.location;
    if (point == null) return false;
    return point.latitude == latitude &&
        point.longitude == longitude &&
        blank.containsAll(blankLocationFields(site));
  }

  @override
  bool operator ==(Object other) =>
      other is SiteLookupNote &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.blank.length == blank.length &&
      other.blank.containsAll(blank);

  @override
  int get hashCode => Object.hash(
    latitude,
    longitude,
    Object.hashAllUnordered(blank.map((f) => f.index)),
  );
}

/// Where [SiteLookupNote]s are kept, keyed by site id.
///
/// Device-local: a note only spares this device a repeat question to
/// OpenStreetMap, so it is not logbook data and is not synced.
abstract interface class SiteLookupMemory {
  Future<Map<String, SiteLookupNote>> read();

  /// Replaces every stored note with [notes].
  Future<void> write(Map<String, SiteLookupNote> notes);
}
