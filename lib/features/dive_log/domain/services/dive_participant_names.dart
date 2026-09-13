import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// The Buddy and Dive Master text of a [Dive], shared by the dive list's table
/// columns and the CSV, Excel and PADI PDF exports so they cannot disagree.
///
/// The `dive_buddies` junction (#553) is the source of truth for modern dives.
/// The legacy free-text [Dive.buddy] / [Dive.diveMaster] scalars are only a
/// whole-dive fallback, used only when the junction is empty (a legacy dive
/// that only ever used the scalars, or a code path that did not hydrate
/// [Dive.buddies]). Once the junction holds any participant the dive is
/// treated as junction-authoritative and both frozen, never-migrated scalars
/// are ignored. Stale legacy text therefore cannot leak onto a modern dive, nor
/// duplicate a name the junction already shows.
extension DiveParticipantNames on Dive {
  /// Every recorded participant whose role is NOT a guide/divemaster (see
  /// [_guideRoleIds]), comma-joined; null when there is no one to show.
  String? get resolvedBuddyNames =>
      buddies.isEmpty ? buddy : _joinedNames(guides: false);

  /// Every recorded participant whose role is a guide/divemaster,
  /// comma-joined; null when there is no one to show.
  String? get resolvedDiveMasterNames =>
      buddies.isEmpty ? diveMaster : _joinedNames(guides: true);

  String? _joinedNames({required bool guides}) {
    final names = buddies
        .where((b) => _guideRoleIds.contains(b.role.id) == guides)
        .map((b) => b.buddy.name.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    return names.isEmpty ? null : names.join(', ');
  }
}

/// `dive_roles` ids representing someone guiding the dive rather than a peer
/// buddy: the built-in dive guide and dive master roles (#553). Narrower than
/// [DiveRole.leaderIds], which also counts instructors.
const _guideRoleIds = {DiveRole.diveGuideId, DiveRole.diveMasterId};
