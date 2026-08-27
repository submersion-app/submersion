import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keyboard bindings for app-wide display zoom.
///
/// Takes callbacks rather than a notifier so this file stays free of feature
/// and Riverpod dependencies.
///
/// On macOS these bindings are normally never reached: once the View menu
/// items carry key equivalents, AppKit consumes the chords before the Flutter
/// engine sees them. They remain registered as the Windows and Linux path.
Map<ShortcutActivator, VoidCallback> displayZoomShortcuts({
  required VoidCallback onZoomIn,
  required VoidCallback onZoomOut,
  required VoidCallback onReset,
  required bool useMetaModifier,
}) {
  SingleActivator activator(LogicalKeyboardKey key) =>
      SingleActivator(key, meta: useMetaModifier, control: !useMetaModifier);

  return {
    // "equal" is the unshifted key users actually press for zoom in.
    activator(LogicalKeyboardKey.equal): onZoomIn,
    activator(LogicalKeyboardKey.numpadAdd): onZoomIn,
    activator(LogicalKeyboardKey.minus): onZoomOut,
    activator(LogicalKeyboardKey.numpadSubtract): onZoomOut,
    activator(LogicalKeyboardKey.digit0): onReset,
  };
}
