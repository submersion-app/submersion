import 'package:equatable/equatable.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

/// The `deco_type` value that marks a mandatory decompression stop
/// (0 = NDL, 1 = safety stop, 2 = deco stop, 3 = deep stop).
const int kDecoTypeDecoStop = 2;

/// The scalars a `dive_profile_series` row stores next to its blob.
///
/// These exist so the SQL consumers that only need a predicate or a span
/// (deco classification, runtime fallback, quality neighbours) never decode
/// a blob. They are computed from the same sample list the codec packs, so
/// a scalar can never disagree with its blob.
class ProfileSeriesSummary extends Equatable {
  const ProfileSeriesSummary({
    required this.sampleCount,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.maxDepth,
    required this.firstDepth,
    required this.lastDepth,
    required this.hasDecoType,
    required this.hasDecoStop,
    required this.hasPositiveCeiling,
  });

  /// Computes the summary of a non-empty, timestamp-ordered series.
  factory ProfileSeriesSummary.of(List<ProfileSample> samples) {
    if (samples.isEmpty) {
      throw ArgumentError.value(
        samples,
        'samples',
        'a series needs at least one sample',
      );
    }
    var maxDepth = samples.first.depth;
    var hasDecoType = false;
    var hasDecoStop = false;
    var hasPositiveCeiling = false;
    for (final sample in samples) {
      if (sample.depth > maxDepth) maxDepth = sample.depth;
      final decoType = sample.decoType;
      if (decoType != null) {
        hasDecoType = true;
        if (decoType == kDecoTypeDecoStop) hasDecoStop = true;
      }
      final ceiling = sample.ceiling;
      if (ceiling != null && ceiling > 0) hasPositiveCeiling = true;
    }
    return ProfileSeriesSummary(
      sampleCount: samples.length,
      startTimestamp: samples.first.timestamp,
      endTimestamp: samples.last.timestamp,
      maxDepth: maxDepth,
      firstDepth: samples.first.depth,
      lastDepth: samples.last.depth,
      hasDecoType: hasDecoType,
      hasDecoStop: hasDecoStop,
      hasPositiveCeiling: hasPositiveCeiling,
    );
  }

  final int sampleCount;

  /// Seconds from dive start of the first sample.
  final int startTimestamp;

  /// Seconds from dive start of the last sample.
  final int endTimestamp;

  /// Metres.
  final double maxDepth;
  final double firstDepth;
  final double lastDepth;

  /// Any sample carries a `deco_type`.
  final bool hasDecoType;

  /// Any sample carries `deco_type == 2`.
  final bool hasDecoStop;

  /// Any sample carries `ceiling > 0`.
  final bool hasPositiveCeiling;

  @override
  List<Object?> get props => [
    sampleCount,
    startTimestamp,
    endTimestamp,
    maxDepth,
    firstDepth,
    lastDepth,
    hasDecoType,
    hasDecoStop,
    hasPositiveCeiling,
  ];
}
