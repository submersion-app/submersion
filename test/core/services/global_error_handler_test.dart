import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/global_error_handler.dart';
import 'package:submersion/core/services/logger_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // installGlobalErrorHandlers() mutates process-global handlers; snapshot and
  // restore both so a test cannot leak state into the next one.
  FlutterExceptionHandler? originalFlutterOnError;
  bool Function(Object, StackTrace)? originalPlatformOnError;

  setUp(() {
    originalFlutterOnError = FlutterError.onError;
    originalPlatformOnError = PlatformDispatcher.instance.onError;
    // Make the chained-to Flutter handler a benign no-op so firing a synthetic
    // error does not reach the test framework's handler and fail the test.
    FlutterError.onError = (_) {};
  });

  tearDown(() {
    FlutterError.onError = originalFlutterOnError;
    PlatformDispatcher.instance.onError = originalPlatformOnError;
  });

  test('routes uncaught Flutter framework errors to the logger', () async {
    installGlobalErrorHandlers();

    final captured = <LogEntry>[];
    final sub = LoggerService.logStream.listen(captured.add);
    addTearDown(sub.cancel);

    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError('boom-flutter'),
        stack: StackTrace.current,
      ),
    );

    await pumpEventQueue();

    expect(
      captured.where(
        (e) => e.level == LogLevel.error && e.message.contains('boom-flutter'),
      ),
      isNotEmpty,
      reason: 'a FlutterError should be logged at error level',
    );
  });

  test('routes uncaught platform errors to the logger and lets the platform '
      'keep handling them', () async {
    // With no prior handler, the new handler falls back to returning false.
    PlatformDispatcher.instance.onError = null;
    installGlobalErrorHandlers();

    final captured = <LogEntry>[];
    final sub = LoggerService.logStream.listen(captured.add);
    addTearDown(sub.cancel);

    final handled = PlatformDispatcher.instance.onError!(
      StateError('boom-platform'),
      StackTrace.current,
    );

    await pumpEventQueue();

    // Returning false means "not fully handled" so the platform still applies
    // its default behavior (e.g. printing to the console / logcat).
    expect(handled, isFalse);
    expect(
      captured.where(
        (e) => e.level == LogLevel.error && e.message.contains('boom-platform'),
      ),
      isNotEmpty,
      reason: 'an uncaught platform error should be logged at error level',
    );
  });

  test('platform error handler delegates to a previously-installed handler '
      'instead of silently replacing it', () async {
    var delegated = false;
    PlatformDispatcher.instance.onError = (error, stack) {
      delegated = true;
      return true; // pretend a crash reporter fully handled it
    };
    installGlobalErrorHandlers();

    final handled = PlatformDispatcher.instance.onError!(
      StateError('boom-chain'),
      StackTrace.current,
    );

    expect(delegated, isTrue, reason: 'the previous handler should still run');
    expect(
      handled,
      isTrue,
      reason: "the previous handler's result should be propagated",
    );
  });

  test('logUncaughtZoneError logs the error at error level', () async {
    final captured = <LogEntry>[];
    final sub = LoggerService.logStream.listen(captured.add);
    addTearDown(sub.cancel);

    logUncaughtZoneError(StateError('boom-zone'), StackTrace.current);

    await pumpEventQueue();

    expect(
      captured.where(
        (e) => e.level == LogLevel.error && e.message.contains('boom-zone'),
      ),
      isNotEmpty,
      reason: 'an uncaught zone error should be logged at error level',
    );
  });
}
