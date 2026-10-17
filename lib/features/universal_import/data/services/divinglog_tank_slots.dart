import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

/// Resolves Diving Log's packed profile tank ids to cylinders.
class DivingLogTankSlots {
  /// A pressure step at a gas switch larger than this, in bar, is read as
  /// the series moving to another cylinder when that cylinder has no
  /// pressure to compare against. Breathing one cylinder between two
  /// consecutive samples drops it by a bar or two at most; switching
  /// transmitters jumps it by tens of bar.
  static const _jumpBar = 10.0;

  const DivingLogTankSlots._(); // coverage:ignore-line

  /// The position in [tanks] that a profile tank id refers to, or null when
  /// it refers to no cylinder we have.
  ///
  /// The two numbering schemes are not the same. `uddfTankId` carries the
  /// source `Tank.TankID`, which the reference logbook writes as 1, while
  /// the id packed into the profile is the computer's own 0-based slot.
  /// Position therefore wins: on a logbook whose cylinders are TankID 1 and
  /// 2, profile slot 1 means the second cylinder, and matching the number
  /// against TankID would resolve it to the first. Where a logbook numbers
  /// its cylinders from zero the two agree anyway, so this stays correct
  /// for both shapes, and id matching is kept only for an id that is out of
  /// range as a position.
  static int? position(int tankId, List<Map<String, dynamic>> tanks) {
    if (tankId >= 0 && tankId < tanks.length) return tankId;
    final byId = tanks.indexWhere(
      (t) => t['uddfTankId'] == 'divinglog:$tankId',
    );
    return byId >= 0 ? byId : null;
  }

  /// The cylinder position that owns each sample's `Profile2` pressure, one
  /// entry per sample in [samples].
  ///
  /// `Profile2` packs a single pressure beside the tank id, and that tank id
  /// is the gas in use, not necessarily the cylinder the pressure was read
  /// from. A computer with one transmitter keeps reporting the back-gas
  /// cylinder after a switch to a stage that has no sensor (#3339), so a
  /// change of tank id alone does not move the series. It moves only when
  /// the first reading after the switch fits the new cylinder better than
  /// it continues the current one: closer to the new cylinder's last
  /// reading, or to its recorded start pressure before it has any, or, with
  /// neither known, a jump larger than [_jumpBar]. A series that never moves
  /// is then placed by [_singleSeriesOwner].
  static List<int> pressureOwners(
    List<DivingLogRawSample> samples,
    List<Map<String, dynamic>> tanks,
  ) {
    final lastReading = <int, double>{};
    final owners = <int>[];
    int? owner;
    int? activeTankId;
    int? candidate;
    double? first;
    double? last;
    for (final s in samples) {
      final tankId = s.tankId;
      if (tankId != null && tankId != activeTankId) {
        final slot = position(tankId, tanks);
        if (owner == null) {
          owner = slot;
        } else {
          // An id with no cylinder cancels any switch still pending, so a
          // reading after it cannot be decided against stale state.
          candidate = slot;
        }
        activeTankId = tankId;
      }
      final current = owner ?? 0;
      final pressure = s.pressureBar;
      var next = current;
      if (pressure != null) {
        if (candidate != null && candidate != current) {
          final expected =
              lastReading[candidate] ??
              _recorded(tanks[candidate], 'startPressure');
          if (_moves(pressure, lastReading[current], expected)) {
            next = candidate;
          }
        }
        candidate = null;
        first ??= pressure;
        last = pressure;
        lastReading[next] = pressure;
      }
      owner = next;
      owners.add(next);
    }
    if (first == null || last == null || owners.toSet().length != 1) {
      return owners;
    }
    final single = _singleSeriesOwner(owners.first, first, last, tanks);
    return [for (final _ in owners) single];
  }

  /// Whether a reading of [pressure] after a gas switch belongs to the new
  /// cylinder, whose [expected] pressure may be unknown, rather than
  /// continuing the current cylinder's [previous] reading.
  static bool _moves(double pressure, double? previous, double? expected) {
    if (previous == null) return true;
    final step = (pressure - previous).abs();
    if (expected == null) return step > _jumpBar;
    return (pressure - expected).abs() < step;
  }

  /// The cylinder a series that never moved belongs to.
  ///
  /// Such a series came from one transmitter, and the cylinder breathed
  /// first is not necessarily the one it is fitted to: a dive that starts
  /// on an unsensored travel gas records the back-gas transmitter under the
  /// travel gas's id. The recorded pressures settle it: the cylinder whose
  /// start and end pressures match the series' first and last readings
  /// within [_jumpBar] each, the closest if several do. With no such
  /// cylinder the [assumed] one stands.
  static int _singleSeriesOwner(
    int assumed,
    double first,
    double last,
    List<Map<String, dynamic>> tanks,
  ) {
    var best = assumed;
    double? bestMiss;
    for (var i = 0; i < tanks.length; i++) {
      final start = _recorded(tanks[i], 'startPressure');
      final end = _recorded(tanks[i], 'endPressure');
      if (start == null || end == null) continue;
      final startMiss = (first - start).abs();
      final endMiss = (last - end).abs();
      if (startMiss > _jumpBar || endMiss > _jumpBar) continue;
      final miss = startMiss + endMiss;
      if (bestMiss == null || miss < bestMiss) {
        best = i;
        bestMiss = miss;
      }
    }
    return best;
  }

  static double? _recorded(Map<String, dynamic> tank, String key) =>
      (tank[key] as num?)?.toDouble();
}
