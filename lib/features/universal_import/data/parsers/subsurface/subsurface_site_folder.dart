import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Result of folding a Subsurface `<divesites>` block.
class FoldedSites {
  /// Surviving sites, in the order their first entry appeared in the file.
  final List<Map<String, dynamic>> sites;

  /// Maps each folded-away site uuid to the uuid it folded into, so a dive's
  /// `divesiteid` can be redirected to the survivor.
  final Map<String, String> aliases;

  const FoldedSites({required this.sites, required this.aliases});
}

/// Two entries sharing a name fold together when no further apart than this.
///
/// Subsurface starts a new dive site whenever a dive's GPS lands more than
/// 20 m from every known one, so a single reef accumulates a long tail of
/// same-named entries a few dozen metres apart. Beyond a kilometre the two
/// are treated as genuinely different places that happen to share a name.
const double _sameNameFoldMeters = 1000;

/// An entry Subsurface left unnamed folds into a site this close, whatever
/// that site is called. Matches the coincidence guard `SiteMatchingService`
/// applies when it proposes sites for a dive.
const double _unnamedFoldMeters = 100;

/// Collapses the duplicate dive sites a Subsurface logbook accumulates.
///
/// Named entries fold into an earlier entry of the same name; entries
/// Subsurface left unnamed fold into whichever site sits on top of them, and
/// otherwise survive under a name built from their coordinates rather than
/// being discarded. An entry with neither a name nor coordinates carries
/// nothing worth importing and is dropped.
FoldedSites foldSubsurfaceSites(List<Map<String, dynamic>> raw) {
  final aliases = <String, String>{};
  final survivors = <_Survivor>[];

  // Named entries fold among themselves first so that an unnamed entry can
  // see every named site regardless of the order Subsurface wrote them in.
  for (var i = 0; i < raw.length; i++) {
    final name = _normalizedName(raw[i]['name'] as String?);
    if (name == null) continue;
    final host = _findSameName(survivors, name, raw[i]);
    if (host == null) {
      // Copy: _absorb writes into the survivor, and the caller's maps must
      // come back out of here exactly as they went in.
      survivors.add(
        _Survivor(
          order: i,
          site: Map<String, dynamic>.from(raw[i]),
          normalizedName: name,
        ),
      );
    } else {
      _absorb(host, raw[i], aliases);
    }
  }

  for (var i = 0; i < raw.length; i++) {
    if (_normalizedName(raw[i]['name'] as String?) != null) continue;
    final point = _pointOf(raw[i]);
    if (point == null) continue;
    final host = _findNearest(survivors, point, _unnamedFoldMeters);
    if (host == null) {
      final named = Map<String, dynamic>.from(raw[i])
        ..['name'] = point.toString();
      survivors.add(_Survivor(order: i, site: named, normalizedName: null));
    } else {
      _absorb(host, raw[i], aliases);
    }
  }

  survivors.sort((a, b) => a.order.compareTo(b.order));
  return FoldedSites(
    sites: [for (final survivor in survivors) survivor.site],
    aliases: aliases,
  );
}

/// A site that survived folding, plus the bookkeeping the fold needs.
class _Survivor {
  /// Position of this site's first entry in the file, so the surviving list
  /// can be restored to document order after the two passes.
  final int order;

  final Map<String, dynamic> site;

  /// Null for a site Subsurface left unnamed: its coordinate-derived name is
  /// a label, not an identity, and must never attract a same-name fold.
  final String? normalizedName;

  _Survivor({
    required this.order,
    required this.site,
    required this.normalizedName,
  });
}

/// Folds [folded] into [host], filling gaps rather than overwriting.
///
/// The first entry of a name wins every field it actually carries; later
/// entries only supply what it was missing. This mirrors how `PayloadMerger`
/// enriches a survivor when it folds entities across files.
void _absorb(
  _Survivor host,
  Map<String, dynamic> folded,
  Map<String, String> aliases,
) {
  final foldedId = folded['uddfId'] as String?;
  final hostId = host.site['uddfId'] as String?;
  if (foldedId != null && hostId != null) aliases[foldedId] = hostId;

  folded.forEach((key, value) {
    if (key == 'uddfId' || key == 'name') return;
    if (_isBlank(value)) return;
    if (_isBlank(host.site[key])) host.site[key] = value;
  });
}

_Survivor? _findSameName(
  List<_Survivor> survivors,
  String name,
  Map<String, dynamic> candidate,
) {
  final point = _pointOf(candidate);
  for (final survivor in survivors) {
    if (survivor.normalizedName != name) continue;
    final hostPoint = _pointOf(survivor.site);
    // A side without coordinates cannot contradict the other, so the shared
    // name decides on its own.
    if (point == null || hostPoint == null) return survivor;
    if (distanceMeters(hostPoint, point) <= _sameNameFoldMeters) {
      return survivor;
    }
  }
  return null;
}

_Survivor? _findNearest(
  List<_Survivor> survivors,
  GeoPoint point,
  double maxMeters,
) {
  _Survivor? nearest;
  var nearestMeters = double.infinity;
  for (final survivor in survivors) {
    final hostPoint = _pointOf(survivor.site);
    if (hostPoint == null) continue;
    final meters = distanceMeters(hostPoint, point);
    if (meters <= maxMeters && meters < nearestMeters) {
      nearest = survivor;
      nearestMeters = meters;
    }
  }
  return nearest;
}

/// Case- and whitespace-insensitive identity for a site name, or null when
/// Subsurface supplied no usable name.
String? _normalizedName(String? raw) {
  if (raw == null) return null;
  final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  return collapsed.isEmpty ? null : collapsed;
}

GeoPoint? _pointOf(Map<String, dynamic> site) {
  final lat = site['latitude'] as double?;
  final lon = site['longitude'] as double?;
  if (lat == null || lon == null) return null;
  return GeoPoint(lat, lon);
}

bool _isBlank(Object? value) =>
    value == null || (value is String && value.trim().isEmpty);
