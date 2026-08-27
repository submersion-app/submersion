import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart' as enums;
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  Dive buildDive({double? visibilityMeters, enums.Visibility? visibility}) =>
      Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 3, 28, 10, 0),
        visibilityMeters: visibilityMeters,
        visibility: visibility,
      );

  group('UDDF visibility export', () {
    test('a measured distance exports verbatim', () {
      // Before v144 this dive would have been stored as "moderate" and
      // exported as "10", losing the real 6.4 m the diver recorded.
      expect(
        UddfExportBuilders.visibilityForUddf(buildDive(visibilityMeters: 6.4)),
        '6.4',
      );
    });

    test('a distance finer than 0.1 m is not rounded away', () {
      // toStringAsFixed(1) would have turned 6.44 into "6.4", quietly losing
      // precision on the way out and defeating a true round trip.
      final exported = UddfExportBuilders.visibilityForUddf(
        buildDive(visibilityMeters: 6.44),
      );
      expect(double.parse(exported!), closeTo(6.44, 0.0001));
    });

    test('a large measured distance is not clamped to a bucket midpoint', () {
      expect(
        UddfExportBuilders.visibilityForUddf(buildDive(visibilityMeters: 42.5)),
        '42.5',
      );
    });

    test('a legacy dive still exports its representative midpoint', () {
      expect(
        UddfExportBuilders.visibilityForUddf(
          buildDive(visibility: enums.Visibility.moderate),
        ),
        '10',
      );
    });

    test('a measurement wins over a legacy bucket', () {
      expect(
        UddfExportBuilders.visibilityForUddf(
          buildDive(
            visibilityMeters: 6.4,
            visibility: enums.Visibility.moderate,
          ),
        ),
        '6.4',
      );
    });

    test('a dive with no visibility exports nothing', () {
      expect(UddfExportBuilders.visibilityForUddf(buildDive()), isNull);
      expect(
        UddfExportBuilders.visibilityForUddf(
          buildDive(visibility: enums.Visibility.unknown),
        ),
        isNull,
      );
    });
  });

  group('round trip', () {
    test('export then re-parse preserves the measured distance', () {
      // The regression guard for the pre-v144 loss: export emits the real
      // number, and the importer parses the same text back to metres.
      const original = 6.4;
      final exported = UddfExportBuilders.visibilityForUddf(
        buildDive(visibilityMeters: original),
      );
      final reparsed = double.tryParse(exported!);
      expect(reparsed, closeTo(original, 0.0001));
    });

    test('a legacy dive round-trips as a measurement once exported', () {
      // Exporting a legacy bucket necessarily commits to its midpoint, which
      // is the best that can be done for data logged before measurement.
      final exported = UddfExportBuilders.visibilityForUddf(
        buildDive(visibility: enums.Visibility.good),
      );
      expect(double.tryParse(exported!), 20);
    });
  });
}
