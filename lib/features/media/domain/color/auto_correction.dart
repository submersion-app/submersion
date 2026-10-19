import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/media/domain/color/channel_stats.dart';
import 'package:submersion/features/media/domain/color/color_matrix.dart';

/// How far the automatic fix may go at [depthMeters], 0..1.
///
/// Water absorbs red with depth, so a 5 m shot has lost far less of it than
/// a 25 m shot and gets a gentler fix. Shallower than 1 m is a surface shot
/// and gets none. No depth (a dive without a profile) allows the full range,
/// because the caller has already checked the photo's own colours.
double depthFactor(double? depthMeters) {
  if (depthMeters == null) return 1.0;
  if (depthMeters < 1.0) return 0.0;
  return (depthMeters / 15).clamp(0.2, 1.0);
}

/// Red at or above this share of green is not deficient.
const _redSufficient = 0.8;

/// The automatic correction: rebuild red from green, then per-channel gains.
class AutoCorrectionParams extends Equatable {
  const AutoCorrectionParams({
    required this.redFromGreen,
    required this.gainR,
    required this.gainG,
    required this.gainB,
  });

  final double redFromGreen;
  final double gainR;
  final double gainG;
  final double gainB;

  static const none = AutoCorrectionParams(
    redFromGreen: 0,
    gainR: 1,
    gainG: 1,
    gainB: 1,
  );

  ColorMatrix toMatrix() => ColorMatrix.redFromGreen(
    redFromGreen,
  ).then(ColorMatrix.gains(gainR, gainG, gainB));

  static AutoCorrectionParams lerp(
    AutoCorrectionParams a,
    AutoCorrectionParams b,
    double t,
  ) {
    double l(double x, double y) => x + (y - x) * t;
    return AutoCorrectionParams(
      redFromGreen: l(a.redFromGreen, b.redFromGreen),
      gainR: l(a.gainR, b.gainR),
      gainG: l(a.gainG, b.gainG),
      gainB: l(a.gainB, b.gainB),
    );
  }

  /// These params limited to what [depthMeters] allows, for one moment of a
  /// video whose depth changes through the clip. Null depth leaves them as
  /// they are.
  AutoCorrectionParams boundedFor(double? depthMeters) {
    if (depthMeters == null) return this;
    final f = depthFactor(depthMeters);
    if (f == 0) return none;
    return AutoCorrectionParams(
      redFromGreen: math.min(redFromGreen, 0.5 * f),
      gainR: math.min(gainR, 1 + 1.5 * f),
      gainG: gainG,
      gainB: gainB,
    );
  }

  @override
  List<Object?> get props => [redFromGreen, gainR, gainG, gainB];
}

/// Works out the automatic fix for a photo or frame with these [stats].
///
/// Green survives water best, so the missing red is rebuilt from it; the
/// channels are then balanced toward neutral grey (grey world), with gains
/// bounded by depth and capped so neither red nor blue can climb above
/// green, which is what turns over-corrected shots purple.
AutoCorrectionParams computeAutoCorrection(
  ChannelStats stats, {
  double? depthMeters,
}) {
  final f = depthFactor(depthMeters);
  if (f == 0 || stats.meanG <= 0) return AutoCorrectionParams.none;
  final mr = stats.meanR, mg = stats.meanG, mb = stats.meanB;
  // Red the water did not take (a strobe-lit macro shot, a red subject):
  // balancing it toward grey would only cut red and cast it green.
  if (mr >= _redSufficient * mg) return AutoCorrectionParams.none;

  final a = math.min(0.5 * f, 0.5 * math.max(0.0, (mg - mr) / mg));
  final r1 = mr + a * mg;
  final grey = (r1 + mg + mb) / 3;

  var gainR = r1 > 0 ? (grey / r1).clamp(1.0, 1 + 1.5 * f) : 1 + 1.5 * f;
  final gainG = (grey / mg).clamp(0.8, 1.25);
  var gainB = mb > 0 ? (grey / mb).clamp(0.6, 1.1) : 1.0;

  final greenOut = gainG * mg;
  // Capped, but never below 1: the fix adds red, it never takes it away.
  if (gainR * r1 > 1.05 * greenOut) {
    gainR = math.max(1.0, 1.05 * greenOut / r1);
  }
  if (gainB * mb > 1.05 * greenOut) gainB = 1.05 * greenOut / mb;

  return AutoCorrectionParams(
    redFromGreen: a,
    gainR: gainR,
    gainG: gainG,
    gainB: gainB,
  );
}
