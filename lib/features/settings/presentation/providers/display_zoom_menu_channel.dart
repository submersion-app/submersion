import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';

const _channel = MethodChannel('app.submersion/display');

/// Registers a method channel handler so the macOS View menu can drive the
/// app-wide display zoom.
void registerDisplayZoomMenuChannel(WidgetRef ref) {
  _channel.setMethodCallHandler((call) async {
    final notifier = ref.read(displayZoomNotifierProvider.notifier);
    switch (call.method) {
      case 'zoomIn':
        await notifier.stepBy(1);
      case 'zoomOut':
        await notifier.stepBy(-1);
      case 'actualSize':
        await notifier.reset();
      default:
        // Fail loudly rather than no-op. This channel is driven by native menu
        // wiring, so an unknown method means a miswired selector or a renamed
        // method -- otherwise a menu item that silently does nothing. Paired
        // with the result handler in AppDelegate, which logs this back on the
        // native side where the miswiring actually happened.
        throw PlatformException(
          code: 'unimplemented',
          message: 'No display zoom method named "${call.method}"',
        );
    }
  });
}
