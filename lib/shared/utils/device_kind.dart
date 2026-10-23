import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The word a title uses for the device it runs on ("Set up this phone").
/// A laptop cannot be told apart from a desktop, so both are a computer.
enum DeviceKind { phone, tablet, computer, other }

/// The shortest side, in logical pixels, from which a phone platform's
/// screen reads as a tablet.
const double _tabletShortestSide = 600;

DeviceKind deviceKindOf(BuildContext context) {
  if (kIsWeb) return DeviceKind.other;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS =>
      MediaQuery.sizeOf(context).shortestSide >= _tabletShortestSide
          ? DeviceKind.tablet
          : DeviceKind.phone,
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => DeviceKind.computer,
    TargetPlatform.fuchsia => DeviceKind.other,
  };
}

/// The value an ARB `select` on the device word takes.
String deviceKindArg(DeviceKind kind) => kind.name;
