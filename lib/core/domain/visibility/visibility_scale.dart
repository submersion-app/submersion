import 'package:submersion/core/domain/visibility/visibility_range.dart';

/// Which calibration a diver has chosen for visibility adjectives.
enum VisibilityScalePreset { tropical, temperate, coldWater, custom }

/// The four qualitative bands a visibility distance can fall into.
enum VisibilityBand { poor, moderate, good, excellent }

/// Maps a measured visibility distance in meters to a [VisibilityBand].
///
/// This is purely presentational. A dive always stores the measured distance,
/// so changing the scale re-labels a logbook without altering a single dive.
/// That is the whole point of measuring rather than bucketing: "excellent"
/// means something different in Cozumel than it does in Puget Sound, but six
/// meters is six meters everywhere.
class VisibilityScale {
  /// A distance at or above this is [VisibilityBand.excellent].
  final double excellentAtOrAboveM;

  /// A distance at or above this, and below [excellentAtOrAboveM], is
  /// [VisibilityBand.good].
  final double goodAtOrAboveM;

  /// A distance at or above this, and below [goodAtOrAboveM], is
  /// [VisibilityBand.moderate]. Anything below it is [VisibilityBand.poor].
  final double moderateAtOrAboveM;

  const VisibilityScale({
    required this.excellentAtOrAboveM,
    required this.goodAtOrAboveM,
    required this.moderateAtOrAboveM,
  });

  /// Reproduces the thresholds hardcoded before v144, so upgrading re-labels
  /// nobody's logbook. This is the default.
  static const tropical = VisibilityScale(
    excellentAtOrAboveM: 30,
    goodAtOrAboveM: 15,
    moderateAtOrAboveM: 5,
  );

  static const temperate = VisibilityScale(
    excellentAtOrAboveM: 20,
    goodAtOrAboveM: 10,
    moderateAtOrAboveM: 4,
  );

  static const coldWater = VisibilityScale(
    excellentAtOrAboveM: 12,
    goodAtOrAboveM: 6,
    moderateAtOrAboveM: 2,
  );

  /// Thresholds must descend strictly and stay positive; otherwise a band
  /// would be unreachable.
  bool get isValid =>
      moderateAtOrAboveM > 0 &&
      goodAtOrAboveM > moderateAtOrAboveM &&
      excellentAtOrAboveM > goodAtOrAboveM;

  /// Resolves a stored preference into a usable scale.
  ///
  /// Custom values that are absent or invalid fall back to [tropical] rather
  /// than producing an unreachable band, so a corrupt preference degrades to
  /// the previous behaviour instead of rendering nonsense.
  static VisibilityScale forPreset(
    VisibilityScalePreset preset, {
    double? excellentM,
    double? goodM,
    double? moderateM,
  }) {
    switch (preset) {
      case VisibilityScalePreset.tropical:
        return tropical;
      case VisibilityScalePreset.temperate:
        return temperate;
      case VisibilityScalePreset.coldWater:
        return coldWater;
      case VisibilityScalePreset.custom:
        if (excellentM == null || goodM == null || moderateM == null) {
          return tropical;
        }
        final candidate = VisibilityScale(
          excellentAtOrAboveM: excellentM,
          goodAtOrAboveM: goodM,
          moderateAtOrAboveM: moderateM,
        );
        return candidate.isValid ? candidate : tropical;
    }
  }

  /// The band [meters] falls into. Bounds are inclusive at the lower edge.
  VisibilityBand bandFor(double meters) {
    if (meters >= excellentAtOrAboveM) return VisibilityBand.excellent;
    if (meters >= goodAtOrAboveM) return VisibilityBand.good;
    if (meters >= moderateAtOrAboveM) return VisibilityBand.moderate;
    return VisibilityBand.poor;
  }

  /// The metres [band] covers on this scale (issue #3226). What a band pick
  /// in the edit form saves: Good on cold water is 6-12 m.
  VisibilityRange rangeFor(VisibilityBand band) => switch (band) {
    VisibilityBand.poor => VisibilityRange(maxM: moderateAtOrAboveM),
    VisibilityBand.moderate => VisibilityRange(
      minM: moderateAtOrAboveM,
      maxM: goodAtOrAboveM,
    ),
    VisibilityBand.good => VisibilityRange(
      minM: goodAtOrAboveM,
      maxM: excellentAtOrAboveM,
    ),
    VisibilityBand.excellent => VisibilityRange(minM: excellentAtOrAboveM),
  };

  /// The band that wholly contains [range], or null when it crosses a band
  /// edge. A saved range keeps its metres when the diver changes scale, so
  /// under a different scale it may honestly belong to no single band.
  ///
  /// `VisibilityBandSql` in the Insights repositories is the SQL twin of
  /// this; keep the two in step.
  VisibilityBand? bandForRange(VisibilityRange range) {
    final lo = range.minM ?? double.negativeInfinity;
    final hi = range.maxM ?? double.infinity;
    if (lo >= excellentAtOrAboveM) return VisibilityBand.excellent;
    if (lo >= goodAtOrAboveM && hi <= excellentAtOrAboveM) {
      return VisibilityBand.good;
    }
    if (lo >= moderateAtOrAboveM && hi <= goodAtOrAboveM) {
      return VisibilityBand.moderate;
    }
    if (hi <= moderateAtOrAboveM) return VisibilityBand.poor;
    return null;
  }

  /// The band whose [rangeFor] is exactly [range], or null. Decides which
  /// chip the edit form shows selected for a stored range.
  VisibilityBand? bandMatching(VisibilityRange range) =>
      VisibilityBand.values.where((b) => rangeFor(b) == range).firstOrNull;

  @override
  bool operator ==(Object other) =>
      other is VisibilityScale &&
      other.excellentAtOrAboveM == excellentAtOrAboveM &&
      other.goodAtOrAboveM == goodAtOrAboveM &&
      other.moderateAtOrAboveM == moderateAtOrAboveM;

  @override
  int get hashCode =>
      Object.hash(excellentAtOrAboveM, goodAtOrAboveM, moderateAtOrAboveM);

  @override
  String toString() =>
      'VisibilityScale(excellent >= $excellentAtOrAboveM m, '
      'good >= $goodAtOrAboveM m, moderate >= $moderateAtOrAboveM m)';
}
