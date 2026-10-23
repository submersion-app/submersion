import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/core/services/window_fullscreen.dart';

/// The word a title uses for the device it runs on ("Set up this phone").
/// A laptop cannot be told apart from a desktop, so both are a computer.
enum DeviceKind { phone, tablet, computer, other }

/// The shortest side, in logical pixels, from which a phone platform's
/// screen is a tablet.
const double kTabletShortestSide = 600;

/// The device, not the window: a tablet in Slide Over or a narrow split is
/// still a tablet, and the word does not change while a window is resized.
DeviceKind deviceKindOf(BuildContext context) {
  if (hasDesktopWindow()) return DeviceKind.computer;
  if (kIsWeb) return DeviceKind.other;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS =>
      _displayShortestSide(context) >= kTabletShortestSide
          ? DeviceKind.tablet
          : DeviceKind.phone,
    _ => DeviceKind.other,
  };
}

/// The display's shortest side in logical pixels, or the window's where the
/// display is unknown.
double _displayShortestSide(BuildContext context) {
  final display = View.maybeOf(context)?.display;
  if (display == null || display.devicePixelRatio == 0) {
    return MediaQuery.sizeOf(context).shortestSide;
  }
  return (display.size / display.devicePixelRatio).shortestSide;
}

/// The value an ARB `select` on the device word takes.
String deviceKindArg(DeviceKind kind) => kind.name;
