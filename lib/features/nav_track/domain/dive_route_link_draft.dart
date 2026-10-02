import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

/// The Dive Edit page's pending underwater route links (spec
/// 2026-10-02-underwater-route-entry-points-design.md, section 1): the
/// routes linked when the form opened, and the ones the diver has linked or
/// removed since. Nothing is written until the dive is saved, when
/// [toUnlink] and [toLink] are applied. Immutable: every change returns a
/// new draft.
class DiveRouteLinkDraft {
  const DiveRouteLinkDraft._(this.original, this.current);

  /// A draft for a dive whose routes are [linked] right now (empty for a
  /// new dive).
  factory DiveRouteLinkDraft.initial(List<NavTrack> linked) {
    final copy = List<NavTrack>.unmodifiable(linked);
    return DiveRouteLinkDraft._(copy, copy);
  }

  /// The routes linked when the form opened.
  final List<NavTrack> original;

  /// The routes the dive will have once saved, in the order shown.
  final List<NavTrack> current;

  Set<String> get _originalIds => {for (final r in original) r.id};
  Set<String> get _currentIds => {for (final r in current) r.id};

  bool contains(String routeId) => _currentIds.contains(routeId);

  bool wasLinkedOnOpen(String routeId) => _originalIds.contains(routeId);

  /// Routes linked when the form opened that the diver has since removed.
  /// They stay linked in the database until Save, so the link picker offers
  /// them again alongside the unlinked routes.
  List<NavTrack> get removed => List.unmodifiable([
    for (final r in original)
      if (!_currentIds.contains(r.id)) r,
  ]);

  List<String> get toLink => List.unmodifiable([
    for (final r in current)
      if (!_originalIds.contains(r.id)) r.id,
  ]);

  List<String> get toUnlink =>
      List.unmodifiable([for (final r in removed) r.id]);

  bool get hasChanges => toLink.isNotEmpty || toUnlink.isNotEmpty;

  DiveRouteLinkDraft add(NavTrack route) => contains(route.id)
      ? this
      : DiveRouteLinkDraft._(original, List.unmodifiable([...current, route]));

  DiveRouteLinkDraft remove(String routeId) => DiveRouteLinkDraft._(
    original,
    List.unmodifiable(current.where((r) => r.id != routeId)),
  );

  /// [replacement] took the place of [replacedRouteId], a duplicate the
  /// import review page has already deleted. The deleted route leaves the
  /// draft entirely (there is no row left to unlink) and [replacement] is
  /// added.
  DiveRouteLinkDraft replaced(String replacedRouteId, NavTrack replacement) =>
      DiveRouteLinkDraft._(
        List.unmodifiable(original.where((r) => r.id != replacedRouteId)),
        List.unmodifiable([
          ...current.where(
            (r) => r.id != replacedRouteId && r.id != replacement.id,
          ),
          replacement,
        ]),
      );
}
