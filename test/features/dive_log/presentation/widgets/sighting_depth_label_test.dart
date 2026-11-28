import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/services/species_profile_positions.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sighting_depth_label.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// The depth chip's text on a Marine life row (issue #5092).
void main() {
  final l10n = AppLocalizationsEn();
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

  SpeciesProfilePositions between(double shallow, double deep) =>
      SpeciesProfilePositions(
        moments: [
          (seconds: 60, depthMeters: shallow),
          (seconds: 120, depthMeters: deep),
        ],
        spans: const [],
      );

  test('one depth when both ends round to the same whole unit', () {
    expect(sightingDepthLabel(between(27.2, 27.4), metric, l10n), '27 m');
  });

  test('a range from the shallowest to the deepest', () {
    expect(sightingDepthLabel(between(16.2, 18.4), metric, l10n), '16 to 18 m');
  });

  test('imperial converts before rounding', () {
    expect(
      sightingDepthLabel(between(4.6, 5.4), imperial, l10n),
      '15 to 18 ft',
    );
  });

  test('a sensor reading above the surface reads as 0', () {
    expect(sightingDepthLabel(between(-0.6, 18.4), metric, l10n), '0 to 18 m');
  });

  test('a span counts its own shallowest and deepest', () {
    const positions = SpeciesProfilePositions(
      moments: [],
      spans: [(start: 0, end: 60, minDepth: 3, maxDepth: 41.6)],
    );
    expect(sightingDepthLabel(positions, metric, l10n), '3 to 42 m');
  });
}
