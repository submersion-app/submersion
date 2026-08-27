import 'package:flutter_test/flutter_test.dart';
// dive_field.dart re-exports the extractor and formatter extensions.
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  const metric = UnitFormatter(AppSettings(depthUnit: DepthUnit.meters));
  const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

  Dive buildDive({double? visibilityMeters, Visibility? visibility}) => Dive(
    id: 'd1',
    dateTime: DateTime(2026, 3, 28, 10, 0),
    visibilityMeters: visibilityMeters,
    visibility: visibility,
  );

  group('DiveField.visibility extraction', () {
    test('returns the raw metric value for a measured dive', () {
      // Raw, like maxDepth and swellHeight: UnitFormatter converts at render
      // time rather than the extractor baking in a unit.
      expect(
        DiveField.visibility.extractFromDive(buildDive(visibilityMeters: 6.0)),
        6.0,
      );
    });

    test('falls back to the legacy label for a pre-v144 dive', () {
      expect(
        DiveField.visibility.extractFromDive(
          buildDive(visibility: Visibility.moderate),
        ),
        'Moderate (5-15m / 15-50ft)',
      );
    });

    test('prefers the measurement when a dive somehow has both', () {
      expect(
        DiveField.visibility.extractFromDive(
          buildDive(visibilityMeters: 6.0, visibility: Visibility.moderate),
        ),
        6.0,
      );
    });

    test('returns null when neither is set', () {
      expect(DiveField.visibility.extractFromDive(buildDive()), isNull);
    });
  });

  group('DiveField.visibility formatting', () {
    test('formats a measured value as a distance in diver units', () {
      expect(
        DiveField.visibility.formatValue(6.0, metric),
        metric.formatDistance(6.0),
      );
      expect(
        DiveField.visibility.formatValue(6.0, imperial),
        imperial.formatDistance(6.0),
      );
    });

    test('passes the legacy label through unchanged', () {
      expect(
        DiveField.visibility.formatValue('Moderate (5-15m / 15-50ft)', metric),
        'Moderate (5-15m / 15-50ft)',
      );
    });

    test('renders null as the standard placeholder', () {
      expect(DiveField.visibility.formatValue(null, metric), '--');
    });
  });
}
