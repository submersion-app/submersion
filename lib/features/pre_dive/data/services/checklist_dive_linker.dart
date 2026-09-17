import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart'
    as domain;

/// Auto-links pre-dive checklist sessions to the dive they belong to,
/// re-evaluated on every dive import so a later, chronologically earlier
/// import can still steal a check away from a dive it was previously linked
/// to. Best-effort: linking failures must never abort a dive import (mirrors
/// DiveEquipmentDefaulter).
class ChecklistDiveLinker {
  final PreDiveSessionRepository _sessions;
  final DiveRepository _dives;

  ChecklistDiveLinker({
    PreDiveSessionRepository? sessions,
    DiveRepository? dives,
  }) : _sessions = sessions ?? PreDiveSessionRepository(),
       _dives = dives ?? DiveRepository();

  /// Absorbs dive-computer wall-clock skew relative to the phone, including a
  /// daylight-saving change between the check and the dive: a session
  /// completed up to this long after the recorded dive start still counts as
  /// having happened before it.
  static const forwardGrace = Duration(hours: 3);

  /// When a run counts as "done" for the purpose of matching it to a dive.
  ///
  /// Completion, not start, is the anchor: the diver finishes the checklist
  /// and gets in the water, so the gap that matters is the one between the
  /// last item ticked and the splash. Anchoring on [startedAt] instead
  /// measured from the wrong end and dropped every run that took a while --
  /// a CCR build or a gear-packing list worked through over an hour would
  /// read as having happened long before the dive even when it ended
  /// minutes before the splash.
  ///
  /// A run still in progress anchors on its start. The status decides that,
  /// not the presence of the stamp: `completedAt` is only written alongside a
  /// terminal status, so a running row carrying one is contradictory data,
  /// and trusting it would anchor the run on a time it never finished at.
  /// Mirrors the same defence in the sessions list's `_whenLabel`.
  static DateTime anchorOf(domain.PreDiveSession session) =>
      session.status == domain.PreDiveSessionStatus.inProgress
      ? session.startedAt
      : session.completedAt ?? session.startedAt;

  /// Links every checklist run of [diverId] whose true next dive is
  /// [diveId] -- there is no time limit on how long a run may have been
  /// waiting, no cap on how many runs may share one dive, and a run already
  /// linked elsewhere is moved here if [diveId] is now its closer next dive.
  /// A dive with no preceding run is simply left alone.
  Future<bool> autoLinkForDive({
    required String diveId,
    required String? diverId,
    required DateTime diveStart,
  }) async {
    if (DatabaseService.instance.databaseOrNull == null) return false;
    try {
      final candidates = await _sessions.getAllSessions(diverId: diverId);
      var changed = false;
      for (final s in candidates) {
        // getAllSessions matches loosely (diverId or unscoped); belt-and-
        // braces re-check, as the old unlinked-only lookup did.
        if (s.diverId != diverId) continue;
        final anchor = anchorOf(s);

        // Cheap pre-filter: a dive that splashed more than forwardGrace
        // before this run's anchor cannot be its next dive, so skip the
        // getNextDive lookup entirely for it.
        if (diveStart.difference(anchor) < -forwardGrace) continue;

        final nextDiveId = await _dives.getNextDive(
          diverId: diverId,
          notBefore: anchor.subtract(forwardGrace),
        );
        if (nextDiveId != diveId) continue;
        if (s.diveId == diveId) continue; // already correctly linked

        await _sessions.linkToDive(s.id, diveId);
        changed = true;
      }
      return changed;
    } catch (_) {
      return false;
    }
  }

  Future<bool> applyForImportedDive(Dive dive) => autoLinkForDive(
    diveId: dive.id,
    diverId: dive.diverId,
    diveStart: dive.effectiveEntryTime,
  );
}
