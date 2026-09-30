import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/dive_lab_eligibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

Dive _dive({required DiveMode mode, required int samples}) => Dive(
  id: 'd',
  dateTime: DateTime(2026, 1, 1),
  diveMode: mode,
  profile: [
    for (var i = 0; i < samples; i++)
      DiveProfilePoint(timestamp: i * 10, depth: 10),
  ],
);

void main() {
  group('isDiveLabEligible', () {
    for (final mode in [DiveMode.oc, DiveMode.ccr, DiveMode.scr]) {
      test('$mode with two samples is eligible', () {
        expect(isDiveLabEligible(_dive(mode: mode, samples: 2)), isTrue);
      });
    }
    test('gauge is never eligible', () {
      expect(
        isDiveLabEligible(_dive(mode: DiveMode.gauge, samples: 50)),
        isFalse,
      );
    });
    test('one sample is not a profile to branch from', () {
      expect(isDiveLabEligible(_dive(mode: DiveMode.oc, samples: 1)), isFalse);
    });
    test('no profile is not eligible', () {
      expect(isDiveLabEligible(_dive(mode: DiveMode.oc, samples: 0)), isFalse);
    });
  });
}
