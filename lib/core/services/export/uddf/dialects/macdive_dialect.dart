import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/uddf_dialect.dart';

/// Normalizes UDDF files exported by MacDive into the canonical form
/// expected by [UddfFullImportService].
///
/// MacDive deviates from the UDDF standard in the following ways:
///
/// **Encoding:**
/// The document root carries a default namespace
/// (`http://www.streit.cc/uddf/3.2/`) which causes [XmlElement.findElements]
/// to return empty results. The namespace is stripped before parsing.
/// MacDive also writes integer-semantics values as float strings (e.g.
/// `<divetime>60.00</divetime>`), which are normalised to plain integers so
/// that standard `int.tryParse()` works in the parser.
///
/// **Structure:**
/// 1. Site country is nested at `geography/address/country` instead of
///    being a direct child of `<site>`.
/// 2. `<equipmentused>` is in `<informationafterdive>` instead of
///    `<informationbeforedive>`.
class MacDiveDialect extends UddfDialect {
  static const _namespace = 'http://www.streit.cc/uddf/3.2/';

  // Float-encoded integer fields output by MacDive (e.g. "60.00" -> "60").
  // MacDive serializes all numeric values as floats regardless of semantics.
  static final _floatIntPattern = RegExp(
    r'<(divetime|diveduration|divenumber|passedtime|gradientfactorlow|gradientfactorhigh)>(\d+)\.0+</',
  );

  @override
  bool isMatch(XmlDocument doc) {
    return doc.rootElement.namespaceUri == _namespace;
  }

  @override
  String normalizeXml(String rawContent) {
    final encoded = _fixEncoding(rawContent);
    final doc = XmlDocument.parse(encoded);
    _fixStructure(doc);
    return doc.toXmlString();
  }

  // Strips the default namespace and normalises float-encoded integer values.
  // Both operations run on the raw string before parsing to avoid
  // re-serialization side-effects from round-tripping through XmlDocument.
  String _fixEncoding(String raw) {
    final withoutNamespace = raw.replaceFirst(' xmlns="$_namespace"', '');
    return withoutNamespace.replaceAllMapped(
      _floatIntPattern,
      (m) => '<${m[1]}>${m[2]}</',
    );
  }

  // Corrects element nesting and misplaced elements.
  void _fixStructure(XmlDocument doc) {
    _fixSiteCountry(doc);
    _moveEquipmentUsed(doc);
  }

  // Copies <country> from geography/address/country to a direct child of
  // each <site> element, where the parser expects it.
  void _fixSiteCountry(XmlDocument doc) {
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

  // Copies <equipmentused> from <informationafterdive> into
  // <informationbeforedive>, which is where the parser reads it.
  void _moveEquipmentUsed(XmlDocument doc) {
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
