import 'package:submersion/core/constants/enums.dart';

/// Body-composition estimate for weight prediction: how much of the
/// diver's own buoyancy the mass-only rule of thumb misses once their build
/// is known.
///
/// Fat tissue (~0.9 kg/L) floats while lean tissue (~1.1 kg/L) sinks, so two
/// divers of equal mass can need noticeably different lead. A body fat
/// percentage the diver entered is used as it stands (issue #4525).
/// Without one it is estimated from body mass index, age and sex with the
/// adult Deurenberg formula; a missing age or sex takes a neutral value, so
/// a profile with only weight and height gives the same term it always did.
/// The term is deliberately small: it refines the personal baseline rather
/// than replacing it, and logged history overrides both.
///
/// Sign convention matches the rest of the engine: positive = more lead.
class BodyComposition {
  /// Breakdown-term key for an ESTIMATED body fat, shared by the engine, the
  /// twin assembler, and the widgets that localize it.
  static const String termLabel = 'bmi';

  /// Breakdown-term key when the diver entered their body fat.
  static const String measuredTermLabel = 'bodyFat';

  /// The height the mass-only personal prior implicitly assumes. At this
  /// height, with a neutral age and sex, the term is zero, so divers of
  /// average build see no change.
  static const double referenceHeightCm = 175.0;

  /// Plausibility bounds for an adult diver's height; anything outside is
  /// treated as unknown rather than fed into a squared denominator.
  static const double minHeightCm = 100.0;
  static const double maxHeightCm = 250.0;

  /// What the body fat field accepts; anything outside is treated as not
  /// entered.
  static const double minBodyFatPercent = 3.0;
  static const double maxBodyFatPercent = 60.0;

  /// The age the estimate assumes when the birth year is unknown.
  static const int neutralAgeYears = 40;

  /// The adult formula does not hold for children, so a younger diver's age
  /// counts as unknown. The upper bound only rejects a mistyped year.
  static const int minAdultAgeYears = 16;
  static const int maxAgeYears = 120;

  /// Deurenberg et al., 1991, adults:
  /// fat % = 1.20 * BMI + 0.23 * age - 10.8 * sex - 5.4, sex 1 for male and
  /// 0 for female.
  static const double fatPercentPerBmiUnit = 1.20;
  static const double fatPercentPerYear = 0.23;
  static const double fatPercentMaleOffset = 10.8;
  static const double fatPercentConstant = 5.4;

  /// Lead-equivalent buoyancy of one kilogram of fat in place of one
  /// kilogram of lean tissue: 1/0.9 - 1/1.1 L, at roughly 1 kg/L of water.
  static const double leadPerKgFatSwap = 0.2;

  /// Whether a height is within the adult plausibility bounds.
  static bool isPlausibleHeight(double heightCm) =>
      heightCm >= minHeightCm && heightCm <= maxHeightCm;

  /// Whether a body fat percentage is one the field accepts.
  static bool isPlausibleBodyFat(double percent) =>
      percent >= minBodyFatPercent && percent <= maxBodyFatPercent;

  /// Body mass index (kg/m^2), or null when either input is missing or
  /// implausible.
  static double? bmi({required double weightKg, required double? heightCm}) {
    if (heightCm == null || weightKg <= 0) return null;
    if (!isPlausibleHeight(heightCm)) return null;
    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  /// The diver's age in whole years on [at], from the birth year alone, or
  /// null when it is unknown or outside what the adult formula covers.
  static int? ageYears({required int? birthYear, required DateTime at}) {
    if (birthYear == null) return null;
    final age = at.year - birthYear;
    if (age < minAdultAgeYears || age > maxAgeYears) return null;
    return age;
  }

  /// Estimated body fat percentage. A missing [ageYears] takes
  /// [neutralAgeYears]; a missing [sex] sits halfway between the two.
  static double estimatedFatPercent({
    required double bmi,
    int? ageYears,
    DiverSex? sex,
  }) {
    final sexTerm = switch (sex) {
      DiverSex.male => 1.0,
      DiverSex.female => 0.0,
      null => 0.5,
    };
    return fatPercentPerBmiUnit * bmi +
        fatPercentPerYear * (ageYears ?? neutralAgeYears) -
        fatPercentMaleOffset * sexTerm -
        fatPercentConstant;
  }

  /// The body fat the mass-only rule assumes for a diver of [bodyMassKg]:
  /// the estimate at [referenceHeightCm] with a neutral age and sex.
  static double referenceFatPercent(double bodyMassKg) => estimatedFatPercent(
    bmi: bmi(weightKg: bodyMassKg, heightCm: referenceHeightCm) ?? 0,
  );

  /// The estimate to show the diver, as a whole percentage inside what the
  /// field accepts. Null unless weight, height, age and sex are all known:
  /// a number built on a neutral guess is not worth showing.
  static int? displayEstimate({
    required double? weightKg,
    required double? heightCm,
    required int? ageYears,
    required DiverSex? sex,
  }) {
    if (weightKg == null || ageYears == null || sex == null) return null;
    final index = bmi(weightKg: weightKg, heightCm: heightCm);
    if (index == null) return null;
    return estimatedFatPercent(
      bmi: index,
      ageYears: ageYears,
      sex: sex,
    ).clamp(minBodyFatPercent, maxBodyFatPercent).round();
  }

  static double? _measured(double? bodyFatPercent) =>
      bodyFatPercent != null && isPlausibleBodyFat(bodyFatPercent)
      ? bodyFatPercent
      : null;

  /// Whether there is anything to build a term from: a body fat the diver
  /// entered, or a height to estimate one with.
  static bool hasTerm({
    required double bodyMassKg,
    required double? heightCm,
    double? bodyFatPercent,
  }) {
    if (bodyMassKg <= 0) return false;
    if (_measured(bodyFatPercent) != null) return true;
    return bmi(weightKg: bodyMassKg, heightCm: heightCm) != null;
  }

  /// The breakdown-term key for a term built from these inputs.
  static String termLabelFor({double? bodyFatPercent}) =>
      _measured(bodyFatPercent) != null ? measuredTermLabel : termLabel;

  /// Extra lead (kg) attributable to body composition, relative to the
  /// build the mass rule assumes: positive for more body fat than
  /// [referenceFatPercent], negative for less. An entered [bodyFatPercent]
  /// is used as it stands and needs no height; otherwise the fat is
  /// estimated from [heightCm], [ageYears] and [sex]. Zero when [hasTerm] is
  /// false. Not clamped: an extreme build gets an extreme term, as before.
  static double leadTermKg({
    required double bodyMassKg,
    required double? heightCm,
    double? bodyFatPercent,
    int? ageYears,
    DiverSex? sex,
  }) {
    if (!hasTerm(
      bodyMassKg: bodyMassKg,
      heightCm: heightCm,
      bodyFatPercent: bodyFatPercent,
    )) {
      return 0.0;
    }
    final fat =
        _measured(bodyFatPercent) ??
        estimatedFatPercent(
          bmi: bmi(weightKg: bodyMassKg, heightCm: heightCm)!,
          ageYears: ageYears,
          sex: sex,
        );
    return bodyMassKg *
        leadPerKgFatSwap *
        (fat - referenceFatPercent(bodyMassKg)) /
        100.0;
  }
}
