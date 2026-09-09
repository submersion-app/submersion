import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// Loads the active diver's registry as a matcher, at import time rather than
/// provider build time so an entry saved a moment ago applies to the next
/// download. A failed load degrades to [TransmitterMatcher.empty].
typedef TransmitterMatcherLoader = Future<TransmitterMatcher> Function();

/// The diver's transmitter registry, indexed for the two lookups an import
/// makes: by normalized serial, then by (dive computer, channel index).
///
/// When sync has landed two entries with the same key, the most recently
/// updated one wins; the manage page shows both so the diver can delete one.
class TransmitterMatcher {
  final Map<String, Transmitter> _bySerial;
  final Map<(String, int), Transmitter> _byChannel;

  const TransmitterMatcher.empty()
    : _bySerial = const {},
      _byChannel = const {};

  const TransmitterMatcher._(this._bySerial, this._byChannel);

  factory TransmitterMatcher.fromEntries(List<Transmitter> entries) {
    // Ascending so the last write wins; the id tie-break keeps the winner
    // deterministic when a sync merge lands two entries on one timestamp
    // (List.sort is not stable).
    final ordered = [...entries]
      ..sort((a, b) {
        final byTime = a.updatedAt.compareTo(b.updatedAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    final bySerial = <String, Transmitter>{};
    final byChannel = <(String, int), Transmitter>{};
    for (final entry in ordered) {
      final serial = normalizeTransmitterSerial(entry.transmitterSerial);
      if (serial != null) bySerial[serial] = entry;
      if (entry.hasChannel) {
        byChannel[(entry.diveComputerId!, entry.channelIndex!)] = entry;
      }
    }
    return TransmitterMatcher._(bySerial, byChannel);
  }

  bool get isEmpty => _bySerial.isEmpty && _byChannel.isEmpty;

  Transmitter? match({
    required String? serial,
    required String? computerId,
    required int index,
  }) {
    final normalized = normalizeTransmitterSerial(serial);
    if (normalized != null) {
      final hit = _bySerial[normalized];
      if (hit != null) return hit;
    }
    if (computerId != null) return _byChannel[(computerId, index)];
    return null;
  }
}

/// Apply the registry to downloaded tanks. Runs BEFORE the default-preset
/// fill so a matched entry claims its tank and the preset only fills back-gas
/// tanks nobody claimed.
///
/// A matched entry always sets the role, gear link, preset name and name; it
/// fills volume, working pressure and material only when the computer
/// reported none (a Suunto that knows its own size keeps it). Gas mix,
/// pressures and serial are never touched. Returns a new list; unmatched
/// tanks are returned as the same instance.
List<TankData> applyTransmitterRegistry(
  List<TankData> tanks,
  TransmitterMatcher matcher, {
  required String? computerId,
}) {
  if (matcher.isEmpty) return List.unmodifiable(tanks);
  return List.unmodifiable(
    tanks.map((tank) {
      final entry = matcher.match(
        serial: tank.transmitterSerial,
        computerId: computerId,
        index: tank.index,
      );
      if (entry == null) return tank;
      final hasVolume = tank.volumeLiters != null && tank.volumeLiters! > 0;
      return tank.copyWith(
        role: entry.role.name,
        equipmentId: entry.equipmentId,
        presetName: entry.presetName,
        tankName: entry.label.isEmpty ? null : entry.label,
        volumeLiters: hasVolume ? tank.volumeLiters : entry.volumeL,
        workingPressure: tank.workingPressure ?? entry.workingPressureBar,
        material: tank.material ?? entry.material?.name,
      );
    }),
  );
}
