/// Best-effort split of a dives CSV Location cell, written from
/// `DiveSite.locationString` as `[city or island · ]region, country`, into
/// region and country. The locality prefix is dropped; a cell with no comma
/// is read as the country. Used only when a dives CSV creates a site the
/// library does not have; an existing site is never changed by it.
({String? region, String? country}) parseSiteLocationText(String? text) {
  var rest = text?.trim() ?? '';
  final dot = rest.lastIndexOf(' · ');
  if (dot >= 0) rest = rest.substring(dot + 3).trim();
  if (rest.isEmpty) return (region: null, country: null);
  final comma = rest.lastIndexOf(',');
  if (comma < 0) return (region: null, country: rest);
  final region = rest.substring(0, comma).trim();
  final country = rest.substring(comma + 1).trim();
  return (
    region: region.isEmpty ? null : region,
    country: country.isEmpty ? null : country,
  );
}
