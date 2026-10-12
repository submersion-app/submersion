import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_row_labels.dart';

void main() {
  test('formatCompactDuration grows to days and years', () {
    expect(formatCompactDuration(const Duration(minutes: 47)), '47min');
    expect(
      formatCompactDuration(const Duration(hours: 3, minutes: 12)),
      '3h 12m',
    );
    // A long "Recorded time" total on the Tracks summary strip.
    expect(formatCompactDuration(const Duration(hours: 50)), '2d 2h');
    expect(formatCompactDuration(const Duration(days: 400)), '1y 35d');
  });
}
