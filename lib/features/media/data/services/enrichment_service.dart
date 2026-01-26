import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Result of enriching a media item with dive profile data.
///
/// Contains the calculated depth and temperature at the time the photo was
/// taken, along with metadata about how confident the match is.
class EnrichmentResult extends Equatable {
  /// Depth in meters at the photo timestamp, or null if not available.
  final double? depthMeters;

  /// Temperature in Celsius at the photo timestamp, or null if not available.
  final double? temperatureCelsius;

  /// Elapsed time in seconds from dive start to photo timestamp.
  final int elapsedSeconds;

  /// Confidence level of the depth/temperature match.
  final MatchConfidence matchConfidence;

  /// Offset in seconds from the photo timestamp to the nearest profile point.
  /// Positive = photo is after the point, negative = photo is before.
  /// Null when using interpolation between points.
  final int? timestampOffsetSeconds;

  const EnrichmentResult({
    this.depthMeters,
    this.temperatureCelsius,
    required this.elapsedSeconds,
    required this.matchConfidence,
    this.timestampOffsetSeconds,
  });

  @override
  List<Object?> get props => [
    depthMeters,
    temperatureCelsius,
    elapsedSeconds,
    matchConfidence,
    timestampOffsetSeconds,
  ];
}

/// Service for enriching media items with depth and temperature data
/// from dive profile recordings.
///
/// This service calculates what depth and temperature the diver was at
/// when a photo was taken by interpolating the dive computer's profile data.
class EnrichmentService {
  /// Maximum seconds from profile point to be considered an exact match.
  static const int exactMatchThreshold = 10;

  /// Maximum gap between profile points for interpolation confidence.
  /// Gaps larger than this result in "estimated" confidence.
  static const int interpolationThreshold = 60;

  const EnrichmentService();

  /// Calculate enrichment data for a photo taken during a dive.
  ///
  /// [profile] - List of dive profile points from the dive computer.
  /// [diveStartTime] - When the dive started (entry time or dateTime).
  /// [photoTime] - When the photo was taken (from EXIF data).
  ///
  /// Returns an [EnrichmentResult] containing calculated depth, temperature,
  /// elapsed time, and confidence level.
  EnrichmentResult calculateEnrichment({
    required List<DiveProfilePoint> profile,
    required DateTime diveStartTime,
    required DateTime photoTime,
  }) {
    final elapsedSeconds = photoTime.difference(diveStartTime).inSeconds;

    // Handle empty profile
    if (profile.isEmpty) {
      return EnrichmentResult(
        elapsedSeconds: elapsedSeconds,
        matchConfidence: MatchConfidence.noProfile,
      );
    }

    // Sort profile by timestamp to ensure correct ordering
    final sortedProfile = List<DiveProfilePoint>.from(profile)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Handle single point profile
    if (sortedProfile.length == 1) {
      final point = sortedProfile.first;
      return EnrichmentResult(
        depthMeters: point.depth,
        temperatureCelsius: point.temperature,
        elapsedSeconds: elapsedSeconds,
        matchConfidence: MatchConfidence.estimated,
        timestampOffsetSeconds: elapsedSeconds - point.timestamp,
      );
    }

    // Find bracketing points
    final bracketResult = _findBracketingPoints(sortedProfile, elapsedSeconds);

    // Photo is before first profile point
    if (bracketResult.beforeIndex == null) {
      final firstPoint = sortedProfile.first;
      return EnrichmentResult(
        depthMeters: firstPoint.depth,
        temperatureCelsius: firstPoint.temperature,
        elapsedSeconds: elapsedSeconds,
        matchConfidence: MatchConfidence.estimated,
        timestampOffsetSeconds: elapsedSeconds - firstPoint.timestamp,
      );
    }

    // Photo is after last profile point
    if (bracketResult.afterIndex == null) {
      final lastPoint = sortedProfile.last;
      return EnrichmentResult(
        depthMeters: lastPoint.depth,
        temperatureCelsius: lastPoint.temperature,
        elapsedSeconds: elapsedSeconds,
        matchConfidence: MatchConfidence.estimated,
        timestampOffsetSeconds: elapsedSeconds - lastPoint.timestamp,
      );
    }

    final beforePoint = sortedProfile[bracketResult.beforeIndex!];
    final afterPoint = sortedProfile[bracketResult.afterIndex!];

    // Check for exact match with either bracketing point
    final diffToBefore = (elapsedSeconds - beforePoint.timestamp).abs();
    final diffToAfter = (afterPoint.timestamp - elapsedSeconds).abs();

    if (diffToBefore <= exactMatchThreshold) {
      return EnrichmentResult(
        depthMeters: beforePoint.depth,
        temperatureCelsius: beforePoint.temperature,
        elapsedSeconds: elapsedSeconds,
        matchConfidence: MatchConfidence.exact,
        timestampOffsetSeconds: elapsedSeconds - beforePoint.timestamp,
      );
    }

    if (diffToAfter <= exactMatchThreshold) {
      return EnrichmentResult(
        depthMeters: afterPoint.depth,
        temperatureCelsius: afterPoint.temperature,
        elapsedSeconds: elapsedSeconds,
        matchConfidence: MatchConfidence.exact,
        timestampOffsetSeconds: elapsedSeconds - afterPoint.timestamp,
      );
    }

    // Interpolate between points
    final gap = afterPoint.timestamp - beforePoint.timestamp;
    final ratio = (elapsedSeconds - beforePoint.timestamp) / gap;

    final interpolatedDepth =
        beforePoint.depth + (afterPoint.depth - beforePoint.depth) * ratio;

    final interpolatedTemp = _interpolateTemperature(
      beforePoint: beforePoint,
      afterPoint: afterPoint,
      ratio: ratio,
    );

    // Determine confidence based on gap size
    final confidence = gap <= interpolationThreshold
        ? MatchConfidence.interpolated
        : MatchConfidence.estimated;

    return EnrichmentResult(
      depthMeters: interpolatedDepth,
      temperatureCelsius: interpolatedTemp,
      elapsedSeconds: elapsedSeconds,
      matchConfidence: confidence,
    );
  }

  /// Find the indices of profile points that bracket the given timestamp.
  ///
  /// Returns (beforeIndex, afterIndex) where:
  /// - beforeIndex is the last point at or before the timestamp
  /// - afterIndex is the first point at or after the timestamp
  /// - Either may be null if the timestamp is outside the profile range
  _BracketResult _findBracketingPoints(
    List<DiveProfilePoint> profile,
    int timestamp,
  ) {
    int? beforeIndex;
    int? afterIndex;

    for (int i = 0; i < profile.length; i++) {
      if (profile[i].timestamp <= timestamp) {
        beforeIndex = i;
      }
      if (profile[i].timestamp >= timestamp && afterIndex == null) {
        afterIndex = i;
      }
    }

    return _BracketResult(beforeIndex: beforeIndex, afterIndex: afterIndex);
  }

  /// Interpolate temperature between two profile points.
  ///
  /// If both points have temperature, linearly interpolate.
  /// If only one point has temperature, use that value.
  /// If neither has temperature, return null.
  double? _interpolateTemperature({
    required DiveProfilePoint beforePoint,
    required DiveProfilePoint afterPoint,
    required double ratio,
  }) {
    final beforeTemp = beforePoint.temperature;
    final afterTemp = afterPoint.temperature;

    if (beforeTemp != null && afterTemp != null) {
      return beforeTemp + (afterTemp - beforeTemp) * ratio;
    }

    if (beforeTemp != null) {
      return beforeTemp;
    }

    if (afterTemp != null) {
      return afterTemp;
    }

    return null;
  }
}

/// Internal class to hold bracket search results.
class _BracketResult {
  final int? beforeIndex;
  final int? afterIndex;

  const _BracketResult({this.beforeIndex, this.afterIndex});
}
