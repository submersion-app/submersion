import 'dart:typed_data';

import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

/// A stored route's data read again from its file, waiting for the dive to
/// be saved (issue #4231): the samples parsed from [sourceFile], and the
/// file itself.
typedef StagedRouteFileUpdate = ({
  List<NavTrackPoint> points,
  Uint8List sourceFile,
});

/// The Dive Edit page's pending underwater route links (spec
/// 2026-10-02-underwater-route-entry-points-design.md, section 1): the
/// routes linked when the form opened, and the ones the diver has linked or
/// removed since. Nothing is written until the dive is saved, when
/// [toUnlink], [updates] and [toLink] are applied. Immutable: every change
/// returns a new draft.
class DiveRouteLinkDraft {
  const DiveRouteLinkDraft._(this.original, this.current, this.updates);

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

  /// Stored routes the diver chose to update from a file imported again,
  /// keyed by route id. Written only on Save, so a cancelled edit leaves
  /// every stored route as it was.
  final Map<String, StagedRouteFileUpdate> updates;

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

  bool get hasChanges =>
      toLink.isNotEmpty || toUnlink.isNotEmpty || updates.isNotEmpty;

  DiveRouteLinkDraft add(NavTrack route) => contains(route.id)
      ? this
      : DiveRouteLinkDraft._(
          original,
          List.unmodifiable([...current, route]),
          updates,
        );

  /// Takes [routeId] off the dive, and drops any update staged for it: a
  /// route the diver no longer links here keeps its stored data.
  DiveRouteLinkDraft remove(String routeId) => DiveRouteLinkDraft._(
    original,
    List.unmodifiable(current.where((r) => r.id != routeId)),
    Map.unmodifiable({
      for (final entry in updates.entries)
        if (entry.key != routeId) entry.key: entry.value,
    }),
  );

  /// [route] read again from a file: it is on the dive (added when it was
  /// not), and [update] replaces its stored data on Save.
  DiveRouteLinkDraft updated(NavTrack route, StagedRouteFileUpdate update) {
    final withRoute = add(route);
    return DiveRouteLinkDraft._(
      original,
      withRoute.current,
      Map.unmodifiable({...updates, route.id: update}),
    );
  }
}
