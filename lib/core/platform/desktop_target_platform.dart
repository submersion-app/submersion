import 'package:flutter/foundation.dart';

/// Whether [platform] is a desktop operating system: macOS, Windows or Linux.
///
/// Pass `defaultTargetPlatform` for the device the app runs on, or
/// `Theme.of(context).platform` where a theme may override it. On web the
/// platform follows the browser's operating system, so a desktop browser
/// counts as desktop here; callers that need a native desktop runtime (a
/// window to control, mounted volumes, file drops) also check for web.
///
/// The switch is exhaustive on purpose: a new [TargetPlatform] fails analysis
/// here instead of silently landing on one side.
bool isDesktopTargetPlatform(TargetPlatform platform) => switch (platform) {
  TargetPlatform.macOS ||
  TargetPlatform.windows ||
  TargetPlatform.linux => true,
  TargetPlatform.android ||
  TargetPlatform.iOS ||
  TargetPlatform.fuchsia => false,
};
