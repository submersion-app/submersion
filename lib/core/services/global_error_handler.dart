import 'package:flutter/foundation.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';

const _logger = LoggerService('UncaughtError');

/// Installs process-wide handlers that route otherwise-silent Dart errors into
/// [LoggerService] (and thus into `submersion.log` when debug mode is on),
/// while preserving each framework's default behavior.
///
/// Before this, the app installed no global handlers, so an uncaught Flutter
/// framework error or async error never reached the on-device debug log -- a
/// key reason issue #318 took so long to diagnose remotely.
///
/// Important: a native-level crash (for example a JNI `UnsatisfiedLinkError`
/// from a misaligned `.so` on a 16 KB-page device) is not a Dart error and
/// cannot be caught here. That failure mode is surfaced on the platform side
/// (the Kotlin/Swift dive-computer bridges report it instead of crashing).
void installGlobalErrorHandlers() {
  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    _logger.error(
      'Uncaught Flutter framework error',
      category: LogCategory.app,
      error: details.exception,
      stackTrace: details.stack,
    );
    // Preserve the default presentation (red error screen in debug builds,
    // console/logcat dump otherwise). Falls back to FlutterError.presentError
    // when no prior handler was installed.
    (previousFlutterOnError ?? FlutterError.presentError)(details);
  };

  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _logger.error(
      'Uncaught platform error',
      category: LogCategory.app,
      error: error,
      stackTrace: stack,
    );
    // Delegate to any previously-installed handler (e.g. a crash reporter)
    // instead of silently replacing it; fall back to false so the platform
    // still applies its default behavior (printing to the console / logcat).
    return previousPlatformOnError?.call(error, stack) ?? false;
  };
}

/// Logs an uncaught error escaping the top-level guarded zone (see `main`).
///
/// Extracted so the logging behavior is unit-testable; `main`'s
/// `runZonedGuarded` wiring itself is untestable startup glue.
void logUncaughtZoneError(Object error, StackTrace stack) {
  _logger.error(
    'Uncaught zone error',
    category: LogCategory.app,
    error: error,
    stackTrace: stack,
  );
}
