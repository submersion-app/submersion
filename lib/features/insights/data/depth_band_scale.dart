import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/units.dart';

/// The most bars the Time at depth chart draws (issue #4600). Time deeper
/// than the last bar's band is folded into it, and it then reads "70+".
const int timeAtDepthMaxBars = 8;

/// How the Time at depth chart cuts depth into bands: how wide a band is in
/// meters, the unit samples are stored in, and how many of the diver's own
/// depth units that width is, which is what the band edges are labelled in.
///
/// A feet diver gets bands 30 ft wide rather than 10 m bands relabelled, so
/// the edges read 0-30, 30-60 instead of 0-33, 33-66 (issue #4600).
@immutable
class DepthBandScale {
  const DepthBandScale({required this.widthMeters, required this.step});

  /// 10 m bands.
  static const metric = DepthBandScale(widthMeters: 10, step: 10);

  /// 30 ft bands. A foot is exactly 0.3048 m, so 30 ft is 9.144 m.
  static const imperial = DepthBandScale(widthMeters: 9.144, step: 30);

  static DepthBandScale forUnit(DepthUnit unit) => switch (unit) {
    DepthUnit.meters => metric,
    DepthUnit.feet => imperial,
  };

  /// Width of one band in meters.
  final double widthMeters;

  /// Width of one band in the diver's depth unit; band `i` runs from
  /// `i * step` to `(i + 1) * step`.
  final int step;

  /// Absorbs float error at a band edge: 60 ft is stored as 18.288 m, and
  /// 18.288 / 9.144 must floor to 2, not to 1.
  static const double _edgeEpsilon = 1e-9;

  /// The index of the band [depthMeters] falls in. A depth exactly on an
  /// edge belongs to the deeper band, and a reading above the surface to the
  /// first.
  int bandOf(double depthMeters) {
    final index = (depthMeters / widthMeters + _edgeEpsilon).floor();
    return index < 0 ? 0 : index;
  }

  @override
  bool operator ==(Object other) =>
      other is DepthBandScale &&
      other.widthMeters == widthMeters &&
      other.step == step;

  @override
  int get hashCode => Object.hash(widthMeters, step);
}
