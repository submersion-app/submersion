import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';

void main() {
  group('AltitudeCalculator', () {
    group('calculateBarometricPressure', () {
      test('should return ~1.013 bar at sea level (0m)', () {
        final pressure = AltitudeCalculator.calculateBarometricPressure(0);
        expect(pressure, closeTo(1.01325, 0.001));
      });

      test('should return ~0.899 bar at 1000m', () {
        final pressure = AltitudeCalculator.calculateBarometricPressure(1000);
        expect(pressure, closeTo(0.899, 0.01));
      });

      test('should return ~0.795 bar at 2000m', () {
        final pressure = AltitudeCalculator.calculateBarometricPressure(2000);
        expect(pressure, closeTo(0.795, 0.01));
      });

      test('should return ~0.701 bar at 3000m', () {
        final pressure = AltitudeCalculator.calculateBarometricPressure(3000);
        expect(pressure, closeTo(0.701, 0.01));
      });

      test('should return ~0.616 bar at 4000m', () {
        final pressure = AltitudeCalculator.calculateBarometricPressure(4000);
        expect(pressure, closeTo(0.616, 0.01));
      });

      test('should handle Lake Titicaca altitude (~3812m)', () {
        // Lake Titicaca is at ~3812m, one of the highest altitude dive sites
        final pressure = AltitudeCalculator.calculateBarometricPressure(3812);
        expect(pressure, closeTo(0.640, 0.02));
      });

      test('should handle negative altitude gracefully', () {
        // Dead Sea is ~430m below sea level
        final pressure = AltitudeCalculator.calculateBarometricPressure(-430);
        expect(pressure, greaterThan(1.01325));
        expect(pressure, closeTo(1.065, 0.02));
      });
    });

    group('calculateAltitudeFromPressure', () {
      test('should return 0m for standard sea level pressure', () {
        final altitude = AltitudeCalculator.calculateAltitudeFromPressure(
          1.01325,
        );
        expect(altitude, closeTo(0, 1));
      });

      test('should return ~1000m for 0.899 bar', () {
        final altitude = AltitudeCalculator.calculateAltitudeFromPressure(
          0.899,
        );
        expect(altitude, closeTo(1000, 50));
      });

      test('should return ~2000m for 0.795 bar', () {
        final altitude = AltitudeCalculator.calculateAltitudeFromPressure(
          0.795,
        );
        expect(altitude, closeTo(2000, 50));
      });

      test('should return ~3000m for 0.701 bar', () {
        final altitude = AltitudeCalculator.calculateAltitudeFromPressure(
          0.701,
        );
        expect(altitude, closeTo(3000, 50));
      });
    });

    group('round-trip conversion', () {
      test('altitude -> pressure -> altitude returns original (1000m)', () {
        const originalAltitude = 1000.0;
        final pressure = AltitudeCalculator.calculateBarometricPressure(
          originalAltitude,
        );
        final recoveredAltitude =
            AltitudeCalculator.calculateAltitudeFromPressure(pressure);
        expect(recoveredAltitude, closeTo(originalAltitude, 1));
      });

      test('altitude -> pressure -> altitude returns original (2500m)', () {
        const originalAltitude = 2500.0;
        final pressure = AltitudeCalculator.calculateBarometricPressure(
          originalAltitude,
        );
        final recoveredAltitude =
            AltitudeCalculator.calculateAltitudeFromPressure(pressure);
        expect(recoveredAltitude, closeTo(originalAltitude, 1));
      });

      test('pressure -> altitude -> pressure returns original (0.8 bar)', () {
        const originalPressure = 0.8;
        final altitude = AltitudeCalculator.calculateAltitudeFromPressure(
          originalPressure,
        );
        final recoveredPressure =
            AltitudeCalculator.calculateBarometricPressure(altitude);
        expect(recoveredPressure, closeTo(originalPressure, 0.001));
      });
    });
  });

  group('AltitudeGroup', () {
    group('fromAltitude', () {
      test('should return seaLevel for altitude < 300m', () {
        expect(AltitudeGroup.fromAltitude(0), equals(AltitudeGroup.seaLevel));
        expect(AltitudeGroup.fromAltitude(150), equals(AltitudeGroup.seaLevel));
        expect(AltitudeGroup.fromAltitude(299), equals(AltitudeGroup.seaLevel));
      });

      test('should return group1 for altitude 300-899m', () {
        expect(AltitudeGroup.fromAltitude(300), equals(AltitudeGroup.group1));
        expect(AltitudeGroup.fromAltitude(500), equals(AltitudeGroup.group1));
        expect(AltitudeGroup.fromAltitude(899), equals(AltitudeGroup.group1));
      });

      test('should return group2 for altitude 900-1799m', () {
        expect(AltitudeGroup.fromAltitude(900), equals(AltitudeGroup.group2));
        expect(AltitudeGroup.fromAltitude(1200), equals(AltitudeGroup.group2));
        expect(AltitudeGroup.fromAltitude(1799), equals(AltitudeGroup.group2));
      });

      test('should return group3 for altitude 1800-2699m', () {
        expect(AltitudeGroup.fromAltitude(1800), equals(AltitudeGroup.group3));
        expect(AltitudeGroup.fromAltitude(2200), equals(AltitudeGroup.group3));
        expect(AltitudeGroup.fromAltitude(2699), equals(AltitudeGroup.group3));
      });

      test('should return extreme for altitude >= 2700m', () {
        expect(AltitudeGroup.fromAltitude(2700), equals(AltitudeGroup.extreme));
        expect(AltitudeGroup.fromAltitude(3000), equals(AltitudeGroup.extreme));
        expect(AltitudeGroup.fromAltitude(3812), equals(AltitudeGroup.extreme));
      });

      test('should treat null altitude as sea level', () {
        expect(
          AltitudeGroup.fromAltitude(null),
          equals(AltitudeGroup.seaLevel),
        );
      });

      test('should treat negative altitude as sea level', () {
        expect(
          AltitudeGroup.fromAltitude(-100),
          equals(AltitudeGroup.seaLevel),
        );
      });
    });

    group('properties', () {
      test('seaLevel should not require adjustment', () {
        expect(AltitudeGroup.seaLevel.requiresAdjustment, isFalse);
      });

      test('group1 and above should require adjustment', () {
        expect(AltitudeGroup.group1.requiresAdjustment, isTrue);
        expect(AltitudeGroup.group2.requiresAdjustment, isTrue);
        expect(AltitudeGroup.group3.requiresAdjustment, isTrue);
        expect(AltitudeGroup.extreme.requiresAdjustment, isTrue);
      });

      test('each group should have correct display name', () {
        expect(AltitudeGroup.seaLevel.displayName, equals('Sea Level'));
        expect(AltitudeGroup.group1.displayName, equals('Altitude Group 1'));
        expect(AltitudeGroup.group2.displayName, equals('Altitude Group 2'));
        expect(AltitudeGroup.group3.displayName, equals('Altitude Group 3'));
        expect(AltitudeGroup.extreme.displayName, equals('Extreme Altitude'));
      });

      test('each group should have altitude range description', () {
        expect(AltitudeGroup.seaLevel.rangeDescription, contains('300'));
        expect(AltitudeGroup.group1.rangeDescription, contains('300'));
        expect(AltitudeGroup.group1.rangeDescription, contains('900'));
        expect(AltitudeGroup.group2.rangeDescription, contains('900'));
        expect(AltitudeGroup.group2.rangeDescription, contains('1800'));
        expect(AltitudeGroup.group3.rangeDescription, contains('1800'));
        expect(AltitudeGroup.group3.rangeDescription, contains('2700'));
        expect(AltitudeGroup.extreme.rangeDescription, contains('2700'));
      });
    });

    group('warningLevel', () {
      test('seaLevel should have no warning', () {
        expect(
          AltitudeGroup.seaLevel.warningLevel,
          equals(AltitudeWarningLevel.none),
        );
      });

      test('group1 should have info level', () {
        expect(
          AltitudeGroup.group1.warningLevel,
          equals(AltitudeWarningLevel.info),
        );
      });

      test('group2 should have caution level', () {
        expect(
          AltitudeGroup.group2.warningLevel,
          equals(AltitudeWarningLevel.caution),
        );
      });

      test('group3 should have warning level', () {
        expect(
          AltitudeGroup.group3.warningLevel,
          equals(AltitudeWarningLevel.warning),
        );
      });

      test('extreme should have severe level', () {
        expect(
          AltitudeGroup.extreme.warningLevel,
          equals(AltitudeWarningLevel.severe),
        );
      });
    });

    group('recommendedMaxAscentRate', () {
      test('seaLevel and group1 should recommend 9 m/min', () {
        expect(AltitudeGroup.seaLevel.recommendedMaxAscentRate, equals(9.0));
        expect(AltitudeGroup.group1.recommendedMaxAscentRate, equals(9.0));
      });

      test('group2 and above should recommend slower ascent', () {
        expect(AltitudeGroup.group2.recommendedMaxAscentRate, lessThan(9.0));
        expect(AltitudeGroup.group3.recommendedMaxAscentRate, lessThan(9.0));
        expect(AltitudeGroup.extreme.recommendedMaxAscentRate, lessThan(9.0));
      });
    });
  });

  group('AltitudeWarningLevel', () {
    test('should have correct ordering (severity)', () {
      expect(
        AltitudeWarningLevel.none.index,
        lessThan(AltitudeWarningLevel.info.index),
      );
      expect(
        AltitudeWarningLevel.info.index,
        lessThan(AltitudeWarningLevel.caution.index),
      );
      expect(
        AltitudeWarningLevel.caution.index,
        lessThan(AltitudeWarningLevel.warning.index),
      );
      expect(
        AltitudeWarningLevel.warning.index,
        lessThan(AltitudeWarningLevel.severe.index),
      );
    });
  });

  group('Integration with dive planning', () {
    test('surface pressure at altitude affects equivalent depth', () {
      // At 2000m altitude, surface pressure is ~0.795 bar
      // A 20m dive at altitude has higher equivalent ocean depth
      final altitudePressure = AltitudeCalculator.calculateBarometricPressure(
        2000,
      );

      // Ambient pressure at 20m depth with altitude surface pressure
      final ambientAtAltitude = altitudePressure + (20.0 / 10.0);

      // Ambient pressure at 20m depth at sea level
      const ambientAtSeaLevel = 1.01325 + (20.0 / 10.0);

      // The altitude dive has lower ambient pressure
      expect(ambientAtAltitude, lessThan(ambientAtSeaLevel));

      // But the pressure ratio (decompression stress) is higher
      final ratioAtAltitude = ambientAtAltitude / altitudePressure;
      const ratioAtSeaLevel = ambientAtSeaLevel / 1.01325;
      expect(ratioAtAltitude, greaterThan(ratioAtSeaLevel));
    });

    test('calculateEquivalentOceanDepth provides correct mapping', () {
      // At 2000m altitude (pressure ~0.795 bar), a 20m dive is equivalent
      // to a deeper ocean dive due to the lower surface pressure
      final eod = AltitudeCalculator.calculateEquivalentOceanDepth(
        actualDepth: 20,
        altitudeMeters: 2000,
      );

      // EOD should be deeper than actual depth
      expect(eod, greaterThan(20));

      // At sea level, EOD should equal actual depth
      final eodSeaLevel = AltitudeCalculator.calculateEquivalentOceanDepth(
        actualDepth: 20,
        altitudeMeters: 0,
      );
      expect(eodSeaLevel, closeTo(20, 0.5));
    });

    test('calculateActualDepthFromOceanEquivalent is inverse of EOD', () {
      const altitude = 1800.0;
      const oceanEquivalent = 30.0;

      final actualDepth =
          AltitudeCalculator.calculateActualDepthFromOceanEquivalent(
            oceanEquivalentDepth: oceanEquivalent,
            altitudeMeters: altitude,
          );

      // Round-trip should work
      final backToOcean = AltitudeCalculator.calculateEquivalentOceanDepth(
        actualDepth: actualDepth,
        altitudeMeters: altitude,
      );

      expect(backToOcean, closeTo(oceanEquivalent, 0.1));
    });
  });
}
