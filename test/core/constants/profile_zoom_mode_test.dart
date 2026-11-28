import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_zoom_mode.dart';

/// The profile chart's Zoom choice (issue #5069): two stored flags read as
/// one of three modes.
void main() {
  test('Time only wins over the viewport flag', () {
    expect(
      ProfileZoomMode.fromFlags(timeOnly: true, followViewport: true),
      ProfileZoomMode.timeOnly,
    );
    expect(
      ProfileZoomMode.fromFlags(timeOnly: true, followViewport: false),
      ProfileZoomMode.timeOnly,
    );
  });

  test('the viewport flag alone keeps overlays in view', () {
    expect(
      ProfileZoomMode.fromFlags(timeOnly: false, followViewport: true),
      ProfileZoomMode.keepOverlaysInView,
    );
  });

  test('neither flag magnifies overlays, the default', () {
    expect(
      ProfileZoomMode.fromFlags(timeOnly: false, followViewport: false),
      ProfileZoomMode.magnifyOverlays,
    );
  });
}
