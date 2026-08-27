import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';

/// Recreational no-decompression planner: finds the maximum bottom time at a
/// target depth that still allows a direct ascent with no mandatory
/// decompression stop.
///
/// This is a thin solver over a validated [DecoModel] (typically [BuhlmannGf]),
/// not a new tissue model. It descends to the target depth, then binary-searches
/// the longest whole-minute bottom time whose ascent schedule is empty. The NDL
/// boundary is therefore defined by the model's own ascent schedule — the same
/// deco math the planner already trusts — rather than a re-derived NDL formula.
/// Tests cross-check the result against the model's [DecoModel.ndlSeconds] so the
/// two independent code paths corroborate each other.
class RecreationalNdlSolver {
  RecreationalNdlSolver({
    required this.model,
    this.descentRate = 18.0,
    this.marginSeconds = 0,
  }) {
    if (descentRate <= 0) {
      throw ArgumentError.value(
        descentRate,
        'descentRate',
        'must be positive (m/min); it divides the descent-time calculation',
      );
    }
    // A negative margin would add time and report an NDL beyond the model's
    // boundary — anti-conservative for a deco tool, so reject it outright.
    if (marginSeconds < 0) {
      throw ArgumentError.value(
        marginSeconds,
        'marginSeconds',
        'must not be negative',
      );
    }
  }

  /// The decompression model whose empty-schedule boundary defines the NDL.
  final DecoModel model;

  /// Descent rate (m/min) used to reach the target depth; the descent itself
  /// on-gasses and reduces the available no-deco time.
  final double descentRate;

  /// Conservatism margin (seconds) subtracted from the computed NDL. Zero
  /// reports the raw model NDL; a positive value backs off from it.
  final int marginSeconds;

  /// Maximum whole-minute no-deco bottom time (seconds) at [depthMeters]
  /// breathing [breathing], after descending at [descentRate].
  ///
  /// Returns 0 when a deco obligation already exists on arrival, and
  /// `capMinutes * 60` when the depth is shallow enough that no obligation
  /// appears within the search cap. [ascentGases] defaults to a fixed ascent on
  /// [breathing] (which must be [OpenCircuit] in that case — recreational dives
  /// are open circuit); pass an explicit plan for anything else.
  int maxNoDecoBottomTimeSeconds({
    required double depthMeters,
    required BreathingConfig breathing,
    AscentGasPlan? ascentGases,
    int capMinutes = 300,
  }) {
    if (capMinutes <= 0) {
      throw ArgumentError.value(
        capMinutes,
        'capMinutes',
        'must be positive (minutes); it is the binary-search upper bound',
      );
    }
    if (depthMeters <= 0) return capMinutes * 60;
    final gases = ascentGases ?? _fixedAscentFor(breathing);

    final descentSeconds = (depthMeters / descentRate * 60).round();
    final afterDescent = model.applySegment(
      model.initial(),
      DecoSegment(
        startDepth: 0,
        endDepth: depthMeters,
        durationSeconds: descentSeconds,
      ),
      breathing,
    );

    bool noDecoAfter(int bottomSeconds) {
      var state = afterDescent;
      if (bottomSeconds > 0) {
        state = model.applySegment(
          state,
          DecoSegment(
            startDepth: depthMeters,
            endDepth: depthMeters,
            durationSeconds: bottomSeconds,
          ),
          breathing,
        );
      }
      return model
          .schedule(state, currentDepth: depthMeters, gases: gases)
          .stops
          .isEmpty;
    }

    // Already in deco on arrival at depth.
    if (!noDecoAfter(0)) return 0;
    // No obligation even at the search cap.
    if (noDecoAfter(capMinutes * 60)) {
      return _withMargin(capMinutes * 60);
    }

    // Binary search the whole-minute boundary: lo is always no-deco, hi is
    // always in deco.
    var lo = 0;
    var hi = capMinutes;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (noDecoAfter(mid * 60)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return _withMargin(lo * 60);
  }

  int _withMargin(int seconds) {
    final result = seconds - marginSeconds;
    return result < 0 ? 0 : result;
  }

  AscentGasPlan _fixedAscentFor(BreathingConfig breathing) {
    if (breathing is OpenCircuit) {
      return FixedAscentGas(fN2: breathing.fN2, fHe: breathing.fHe);
    }
    throw ArgumentError(
      'Recreational NDL solving defaults to an open-circuit ascent; pass an '
      'explicit ascentGases plan for loop breathing.',
    );
  }
}
