import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/profile/surfacing_pressure.dart';
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
///
/// When [trimAtSurfacing] is set, each cylinder's end pressure is read at the
/// moment the diver surfaced rather than at the end of the recording. Dive
/// computers keep logging topside, and a rebreather oxygen cylinder feeding a
/// constant mass flow orifice bleeds down through it once the valve is closed,
/// so the computer's own end pressure can be a small fraction of what was
/// actually left at the end of the dive (issue #1092).
List<DownloadedTank> resolveParsedTanks(
  pigeon.ParsedDive parsed, {
  bool trimAtSurfacing = true,
}) => _resolveCylinders(parsed, trimAtSurfacing: trimAtSurfacing).tanks;

/// The gas mix of the first cylinder tagged [TankRole.diluent] among
/// [tanks], or null when none carries that role.
///
/// Shared by the download mapper and the reparse service so a dive's
/// dive-level diluent field (issue #1879) is always derived the same way a
/// diluent cylinder was already identified, rather than re-deriving it from
/// raw tank usage a second time.
({double o2, double he})? resolveDiluentGas(List<DownloadedTank> tanks) {
  for (final tank in tanks) {
    if (tank.role == TankRole.diluent.name) {
      return (o2: tank.o2Percent, he: tank.hePercent);
    }
  }
  return null;
}

/// Derive the dive's gas switches from per-sample gas-mix transitions, keyed by
/// the cylinder index assigned by [resolveParsedTanks].
///
/// Shearwater (and most air-integrated computers) report gas changes as
/// per-sample `DC_SAMPLE_GASMIX` rather than discrete `gaschange` events, so the
/// only authoritative record of when a gas was switched is a change in
/// `sample.gasMixIndex`. The first observed gas is the baseline (it is the
/// starting tank in the gas-usage timeline, not a switch); every later change to
/// a different gas mix becomes a [GasSwitchEvent] pointing at the cylinder that
/// holds that gas.
List<GasSwitchEvent> resolveGasSwitches(pigeon.ParsedDive parsed) {
  final gasIndexToTankIndex = _resolveCylinders(
    parsed,
    trimAtSurfacing: false,
  ).gasIndexToTankIndex;
  if (gasIndexToTankIndex.isEmpty) {
    return const [];
  }

  // Sort by time, tie-broken by original order, so the same raw bytes always
  // yield identical switches (List.sort is not guaranteed stable).
  final indexed =
      [for (var i = 0; i < parsed.samples.length; i++) (i, parsed.samples[i])]
        ..sort((a, b) {
          final byTime = a.$2.timeSeconds.compareTo(b.$2.timeSeconds);
          return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
        });

  final switches = <GasSwitchEvent>[];
  int? previousGasIndex;
  for (final (_, s) in indexed) {
    final gasIndex = s.gasMixIndex;
    // Treat a sample with no usable gas (null, or an index that maps to no
    // cylinder, e.g. an out-of-range/sentinel value) as carrying no gas info:
    // skip it without disturbing the baseline, so a stray value can't suppress
    // or fabricate a later switch.
    if (gasIndex == null || !gasIndexToTankIndex.containsKey(gasIndex)) {
      continue;
    }
    if (previousGasIndex == null) {
      // Baseline: the starting gas, represented by the starting tank.
      previousGasIndex = gasIndex;
      continue;
    }
    if (gasIndex == previousGasIndex) {
      continue;
    }
    previousGasIndex = gasIndex;
    switches.add(
      GasSwitchEvent(
        timeSeconds: s.timeSeconds,
        depth: s.depthMeters,
        toTankIndex: gasIndexToTankIndex[gasIndex]!,
      ),
    );
  }
  return switches;
}

/// The resolved cylinders plus the map from each gas-mix index to the cylinder
/// index that holds it, so tank labeling and gas-switch derivation share one
/// gas-to-cylinder assignment and cannot drift apart.
class _ResolvedCylinders {
  final List<DownloadedTank> tanks;
  final Map<int, int> gasIndexToTankIndex;

  const _ResolvedCylinders(this.tanks, this.gasIndexToTankIndex);
}

_ResolvedCylinders _resolveCylinders(
  pigeon.ParsedDive parsed, {
  required bool trimAtSurfacing,
}) {
  final gasMixes = parsed.gasMixes;
  final gasIndexToTankIndex = <int, int>{};

  // No tank records: one pressureless cylinder per gas mix. Gauge (bottom-timer)
  // dives are the exception -- they log depth+time only, so stay tankless rather
  // than gain a fabricated air/gas cylinder. Real tank records the computer
  // reports (handled below) are kept even for gauge, so switching a downloaded
  // gauge dive back to OC is lossless.
  if (parsed.tanks.isEmpty) {
    if (parsed.diveMode == 'gauge') {
      return const _ResolvedCylinders([], {});
    }
    final tanks = <DownloadedTank>[];
    final roles = _inferSensorlessRoles(gasMixes, [
      for (var i = 0; i < gasMixes.length; i++) i,
    ], parsed.diveMode);
    for (var i = 0; i < gasMixes.length; i++) {
      final g = gasMixes[i];
      gasIndexToTankIndex[i] = g.index;
      tanks.add(
        DownloadedTank(
          index: g.index,
          o2Percent: g.o2Percent,
          hePercent: g.hePercent,
          role: roles[i],
        ),
      );
    }
    return _ResolvedCylinders(tanks, gasIndexToTankIndex);
  }

  // Gas indices are positions into gasMixes (every bridge sets GasMix.index == i).
  // Scanned only once there are tank records to correct: a tankless dive
  // synthesizes pressureless cylinders that have no end pressure to trim.
  final surfacingReadings = trimAtSurfacing
      ? surfacingTankReadings(_surfacingPoints(parsed.samples))
      : const <int, SurfacingTankReading>{};
  final result = <DownloadedTank>[];
  final consumed = <int>{};

  for (final tank in parsed.tanks) {
    final gasIndex = _resolveTankGasIndex(tank, parsed.samples, gasMixes);
    final gas = gasIndex != null ? gasMixes[gasIndex] : null;
    if (gasIndex != null) {
      consumed.add(gasIndex);
      gasIndexToTankIndex[gasIndex] = tank.index;
    }
    // Resolve the role first: Shearwater HP CCR pressure records tag the O2
    // tank with DC_USAGE_OXYGEN but never link it to a gas mix (it carries
    // DC_GASMIX_UNKNOWN, see the class comment above), so `gas` is null here
    // even though the role is known. The O2-heuristic inputs below don't
    // matter for that case: DC_USAGE_OXYGEN short-circuits _inferRole before
    // they're consulted.
    final role = _inferRole(
      tank.usage,
      gas?.o2Percent ?? 21.0,
      gas?.hePercent ?? 0.0,
    );
    // No gas mixes (e.g. gauge mode): default to air rather than mislabel,
    // except a CCR oxygen supply cylinder, which is pure O2 by definition
    // (#726) -- unlike air, that default isn't a guess.
    final o2 =
        gas?.o2Percent ?? (role == TankRole.oxygenSupply.name ? 100.0 : 21.0);
    final he = gas?.hePercent ?? 0.0;
    result.add(
      DownloadedTank(
        index: tank.index,
        o2Percent: o2,
        hePercent: he,
        startPressure: tank.startPressureBar,
        endPressure: trimEndPressureBar(
          reportedBar: tank.endPressureBar,
          reading: surfacingReadings[tank.index],
        ),
        volumeLiters: tank.volumeLiters,
        role: role,
        transmitterSerial: _transmitterSerial(tank.transmitterSerial),
      ),
    );
  }

  // Pressureless cylinder for any gas not on a transmitter; indices sit above
  // every real tank/sample index so they never capture per-sample pressure.
  // These are sensorless cylinders, so they get the same roles a tankless dive
  // gives its gases: the gas's own usage tag first, then on CCR the bailout
  // ranking (issue #2318). The breathed diluent goes first, so a dive whose
  // diluent has no transmitter still gets the one used, not merely the first
  // programmed one, from [resolveDiluentGas].
  final breathedDiluent = _breathedDiluentIndex(parsed.samples, gasMixes);
  final unclaimed = [
    if (breathedDiluent != null && !consumed.contains(breathedDiluent))
      breathedDiluent,
    for (var i = 0; i < gasMixes.length; i++)
      if (!consumed.contains(i) && i != breathedDiluent) i,
  ];
  final unclaimedRoles = _inferSensorlessRoles(
    gasMixes,
    unclaimed,
    parsed.diveMode,
  );
  var nextIndex = _firstFreeIndex(parsed);
  for (final i in unclaimed) {
    gasIndexToTankIndex[i] = nextIndex;
    result.add(
      DownloadedTank(
        index: nextIndex++,
        o2Percent: gasMixes[i].o2Percent,
        hePercent: gasMixes[i].hePercent,
        role: unclaimedRoles[i],
      ),
    );
  }

  return _ResolvedCylinders(result, gasIndexToTankIndex);
}

/// Infer a cylinder [TankRole] (returned as its `.name`). The computer's tank
/// [usage] (libdivecomputer `dc_usage_t`: 1=oxygen, 2=diluent) is authoritative
/// when present; otherwise fall back to an open-circuit gas heuristic where a
/// nitrox mix of 41% O2 or more is a deco gas. Everything else is back gas.
/// The native layer sends zero for "no transmitter"; keep that out of the
/// stored identity so two serial-less tanks never look like the same cylinder.
String? _transmitterSerial(int? serial) =>
    serial == null || serial <= 0 ? null : '$serial';

String _inferRole(int? usage, double o2Percent, double hePercent) {
  switch (usage) {
    case 1: // DC_USAGE_OXYGEN
      return TankRole.oxygenSupply.name;
    case 2: // DC_USAGE_DILUENT
      return TankRole.diluent.name;
  }
  if (hePercent == 0.0 && o2Percent >= 41.0) {
    return TankRole.deco.name;
  }
  return TankRole.backGas.name;
}

/// Role for each gas in [indices] (positions into [gasMixes]) that has no
/// transmitter: every gas on a tankless dive, or the gases left unclaimed by
/// the transmitters on one that has tank records. Keyed by gas index.
///
/// A gas whose usage the computer reported directly on the gas mix itself
/// (`dc_gasmix_t.usage`, independent of any tank/transmitter record) is
/// authoritative device data, regardless of dive mode: oxygen maps to
/// [TankRole.oxygenSupply], diluent to [TankRole.diluent]. Sidemount maps to
/// [TankRole.backGas] rather than [TankRole.sidemountLeft]/[TankRole.sidemountRight]
/// -- the flag only says the gas is on a sidemount cylinder, not which side,
/// so it cannot pick between the two.
///
/// For a dive recognized as CCR, the gases left with no reported usage are
/// the open-circuit bailout candidates and are ranked against each other
/// instead of scored in isolation:
/// 1. Bottom gas: the lowest O2 percentage among every gas of the dive with no
///    reported usage (one on a transmitter included) becomes
///    [TankRole.bailout]; a tie is broken by the higher helium percentage,
///    and a further tie gives Bailout to every still-tied gas. A gas that
///    only loses the helium tie-break gets no automatic Bailout role and
///    falls through to the next rule.
/// 2. Deco: every still-unassigned gas at or above the same 41% O2
///    threshold [_inferRole] uses for open circuit becomes [TankRole.deco].
/// 3. Stage: everything still unassigned becomes [TankRole.stage].
///
/// On any other recognized dive mode, a gas with no reported usage keeps
/// [_inferRole]'s original single-threshold heuristic, unaffected by this.
Map<int, String> _inferSensorlessRoles(
  List<pigeon.GasMix> gasMixes,
  List<int> indices,
  String? diveMode,
) {
  final roles = <int, String>{};
  final unranked = <int>[];
  for (final i in indices) {
    final g = gasMixes[i];
    // Keep in step with _hasReportedUsage.
    switch (g.usage) {
      case 1: // DC_USAGE_OXYGEN
        roles[i] = TankRole.oxygenSupply.name;
      case 2: // DC_USAGE_DILUENT
        roles[i] = TankRole.diluent.name;
      case 3: // DC_USAGE_SIDEMOUNT
        roles[i] = TankRole.backGas.name;
      default:
        unranked.add(i);
    }
  }

  if (diveMode != 'ccr') {
    for (final i in unranked) {
      final g = gasMixes[i];
      roles[i] = _inferRole(null, g.o2Percent, g.hePercent);
    }
    return roles;
  }

  if (unranked.isNotEmpty) {
    // Ranked against every gas of the dive with no reported usage, including
    // one a transmitter claimed: a bailout cylinder on its own transmitter is
    // still the bottom gas, and leaving it out would promote the leanest
    // remaining gas (say a 50% deco gas) to Bailout (review on #2318).
    final candidates = [
      for (var i = 0; i < gasMixes.length; i++)
        if (!_hasReportedUsage(gasMixes[i])) i,
    ];
    final lowestO2 = candidates
        .map((i) => gasMixes[i].o2Percent)
        .reduce((a, b) => a < b ? a : b);
    final atLowestO2 = candidates.where(
      (i) => _nearlyEqualPercent(gasMixes[i].o2Percent, lowestO2),
    );
    final highestHeAtLowestO2 = atLowestO2
        .map((i) => gasMixes[i].hePercent)
        .reduce((a, b) => a > b ? a : b);
    for (final i in atLowestO2) {
      if (unranked.contains(i) &&
          _nearlyEqualPercent(gasMixes[i].hePercent, highestHeAtLowestO2)) {
        roles[i] = TankRole.bailout.name;
      }
    }
    for (final i in unranked) {
      if (roles.containsKey(i)) continue;
      roles[i] = gasMixes[i].o2Percent >= 41.0
          ? TankRole.deco.name
          : TankRole.stage.name;
    }
  }

  return roles;
}

/// Whether the computer tagged [gas] with a usage that fixes its role
/// (oxygen, diluent or sidemount), taking it out of the bailout ranking.
bool _hasReportedUsage(pigeon.GasMix gas) =>
    gas.usage == 1 || gas.usage == 2 || gas.usage == 3;

/// Whether two gas percentages are the same value within floating-point
/// noise. Each of the four platform converters independently computes
/// `fraction * 100.0` from the native `dc_gasmix_t`, so two mixes the diver
/// set to the same nominal percentage can differ by a few ULPs; an exact
/// `==` would then miss a real tie in [_inferSensorlessRoles]'s bailout
/// ranking.
bool _nearlyEqualPercent(double a, double b) => (a - b).abs() < 1e-6;

/// The gas-mix index (position in [gasMixes]) for [tank], preferring the gas
/// actually breathed on it. Returns null when there are no gas mixes, or for
/// a CCR oxygen supply tank the computer gave no gas mix of its own.
int? _resolveTankGasIndex(
  pigeon.TankInfo tank,
  List<pigeon.ProfileSample> samples,
  List<pigeon.GasMix> gasMixes,
) {
  if (gasMixes.isEmpty) {
    return null;
  }
  final linked = tank.gasMixIndex >= 0 && tank.gasMixIndex < gasMixes.length
      ? tank.gasMixIndex
      : null;
  // A CCR supply cylinder is never breathed the way rule 1 below measures it:
  // on the loop the active gas is always the diluent, so every transmitter
  // reporting during the dive would be credited with it, and the oxygen
  // cylinder came out as the diluent (issue #2318). Its usage tag decides.
  switch (tank.usage) {
    case 1: // DC_USAGE_OXYGEN
      // The computer's own link, else a gas mix it tagged as oxygen (some
      // computers report one without index-linking the tank, caught in review
      // on #1972). Otherwise left gasless so the caller applies the 100% O2
      // default (#726): Shearwater never links it and never tags a gas oxygen.
      if (linked != null) return linked;
      final oxygenGasIndex = gasMixes.indexWhere((g) => g.usage == 1);
      return oxygenGasIndex >= 0 ? oxygenGasIndex : null;
    case 2: // DC_USAGE_DILUENT
      // The computer's own link, else the diluent actually breathed. Only
      // when the computer tagged no gas as a diluent do the generic rules
      // below apply.
      final diluent = linked ?? _breathedDiluentIndex(samples, gasMixes);
      if (diluent != null) return diluent;
  }
  // 1. The gas breathed on this transmitter (per-sample DC_SAMPLE_GASMIX).
  final breathed = _dominantGasIndex(tank.index, samples, gasMixes.length);
  if (breathed != null) {
    return breathed;
  }
  // 2. The computer's own tank->gas link, when it set one (non-Shearwater).
  if (linked != null) {
    return linked;
  }
  // 3. Last resort: the dive's primary (first) mix -- never a hardcoded air
  //    default, which would mislabel an EAN dive.
  return 0;
}

/// The diluent-tagged gas mix (`usage == 2`) breathed in the most samples, or
/// the first diluent-tagged one when none was breathed. Null when the computer
/// tagged no gas mix as a diluent.
///
/// Shearwater reports every enabled diluent, not only the one used, and its
/// gas list puts the open-circuit gases first, so neither "the first gas" nor
/// "the first diluent" is safe on its own.
int? _breathedDiluentIndex(
  List<pigeon.ProfileSample> samples,
  List<pigeon.GasMix> gasMixes,
) {
  bool isDiluent(int? i) =>
      i != null && i >= 0 && i < gasMixes.length && gasMixes[i].usage == 2;
  final breathed = _mostFrequent([
    for (final s in samples)
      if (isDiluent(s.gasMixIndex)) s.gasMixIndex!,
  ]);
  if (breathed != null) {
    return breathed;
  }
  final first = gasMixes.indexWhere((g) => g.usage == 2);
  return first >= 0 ? first : null;
}

/// The most frequent gas-mix index among the pressure samples of [tankIndex],
/// or null when none of that tank's samples carry a gas mix.
///
/// Deliberately keyed on the sample's own `tankIndex` rather than on every
/// transmitter the sample carries: a transmitter reports all dive long, so
/// crediting every reporting tank would hand each one the dive's main gas and
/// override a computer's own tank->gas link (review on #2318).
int? _dominantGasIndex(
  int tankIndex,
  List<pigeon.ProfileSample> samples,
  int gasCount,
) => _mostFrequent([
  for (final s in samples)
    if (s.gasMixIndex case final gasIndex?
        when s.tankIndex == tankIndex && gasIndex >= 0 && gasIndex < gasCount)
      gasIndex,
]);

/// The most frequent value in [values], or null when it is empty.
int? _mostFrequent(List<int> values) {
  final counts = <int, int>{};
  for (final value in values) {
    counts[value] = (counts[value] ?? 0) + 1;
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
    final perTank = s.tankPressuresBar;
    if (perTank != null && perTank.length - 1 > maxIndex) {
      maxIndex = perTank.length - 1;
    }
  }
  return maxIndex + 1;
}

/// Every transmitter reading [sample] carries, keyed by tank index.
///
/// libdivecomputer reports one pressure per air-integrated transmitter, so a
/// sample can carry several, and `pressureBar`/`tankIndex` hold only the last
/// of them (on a Shearwater CCR, always the oxygen transmitter). Reading the
/// pair alone left every other transmitter without a reading at surfacing, so
/// the diluent kept its post-surfacing bleed-down (issue #2318).
/// `tankPressuresBar` is the complete record; the pair remains the fallback
/// for sources that never report more than one tank per sample, the same rule
/// `groupPressuresByTank` applies to the stored pressure series.
Map<int, double> _sampleTankReadings(pigeon.ProfileSample sample) {
  final perTank = sample.tankPressuresBar;
  if (perTank != null) {
    return {
      for (var index = 0; index < perTank.length; index++)
        index: ?perTank[index],
    };
  }
  // A reading without a tank index belongs to tank 0, as in the stored series.
  final pressure = sample.pressureBar;
  return pressure != null ? {sample.tankIndex ?? 0: pressure} : const {};
}

/// Reduce libdivecomputer samples to the depth-plus-pressure points the
/// surfacing rule reads, with every transmitter the sample carries.
List<SurfacingProfilePoint> _surfacingPoints(List<pigeon.ProfileSample> s) => [
  for (final sample in s)
    SurfacingProfilePoint(
      timeSeconds: sample.timeSeconds,
      depthMeters: sample.depthMeters,
      tankPressuresBar: _sampleTankReadings(sample),
    ),
];
