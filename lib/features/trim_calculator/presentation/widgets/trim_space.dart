import 'dart:ui';

import 'package:submersion/core/buoyancy/trim/trim_body.dart';

/// The space the trim figure's side-view artwork is drawn in (issue #5028):
/// 400 wide, 200 tall, y down, the diver prone and facing left, back up, in
/// the straight pose, seen from their left side. One unit of the body
/// model's height is [kTrimUnitsPerHeight], so the art fits every diver.
const double kTrimWidth = 400;
const double kTrimHeight = 200;

/// Where the crown sits and the line the body lies along.
const double kTrimCrownX = 20;
const double kTrimAxisY = 100;
const double kTrimUnitsPerHeight = 272;

/// Joint pivots in the straight pose, as the body model places them.
const Offset kTrimShoulder = Offset(
  kTrimCrownX + 0.182 * kTrimUnitsPerHeight,
  kTrimAxisY,
);
const Offset kTrimKnee = Offset(
  kTrimCrownX + 0.715 * kTrimUnitsPerHeight,
  kTrimAxisY,
);
const Offset kTrimAnkle = Offset(
  kTrimCrownX + 0.961 * kTrimUnitsPerHeight,
  kTrimAxisY,
);

/// [point] on [body] in side space.
Offset trimSpaceOf(TrimPoint point, TrimBody body) => Offset(
  kTrimCrownX + kTrimUnitsPerHeight * point.s / body.heightM,
  kTrimAxisY - kTrimUnitsPerHeight * point.z / body.heightM,
);
