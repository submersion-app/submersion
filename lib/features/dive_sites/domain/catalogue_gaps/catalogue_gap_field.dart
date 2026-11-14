/// A detail a built-in catalogue record can give to one of the diver's
/// sites, in the order they are shown.
///
/// The names are stored: a field the diver turned down is remembered by
/// its name in the site's catalogue answers. Never rename one.
enum CatalogueGapField {
  position,
  depth,
  country,
  region,
  city,
  island,
  bodyOfWater,
  waterType,
  siteTypes,
  entry,
  difficulty,
  hazards,
  description;

  /// The fields that say where the site is. They are offered only to a
  /// site that is at the record's place.
  static const place = {position, country, region, city, island, bodyOfWater};
}
