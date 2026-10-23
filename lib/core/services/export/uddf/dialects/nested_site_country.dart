import 'package:xml/xml.dart';

/// Copies `<country>` from `geography/address/country` to a direct child of
/// each `<site>`, where [UddfFullImportService] reads it.
///
/// MacDive and DiveMate both nest the country this way. The nested original
/// is left in place, and a site that already has a direct `<country>` keeps
/// it, so applying this twice changes nothing.
void copyNestedSiteCountry(XmlDocument doc) {
  for (final site in doc.findAllElements('site')) {
    final country = site
        .findElements('geography')
        .firstOrNull
        ?.findElements('address')
        .firstOrNull
        ?.findElements('country')
        .firstOrNull;
    if (country == null) continue;
    final hasDirectCountry = site.childElements.any(
      (child) => child.name.local == 'country',
    );
    if (hasDirectCountry) continue;
    site.children.add(country.copy());
  }
}
