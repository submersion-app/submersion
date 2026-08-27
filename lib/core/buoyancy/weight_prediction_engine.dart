import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/buoyancy/gear_feature.dart';
import 'package:submersion/core/buoyancy/ridge_regression.dart';
import 'package:submersion/core/buoyancy/weight_observation.dart';
import 'package:submersion/core/constants/enums.dart';

/// A tank in a planned rig.
class TankSpec extends Equatable {
  final String? presetName;
  final double? volumeL;
  final double? workingPressureBar;
  final TankMaterial? material;

  const TankSpec({
    this.presetName,
    this.volumeL,
    this.workingPressureBar,
    this.material,
  });

  @override
  List<Object?> get props => [
    presetName,
    volumeL,
    workingPressureBar,
    material,
  ];
}

/// The rig a prediction is requested for.
class RigSpec extends Equatable {
  final List<GearFeature> gear;
  final List<TankSpec> tanks;
  final WaterType? waterType;
  final double? bodyWeightKg;

  const RigSpec({
    this.gear = const [],
    this.tanks = const [],
    this.waterType,
    this.bodyWeightKg,
  });

  @override
  List<Object?> get props => [gear, tanks, waterType, bodyWeightKg];
}

/// Where a breakdown term's value came from.
enum TermSource { measured, userSpec, typeDefault, physics }

class PredictionTerm extends Equatable {
  final String label;
  final double kg;
  final TermSource source;

  const PredictionTerm({
    required this.label,
    required this.kg,
    required this.source,
  });

  @override
  List<Object?> get props => [label, kg, source];
}

enum PredictionConfidence { low, medium, high }

class WeightPrediction extends Equatable {
  final double totalKg;
  final List<PredictionTerm> terms;
  final PredictionConfidence confidence;
  final int supportingDives;

  const WeightPrediction({
    required this.totalKg,
    required this.terms,
    required this.confidence,
    required this.supportingDives,
  });

  @override
  List<Object?> get props => [totalKg, terms, confidence, supportingDives];
}

/// Hybrid weight prediction: physics terms are computed deterministically
/// (tank near-empty buoyancy, water-density shift); the personal baseline
/// and per-gear-item terms are learned from feedback-corrected history via
/// ridge regression toward priors.
///
/// Subtracting the physics terms BEFORE the regression is the key trick:
/// the learned part only explains what physics cannot (body, actual suit
/// buoyancy, habits), so e.g. a salt-only history still yields a sane
/// fresh-water prediction.
class WeightPredictionEngine {
  /// Correction applied when feedback gives a direction but no magnitude.
  static const double kDefaultFeedbackMagnitudeKg = 1.0;

  /// Ridge strength (virtual observations) of the personal-baseline prior.
  static const double kPersonalPriorStrength = 2.0;

  /// Observation weight halves roughly every two years.
  static const double kRecencyHalfLifeDays = 730.0;

  /// Fits a model for one diver.
  ///
  /// [gearById] resolves an observation's equipment ids to features and
  /// returns null for ids that must not become features (lead/tank items,
  /// or per the caller's policy). Deleted gear should be given a weak
  /// zero-prior feature by the caller so its dives still inform the fit.
  static FittedWeightModel fit({
    required List<WeightObservation> observations,
    required GearFeature? Function(String equipmentId) gearById,
    double? bodyWeightKg,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final bodyMass = bodyWeightKg ?? BuoyancyPhysics.defaultBodyMassKg;

    // Collect the distinct gear features seen in history.
    final featuresById = <String, GearFeature>{};
    for (final observation in observations) {
      for (final id in observation.equipmentIds) {
        if (featuresById.containsKey(id)) continue;
        final feature = gearById(id);
        if (feature != null) featuresById[id] = feature;
      }
    }
    final featureIds = featuresById.keys.toList();
    final usageCounts = <String, int>{
      for (final id in featureIds)
        id: observations.where((o) => o.equipmentIds.contains(id)).length,
    };

    // Build the design matrix: column 0 = personal intercept.
    final personalPrior = 2.0 + math.max(0.0, (bodyMass - 70.0) / 10.0);
    final prior = [
      personalPrior,
      ...featureIds.map((id) => featuresById[id]!.priorKg),
    ];
    final lambda = [
      kPersonalPriorStrength,
      ...featureIds.map((id) => featuresById[id]!.priorStrength),
    ];

    final x = <List<double>>[];
    final y = <double>[];
    final weights = <double>[];
    var supportingDives = 0;
    for (final observation in observations) {
      if (observation.carriedKg <= 0) continue;
      supportingDives++;

      final corrected =
          observation.carriedKg + _feedbackAdjustment(observation);
      final physics = _observationPhysics(observation, bodyMass, featuresById);
      y.add(corrected - physics);

      final row = List.filled(featureIds.length + 1, 0.0);
      row[0] = 1.0;
      for (final id in observation.equipmentIds) {
        final index = featureIds.indexOf(id);
        if (index >= 0) row[index + 1] = 1.0;
      }
      x.add(row);

      final ageDays = effectiveNow
          .difference(observation.diveDateTime)
          .inDays
          .clamp(0, 100000);
      final feedbackFactor = observation.feedback == 'correct' ? 2.0 : 1.0;
      weights.add(
        feedbackFactor * math.pow(0.5, ageDays / kRecencyHalfLifeDays),
      );
    }

    var coefficients = RidgeRegression.solve(
      x: x,
      y: y,
      weights: weights,
      prior: prior,
      lambda: lambda,
    );

    // One deterministic robustness pass: down-weight >3-sigma residuals
    // and refit (a lone wildly-atypical dive should not skew everyone).
    var residualStd = _weightedResidualStd(x, y, weights, coefficients);
    if (x.length >= 5 && residualStd > 0) {
      var reweighted = false;
      for (var i = 0; i < x.length; i++) {
        final residual = y[i] - _dot(x[i], coefficients);
        if (residual.abs() > 3 * residualStd) {
          weights[i] *= 0.2;
          reweighted = true;
        }
      }
      if (reweighted) {
        coefficients = RidgeRegression.solve(
          x: x,
          y: y,
          weights: weights,
          prior: prior,
          lambda: lambda,
        );
        residualStd = _weightedResidualStd(x, y, weights, coefficients);
      }
    }

    return FittedWeightModel._(
      personalCoefficient: coefficients[0],
      coefficientsById: {
        for (var i = 0; i < featureIds.length; i++)
          featureIds[i]: coefficients[i + 1],
      },
      usageCounts: usageCounts,
      supportingDives: supportingDives,
      residualStdKg: residualStd,
      bodyWeightKg: bodyWeightKg,
    );
  }

  static double _feedbackAdjustment(WeightObservation observation) {
    final magnitude = observation.feedbackKg ?? kDefaultFeedbackMagnitudeKg;
    return switch (observation.feedback) {
      'overweighted' => -magnitude,
      'underweighted' => magnitude,
      _ => 0.0,
    };
  }

  static double _observationPhysics(
    WeightObservation observation,
    double bodyMass,
    Map<String, GearFeature> featuresById,
  ) {
    var gearDryMass = 0.0;
    for (final id in observation.equipmentIds) {
      gearDryMass += featuresById[id]?.dryMassKg ?? 0.0;
    }
    var tankTerms = 0.0;
    var tankDryMass = 0.0;
    for (final tank in observation.tanks) {
      tankTerms += BuoyancyPhysics.tankTermKg(
        presetName: tank.presetName,
        volumeL: tank.volumeL,
        workingPressureBar: tank.workingPressureBar,
        material: tank.material,
      );
      tankDryMass += BuoyancyPhysics.tankDryMassKg(
        presetName: tank.presetName,
        volumeL: tank.volumeL,
        material: tank.material,
      );
    }
    final waterTerm = BuoyancyPhysics.waterTermKg(
      waterType: observation.waterType,
      totalMassKg: bodyMass + gearDryMass + tankDryMass,
    );
    return tankTerms + waterTerm;
  }

  static double _dot(List<double> row, List<double> coefficients) {
    var sum = 0.0;
    for (var i = 0; i < row.length; i++) {
      sum += row[i] * coefficients[i];
    }
    return sum;
  }

  static double _weightedResidualStd(
    List<List<double>> x,
    List<double> y,
    List<double> weights,
    List<double> coefficients,
  ) {
    var weightSum = 0.0;
    var squaredSum = 0.0;
    for (var i = 0; i < x.length; i++) {
      final residual = y[i] - _dot(x[i], coefficients);
      weightSum += weights[i];
      squaredSum += weights[i] * residual * residual;
    }
    if (weightSum <= 0) return 0.0;
    return math.sqrt(squaredSum / weightSum);
  }
}

/// The calibrated per-diver model; [predict] is pure and cheap enough to
/// run on every rig edit.
class FittedWeightModel {
  final double personalCoefficient;
  final Map<String, double> coefficientsById;
  final Map<String, int> usageCounts;
  final int supportingDives;
  final double residualStdKg;
  final double? bodyWeightKg;

  const FittedWeightModel._({
    required this.personalCoefficient,
    required this.coefficientsById,
    required this.usageCounts,
    required this.supportingDives,
    required this.residualStdKg,
    required this.bodyWeightKg,
  });

  WeightPrediction predict(RigSpec rig) {
    final bodyMass =
        rig.bodyWeightKg ?? bodyWeightKg ?? BuoyancyPhysics.defaultBodyMassKg;
    final terms = <PredictionTerm>[];

    terms.add(
      PredictionTerm(
        label: 'personal',
        kg: personalCoefficient,
        source: supportingDives >= 3
            ? TermSource.measured
            : TermSource.typeDefault,
      ),
    );

    var gearDryMass = 0.0;
    for (final gear in rig.gear) {
      gearDryMass += gear.dryMassKg;
      final fitted = coefficientsById[gear.id];
      final TermSource source;
      if (fitted != null && (usageCounts[gear.id] ?? 0) >= 3) {
        source = TermSource.measured;
      } else if (gear.hasUserSpec) {
        source = TermSource.userSpec;
      } else {
        source = TermSource.typeDefault;
      }
      terms.add(
        PredictionTerm(
          label: gear.label,
          kg: fitted ?? gear.priorKg,
          source: source,
        ),
      );
    }

    var tankDryMass = 0.0;
    for (final tank in rig.tanks) {
      tankDryMass += BuoyancyPhysics.tankDryMassKg(
        presetName: tank.presetName,
        volumeL: tank.volumeL,
        material: tank.material,
      );
      terms.add(
        PredictionTerm(
          label: tank.presetName ?? 'tank',
          kg: BuoyancyPhysics.tankTermKg(
            presetName: tank.presetName,
            volumeL: tank.volumeL,
            workingPressureBar: tank.workingPressureBar,
            material: tank.material,
          ),
          source: TermSource.physics,
        ),
      );
    }

    terms.add(
      PredictionTerm(
        label: 'water',
        kg: BuoyancyPhysics.waterTermKg(
          waterType: rig.waterType,
          totalMassKg: bodyMass + gearDryMass + tankDryMass,
        ),
        source: TermSource.physics,
      ),
    );

    final total = terms.fold(0.0, (sum, t) => sum + t.kg);
    return WeightPrediction(
      totalKg: math.max(0.0, total),
      terms: terms,
      confidence: _confidence(rig),
      supportingDives: supportingDives,
    );
  }

  double _informedCoverage(RigSpec rig) {
    if (rig.gear.isEmpty) return 1.0;
    final informed = rig.gear.where(
      (g) => g.hasUserSpec || (usageCounts[g.id] ?? 0) >= 3,
    );
    return informed.length / rig.gear.length;
  }

  PredictionConfidence _confidence(RigSpec rig) {
    final coverage = _informedCoverage(rig);
    final bodyWeightKnown = (rig.bodyWeightKg ?? bodyWeightKg) != null;
    if (supportingDives >= 10 &&
        coverage >= 0.75 &&
        bodyWeightKnown &&
        residualStdKg <= 1.5) {
      return PredictionConfidence.high;
    }
    if (supportingDives >= 3 && coverage >= 0.5) {
      return PredictionConfidence.medium;
    }
    return PredictionConfidence.low;
  }
}
