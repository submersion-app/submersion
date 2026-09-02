import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

/// Drops samples that repeat one already seen, comparing every field.
///
/// This is the write-side home of what `DiveRepository._dropDuplicateSamples`
/// does on every read today: a repeated import stored the same sample twice,
/// and analysis curves are index-aligned against the list, so the duplicate
/// has to go before the series is packed. Samples that share a timestamp but
/// differ in any field are all kept, in insertion order.
List<ProfileSample> dedupeExactSamples(List<ProfileSample> samples) {
  final seen = <ProfileSample>{};
  return [
    for (final sample in samples)
      if (seen.add(sample)) sample,
  ];
}

/// [dedupeExactSamples] for tank pressure readings.
List<TankPressureSample> dedupeExactPressureSamples(
  List<TankPressureSample> samples,
) {
  final seen = <TankPressureSample>{};
  return [
    for (final sample in samples)
      if (seen.add(sample)) sample,
  ];
}
