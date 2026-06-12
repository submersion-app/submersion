import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

/// Resolve a parsed dive's tanks to concrete per-tank gas mixes.
///
/// This is the single source of truth shared by the live-download mapper
/// ([parsedDiveToDownloaded]) and the reparse service, so the two paths
/// cannot drift apart in how they assign gas to a downloaded tank.
///
/// Two cases are folded together:
///
/// 1. The computer reported tank records (air-integration transmitters):
///    each tank links to its gas mix by index, falling back to the dive's
///    primary (first) mix when the link is DC_GASMIX_UNKNOWN -- never to a
///    hardcoded air default, which would mislabel an EAN dive.
///
/// 2. The computer reported gas mixes but no tank records. Tank records only
///    exist when a transmitter supplied pressure (e.g. Shearwater's parser
///    counts a tank only when it saw pressure samples), and whole families
///    (Oceanic/Aqualung, including the i330R) never report `DC_FIELD_TANK`
///    at all. For those dives the real mix lives in `parsed.gasMixes` while
///    `parsed.tanks` is empty -- a purely tank-driven mapping dropped the
///    gas, and every transmitter-less nitrox dive fell back to the 21% air
///    default. Synthesize one tank per reported gas mix instead, keeping the
///    tank index aligned with the gas-mix index so gas-switch events (which
///    reference gas indices) keep pointing at the right tank. A synthesized
///    tank carries no pressures or volume -- the computer reported a gas,
///    not a cylinder.
List<DownloadedTank> resolveParsedTanks(pigeon.ParsedDive parsed) {
  final gasMixes = parsed.gasMixes;

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

  return parsed.tanks.map((t) {
    final gasMix = gasMixes.firstWhere(
      (g) => g.index == t.gasMixIndex,
      orElse: () => gasMixes.isNotEmpty
          ? gasMixes.first
          : pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0),
    );
    return DownloadedTank(
      index: t.index,
      o2Percent: gasMix.o2Percent,
      hePercent: gasMix.hePercent,
      startPressure: t.startPressureBar,
      endPressure: t.endPressureBar,
      volumeLiters: t.volumeLiters,
    );
  }).toList();
}
