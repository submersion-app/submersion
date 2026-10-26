import 'package:xml/xml.dart';

import 'package:submersion/features/universal_import/data/parsers/subsurface/subsurface_gps.dart';

/// Reads one `<site>` from a file's top-level `<divesites>` block, verbatim,
/// including a site left unnamed. Deciding which sites are the same place is
/// the folder's job: dropping an unnamed site here would strand its dives
/// with no coordinates at all.
///
/// Subsurface writes each field as an attribute:
///
/// ```xml
/// <site uuid='29956c0b' name='Mosquito Pier' gps='18.149017 -65.515307'>
///   <geo cat='2' origin='2' value='Puerto Rico'/>
/// </site>
/// ```
///
/// Its reader takes a child element of the same name just as well, and
/// DiveMate's "Subsurface XML" export writes them that way (#3110):
///
/// ```xml
/// <site uuid='7dd52921'>
///   <name><![CDATA[Panoramabad Pappelsee]]></name>
///   <geo cat='2' origin='2'><value><![CDATA[Deutschland]]></value></geo>
/// </site>
/// ```
///
/// So each field is read from the attribute first, then from the child
/// element. Read as attributes only, a DiveMate site arrived with no name
/// and no country, and the fold dropped every one without coordinates.
///
/// Returns a site map ready for `foldImportSites`. Blank values are left
/// out.
Map<String, dynamic> parseDeclaredSubsurfaceSite(XmlElement site) {
  final coordinates = parseSubsurfaceGps(_field(site, 'gps'));
  final siteData = <String, dynamic>{
    'name': ?_field(site, 'name'),
    'uddfId': ?_field(site, 'uuid'),
    if (coordinates != null) 'latitude': coordinates.$1,
    if (coordinates != null) 'longitude': coordinates.$2,
    'description': ?_field(site, 'description'),
  };
  for (final geo in site.findElements('geo')) {
    final value = _field(geo, 'value');
    if (value == null) continue;
    switch (geo.getAttribute('cat')) {
      case '2':
        siteData['country'] = value;
      case '3':
        siteData['region'] = value;
    }
  }
  final notes = _childText(site, 'notes');
  if (notes != null) siteData['notes'] = notes;
  return siteData;
}

/// The trimmed [name] attribute of [element], else the text of its first
/// [name] child, or null when neither holds anything but whitespace.
String? _field(XmlElement element, String name) =>
    _nonBlank(element.getAttribute(name)) ?? _childText(element, name);

String? _childText(XmlElement element, String name) =>
    _nonBlank(element.findElements(name).firstOrNull?.innerText);

String? _nonBlank(String? raw) {
  final trimmed = raw?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
