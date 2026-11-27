import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/feature_flags.dart';

/// Turns marine life identification off for each test of a file that shows
/// photos or the photo viewer but is not about identification.
///
/// It is on for Android, the test platform, but such a file never sets it
/// up. The viewer's species layer is tested with it on in
/// media_viewer_photo_labels_test.dart, media_viewer_video_playhead_test.dart
/// and test/features/species_id/. The viewer's species tag control does not
/// read the flag, so tagging tests run the same either way.
///
/// Call it at the top of `main()`.
void turnOffMarineLifeIdForEachTest() {
  setUp(() {
    marineLifeIdEnabled = false;
    addTearDown(resetMarineLifeIdEnabled);
  });
}
