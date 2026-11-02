/// The application log file: written by [LoggerService], read by the debug
/// log viewer, shared from the diagnostics card.
///
/// Native builds append to `<logDirectory>/submersion.log` and rotate it
/// (`log_file_service_io.dart`). The browser has no file to append to, so
/// the web variant keeps the most recent lines in memory with the same
/// rotation rule.
library;

export 'package:submersion/core/services/log_file_service_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/services/log_file_service_web.dart';
