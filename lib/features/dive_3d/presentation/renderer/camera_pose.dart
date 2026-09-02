/// Camera presets for the path scene. Front looks along +Z (depth vs
/// time), side along -X (depth vs metric), top straight down (metric vs
/// time): each turns one wall shadow into a front-on 2D chart.
enum CameraPose {
  defaultView(-32, 22),
  front(0, 0),
  side(90, 0),
  top(0, 90);

  final double yawDegrees;
  final double pitchDegrees;
  const CameraPose(this.yawDegrees, this.pitchDegrees);
}
