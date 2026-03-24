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
    if (doc.rootElement.namespaceUri != _namespace) return false;

    // UDDF-compliant exporters include <generator><name> identifying the app
    // (e.g. Subsurface, divelog_convert). When present, use it as the
    // authoritative signal to avoid false positives on other apps' exports.
    final generators = doc.findAllElements('generator');
    if (generators.isNotEmpty) {
      return generators.any((gen) {
        final name = gen.findElements('name').firstOrNull?.innerText ?? '';
        return name.toLowerCase().contains('macdive');
      });
    }

    // No <generator> tag: fall back to structural quirk detection for files
    // that lack one (e.g. older MacDive versions or hand-edited UDDF).
    return _hasMacDiveStructuralQuirks(doc);
  }

  // Returns true when the document exhibits structural deviations unique to
  // MacDive: country nested under geography/address instead of directly under
  // site, or equipmentused placed in informationafterdive.
  bool _hasMacDiveStructuralQuirks(XmlDocument doc) {
    final hasNestedCountry = doc.findAllElements('site').any((site) {
      final geo = site.findElements('geography').firstOrNull;
      if (geo == null) return false;
      final address = geo.findElements('address').firstOrNull;
      if (address == null) return false;
      return address.findElements('country').isNotEmpty;
    });

    final hasEquipmentInAfter = doc.findAllElements('dive').any((dive) {
      final after = dive.findElements('informationafterdive').firstOrNull;
      if (after == null) return false;
      return after.findElements('equipmentused').isNotEmpty;
    });

    return hasNestedCountry || hasEquipmentInAfter;
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
      // Skip if <site> already has a direct <country> child (idempotency).
      final hasDirectCountry = site.children.whereType<XmlElement>().any(
        (child) => child.name.local == 'country',
      );
      if (hasDirectCountry) continue;
      site.children.add(country.copy());
    }
  }

  // Copies <equipmentused> from <informationafterdive> into
  // <informationbeforedive>, which is where the parser reads it.
  // Creates <informationbeforedive> if absent so equipment data is not lost.
  void _moveEquipmentUsed(XmlDocument doc) {
    for (final dive in doc.findAllElements('dive')) {
      final after = dive.findElements('informationafterdive').firstOrNull;
      if (after == null) continue;
      final equip = after.findElements('equipmentused').firstOrNull;
      if (equip == null) continue;
      var before = dive.findElements('informationbeforedive').firstOrNull;
      if (before == null) {
        before = XmlElement(XmlName('informationbeforedive'));
        dive.children.add(before);
      }
      // Skip if informationbeforedive already has equipmentused (idempotency).
      if (before.findElements('equipmentused').isNotEmpty) continue;
      before.children.add(equip.copy());
    }
  }
}
