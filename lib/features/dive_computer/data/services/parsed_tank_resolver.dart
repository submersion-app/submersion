import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

/// Resolve a parsed dive's gas mixes to concrete cylinders, shared by the
/// live-download mapper and the reparse service so they stay consistent.
///
/// Every reported gas mix yields a cylinder. A cylinder backed by a transmitter
/// keeps its tank index (so per-sample pressure still links by `sample.tankIndex`)
/// and is labeled with the gas actually breathed on it: Shearwater never links a
/// tank to a gas mix (`tank.gasMixIndex` is `DC_GASMIX_UNKNOWN`), so the old
/// "first gas mix" fallback both mislabeled the transmitter and dropped any gas
/// used without one (e.g. a deco bottle). Gases with no tank become pressureless
/// cylinders.
List<DownloadedTank> resolveParsedTanks(pigeon.ParsedDive parsed) {
  final gasMixes = parsed.gasMixes;

  // No tank records: one pressureless cylinder per gas mix.
  if (parsed.tanks.isEmpty) {
    return gasMixes
        .map(
          (g) => DownloadedTank(
            index: g.index,
            o2Percent: g.o2Percent,
            hePercent: g.hePercent,
          ),
        )
        .toList();
  }

  // Gas indices are positions into gasMixes (every bridge sets GasMix.index == i).
  final result = <DownloadedTank>[];
  final consumed = <int>{};

  for (final tank in parsed.tanks) {
    final gasIndex = _resolveTankGasIndex(tank, parsed.samples, gasMixes);
    final gas = gasIndex != null ? gasMixes[gasIndex] : null;
    if (gasIndex != null) {
      consumed.add(gasIndex);
    }
    result.add(
      DownloadedTank(
        index: tank.index,
        // No gas mixes (e.g. gauge mode): default to air rather than mislabel.
        o2Percent: gas?.o2Percent ?? 21.0,
        hePercent: gas?.hePercent ?? 0.0,
        startPressure: tank.startPressureBar,
        endPressure: tank.endPressureBar,
        volumeLiters: tank.volumeLiters,
      ),
    );
  }

  // Pressureless cylinder for any gas not on a transmitter; indices sit above
  // every real tank/sample index so they never capture per-sample pressure.
  var nextIndex = _firstFreeIndex(parsed);
  for (var i = 0; i < gasMixes.length; i++) {
    if (consumed.contains(i)) {
      continue;
    }
    result.add(
      DownloadedTank(
        index: nextIndex++,
        o2Percent: gasMixes[i].o2Percent,
        hePercent: gasMixes[i].hePercent,
      ),
    );
  }

  return result;
}

/// The gas-mix index (position in [gasMixes]) for [tank], preferring the gas
/// actually breathed on it. Returns null only when there are no gas mixes.
int? _resolveTankGasIndex(
  pigeon.TankInfo tank,
  List<pigeon.ProfileSample> samples,
  List<pigeon.GasMix> gasMixes,
) {
  if (gasMixes.isEmpty) {
    return null;
  }
  // 1. The gas breathed on this transmitter (per-sample DC_SAMPLE_GASMIX).
  final breathed = _dominantGasIndex(tank.index, samples, gasMixes.length);
  if (breathed != null) {
    return breathed;
  }
  // 2. The computer's own tank->gas link, when it set one (non-Shearwater).
  if (tank.gasMixIndex >= 0 && tank.gasMixIndex < gasMixes.length) {
    return tank.gasMixIndex;
  }
  // 3. Last resort: the dive's primary (first) mix -- never a hardcoded air
  //    default, which would mislabel an EAN dive.
  return 0;
}

/// The most frequent gas-mix index among the pressure samples of [tankIndex],
/// or null when none of that tank's samples carry a gas mix.
int? _dominantGasIndex(
  int tankIndex,
  List<pigeon.ProfileSample> samples,
  int gasCount,
) {
  final counts = <int, int>{};
  for (final s in samples) {
    final gasIndex = s.gasMixIndex;
    if (s.tankIndex == tankIndex &&
        gasIndex != null &&
        gasIndex >= 0 &&
        gasIndex < gasCount) {
      counts[gasIndex] = (counts[gasIndex] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) {
    return null;
  }
  // Tie -> first-seen (earliest-breathed) gas, since counts keeps insertion order.
  var bestIndex = counts.keys.first;
  var bestCount = counts[bestIndex]!;
  for (final entry in counts.entries) {
    if (entry.value > bestCount) {
      bestIndex = entry.key;
      bestCount = entry.value;
    }
  }
  return bestIndex;
}

/// The first cylinder index that cannot collide with a real tank record or a
/// per-sample tank index (used for synthesized, pressureless cylinders).
int _firstFreeIndex(pigeon.ParsedDive parsed) {
  var maxIndex = -1;
  for (final tank in parsed.tanks) {
    if (tank.index > maxIndex) {
      maxIndex = tank.index;
    }
  }
  for (final s in parsed.samples) {
    final tankIndex = s.tankIndex;
    if (tankIndex != null && tankIndex > maxIndex) {
      maxIndex = tankIndex;
    }
  }
  return maxIndex + 1;
}
