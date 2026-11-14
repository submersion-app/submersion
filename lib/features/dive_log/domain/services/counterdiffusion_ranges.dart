import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/gas_exchange.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/domain/entities/counterdiffusion_analysis.dart';

/// Smallest net on-gassing rate, in bar/min, that counts as isobaric
/// counterdiffusion. Below it the tissue gains so little that marking it
/// would only flag rounding at the edge of equilibrium (issue #4530).
const double minIcdNetRateBarPerMin = 0.005;

/// Runs shorter than this, in seconds, are dropped so a band does not flicker.
const int minCounterdiffusionDurationSeconds = 30;

/// Runs closer together than this, in seconds, are merged into one.
const int counterdiffusionMergeGapSeconds = 10;

/// Where [statuses] show counterdiffusion, one status per entry of
/// [timestamps] (seconds from dive start). Mismatched or empty inputs, and
/// a dive with no helium in gas or tissue, give [CounterdiffusionAnalysis.none].
///
/// A sample counts as opposing when nitrogen and helium move in opposite
/// directions in at least one compartment, by the same per-gas reading the
/// tissue card shows ([DecoStatus.n2Exchange], [DecoStatus.heExchange]). It
/// counts as ICD when, in at least one compartment, the tissue holds more
/// inert gas than is breathed (by more than
/// [DecoStatus.gasEquilibriumToleranceBar]) and still takes gas up net faster
/// than [minNetRateBarPerMin]: then the gain comes only from one gas entering
/// faster than the other leaves, not from ordinary uptake. The net rate is
/// [DecoStatus.netHaldaneRateBarPerMin], the same rate whose sign drives the
/// tissue card's net badge. The tolerance keeps out air-saturated tissues on
/// their first breaths of a trimix with air's 21 % O2 at the surface, whose
/// inert total equals the breathed one.
///
/// A sample's state holds until the next sample, so a run spans from its
/// first qualifying sample to the sample after its last one. That keeps the
/// merge gap and the minimum duration in seconds of dive, whatever the
/// computer's sample interval.
CounterdiffusionAnalysis counterdiffusionAnalysisOf(
  List<DecoStatus> statuses,
  List<int> timestamps, {
  double minNetRateBarPerMin = minIcdNetRateBarPerMin,
  int minDurationSeconds = minCounterdiffusionDurationSeconds,
  int mergeGapSeconds = counterdiffusionMergeGapSeconds,
}) {
  if (statuses.isEmpty || statuses.length != timestamps.length) {
    return CounterdiffusionAnalysis.none;
  }
  // Air and nitrox dives with no residual helium cannot counterdiffuse; skip
  // the per-compartment pass for them.
  if (!statuses.any(_holdsHelium)) return CounterdiffusionAnalysis.none;

  final icdRuns = _RunBuilder(CounterdiffusionKind.netOngassing);
  final opposingRuns = _RunBuilder(CounterdiffusionKind.opposing);
  const tolerance = DecoStatus.gasEquilibriumToleranceBar;

  for (var i = 0; i < statuses.length; i++) {
    final status = statuses[i];
    final start = timestamps[i];
    final end = i + 1 < timestamps.length ? timestamps[i + 1] : start;

    final icdHere = <int>{};
    final opposingHere = <int>{};
    final inspiredN2 = status.inspiredN2Bar;
    final inspiredHe = status.inspiredHeBar;
    if (inspiredN2 != null && inspiredHe != null) {
      for (final compartment in status.compartments) {
        if (!_opposite(status, compartment)) continue;
        opposingHere.add(compartment.compartmentNumber);
        final tissueTotal = compartment.currentPN2 + compartment.currentPHe;
        // Non-null: the inspired gas is known on this branch.
        final rate = status.netHaldaneRateBarPerMin(compartment)!;
        if (tissueTotal > inspiredN2 + inspiredHe + tolerance &&
            rate > minNetRateBarPerMin) {
          icdHere.add(compartment.compartmentNumber);
        }
      }
    }
    icdRuns.add(start, end, icdHere);
    opposingRuns.add(start, end, opposingHere);
  }

  return CounterdiffusionAnalysis(
    icdRanges: icdRuns.build(minDurationSeconds, mergeGapSeconds),
    opposingRanges: opposingRuns.build(minDurationSeconds, mergeGapSeconds),
    heliumPresent: true,
  );
}

bool _opposite(DecoStatus status, TissueCompartment compartment) {
  final n2 = status.n2Exchange(compartment);
  final he = status.heExchange(compartment);
  return (n2 == GasExchange.ongassing && he == GasExchange.offgassing) ||
      (n2 == GasExchange.offgassing && he == GasExchange.ongassing);
}

bool _holdsHelium(DecoStatus status) {
  const tolerance = DecoStatus.gasEquilibriumToleranceBar;
  if ((status.inspiredHeBar ?? 0) > tolerance) return true;
  for (final compartment in status.compartments) {
    if (compartment.currentPHe > tolerance) return true;
  }
  return false;
}

/// [numbers] ascending, as a list no consumer can change: the ranges are
/// shared by the chart and the safety review.
List<int> _sortedNumbers(Iterable<int> numbers) =>
    List.unmodifiable(numbers.toList()..sort());

/// Collects consecutive samples that meet one kind into spans.
class _RunBuilder {
  final CounterdiffusionKind kind;
  final List<CounterdiffusionRange> _runs = [];
  int? _start;
  int? _end;
  final Set<int> _compartments = {};

  _RunBuilder(this.kind);

  /// Adds the sample at [start], whose state holds until [end].
  void add(int start, int end, Set<int> compartments) {
    if (compartments.isEmpty) {
      _close();
      return;
    }
    _start ??= start;
    _end = end;
    _compartments.addAll(compartments);
  }

  void _close() {
    final start = _start;
    final end = _end;
    if (start != null && end != null) {
      _runs.add(
        CounterdiffusionRange(
          startSeconds: start,
          endSeconds: end,
          kind: kind,
          compartmentNumbers: _sortedNumbers(_compartments),
        ),
      );
    }
    _start = null;
    _end = null;
    _compartments.clear();
  }

  List<CounterdiffusionRange> build(int minDuration, int mergeGap) {
    _close();
    final merged = <CounterdiffusionRange>[];
    for (final run in _runs) {
      final last = merged.isEmpty ? null : merged.last;
      if (last != null && run.startSeconds - last.endSeconds <= mergeGap) {
        merged[merged.length - 1] = last.copyWith(
          endSeconds: run.endSeconds,
          compartmentNumbers: _sortedNumbers({
            ...last.compartmentNumbers,
            ...run.compartmentNumbers,
          }),
        );
      } else {
        merged.add(run);
      }
    }
    return List.unmodifiable(
      merged.where((r) => r.endSeconds - r.startSeconds >= minDuration),
    );
  }
}
