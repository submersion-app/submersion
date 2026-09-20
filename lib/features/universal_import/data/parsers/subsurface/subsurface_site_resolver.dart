import 'package:xml/xml.dart';

import 'package:submersion/features/universal_import/data/parsers/subsurface/subsurface_inline_site.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface/subsurface_site_folder.dart';

/// Works out which dive site each dive belongs to, across both layouts
/// Subsurface has written.
///
/// Since 4.5 a file declares its sites once in a top-level `<divesites>`
/// block and every dive points at one by `divesiteid`. Before 4.5 there was
/// no such block: each dive carried its site inline, as a `<location>` child.
///
/// A dive with no usable `divesiteid` falls back to its inline site, which is
/// folded alongside the declared ones so that the same reef logged on twenty
/// dives becomes one site rather than twenty.
class SubsurfaceSiteResolver {
  /// The sites to import, folded so that duplicates collapse, in the order
  /// their first entry appeared in the file.
  final List<Map<String, dynamic>> sites;

  /// The synthesised uuid of each dive's inline site. A pre-4.5 file has no
  /// site identifiers of its own, so one is minted per dive that needs it.
  final Map<XmlElement, String> _inlineIds;

  /// Folded-away uuid to surviving uuid, from [foldSubsurfaceSites].
  final Map<String, String> _aliases;

  final Set<String> _survivingIds;

  const SubsurfaceSiteResolver._({
    required this.sites,
    required Map<XmlElement, String> inlineIds,
    required Map<String, String> aliases,
    required Set<String> survivingIds,
  }) : _inlineIds = inlineIds,
       _aliases = aliases,
       _survivingIds = survivingIds;

  /// Builds a resolver from the file's declared sites and every `<dive>` in
  /// it, in the order the parser reads them.
  ///
  /// [declaredSites] is left untouched: the inline sites go into a copy.
  factory SubsurfaceSiteResolver.of({
    required List<Map<String, dynamic>> declaredSites,
    required Iterable<XmlElement> dives,
  }) {
    final takenIds = {
      for (final site in declaredSites)
        if (site['uddfId'] case final String id) id,
    };

    final raw = [...declaredSites];
    final inlineIds = <XmlElement, String>{};
    for (final dive in dives) {
      // A dive that already points at a site the file describes needs no
      // inline fallback, even when it also carries a legacy `<location>`:
      // the declared site is the richer record of the two.
      final declared = _declaredIdOf(dive);
      if (declared != null && takenIds.contains(declared)) continue;

      final inline = parseInlineSubsurfaceSite(dive);
      if (inline == null) continue;

      final id = _freshInlineId(takenIds, inlineIds.length + 1);
      takenIds.add(id);
      inlineIds[dive] = id;
      raw.add({...inline, 'uddfId': id});
    }

    final folded = foldSubsurfaceSites(raw);
    return SubsurfaceSiteResolver._(
      sites: folded.sites,
      inlineIds: inlineIds,
      aliases: folded.aliases,
      survivingIds: {
        for (final site in folded.sites)
          if (site['uddfId'] case final String id) id,
      },
    );
  }

  /// The uuid of the surviving site [dive] belongs to, or null when the file
  /// gives the dive no site that survived the fold.
  String? refFor(XmlElement dive) {
    final candidate = _inlineIds[dive] ?? _declaredIdOf(dive);
    if (candidate == null) return null;
    final resolved = _aliases[candidate] ?? candidate;
    return _survivingIds.contains(resolved) ? resolved : null;
  }

  /// Whether [dive] points at a site the file never describes and carries no
  /// inline site to fall back on, so it will import without a site.
  ///
  /// A dive that names no site at all is not counted: nothing was lost.
  bool namesMissingSite(XmlElement dive) =>
      _declaredIdOf(dive) != null && refFor(dive) == null;

  static String? _declaredIdOf(XmlElement dive) {
    final raw = dive.getAttribute('divesiteid')?.trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// A uuid for an inline site that no site in the file already claims.
  static String _freshInlineId(Set<String> taken, int ordinal) {
    var candidate = 'inline-site-$ordinal';
    for (var collision = 2; taken.contains(candidate); collision++) {
      candidate = 'inline-site-$ordinal-$collision';
    }
    return candidate;
  }
}
