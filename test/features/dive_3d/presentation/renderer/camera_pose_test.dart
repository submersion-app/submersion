import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/camera_pose.dart';

void main() {
  test('presets carry the spec poses', () {
    (double, double) of(CameraPose p) => (p.yawDegrees, p.pitchDegrees);
    expect(of(CameraPose.defaultView), (-32.0, 22.0));
    expect(of(CameraPose.front), (0.0, 0.0));
    expect(of(CameraPose.side), (90.0, 0.0));
    expect(of(CameraPose.top), (0.0, 90.0));
  });
}
