import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/data/services/libdc_sample_units.dart';

/// libdivecomputer's DC_SAMPLE_RBT is minutes (Shearwater GTR byte, Uwatec
/// RBT, Suunto EON gastime / 60); the app stores remaining bottom time in
/// seconds like every other duration on a profile point.
void main() {
  test('converts libdc RBT minutes to seconds', () {
    expect(libdcRbtToSeconds(25), 1500);
    expect(libdcRbtToSeconds(0), 0);
  });

  test('keeps an absent reading absent', () {
    expect(libdcRbtToSeconds(null), isNull);
  });
}
