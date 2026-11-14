import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/body_composition.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  group('BodyComposition.bmi', () {
    test('computes kilograms per square metre', () {
      expect(
        BodyComposition.bmi(weightKg: 80, heightCm: 175),
        closeTo(26.12, 0.01),
      );
    });

    test('is null without a height', () {
      expect(BodyComposition.bmi(weightKg: 80, heightCm: null), isNull);
    });

    test('rejects implausible heights and weights', () {
      expect(BodyComposition.bmi(weightKg: 80, heightCm: 60), isNull);
      expect(BodyComposition.bmi(weightKg: 80, heightCm: 300), isNull);
      expect(BodyComposition.bmi(weightKg: 0, heightCm: 175), isNull);
      expect(BodyComposition.bmi(weightKg: -5, heightCm: 175), isNull);
    });
  });

  group('BodyComposition.isPlausibleHeight', () {
    test('accepts the adult range and rejects the rest', () {
      expect(BodyComposition.isPlausibleHeight(100), isTrue);
      expect(BodyComposition.isPlausibleHeight(250), isTrue);
      expect(BodyComposition.isPlausibleHeight(99.9), isFalse);
      expect(BodyComposition.isPlausibleHeight(12.7), isFalse);
    });
  });

  group('BodyComposition.leadTermKg', () {
    test('is zero at the reference build the mass rule already assumes', () {
      expect(
        BodyComposition.leadTermKg(bodyMassKg: 80, heightCm: 175),
        closeTo(0, 1e-9),
      );
      expect(
        BodyComposition.leadTermKg(bodyMassKg: 100, heightCm: 175),
        closeTo(0, 1e-9),
      );
    });

    test('a shorter diver of equal mass needs more lead', () {
      // 80 kg at 165 cm is BMI 29.4 against 26.1 at the reference height:
      // 80 * 0.012 * 0.2 * (29.38 - 26.12) = 0.63 kg.
      expect(
        BodyComposition.leadTermKg(bodyMassKg: 80, heightCm: 165),
        closeTo(0.63, 0.02),
      );
    });

    test('a taller diver of equal mass needs less lead', () {
      // 100 kg at 195 cm is BMI 26.3 against 32.7: 100 * 0.0024 * -6.35.
      expect(
        BodyComposition.leadTermKg(bodyMassKg: 100, heightCm: 195),
        closeTo(-1.52, 0.03),
      );
    });

    test('is zero when the height is unknown or implausible', () {
      expect(BodyComposition.leadTermKg(bodyMassKg: 80, heightCm: null), 0);
      expect(BodyComposition.leadTermKg(bodyMassKg: 80, heightCm: 20), 0);
      expect(BodyComposition.leadTermKg(bodyMassKg: 0, heightCm: 175), 0);
    });
  });

  group('explicit body fat (issue #4525)', () {
    double legacyTerm(double mass, double height) {
      final bmi = mass / ((height / 100) * (height / 100));
      final reference = mass / (1.75 * 1.75);
      return mass * 0.012 * 0.2 * (bmi - reference);
    }

    test('with no body fat, sex or age the term equals the BMI term', () {
      for (final mass in [45.0, 60.0, 80.0, 110.0, 140.0]) {
        for (final height in [150.0, 165.0, 175.0, 190.0, 205.0]) {
          expect(
            BodyComposition.leadTermKg(bodyMassKg: mass, heightCm: height),
            closeTo(legacyTerm(mass, height), 1e-9),
            reason: '$mass kg at $height cm',
          );
        }
      }
    });

    test('the estimate is the adult Deurenberg formula', () {
      // 1.20 * 26 + 0.23 * 50 - 10.8 * 1 - 5.4
      expect(
        BodyComposition.estimatedFatPercent(
          bmi: 26,
          ageYears: 50,
          sex: DiverSex.male,
        ),
        closeTo(26.5, 1e-9),
      );
      // Neutral age (40) and sex (halfway): 1.20 * 26 + 9.2 - 5.4 - 5.4
      expect(BodyComposition.estimatedFatPercent(bmi: 26), closeTo(29.6, 1e-9));
    });

    test('a typed body fat replaces the estimate', () {
      final reference = BodyComposition.referenceFatPercent(80);
      expect(
        BodyComposition.leadTermKg(
          bodyMassKg: 80,
          heightCm: 175,
          bodyFatPercent: 20,
        ),
        closeTo(80 * 0.2 * (20 - reference) / 100, 1e-9),
      );
    });

    test('a typed body fat needs no height', () {
      expect(
        BodyComposition.leadTermKg(
          bodyMassKg: 80,
          heightCm: null,
          bodyFatPercent: 35,
        ),
        greaterThan(0),
      );
      expect(
        BodyComposition.hasTerm(
          bodyMassKg: 80,
          heightCm: null,
          bodyFatPercent: 35,
        ),
        isTrue,
      );
    });

    test('male lowers and female raises the term by the same amount', () {
      const shift = 80 * 0.2 * 5.4 / 100;
      double term(DiverSex sex) => BodyComposition.leadTermKg(
        bodyMassKg: 80,
        heightCm: 175,
        ageYears: 40,
        sex: sex,
      );
      expect(term(DiverSex.male), closeTo(-shift, 1e-9));
      expect(term(DiverSex.female), closeTo(shift, 1e-9));
    });

    test('age above the neutral 40 raises the term', () {
      expect(
        BodyComposition.leadTermKg(bodyMassKg: 80, heightCm: 175, ageYears: 60),
        closeTo(80 * 0.2 * (0.23 * 20) / 100, 1e-9),
      );
    });

    test('an implausible typed value is ignored', () {
      expect(BodyComposition.isPlausibleBodyFat(3), isTrue);
      expect(BodyComposition.isPlausibleBodyFat(60), isTrue);
      expect(BodyComposition.isPlausibleBodyFat(2.9), isFalse);
      expect(BodyComposition.isPlausibleBodyFat(61), isFalse);
      expect(
        BodyComposition.leadTermKg(
          bodyMassKg: 80,
          heightCm: 175,
          bodyFatPercent: 90,
        ),
        closeTo(0, 1e-9),
      );
    });

    test('with neither a typed value nor a height there is no term', () {
      expect(
        BodyComposition.leadTermKg(
          bodyMassKg: 80,
          heightCm: null,
          sex: DiverSex.male,
          ageYears: 30,
        ),
        0,
      );
      expect(BodyComposition.hasTerm(bodyMassKg: 80, heightCm: null), isFalse);
    });

    test('the term label says whether the fat was measured', () {
      expect(BodyComposition.termLabelFor(bodyFatPercent: 20), 'bodyFat');
      expect(BodyComposition.termLabelFor(), 'bmi');
      expect(BodyComposition.termLabelFor(bodyFatPercent: 99), 'bmi');
    });

    test('age comes from the birth year, and under 16 counts as unknown', () {
      final at = DateTime(2026, 6, 1);
      expect(BodyComposition.ageYears(birthYear: 1984, at: at), 42);
      expect(BodyComposition.ageYears(birthYear: 2015, at: at), isNull);
      expect(BodyComposition.ageYears(birthYear: 2010, at: at), 16);
      expect(BodyComposition.ageYears(birthYear: null, at: at), isNull);
      expect(BodyComposition.ageYears(birthYear: 2030, at: at), isNull);
    });

    test('displayEstimate needs all four inputs', () {
      int? estimate({
        double? weight = 80,
        double? height = 175,
        int? age = 40,
        DiverSex? sex = DiverSex.male,
      }) => BodyComposition.displayEstimate(
        weightKg: weight,
        heightCm: height,
        ageYears: age,
        sex: sex,
      );
      // 1.20 * 26.12 + 9.2 - 10.8 - 5.4 = 24.3
      expect(estimate(), 24);
      expect(estimate(weight: null), isNull);
      expect(estimate(height: null), isNull);
      expect(estimate(age: null), isNull);
      expect(estimate(sex: null), isNull);
      expect(estimate(height: 60), isNull);
    });

    test('displayEstimate is clamped to what the field accepts', () {
      expect(
        BodyComposition.displayEstimate(
          weightKg: 250,
          heightCm: 150,
          ageYears: 70,
          sex: DiverSex.female,
        ),
        60,
      );
      expect(
        BodyComposition.displayEstimate(
          weightKg: 40,
          heightCm: 200,
          ageYears: 16,
          sex: DiverSex.male,
        ),
        3,
      );
    });
  });
}
