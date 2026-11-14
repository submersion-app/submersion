/// The one place name that best says where a site is: its island, else its
/// region, else its country. Null when it names none.
///
/// One rule for the diver's own sites and the built-in catalogue's, so the
/// picker's "near Bonaire" header and the rows under it name a place the
/// same way.
String? areaPlaceName({String? island, String? region, String? country}) {
  for (final value in [island, region, country]) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}
