import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

void main() {
  test(
    'diveProfileAnalysisProvider returns profile-only analysis for gauge dives, '
    'ignoring any computer-reported deco in the profile',
    () {
      // A gauge dive whose samples carry computer ceiling/NDL. Without the
      // gauge short-circuit the computer-deco overlay would surface these;
      // for a gauge dive they must stay absent.
      final depths = <double>[0, 20, 40, 40, 40, 20, 0];
      final ceilings = <double?>[null, null, 3.0, 3.0, 3.0, 3.0, null];
      final profile = <DiveProfilePoint>[
        for (var i = 0; i < depths.length; i++)
          DiveProfilePoint(
            timestamp: i * 60,
            depth: depths[i],
            ceiling: ceilings[i],
            ndl: ceilings[i] != null ? 0 : 99,
          ),
      ];
      final dive = Dive(
        id: 'gauge-1',
        dateTime: DateTime.utc(2026, 1, 1),
        diveMode: DiveMode.gauge,
        profile: profile,
      );

      final container = ProviderContainer(
        overrides: [
          // Inject a default analysis service so the bare container skips the
          // DB-backed settings chain. In production the gauge branch uses the
          // user-configured service (ascent-rate thresholds).
          profileAnalysisServiceProvider.overrideWithValue(
            ProfileAnalysisService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final analysis = container.read(diveProfileAnalysisProvider(dive));

      expect(analysis, isNotNull);
      expect(analysis!.ceilingCurve, isEmpty);
      expect(analysis.ndlCurve, isEmpty);
      expect(analysis.ppO2Curve, isEmpty);
      expect(analysis.hasCnsData, isFalse);
      expect(analysis.ascentRates, isNotEmpty);
    },
  );
}
