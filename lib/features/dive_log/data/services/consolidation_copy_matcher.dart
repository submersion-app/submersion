import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart'
    as domain;

/// Finds what a same-computer copy of a stretch of the target repeats, so
/// DiveConsolidationService adds only what the target lacks (#4841).
///
/// One matcher serves one fold. A target row, once matched, is not offered
/// again: two rows of the copy never collapse onto one row of the target.
///
/// The builder has already shown the copy's computer is the target's, by
/// serial or by linked computer, so every computer id either dive carries
/// for it (two rows for one serial, or one still unlinked) counts as one.
class ConsolidationCopyMatcher {
  ConsolidationCopyMatcher({
    required this.targetDiveId,
    required this.targetComputerId,
    required List<DiveProfileEvent> eventRows,
    required List<GasSwitche> gasSwitchRows,
    List<domain.TankPressureSeries> targetTankSeries = const [],
  }) : _targetEvents = [
         for (final e in eventRows)
           if (e.diveId == targetDiveId) e,
       ],
       _targetSwitches = [
         for (final g in gasSwitchRows)
           if (g.diveId == targetDiveId) g,
       ],
       _targetTankSeries = [
         for (final s in targetTankSeries)
           if (s.diveId == targetDiveId) s,
       ];

  /// How far apart, in seconds, two rows of one kind can sit and still be the
  /// same row once an exact copy is placed on the target's clock.
  static const int toleranceSeconds = 2;

  /// Stands for the one computer both dives share, whichever id names it.
  static const Object _sharedComputer = Object();

  final String targetDiveId;
  final String? targetComputerId;
  final List<DiveProfileEvent> _targetEvents;
  final List<GasSwitche> _targetSwitches;
  final List<domain.TankPressureSeries> _targetTankSeries;
  final _claimedEvents = <String>{};
  final _claimedSwitches = <String>{};

  /// The target's own event that [copyEvent] of the copy owned by
  /// [copyComputerId], shifted by [offset], repeats: the same type from the
  /// same recorder on the same cylinder within [toleranceSeconds]. Null when
  /// it is new. [targetTankId] is the copy event's cylinder as the target
  /// knows it, null for an event on none, so a gas change on each of two
  /// cylinders at one moment stays two events.
  ///
  /// The recorder is the computer a fold would attribute the event to: its
  /// own computerId, else its dive's for an event the computer logged. A
  /// computer-logged event that names no computer at all, on a dive linked
  /// to none, can only be the shared computer's.
  DiveProfileEvent? matchEvent(
    DiveProfileEvent copyEvent,
    String? copyComputerId,
    String? targetTankId,
    int offset,
  ) {
    final shared = {targetComputerId, copyComputerId}.nonNulls.toSet();
    final copyRecorder = _recorder(copyEvent, copyComputerId, shared);
    for (final e in _targetEvents) {
      if (_claimedEvents.contains(e.id)) continue;
      if (e.eventType != copyEvent.eventType) continue;
      if (e.tankId != targetTankId) continue;
      if (_recorder(e, targetComputerId, shared) != copyRecorder) continue;
      if ((e.timestamp - (copyEvent.timestamp + offset)).abs() >
          toleranceSeconds) {
        continue;
      }
      _claimedEvents.add(e.id);
      return e;
    }
    return null;
  }

  /// Whether the target already holds the switch [copySwitch] of the copy
  /// owned by [copyComputerId] makes, once its tank is mapped to
  /// [targetTankId] and its time shifted by [offset].
  ///
  /// A switch another computer logged on the target is that computer's own
  /// record and repeats nothing of the copy's. One that names no computer
  /// could be either's (#2582), so it still counts.
  bool repeatsGasSwitch(
    GasSwitche copySwitch,
    String? copyComputerId,
    String targetTankId,
    int offset,
  ) {
    final shared = {targetComputerId, copyComputerId}.nonNulls.toSet();
    final copyKey = _switchRecorder(copySwitch.computerId, shared);
    for (final g in _targetSwitches) {
      if (_claimedSwitches.contains(g.id)) continue;
      if (g.tankId != targetTankId) continue;
      final targetKey = _switchRecorder(g.computerId, shared);
      if (copyKey != null && targetKey != null && copyKey != targetKey) {
        continue;
      }
      if ((g.timestamp - (copySwitch.timestamp + offset)).abs() >
          toleranceSeconds) {
        continue;
      }
      _claimedSwitches.add(g.id);
      return true;
    }
    return false;
  }

  /// The readings of [shifted], a pressure series of the copy already placed
  /// on the target's clock, that the target's own series for [targetTankId]
  /// do not cover. A reading is covered when it falls within the span of a
  /// series the shared computer recorded on that cylinder; a series another
  /// computer recorded there covers nothing, since its sensor is not this
  /// one. Empty when the target already holds the whole stretch.
  List<TankPressureSample> uncoveredPressures(
    List<TankPressureSample> shifted,
    String targetTankId,
    String? copyComputerId,
  ) {
    final shared = {targetComputerId, copyComputerId}.nonNulls.toSet();
    final spans = [
      for (final s in _targetTankSeries)
        if (s.tankId == targetTankId &&
            (s.computerId == null || shared.contains(s.computerId)))
          s.summary,
    ];
    return [
      for (final p in shifted)
        if (!spans.any(
          (s) =>
              p.timestamp >= s.startTimestamp - toleranceSeconds &&
              p.timestamp <= s.endTimestamp + toleranceSeconds,
        ))
          p,
    ];
  }

  /// The shared computer's key for a switch [computerId] names, the id
  /// itself for any other computer, null when it names none.
  static Object? _switchRecorder(String? computerId, Set<String> shared) {
    if (computerId == null) return null;
    return shared.contains(computerId) ? _sharedComputer : computerId;
  }

  static Object? _recorder(
    DiveProfileEvent e,
    String? diveComputerId,
    Set<String> shared,
  ) {
    final byUser = e.source == EventSource.user.name;
    final recorder = byUser ? e.computerId : e.computerId ?? diveComputerId;
    if (recorder == null) return byUser ? null : _sharedComputer;
    return shared.contains(recorder) ? _sharedComputer : recorder;
  }
}
