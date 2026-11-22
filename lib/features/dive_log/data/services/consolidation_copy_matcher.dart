import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';

/// Finds what a same-computer copy of a stretch of the target repeats, so
/// DiveConsolidationService adds only what the target lacks (#4841).
///
/// One matcher serves one fold. A target row, once matched, is not offered
/// again: two rows of the copy never collapse onto one row of the target.
class ConsolidationCopyMatcher {
  ConsolidationCopyMatcher({
    required this.targetDiveId,
    required this.targetComputerId,
    required List<DiveProfileEvent> eventRows,
    required List<GasSwitche> gasSwitchRows,
  }) : _targetEvents = [
         for (final e in eventRows)
           if (e.diveId == targetDiveId) e,
       ],
       _targetSwitches = [
         for (final g in gasSwitchRows)
           if (g.diveId == targetDiveId) g,
       ];

  /// How far apart, in seconds, two rows of one kind can sit and still be the
  /// same row once an exact copy is placed on the target's clock.
  static const int toleranceSeconds = 2;

  final String targetDiveId;
  final String? targetComputerId;
  final List<DiveProfileEvent> _targetEvents;
  final List<GasSwitche> _targetSwitches;
  final _claimedEvents = <String>{};
  final _claimedSwitches = <String>{};

  /// The target's own event that [copyEvent] of the copy owned by
  /// [copyComputerId], shifted by [offset], repeats: the same type from the
  /// same recorder within [toleranceSeconds]. Null when it is new.
  ///
  /// The recorder is the computer a fold would attribute the event to: its
  /// own computerId, else its dive's for an event the computer logged. The
  /// builder has already shown the copy's computer is the target's, so their
  /// two computer ids (two rows for one serial, or one still unlinked) count
  /// as one.
  DiveProfileEvent? matchEvent(
    DiveProfileEvent copyEvent,
    String? copyComputerId,
    int offset,
  ) {
    final sameComputer = {targetComputerId, copyComputerId}.nonNulls.toSet();
    final copyRecorder = _recorder(copyEvent, copyComputerId);
    for (final e in _targetEvents) {
      if (_claimedEvents.contains(e.id)) continue;
      if (e.eventType != copyEvent.eventType) continue;
      final targetRecorder = _recorder(e, targetComputerId);
      final sameRecorder =
          targetRecorder == copyRecorder ||
          (sameComputer.contains(targetRecorder) &&
              sameComputer.contains(copyRecorder));
      if (!sameRecorder) continue;
      if ((e.timestamp - (copyEvent.timestamp + offset)).abs() >
          toleranceSeconds) {
        continue;
      }
      _claimedEvents.add(e.id);
      return e;
    }
    return null;
  }

  /// Whether the target already holds the switch [copySwitch] makes, once its
  /// tank is mapped to [targetTankId] and its time shifted by [offset].
  bool repeatsGasSwitch(
    GasSwitche copySwitch,
    String targetTankId,
    int offset,
  ) {
    for (final g in _targetSwitches) {
      if (_claimedSwitches.contains(g.id)) continue;
      if (g.tankId != targetTankId) continue;
      if ((g.timestamp - (copySwitch.timestamp + offset)).abs() >
          toleranceSeconds) {
        continue;
      }
      _claimedSwitches.add(g.id);
      return true;
    }
    return false;
  }

  static String? _recorder(DiveProfileEvent e, String? diveComputerId) =>
      e.source == EventSource.user.name
      ? e.computerId
      : e.computerId ?? diveComputerId;
}
