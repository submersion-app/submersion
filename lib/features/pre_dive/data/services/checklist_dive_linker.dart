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
  /// after it started.
  static const linkWindow = Duration(hours: 3);

  /// Absorbs dive-computer wall-clock skew relative to the phone: a session
  /// "started" slightly after the recorded dive start still links.
  static const forwardGrace = Duration(minutes: 15);

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
        final delta = diveStart.difference(s.startedAt);
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
