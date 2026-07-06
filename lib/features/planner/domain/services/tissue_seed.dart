import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';

/// Builds the [TissueState] a plan should start from when it follows a
/// logged dive: the dive's end-of-dive [compartments], off-gassed at the
/// surface (breathing air) for [surfaceInterval].
///
/// Mirrors the residual-tissue lookback the dive details page performs in
/// profile_analysis_provider so a plan seeded from a dive agrees with the
/// log's own repetitive-dive math. The GF-low ceiling anchor is re-derived
/// from the seeded loading, as a fresh dive would.
///
/// Returns null when [compartments] is null (nothing to seed).
TissueState? seededTissueState({
  required List<TissueCompartment>? compartments,
  required Duration? surfaceInterval,
  required double gfLow,
  required double gfHigh,
  DiveEnvironment environment = DiveEnvironment.standard,
}) {
  if (compartments == null || compartments.isEmpty) return null;

  final algorithm = BuhlmannAlgorithm(
    gfLow: gfLow,
    gfHigh: gfHigh,
    environment: environment,
  );
  algorithm.setCompartments(List.from(compartments));

  final intervalSeconds = surfaceInterval?.inSeconds ?? 0;
  if (intervalSeconds > 0) {
    algorithm.calculateSegment(
      depthMeters: 0,
      durationSeconds: intervalSeconds,
      fN2: airN2Fraction,
      fHe: 0.0,
    );
  }

  return BuhlmannState(
    compartments: algorithm.compartments,
    gfLowCeilingAnchor: algorithm.gfLowCeilingAnchor,
  );
}
