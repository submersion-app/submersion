import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

void main() {
  // A square 30 m / 25 min profile sampled every 30 s.
  final depths = <double>[];
  final timestamps = <int>[];
  for (int t = 0; t <= 1620; t += 30) {
    timestamps.add(t);
    if (t < 120) {
      depths.add(30.0 * t / 120.0);
    } else if (t <= 1500) {
      depths.add(30.0);
    } else {
      depths.add(30.0 * (1620 - t) / 120.0);
    }
  }

  test('altitude environment yields shorter NDL in the analysis', () {
    final seaLevel = ProfileAnalysisService(gfLow: 0.5, gfHigh: 0.8);
    final altitude = ProfileAnalysisService(
      gfLow: 0.5,
      gfHigh: 0.8,
      environment: DiveEnvironment.forConditions(altitudeMeters: 2500),
    );

    final seaAnalysis = seaLevel.analyze(
      diveId: 'test',
      depths: depths,
      timestamps: timestamps,
    );
    final altAnalysis = altitude.analyze(
      diveId: 'test',
      depths: depths,
      timestamps: timestamps,
    );

    // Early in the bottom phase (t = 300 s, 3 min at 30 m) the NDL is
    // still positive for both, and shorter at altitude.
    final early = timestamps.indexOf(300);
    expect(seaAnalysis.ndlCurve[early], greaterThan(0));
    expect(altAnalysis.ndlCurve[early], lessThan(seaAnalysis.ndlCurve[early]));

    // The altitude dive enters deco (NDL -1) no later than the sea-level one.
    int decoEntry(List<int> ndl) => ndl.indexWhere((v) => v < 0);
    final seaEntry = decoEntry(seaAnalysis.ndlCurve);
    final altEntry = decoEntry(altAnalysis.ndlCurve);
    expect(altEntry, isNot(-1));
    expect(altEntry, lessThanOrEqualTo(seaEntry == -1 ? 1 << 30 : seaEntry));
  });
}
