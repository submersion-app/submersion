import 'package:equatable/equatable.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';

/// What the whole map shows: which kinds are nodes, which pairs of kinds are
/// joined by lines, and the fewest shared dives a line needs.
///
/// Invariant: every link's kinds are in [kinds]; the constructor drops any
/// link that breaks it.
class MapSpec extends Equatable {
  MapSpec({
    required Set<ConnectionKind> kinds,
    required Set<KindLink> links,
    int minSharedDives = 1,
  }) : kinds = Set.unmodifiable(kinds),
       links = Set.unmodifiable(
         links.where((l) => kinds.contains(l.a) && kinds.contains(l.b)),
       ),
       minSharedDives = minSharedDives.clamp(minMinimum, maxMinimum);

  factory MapSpec.of(Set<ConnectionKind> kinds, Set<KindLink> links) =>
      MapSpec(kinds: kinds, links: links);

  static const int minMinimum = 1;
  static const int maxMinimum = 10;

  final Set<ConnectionKind> kinds;
  final Set<KindLink> links;
  final int minSharedDives;

  /// Adds [kind] and links it to every kind already on. A same-kind link
  /// is never added automatically.
  MapSpec withKind(ConnectionKind kind) {
    if (kinds.contains(kind)) return this;
    return MapSpec(
      kinds: {...kinds, kind},
      links: {...links, for (final k in kinds) KindLink(k, kind)},
      minSharedDives: minSharedDives,
    );
  }

  MapSpec withoutKind(ConnectionKind kind) {
    if (!kinds.contains(kind)) return this;
    return MapSpec(
      kinds: {...kinds}..remove(kind),
      links: links.where((l) => !l.touches(kind)).toSet(),
      minSharedDives: minSharedDives,
    );
  }

  /// Adds or removes [link]; a link whose kinds are not both on is ignored.
  MapSpec toggleLink(KindLink link) {
    if (!kinds.contains(link.a) || !kinds.contains(link.b)) return this;
    final next = {...links};
    if (!next.remove(link)) next.add(link);
    return MapSpec(kinds: kinds, links: next, minSharedDives: minSharedDives);
  }

  MapSpec withMinimum(int n) =>
      MapSpec(kinds: kinds, links: links, minSharedDives: n);

  /// Every pair among [kinds], same-kind included, in enum order.
  List<KindLink> get possibleLinks {
    final sorted = kinds.toList()..sort((x, y) => x.index.compareTo(y.index));
    return [
      for (var i = 0; i < sorted.length; i++)
        for (var j = i; j < sorted.length; j++) KindLink(sorted[i], sorted[j]),
    ];
  }

  Map<String, Object?> toJson() {
    final sortedKinds = kinds.toList()
      ..sort((x, y) => x.index.compareTo(y.index));
    final sortedLinks = links.map((l) => l.wire).toList()..sort();
    return {
      'kinds': [for (final k in sortedKinds) k.name],
      'links': sortedLinks,
      'min': minSharedDives,
    };
  }

  /// Null for anything malformed or naming a kind this build does not know.
  static MapSpec? fromJson(Object? json) {
    if (json is! Map) return null;
    final rawKinds = json['kinds'];
    final rawLinks = json['links'];
    final rawMin = json['min'];
    if (rawKinds is! List || rawLinks is! List) return null;
    final kinds = <ConnectionKind>{};
    for (final raw in rawKinds) {
      final k = raw is String ? ConnectionKind.fromName(raw) : null;
      if (k == null) return null;
      kinds.add(k);
    }
    final links = <KindLink>{};
    for (final raw in rawLinks) {
      final l = raw is String ? KindLink.parse(raw) : null;
      if (l == null) return null;
      links.add(l);
    }
    return MapSpec(
      kinds: kinds,
      links: links,
      minSharedDives: rawMin is int ? rawMin : 1,
    );
  }

  @override
  List<Object?> get props => [kinds, links, minSharedDives];
}
