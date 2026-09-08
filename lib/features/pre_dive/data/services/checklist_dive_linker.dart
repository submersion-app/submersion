import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart'
    as domain;

/// Auto-links pre-dive checklist sessions to dives created afterwards.
/// Best-effort: linking failures must never abort a dive import
/// (mirrors DiveEquipmentDefaulter).
class ChecklistDiveLinker {
  final PreDiveSessionRepository _sessions;

  ChecklistDiveLinker({PreDiveSessionRepository? sessions})
    : _sessions = sessions ?? PreDiveSessionRepository();

  /// A checklist run belongs to the dive that splashed within this window
  /// after the run finished.
  static const linkWindow = Duration(hours: 3);

  /// Absorbs dive-computer wall-clock skew relative to the phone: a session
  /// timestamped slightly after the recorded dive start still links.
  static const forwardGrace = Duration(minutes: 15);

  /// When a run counts as "done" for the purpose of matching it to a dive.
  ///
  /// Completion, not start, is the anchor: the diver finishes the checklist
  /// and gets in the water, so the gap that matters is the one between the
  /// last item ticked and the splash. Anchoring on [startedAt] instead
  /// measured from the wrong end and dropped every run that took a while --
  /// a CCR build or a gear-packing list worked through over an hour would
  /// fall out of the window even when it ended minutes before the dive.
  ///
  /// A run still in progress anchors on its start. The status decides that,
  /// not the presence of the stamp: `completedAt` is only written alongside a
  /// terminal status, so a running row carrying one is contradictory data,
  /// and trusting it would anchor the run on a time it never finished at and
  /// hand it to the wrong dive -- or, if that time falls outside the window,
  /// to none at all. Mirrors the same defence in the sessions list's
  /// `_whenLabel`.
  static DateTime anchorOf(domain.PreDiveSession session) =>
      session.status == domain.PreDiveSessionStatus.inProgress
      ? session.startedAt
      : session.completedAt ?? session.startedAt;

  Future<bool> autoLinkForDive({
    required String diveId,
    required String? diverId,
    required DateTime diveStart,
  }) async {
    if (DatabaseService.instance.databaseOrNull == null) return false;
    try {
      // One-to-one: never steal onto a dive that already has a session.
      if (await _sessions.getSessionForDive(diveId) != null) return false;

      final candidates = await _sessions.getUnlinkedSessions(diverId: diverId);
      domain.PreDiveSession? best;
      Duration? bestDistance;
      for (final s in candidates) {
        // getUnlinkedSessions filters exactly; belt-and-braces re-check.
        if (s.diverId != diverId) continue;
        final delta = diveStart.difference(anchorOf(s));
        final inWindow = delta <= linkWindow && delta >= -forwardGrace;
        if (!inWindow) continue;
        final distance = delta.abs();
        if (bestDistance == null || distance < bestDistance) {
          best = s;
          bestDistance = distance;
        }
      }
      if (best == null) return false;
      await _sessions.linkToDive(best.id, diveId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> applyForImportedDive(Dive dive) => autoLinkForDive(
    diveId: dive.id,
    diverId: dive.diverId,
    diveStart: dive.dateTime,
  );
}
