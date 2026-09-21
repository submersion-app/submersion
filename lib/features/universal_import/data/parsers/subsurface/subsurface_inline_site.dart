import 'package:xml/xml.dart';

import 'package:submersion/features/universal_import/data/parsers/subsurface/subsurface_gps.dart';

/// Reads the dive site a pre-4.5 Subsurface file carried inline on its dive.
///
/// The top-level `<divesites>` block arrived in Subsurface 4.5. Every file
/// written before that names the site on the dive itself, and its
/// `show_location()` wrote one of three shapes:
///
/// ```xml
/// <location gps='12.216667 -68.283333'>Karpata</location>
/// <location gps='12.216667 -68.283333'/>
/// <location>Salt Pier</location>
/// ```
///
/// A `<gps>` child is accepted too. Subsurface never wrote one, but its own
/// parser matches a bare `gps` entry anywhere under a dive, so files other
/// tools produced for it carry the coordinates that way.
///
/// Returns a site map in the same shape the `<divesites>` block produces,
/// ready for `foldSubsurfaceSites`, or null when the dive names no site and
/// carries no coordinates. The map has no `uddfId`: the caller assigns one,
/// since a pre-4.5 file has no site identifiers to reuse.
Map<String, dynamic>? parseInlineSubsurfaceSite(XmlElement dive) {
  final location = dive.findElements('location').firstOrNull;
  final name = location?.innerText.trim() ?? '';
  final coordinates =
      parseSubsurfaceGps(location?.getAttribute('gps')) ??
      parseSubsurfaceGps(dive.findElements('gps').firstOrNull?.innerText);

  if (name.isEmpty && coordinates == null) return null;

  return <String, dynamic>{
    if (name.isNotEmpty) 'name': name,
    if (coordinates != null) 'latitude': coordinates.$1,
    if (coordinates != null) 'longitude': coordinates.$2,
  };
}
