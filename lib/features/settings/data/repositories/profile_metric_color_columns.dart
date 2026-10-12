import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';

/// [companion] with every `profile_color_*` column set from [overrides]
/// (null where the metric shows its default), so a save also clears a
/// colour the diver reset.
DiverSettingsCompanion withProfileMetricColors(
  DiverSettingsCompanion companion,
  ProfileMetricColorOverrides overrides,
) {
  Value<int?> v(ProfileMetric m) => Value(overrides.argbOf(m));
  return companion.copyWith(
    profileColorDepth: v(ProfileMetric.depth),
    profileColorTemperature: v(ProfileMetric.temperature),
    profileColorPressure: v(ProfileMetric.pressure),
    profileColorHeartRate: v(ProfileMetric.heartRate),
    profileColorSac: v(ProfileMetric.sac),
    profileColorMaxDepth: v(ProfileMetric.maxDepth),
    profileColorCeiling: v(ProfileMetric.ceiling),
    profileColorNdl: v(ProfileMetric.ndl),
    profileColorTts: v(ProfileMetric.tts),
    profileColorGtr: v(ProfileMetric.gtr),
    profileColorCns: v(ProfileMetric.cns),
    profileColorOtu: v(ProfileMetric.otu),
    profileColorPpO2: v(ProfileMetric.ppO2),
    profileColorPpN2: v(ProfileMetric.ppN2),
    profileColorPpHe: v(ProfileMetric.ppHe),
    profileColorMod: v(ProfileMetric.mod),
    profileColorDensity: v(ProfileMetric.density),
    profileColorGf: v(ProfileMetric.gf),
    profileColorSurfaceGf: v(ProfileMetric.surfaceGf),
    profileColorMeanDepth: v(ProfileMetric.meanDepth),
  );
}

/// The colours stored on [row], deduped: per-field sync conflict resolution
/// can leave two metrics on one colour, and reading the repair here means
/// the next settings save stores it. Reading never writes.
ProfileMetricColorOverrides profileMetricColorsFromRow(DiverSetting row) =>
    ProfileMetricColorOverrides.fromArgb({
      ProfileMetric.depth: row.profileColorDepth,
      ProfileMetric.temperature: row.profileColorTemperature,
      ProfileMetric.pressure: row.profileColorPressure,
      ProfileMetric.heartRate: row.profileColorHeartRate,
      ProfileMetric.sac: row.profileColorSac,
      ProfileMetric.maxDepth: row.profileColorMaxDepth,
      ProfileMetric.ceiling: row.profileColorCeiling,
      ProfileMetric.ndl: row.profileColorNdl,
      ProfileMetric.tts: row.profileColorTts,
      ProfileMetric.gtr: row.profileColorGtr,
      ProfileMetric.cns: row.profileColorCns,
      ProfileMetric.otu: row.profileColorOtu,
      ProfileMetric.ppO2: row.profileColorPpO2,
      ProfileMetric.ppN2: row.profileColorPpN2,
      ProfileMetric.ppHe: row.profileColorPpHe,
      ProfileMetric.mod: row.profileColorMod,
      ProfileMetric.density: row.profileColorDensity,
      ProfileMetric.gf: row.profileColorGf,
      ProfileMetric.surfaceGf: row.profileColorSurfaceGf,
      ProfileMetric.meanDepth: row.profileColorMeanDepth,
    }).deduped();
