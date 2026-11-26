import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';

/// The headline figures the planner shows around its chart: the plan's, or
/// in Bailout view the bailout's the chart draws (issue #4983).
class PlanHeadlineFigures {
  const PlanHeadlineFigures({
    required this.runtimeSeconds,
    required this.ndlSeconds,
    required this.owesDecompression,
    required this.ttsSeconds,
    required this.decoSeconds,
    required this.cnsEnd,
    this.isBailout = false,
    this.stale = false,
  });

  final int runtimeSeconds;

  /// NDL at the bottom, -1 in deco ([PlanOutcome.ndlAtBottom]'s convention).
  /// Always -1 for the bailout, which shows its TTS.
  final int ndlSeconds;
  final bool owesDecompression;
  final int ttsSeconds;

  /// Time on decompression stops, switch-only stops left out.
  final int decoSeconds;
  final double cnsEnd;

  /// Whether these are the worst-case bailout's figures.
  final bool isBailout;

  /// Whether a newer bailout result is on its way.
  final bool stale;

  PlanHeadlineFigures copyWith({
    int? runtimeSeconds,
    int? ndlSeconds,
    bool? owesDecompression,
    int? ttsSeconds,
    int? decoSeconds,
    double? cnsEnd,
    bool? isBailout,
    bool? stale,
  }) => PlanHeadlineFigures(
    runtimeSeconds: runtimeSeconds ?? this.runtimeSeconds,
    ndlSeconds: ndlSeconds ?? this.ndlSeconds,
    owesDecompression: owesDecompression ?? this.owesDecompression,
    ttsSeconds: ttsSeconds ?? this.ttsSeconds,
    decoSeconds: decoSeconds ?? this.decoSeconds,
    cnsEnd: cnsEnd ?? this.cnsEnd,
    isBailout: isBailout ?? this.isBailout,
    stale: stale ?? this.stale,
  );

  @override
  bool operator ==(Object other) =>
      other is PlanHeadlineFigures &&
      other.runtimeSeconds == runtimeSeconds &&
      other.ndlSeconds == ndlSeconds &&
      other.owesDecompression == owesDecompression &&
      other.ttsSeconds == ttsSeconds &&
      other.decoSeconds == decoSeconds &&
      other.cnsEnd == cnsEnd &&
      other.isBailout == isBailout &&
      other.stale == stale;

  @override
  int get hashCode => Object.hash(
    runtimeSeconds,
    ndlSeconds,
    owesDecompression,
    ttsSeconds,
    decoSeconds,
    cnsEnd,
    isBailout,
    stale,
  );
}

/// [PlanHeadlineFigures] for the readouts, status chips and Results tiles:
/// the bailout's while the chart draws the bailout picture, else the plan's.
final planHeadlineFiguresProvider = Provider<PlanHeadlineFigures>((ref) {
  final chart = ref.watch(planChartBailoutProvider);
  final picture = chart.picture;
  if (picture != null) {
    final worst = picture.worstCase;
    return PlanHeadlineFigures(
      runtimeSeconds: worst.runtimeSeconds + worst.ttsSeconds,
      ndlSeconds: -1,
      owesDecompression: true,
      ttsSeconds: worst.ttsSeconds,
      decoSeconds: picture.ocStops
          .where((stop) => !stop.isGasSwitchOnly)
          .fold(0, (sum, stop) => sum + stop.durationSeconds),
      cnsEnd: picture.worstCaseCnsEnd,
      isBailout: true,
      stale: chart.status != null,
    );
  }
  final outcome = ref.watch(activePlanOutcomeProvider);
  return PlanHeadlineFigures(
    runtimeSeconds: outcome.runtimeSeconds,
    ndlSeconds: outcome.ndlAtBottom,
    owesDecompression: outcome.owesDecompression,
    ttsSeconds: outcome.ttsAtBottom,
    decoSeconds: outcome.totalDecoSeconds,
    cnsEnd: outcome.cnsEnd,
  );
});
