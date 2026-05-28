import 'package:submersion/features/dive_sites/domain/matching/match_thresholds.dart';

/// User-facing sensitivity preset for auto site matching.
enum SiteMatchSensitivity {
  strict,
  balanced,
  relaxed;

  static SiteMatchSensitivity fromName(String name) {
    return SiteMatchSensitivity.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SiteMatchSensitivity.balanced,
    );
  }

  MatchThresholds get thresholds {
    switch (this) {
      case SiteMatchSensitivity.strict:
        return const MatchThresholds(
          innerRadiusMeters: 100,
          outerRadiusMeters: 500,
          separationMeters: 100,
        );
      case SiteMatchSensitivity.balanced:
        return const MatchThresholds(
          innerRadiusMeters: 150,
          outerRadiusMeters: 1000,
          separationMeters: 75,
        );
      case SiteMatchSensitivity.relaxed:
        return const MatchThresholds(
          innerRadiusMeters: 300,
          outerRadiusMeters: 2000,
          separationMeters: 50,
        );
    }
  }
}
