import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/computer_cns_extractor.dart';

void main() {
  group('extractComputerCns', () {
    test('returns null when profile has no CNS samples', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 10.0),
        const DiveProfilePoint(timestamp: 60, depth: 20.0),
        const DiveProfilePoint(timestamp: 120, depth: 10.0),
      ];
      expect(extractComputerCns(profile), isNull);
    });

    test('returns start and end from computer CNS samples', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 10.0, cns: 5.0),
        const DiveProfilePoint(timestamp: 60, depth: 20.0, cns: 8.0),
        const DiveProfilePoint(timestamp: 120, depth: 10.0, cns: 12.0),
      ];
      final result = extractComputerCns(profile);
      expect(result, isNotNull);
      expect(result!.cnsStart, 5.0);
      expect(result.cnsEnd, 12.0);
    });

    test('handles sparse CNS samples (nulls in between)', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 10.0),
        const DiveProfilePoint(timestamp: 60, depth: 20.0, cns: 3.0),
        const DiveProfilePoint(timestamp: 120, depth: 15.0),
        const DiveProfilePoint(timestamp: 180, depth: 10.0, cns: 9.0),
      ];
      final result = extractComputerCns(profile);
      expect(result, isNotNull);
      expect(result!.cnsStart, 3.0);
      expect(result.cnsEnd, 9.0);
    });

    // A single reading is not a series: the OSTC reports one CNS value from
    // its header on the first sample even when it logs no CNS during the dive,
    // and that value says nothing about where the dive ended (#2545).
    test('returns null for a single CNS sample', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 10.0),
        const DiveProfilePoint(timestamp: 60, depth: 20.0, cns: 7.0),
        const DiveProfilePoint(timestamp: 120, depth: 10.0),
      ];
      expect(extractComputerCns(profile), isNull);
    });

    test('returns null for empty profile', () {
      expect(extractComputerCns([]), isNull);
    });
  });

  group('hasComputerCns', () {
    test('returns true when profile has CNS samples', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 10.0, cns: 5.0),
        const DiveProfilePoint(timestamp: 60, depth: 20.0),
        const DiveProfilePoint(timestamp: 120, depth: 10.0, cns: 6.0),
      ];
      expect(hasComputerCns(profile), isTrue);
    });

    test('returns false for a single header CNS reading', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 10.0, cns: 5.0),
        const DiveProfilePoint(timestamp: 60, depth: 20.0),
      ];
      expect(hasComputerCns(profile), isFalse);
    });

    test('returns false when profile has no CNS samples', () {
      final profile = [const DiveProfilePoint(timestamp: 0, depth: 10.0)];
      expect(hasComputerCns(profile), isFalse);
    });
  });
}
