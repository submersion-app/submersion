import 'package:xml/xml.dart';

/// Normalizes UDDF files exported by MacDive into the canonical form
/// expected by [UddfFullImportService].
///
/// MacDive exports use the UDDF 3.2 default namespace which causes
/// findElements() calls to return empty results, and has two structural
/// divergences from the Submersion UDDF layout:
///
///   1. Site country is nested at geography/address/country instead of
///      being a direct child of the site element.
///   2. equipmentused is inside informationafterdive instead of
///      informationbeforedive.
class MacDiveDialectNormalizer {
  const MacDiveDialectNormalizer._();

  static const _namespace = 'http://www.streit.cc/uddf/3.2/';

  /// Returns true when [doc] is a MacDive UDDF export.
  static bool isMatch(XmlDocument doc) {
    return doc.rootElement.namespaceUri == _namespace;
  }

  /// Normalizes a MacDive [doc] and returns the resulting XML string.
  static String normalize(XmlDocument doc) {
    // Strip the default namespace declaration so that the existing parser's
    // findElements() calls (which use the empty namespace) work correctly.
    final stripped = doc.toXmlString().replaceFirst(' xmlns="$_namespace"', '');
    final clean = XmlDocument.parse(stripped);

    _fixSiteCountry(clean);
    _moveEquipmentUsed(clean);

    return clean.toXmlString();
  }

  /// Moves <country> from geography/address/country to a direct child of
  /// each <site> element, which is where the parser's getElementText() call
  /// expects to find it.
  static void _fixSiteCountry(XmlDocument doc) {
    for (final site in doc.findAllElements('site')) {
      final geo = site.findElements('geography').firstOrNull;
      if (geo == null) continue;
      final address = geo.findElements('address').firstOrNull;
      if (address == null) continue;
      final country = address.findElements('country').firstOrNull;
      if (country == null) continue;
      site.children.add(country.copy());
    }
  }

  /// Copies <equipmentused> from informationafterdive into
  /// informationbeforedive, which is where the parser reads it.
  static void _moveEquipmentUsed(XmlDocument doc) {
    for (final dive in doc.findAllElements('dive')) {
      final after = dive.findElements('informationafterdive').firstOrNull;
      final before = dive.findElements('informationbeforedive').firstOrNull;
      if (after == null || before == null) continue;
      final equip = after.findElements('equipmentused').firstOrNull;
      if (equip == null) continue;
      before.children.add(equip.copy());
    }
  }
}
