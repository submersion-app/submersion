import 'dart:math' as math;

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

/// Net Haldane rate of [compartment], in bar/min, for both inert gases
/// together: positive while it takes gas up. Unlike
/// [DecoStatus.isOffgassing], which only needs the sign, this keeps the ln 2
/// so the value is a real rate.
double netHaldaneRateBarPerMin(
  TissueCompartment compartment, {
  required double inspiredN2Bar,
  required double inspiredHeBar,
}) =>
    math.ln2 *
    ((inspiredN2Bar - compartment.currentPN2) / compartment.halfTimeN2 +
        (inspiredHeBar - compartment.currentPHe) / compartment.halfTimeHe);

/// Where [statuses] show counterdiffusion, one status per entry of
/// [timestamps] (seconds from dive start). Mismatched or empty inputs, and
/// a dive with no helium in gas or tissue, give [CounterdiffusionAnalysis.none].
///
/// A sample counts as opposing when nitrogen and helium move in opposite
/// directions in at least one compartment, by the same per-gas reading the
/// tissue card shows ([DecoStatus.n2Exchange], [DecoStatus.heExchange]). It
/// counts as ICD when, in at least one compartment, the tissue already holds
/// at least as much inert gas as is breathed and still takes gas up net
/// faster than [minNetRateBarPerMin]: then the gain comes only from one gas
/// entering faster than the other leaves, not from ordinary uptake.
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

  final icdRuns = _RunBuilder(CounterdiffusionKind.netOngassing);
  final opposingRuns = _RunBuilder(CounterdiffusionKind.opposing);
  var heliumPresent = false;

  for (var i = 0; i < statuses.length; i++) {
    final status = statuses[i];
    final time = timestamps[i];
    if (!heliumPresent && _holdsHelium(status)) heliumPresent = true;

    final icdHere = <int>{};
    final opposingHere = <int>{};
    final inspiredN2 = status.inspiredN2Bar;
    final inspiredHe = status.inspiredHeBar;
    if (inspiredN2 != null && inspiredHe != null) {
      for (final compartment in status.compartments) {
        if (!_opposite(status, compartment)) continue;
        opposingHere.add(compartment.compartmentNumber);
        final tissueTotal = compartment.currentPN2 + compartment.currentPHe;
        final rate = netHaldaneRateBarPerMin(
          compartment,
          inspiredN2Bar: inspiredN2,
          inspiredHeBar: inspiredHe,
        );
        if (tissueTotal >= inspiredN2 + inspiredHe &&
            rate > minNetRateBarPerMin) {
          icdHere.add(compartment.compartmentNumber);
        }
      }
    }
    icdRuns.add(time, icdHere);
    opposingRuns.add(time, opposingHere);
  }

  if (!heliumPresent) return CounterdiffusionAnalysis.none;
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

/// Collects consecutive samples that meet one kind into spans.
class _RunBuilder {
  final CounterdiffusionKind kind;
  final List<CounterdiffusionRange> _runs = [];
  int? _start;
  int? _end;
  final Set<int> _compartments = {};

  _RunBuilder(this.kind);

  void add(int time, Set<int> compartments) {
    if (compartments.isEmpty) {
      _close();
      return;
    }
    _start ??= time;
    _end = time;
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
          compartmentNumbers: (_compartments.toList()..sort()),
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
        merged[merged.length - 1] = CounterdiffusionRange(
          startSeconds: last.startSeconds,
          endSeconds: run.endSeconds,
          kind: kind,
          compartmentNumbers: ({
            ...last.compartmentNumbers,
            ...run.compartmentNumbers,
          }.toList()..sort()),
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
