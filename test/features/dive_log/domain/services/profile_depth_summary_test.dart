import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_summary.dart';

void main() {
  DiveProfilePoint at(int timestamp, double depth) =>
      DiveProfilePoint(timestamp: timestamp, depth: depth);

  test('takes the deepest reading and the mean of the readings', () {
    final summary = profileDepthSummary([
      at(0, 0),
      at(60, 20),
      at(120, 20),
      at(180, 0),
    ]);

    expect(summary, (maxDepth: 20.0, avgDepth: 10.0));
  });

  test('has nothing to say about no readings', () {
    expect(profileDepthSummary(const []), isNull);
  });
}
