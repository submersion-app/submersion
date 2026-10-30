import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/dialects/nested_site_country.dart';
import 'package:submersion/core/services/export/uddf/uddf_dialect.dart';

/// Normalizes UDDF files exported by DiveMate into the canonical form
/// expected by [UddfFullImportService] (#3110).
///
/// DiveMate deviates from the UDDF standard in two ways:
///
/// 1. Every field it has no value for is written as the text `null`
///    (`<email>null</email>`, `<serialnumber>null</serialnumber>`, and
///    `<notes><para>null</para></notes>` on a dive without notes), so a
///    plain read imports the word as data. In one donated logbook 492 of 545
///    dives came in with the note "null". Those elements are removed, which
///    reads them as absent.
/// 2. A site's country is nested at `geography/address/country`, as MacDive
///    writes it, rather than being a direct child of `<site>`.
class DiveMateDialect extends UddfDialect {
  // <generator> is a direct child of the root, so only the root's children
  // are searched rather than every waypoint in the file. A contains match
  // keeps a versioned name ("DiveMate 5.1") working, as MacDive's does.
  @override
  bool isMatch(XmlDocument doc) =>
      doc.rootElement.findElements('generator').any((gen) {
        final name = gen.findElements('name').firstOrNull?.innerText ?? '';
        return name.toLowerCase().contains('divemate');
      });

  @override
  String normalizeXml(String rawContent) {
    final doc = XmlDocument.parse(rawContent);
    _removeNullValues(doc);
    copyNestedSiteCountry(doc);
    return doc.toXmlString();
  }

  // Removes each leaf element whose whole text is DiveMate's `null`. The
  // list is taken before removing, since removal edits the tree being walked.
  void _removeNullValues(XmlDocument doc) {
    final nulls = doc.descendants
        .whereType<XmlElement>()
        .where((e) => e.childElements.isEmpty && e.innerText.trim() == 'null')
        .toList();
    for (final element in nulls) {
      element.remove();
    }
  }
}
