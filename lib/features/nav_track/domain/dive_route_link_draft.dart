import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

/// The Dive Edit page's pending underwater route links (spec
/// 2026-10-02-underwater-route-entry-points-design.md, section 1): the
/// routes linked when the form opened, and the ones the diver has linked or
/// removed since. Nothing is written until the dive is saved, when
/// [toUnlink], [toLink] and [replacements] are applied. Immutable: every
/// change returns a new draft.
class DiveRouteLinkDraft {
  const DiveRouteLinkDraft._(this.original, this.current, this.replacements);

  /// A draft for a dive whose routes are [linked] right now (empty for a
  /// new dive).
  factory DiveRouteLinkDraft.initial(List<NavTrack> linked) {
    final copy = List<NavTrack>.unmodifiable(linked);
    return DiveRouteLinkDraft._(copy, copy, const {});
  }

  /// The routes linked when the form opened.
  final List<NavTrack> original;

  /// The routes the dive will have once saved, in the order shown.
  final List<NavTrack> current;

  /// Re-imports staged to supersede an older route on Save, keyed by the
  /// old route's id, valued by the re-import's id. The old row is replaced
  /// (and deleted) only on Save, after the re-import is linked, so it can
  /// hand over the primary role and a cancelled edit loses nothing.
  final Map<String, String> replacements;

  Set<String> get _originalIds => {for (final r in original) r.id};
  Set<String> get _currentIds => {for (final r in current) r.id};

  bool contains(String routeId) => _currentIds.contains(routeId);

  bool wasLinkedOnOpen(String routeId) => _originalIds.contains(routeId);

  /// Routes linked when the form opened that the diver has since removed.
  /// They stay linked in the database until Save, so the link picker offers
  /// them again alongside the unlinked routes.
  List<NavTrack> get removed => List.unmodifiable([
    for (final r in original)
      if (!_currentIds.contains(r.id) && !replacements.containsKey(r.id)) r,
  ]);

  List<String> get toLink => List.unmodifiable([
    for (final r in current)
      if (!_originalIds.contains(r.id)) r.id,
  ]);

  List<String> get toUnlink =>
      List.unmodifiable([for (final r in removed) r.id]);

  bool get hasChanges =>
      toLink.isNotEmpty || toUnlink.isNotEmpty || replacements.isNotEmpty;

  DiveRouteLinkDraft add(NavTrack route) => contains(route.id)
      ? this
      : DiveRouteLinkDraft._(
          original,
          List.unmodifiable([...current, route]),
          replacements,
        );

  /// Takes [routeId] off the dive. A re-import removed this way also drops
  /// its staged replacement, so the route it would have superseded stays.
  DiveRouteLinkDraft remove(String routeId) => DiveRouteLinkDraft._(
    original,
    List.unmodifiable(current.where((r) => r.id != routeId)),
    Map.unmodifiable({
      for (final entry in replacements.entries)
        if (entry.value != routeId) entry.key: entry.value,
    }),
  );

  /// [replacement] is a re-import the diver chose to supersede
  /// [replacedRouteId] with. The old route leaves the dive's list and the
  /// swap is staged in [replacements]; nothing is unlinked or deleted until
  /// Save.
  DiveRouteLinkDraft replaced(String replacedRouteId, NavTrack replacement) =>
      DiveRouteLinkDraft._(
        original,
        List.unmodifiable([
          ...current.where(
            (r) => r.id != replacedRouteId && r.id != replacement.id,
          ),
          replacement,
        ]),
        Map.unmodifiable({...replacements, replacedRouteId: replacement.id}),
      );
}
