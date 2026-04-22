import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/database_version_exception.dart';
import 'package:submersion/core/domain/entities/migration_progress.dart';
import 'package:submersion/core/presentation/pages/startup_page.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/pre_migration_backup_service.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A fake [DatabaseLocationService] that returns a fixed path.
class _FakeLocationService extends DatabaseLocationService {
  final String _path;
  _FakeLocationService(super.prefs) : _path = '/tmp/test.db';

  @override
  Future<String> getDatabasePath() async => _path;
}

/// A fake [DatabaseLocationService] that returns a caller-provided path.
/// Used by recovery tests so each test has its own isolated db file path —
/// necessary because the recovery flow actually invokes sqlite3 against the
/// path (unlike most lifecycle tests where the path is never touched).
class _CustomPathLocationService extends DatabaseLocationService {
  final String _path;
  _CustomPathLocationService(super.prefs, this._path);

  @override
  Future<String> getDatabasePath() async => _path;
}

/// A fake [DatabaseLocationService] that succeeds for the first [failAfter]
/// calls, then throws on every call thereafter. Used to drive the
/// `_runRecovery` catch block (which only fires when a non-SqliteException
/// escapes) without corrupting a real SQLite file.
class _FlakyLocationService extends DatabaseLocationService {
  final String path;
  final int failAfter;
  int calls = 0;

  _FlakyLocationService(
    super.prefs, {
    required this.path,
    required this.failAfter,
  });

  @override
  Future<String> getDatabasePath() async {
    calls++;
    if (calls > failAfter) {
      throw StateError('simulated location failure');
    }
    return path;
  }
}

/// A synchronous no-op subclass of [PreMigrationBackupService] for tests that
/// exercise the migration path without wanting real file I/O.
class _NoOpBackupService extends PreMigrationBackupService {
  _NoOpBackupService({required super.preferences})
    : super(
        livePathProvider: () async => '/tmp/test.db',
        backupsDirProvider: () async => '/tmp/test-backups',
      );

  @override
  Future<void> backupIfMigrationPending({
    required int stored,
    required int target,
    required String appVersion,
  }) async {
    // Intentional no-op: skip all file I/O in widget tests.
  }
}

/// Factory for the no-op backup service used by tests that exercise the
/// migration path but do not want to test backup behaviour.
PreMigrationBackupService _noOpBackupFactory({
  required String livePath,
  required BackupPreferences preferences,
}) {
  return _NoOpBackupService(preferences: preferences);
}

/// Builds a [StartupWrapper] for widget testing with injectable overrides.
Widget _buildStartupWrapper({
  required SharedPreferences prefs,
  required LogFileService logFileService,
  required DatabaseLocationService locationService,
  ServiceInitializer? initializerOverride,
  SchemaVersionProbe? schemaVersionProbeOverride,
  VoidCallback? closeAppOverride,
  PreMigrationBackupService Function({
    required String livePath,
    required BackupPreferences preferences,
  })?
  preMigrationBackupFactory,
}) {
  return StartupWrapper(
    prefs: prefs,
    logFileService: logFileService,
    locationService: locationService,
    initializerOverride: initializerOverride,
    schemaVersionProbeOverride: schemaVersionProbeOverride,
    closeAppOverride: closeAppOverride,
    preMigrationBackupFactory: preMigrationBackupFactory,
  );
}

// ---------------------------------------------------------------------------
// Reusable builders that mirror the actual StartupWrapper build logic
// for each state, allowing isolated widget testing without needing to
// instantiate the full StartupWrapper (which requires DatabaseService etc.).
// ---------------------------------------------------------------------------

Widget _buildSplashContent({
  bool isMigrating = false,
  MigrationProgress progress = const MigrationProgress(
    currentStep: 0,
    totalSteps: 0,
  ),
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Submersion',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 240,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: isMigrating
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LinearProgressIndicator(
                              value: progress.fraction,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Upgrading database... '
                              'step ${progress.currentStep} of ${progress.totalSteps}',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildVersionMismatchError({
  required int dbVersion,
  required int appVersion,
  VoidCallback? onClose,
}) {
  const textColor = Colors.black87;
  const subtitleColor = Colors.black54;

  return MaterialApp(
    home: Scaffold(
      key: const ValueKey('error'),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.update, size: 64, color: Colors.orange),
                const SizedBox(height: 24),
                const Text(
                  'Update Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your dive data was saved by a newer version of '
                  'Submersion (schema v$dbVersion). This version '
                  'only supports up to schema v$appVersion.',
                  style: const TextStyle(fontSize: 14, color: subtitleColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please update Submersion to the latest version. '
                  'Your data is safe and has not been modified.',
                  style: TextStyle(fontSize: 14, color: subtitleColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onClose ?? () {},
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildGenericError({
  required String errorMessage,
  VoidCallback? onClose,
}) {
  const textColor = Colors.black87;
  const subtitleColor = Colors.black54;

  return MaterialApp(
    home: Scaffold(
      key: const ValueKey('error'),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'Database upgrade failed',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: const TextStyle(fontSize: 14, color: subtitleColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Try restarting the app. If this persists, '
                  'reinstall or contact support.',
                  style: TextStyle(fontSize: 14, color: subtitleColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onClose ?? () {},
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // ===========================================================================
  // Isolated UI builder tests (no real services needed)
  // ===========================================================================

  group('Splash UI - initializing state', () {
    testWidgets('shows Submersion text and no progress bar', (tester) async {
      await tester.pumpWidget(_buildSplashContent());
      await tester.pumpAndSettle();

      expect(find.text('Submersion'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows SizedBox.shrink when not migrating', (tester) async {
      await tester.pumpWidget(_buildSplashContent(isMigrating: false));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('Upgrading'), findsNothing);
    });
  });

  group('Splash UI - migrating state', () {
    testWidgets('shows progress bar with step text', (tester) async {
      const progress = MigrationProgress(currentStep: 3, totalSteps: 7);

      await tester.pumpWidget(
        _buildSplashContent(isMigrating: true, progress: progress),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Upgrading database... step 3 of 7'), findsOneWidget);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.4286, 0.001));
    });

    testWidgets('shows progress at 0 of N at start of migration', (
      tester,
    ) async {
      const progress = MigrationProgress(currentStep: 0, totalSteps: 5);

      await tester.pumpWidget(
        _buildSplashContent(isMigrating: true, progress: progress),
      );
      await tester.pumpAndSettle();

      expect(find.text('Upgrading database... step 0 of 5'), findsOneWidget);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.0);
    });

    testWidgets('shows complete progress at N of N', (tester) async {
      const progress = MigrationProgress(currentStep: 5, totalSteps: 5);

      await tester.pumpWidget(
        _buildSplashContent(isMigrating: true, progress: progress),
      );
      await tester.pumpAndSettle();

      expect(find.text('Upgrading database... step 5 of 5'), findsOneWidget);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 1.0);
    });
  });

  group('Error UI - version mismatch', () {
    testWidgets('shows update required with version numbers', (tester) async {
      await tester.pumpWidget(
        _buildVersionMismatchError(dbVersion: 99, appVersion: 63),
      );
      await tester.pumpAndSettle();

      expect(find.text('Update Required'), findsOneWidget);
      expect(find.byIcon(Icons.update), findsOneWidget);
      expect(find.textContaining('schema v99'), findsOneWidget);
      expect(find.textContaining('schema v63'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('shows safe data message', (tester) async {
      await tester.pumpWidget(
        _buildVersionMismatchError(dbVersion: 70, appVersion: 63),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Your data is safe and has not been modified'),
        findsOneWidget,
      );
    });

    testWidgets('close button is tappable', (tester) async {
      var closeCalled = false;
      await tester.pumpWidget(
        _buildVersionMismatchError(
          dbVersion: 99,
          appVersion: 63,
          onClose: () => closeCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close'));
      expect(closeCalled, isTrue);
    });

    testWidgets('uses correct scaffold key', (tester) async {
      await tester.pumpWidget(
        _buildVersionMismatchError(dbVersion: 99, appVersion: 63),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('error')), findsOneWidget);
    });
  });

  group('Error UI - generic error', () {
    testWidgets('shows error message and icon', (tester) async {
      await tester.pumpWidget(
        _buildGenericError(errorMessage: 'Migration step 42 failed'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Database upgrade failed'), findsOneWidget);
      expect(find.text('Migration step 42 failed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows restart guidance', (tester) async {
      await tester.pumpWidget(_buildGenericError(errorMessage: 'Some error'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Try restarting the app'), findsOneWidget);
    });

    testWidgets('close button is tappable', (tester) async {
      var closeCalled = false;
      await tester.pumpWidget(
        _buildGenericError(
          errorMessage: 'Error',
          onClose: () => closeCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close'));
      expect(closeCalled, isTrue);
    });

    testWidgets('uses correct scaffold key', (tester) async {
      await tester.pumpWidget(_buildGenericError(errorMessage: 'Error'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('error')), findsOneWidget);
    });

    testWidgets('shows empty error message', (tester) async {
      await tester.pumpWidget(_buildGenericError(errorMessage: ''));
      await tester.pumpAndSettle();

      expect(find.text('Database upgrade failed'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });
  });

  group('MigrationProgress in UI', () {
    testWidgets('progress bar updates with new values', (tester) async {
      final progressNotifier = ValueNotifier<MigrationProgress>(
        const MigrationProgress(currentStep: 1, totalSteps: 5),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<MigrationProgress>(
              valueListenable: progressNotifier,
              builder: (context, progress, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: progress.fraction),
                    Text(
                      'step ${progress.currentStep} of ${progress.totalSteps}',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('step 1 of 5'), findsOneWidget);
      var indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.2, 0.001));

      progressNotifier.value = const MigrationProgress(
        currentStep: 4,
        totalSteps: 5,
      );
      await tester.pump();

      expect(find.text('step 4 of 5'), findsOneWidget);
      indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.8, 0.001));
    });

    testWidgets('handles zero total steps gracefully', (tester) async {
      const progress = MigrationProgress(currentStep: 0, totalSteps: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinearProgressIndicator(value: progress.fraction),
          ),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.0);
    });
  });

  // ===========================================================================
  // StartupWrapper lifecycle tests (using injectable overrides)
  //
  // NOTE: Tests that let initialization *succeed* would cause the widget to
  // render SubmersionRestart (the full app with router, database, etc.),
  // which cannot be rendered in unit tests. Instead, we keep the initializer
  // pending via a Completer that is never completed for splash/migration
  // tests, and only let the initializer throw for error tests.
  //
  // The splash screen renders Image.asset('assets/icon/icon.png'), which is
  // available only through the real asset bundle. We suppress image-loading
  // errors to avoid test failures from missing image decode support.
  // ===========================================================================

  group('StartupWrapper lifecycle', () {
    late SharedPreferences prefs;
    late LogFileService logFileService;
    late DatabaseLocationService locationService;
    void Function(FlutterErrorDetails)? originalOnError;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      logFileService = LogFileService(logDirectory: '/tmp/test-logs');
      locationService = _FakeLocationService(prefs);
      // Suppress image-loading errors from Image.asset in the splash screen.
      // The splash screen uses Image.asset('assets/icon/icon.png') which
      // the test framework cannot decode, but this does not affect the test
      // assertions (the widget tree still builds correctly).
      originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final message = details.toString();
        if (message.contains('IMAGE RESOURCE SERVICE') ||
            message.contains('resolving an image') ||
            message.contains('Message corrupted')) {
          return; // Suppress image errors
        }
        originalOnError?.call(details);
      };
    });

    tearDown(() {
      FlutterError.onError = originalOnError;
    });

    testWidgets('shows splash screen during initialization', (tester) async {
      // Keep the initializer pending so we stay on the splash screen
      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) => Completer<void>().future,
        ),
      );

      await tester.pump();

      // Should show splash with Submersion text
      expect(find.text('Submersion'), findsOneWidget);
      expect(find.byKey(const ValueKey('splash')), findsOneWidget);
      expect(find.byKey(const ValueKey('error')), findsNothing);
      // No migration progress shown
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('Upgrading'), findsNothing);

      // Drain the 1-second splash delay timer to avoid pending timer errors
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('shows migration progress when migration is needed', (
      tester,
    ) async {
      late void Function(int, int) capturedCallback;

      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: true, totalSteps: 5),
          preMigrationBackupFactory: _noOpBackupFactory,
          initializerOverride: (onProgress) {
            capturedCallback = onProgress;
            // Never completes -- we stay on the migration screen
            return Completer<void>().future;
          },
        ),
      );

      // Pump through the backup step (synchronous no-op factory) then into
      // migrating state.
      await tester.pump();
      await tester.pump();

      // Verify migration UI is shown
      expect(find.textContaining('Upgrading database'), findsOneWidget);
      expect(find.text('Upgrading database... step 0 of 5'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byKey(const ValueKey('splash')), findsOneWidget);

      // Simulate migration progress
      capturedCallback(3, 5);
      await tester.pump();

      expect(find.text('Upgrading database... step 3 of 5'), findsOneWidget);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.6, 0.001));

      // Drain the 1-second splash delay timer
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('shows version mismatch error on DatabaseVersionMismatch', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) async {
            throw const DatabaseVersionMismatchException(
              databaseVersion: 99,
              appVersion: 63,
            );
          },
        ),
      );

      // Let the initialization error propagate
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Should show version mismatch error UI
      expect(find.text('Update Required'), findsOneWidget);
      expect(find.byIcon(Icons.update), findsOneWidget);
      expect(find.textContaining('schema v99'), findsOneWidget);
      expect(find.textContaining('schema v63'), findsOneWidget);
      expect(find.byKey(const ValueKey('error')), findsOneWidget);
    });

    testWidgets('shows generic error on initialization failure', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) async {
            throw Exception('Disk is full');
          },
        ),
      );

      // Let the initialization error propagate
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Should show generic error UI
      expect(find.text('Database upgrade failed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('Disk is full'), findsOneWidget);
      expect(find.byKey(const ValueKey('error')), findsOneWidget);
    });

    testWidgets('close button on error screen invokes closeAppOverride', (
      tester,
    ) async {
      var closeCalled = false;

      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) async {
            throw Exception('Something broke');
          },
          closeAppOverride: () => closeCalled = true,
        ),
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Tap the Close button
      await tester.tap(find.text('Close'));
      await tester.pump();

      expect(closeCalled, isTrue);
    });

    testWidgets(
      'close button on version mismatch screen invokes closeAppOverride',
      (tester) async {
        var closeCalled = false;

        await tester.pumpWidget(
          _buildStartupWrapper(
            prefs: prefs,
            logFileService: logFileService,
            locationService: locationService,
            schemaVersionProbeOverride: (_) =>
                (needsMigration: false, totalSteps: 0),
            initializerOverride: (_) async {
              throw const DatabaseVersionMismatchException(
                databaseVersion: 70,
                appVersion: 63,
              );
            },
            closeAppOverride: () => closeCalled = true,
          ),
        );

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Close'));
        await tester.pump();

        expect(closeCalled, isTrue);
      },
    );

    testWidgets('no migration progress shown when probe says not needed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) => Completer<void>().future,
        ),
      );

      await tester.pump();
      expect(find.text('Submersion'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('Upgrading'), findsNothing);

      // Drain the 1-second splash delay timer
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('migration progress callbacks update UI in real time', (
      tester,
    ) async {
      late void Function(int, int) progressCallback;

      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: true, totalSteps: 10),
          preMigrationBackupFactory: _noOpBackupFactory,
          initializerOverride: (onProgress) {
            progressCallback = onProgress;
            return Completer<void>().future;
          },
        ),
      );

      // Pump through the backup step (synchronous no-op factory) then into
      // migrating state.
      await tester.pump();
      await tester.pump();

      // Initial: step 0 of 10
      expect(find.text('Upgrading database... step 0 of 10'), findsOneWidget);

      // Simulate progress steps
      progressCallback(1, 10);
      await tester.pump();
      expect(find.text('Upgrading database... step 1 of 10'), findsOneWidget);

      progressCallback(5, 10);
      await tester.pump();
      expect(find.text('Upgrading database... step 5 of 10'), findsOneWidget);

      progressCallback(10, 10);
      await tester.pump();
      expect(find.text('Upgrading database... step 10 of 10'), findsOneWidget);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 1.0);

      // Drain the 1-second splash delay timer
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('splash scaffold key is used during init', (tester) async {
      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) => Completer<void>().future,
        ),
      );

      await tester.pump();

      expect(find.byKey(const ValueKey('splash')), findsOneWidget);
      expect(find.byKey(const ValueKey('error')), findsNothing);

      // Drain the 1-second splash delay timer
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('splash scaffold key is also used during migration', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: true, totalSteps: 3),
          preMigrationBackupFactory: _noOpBackupFactory,
          initializerOverride: (_) => Completer<void>().future,
        ),
      );

      await tester.pump();

      expect(find.byKey(const ValueKey('splash')), findsOneWidget);

      // Drain the 1-second splash delay timer
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('error state renders error scaffold key', (tester) async {
      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) async {
            throw Exception('Test error');
          },
        ),
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('error')), findsOneWidget);
      expect(find.byKey(const ValueKey('splash')), findsNothing);
    });

    testWidgets('generic error shows error message text', (tester) async {
      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) async {
            throw Exception('Corrupt database header');
          },
        ),
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.textContaining('Corrupt database header'), findsOneWidget);
      expect(find.textContaining('Try restarting the app'), findsOneWidget);
    });

    testWidgets('version mismatch error shows correct version numbers', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) async {
            throw const DatabaseVersionMismatchException(
              databaseVersion: 100,
              appVersion: 50,
            );
          },
        ),
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.textContaining('schema v100'), findsOneWidget);
      expect(find.textContaining('schema v50'), findsOneWidget);
      expect(find.textContaining('Your data is safe'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Pre-migration backup flow transitions
  // ---------------------------------------------------------------------------
  group('pre-migration backup flow', () {
    late SharedPreferences prefs;
    late LogFileService logFileService;
    late DatabaseLocationService locationService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      logFileService = LogFileService(logDirectory: '/tmp/test-logs');
      locationService = _FakeLocationService(prefs);
    });

    testWidgets(
      'BackupFailedException transitions to backupFailed with classified message',
      (tester) async {
        PreMigrationBackupService failingFactory({
          required String livePath,
          required BackupPreferences preferences,
        }) {
          return _ThrowingBackupService(
            preferences: preferences,
            error: const BackupFailedException(
              cause: BackupFailureCause.diskFull,
              userMessage: 'Not enough free disk space to back up your data.',
              technicalDetails: 'FileSystemException(28)',
            ),
          );
        }

        await tester.pumpWidget(
          _buildStartupWrapper(
            prefs: prefs,
            logFileService: logFileService,
            locationService: locationService,
            schemaVersionProbeOverride: (_) =>
                (needsMigration: true, totalSteps: 5),
            preMigrationBackupFactory: failingFactory,
            initializerOverride: (_) async {
              // Should never be called: backup failure blocks migration.
              throw StateError('initializer must not run on backup failure');
            },
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('error')), findsOneWidget);
        expect(find.text("Couldn't back up your data"), findsOneWidget);
        expect(
          find.text('Not enough free disk space to back up your data.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Quit'), findsOneWidget);
      },
    );

    testWidgets(
      'Retry after backup failure recovers when second attempt succeeds',
      (tester) async {
        var attempt = 0;
        PreMigrationBackupService flakyFactory({
          required String livePath,
          required BackupPreferences preferences,
        }) {
          attempt += 1;
          if (attempt == 1) {
            return _ThrowingBackupService(
              preferences: preferences,
              error: const BackupFailedException(
                cause: BackupFailureCause.unknown,
                userMessage: 'Temporary backup failure.',
                technicalDetails: 'flaky',
              ),
            );
          }
          return _NoOpBackupService(preferences: preferences);
        }

        await tester.pumpWidget(
          _buildStartupWrapper(
            prefs: prefs,
            logFileService: logFileService,
            locationService: locationService,
            schemaVersionProbeOverride: (_) =>
                (needsMigration: true, totalSteps: 3),
            preMigrationBackupFactory: flakyFactory,
            // Never completes so retry path stops at the "migrating" state,
            // avoiding go_router redirect that would need DatabaseService.
            initializerOverride: (_) => Completer<void>().future,
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text("Couldn't back up your data"), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
        await tester.pump();
        await tester.pump();

        expect(attempt, 2);
        // Recovery: the error scaffold is gone; the progress UI took its place.
        expect(find.byKey(const ValueKey('error')), findsNothing);
        expect(find.text("Couldn't back up your data"), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        // Drain any pending timers from the retry path.
        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets(
      'Retry that fails again with BackupFailedException stays on backupFailed',
      (tester) async {
        var attempt = 0;
        PreMigrationBackupService alwaysFailingFactory({
          required String livePath,
          required BackupPreferences preferences,
        }) {
          attempt += 1;
          return _ThrowingBackupService(
            preferences: preferences,
            error: BackupFailedException(
              cause: BackupFailureCause.permissionDenied,
              userMessage: 'Attempt $attempt failed.',
              technicalDetails: 'EACCES',
            ),
          );
        }

        await tester.pumpWidget(
          _buildStartupWrapper(
            prefs: prefs,
            logFileService: logFileService,
            locationService: locationService,
            schemaVersionProbeOverride: (_) =>
                (needsMigration: true, totalSteps: 1),
            preMigrationBackupFactory: alwaysFailingFactory,
            initializerOverride: (_) async {},
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('Attempt 1 failed.'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(attempt, 2);
        expect(find.text("Couldn't back up your data"), findsOneWidget);
        expect(find.text('Attempt 2 failed.'), findsOneWidget);
      },
    );

    testWidgets(
      'Retry that throws a non-BackupFailedException goes to generic error',
      (tester) async {
        var attempt = 0;
        PreMigrationBackupService factory({
          required String livePath,
          required BackupPreferences preferences,
        }) {
          attempt += 1;
          if (attempt == 1) {
            return _ThrowingBackupService(
              preferences: preferences,
              error: const BackupFailedException(
                cause: BackupFailureCause.unknown,
                userMessage: 'First failure.',
                technicalDetails: '',
              ),
            );
          }
          return _ThrowingBackupService(
            preferences: preferences,
            error: Exception('unexpected non-backup-failed'),
          );
        }

        await tester.pumpWidget(
          _buildStartupWrapper(
            prefs: prefs,
            logFileService: logFileService,
            locationService: locationService,
            schemaVersionProbeOverride: (_) =>
                (needsMigration: true, totalSteps: 1),
            preMigrationBackupFactory: factory,
            initializerOverride: (_) async {},
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(attempt, 2);
        expect(find.byKey(const ValueKey('error')), findsOneWidget);
        expect(
          find.textContaining('unexpected non-backup-failed'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Quit button on backupFailed invokes closeAppOverride', (
      tester,
    ) async {
      var quitCalled = 0;
      PreMigrationBackupService factory({
        required String livePath,
        required BackupPreferences preferences,
      }) {
        return _ThrowingBackupService(
          preferences: preferences,
          error: const BackupFailedException(
            cause: BackupFailureCause.diskFull,
            userMessage: 'Disk is full.',
            technicalDetails: '',
          ),
        );
      }

      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: true, totalSteps: 1),
          preMigrationBackupFactory: factory,
          initializerOverride: (_) async {},
          closeAppOverride: () => quitCalled++,
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Quit'));
      await tester.pump();

      expect(quitCalled, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // Hot-journal recovery flow
  //
  // Triggered when initialization raises a SqliteException in the
  // SQLITE_READONLY family (primary code 8) — typically code 776
  // (SQLITE_READONLY_ROLLBACK) left behind by a crashed or cancelled
  // transaction. Rather than parroting "reinstall or contact support", the
  // startup screen should offer a one-tap recovery path that reopens the
  // database RW so SQLite can finish the rollback.
  // ---------------------------------------------------------------------------
  group('recovery flow', () {
    late SharedPreferences prefs;
    late LogFileService logFileService;
    late DatabaseLocationService locationService;
    late Directory tempDir;
    void Function(FlutterErrorDetails)? originalOnError;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      logFileService = LogFileService(logDirectory: '/tmp/test-logs');
      tempDir = Directory.systemTemp.createTempSync('startup_recovery_test_');
      locationService = _CustomPathLocationService(
        prefs,
        p.join(tempDir.path, 'test.db'),
      );
      // Suppress splash Image.asset decode noise (same as the lifecycle group).
      originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final message = details.toString();
        if (message.contains('IMAGE RESOURCE SERVICE') ||
            message.contains('resolving an image') ||
            message.contains('Message corrupted')) {
          return;
        }
        originalOnError?.call(details);
      };
    });

    tearDown(() {
      FlutterError.onError = originalOnError;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets(
      'SqliteException code 776 routes to recovery UI, not generic error',
      (tester) async {
        await tester.pumpWidget(
          _buildStartupWrapper(
            prefs: prefs,
            logFileService: logFileService,
            locationService: locationService,
            schemaVersionProbeOverride: (_) =>
                (needsMigration: false, totalSteps: 0),
            initializerOverride: (_) async {
              throw sqlite3.SqliteException(
                776,
                'attempt to write a readonly database',
              );
            },
          ),
        );

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // Recovery UI, not "Database upgrade failed".
        expect(find.text('Database needs recovery'), findsOneWidget);
        expect(find.byIcon(Icons.build_circle_outlined), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Recover database'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextButton, 'Close without recovering'),
          findsOneWidget,
        );
        expect(find.text('Database upgrade failed'), findsNothing);
        expect(find.byKey(const ValueKey('error')), findsOneWidget);
      },
    );

    testWidgets(
      'recovery UI surfaces the SQLite extended result code for diagnostics',
      (tester) async {
        await tester.pumpWidget(
          _buildStartupWrapper(
            prefs: prefs,
            logFileService: logFileService,
            locationService: locationService,
            schemaVersionProbeOverride: (_) =>
                (needsMigration: false, totalSteps: 0),
            initializerOverride: (_) async {
              throw sqlite3.SqliteException(776, 'readonly');
            },
          ),
        );

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        expect(find.textContaining('SQLite code 776'), findsOneWidget);
      },
    );

    testWidgets(
      'non-readonly SqliteException (e.g. SQLITE_BUSY) still shows generic error',
      (tester) async {
        await tester.pumpWidget(
          _buildStartupWrapper(
            prefs: prefs,
            logFileService: logFileService,
            locationService: locationService,
            schemaVersionProbeOverride: (_) =>
                (needsMigration: false, totalSteps: 0),
            initializerOverride: (_) async {
              // SQLITE_BUSY — primary code 5; not in the READONLY family.
              throw sqlite3.SqliteException(5, 'database is locked');
            },
          ),
        );

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        expect(find.text('Database upgrade failed'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Database needs recovery'), findsNothing);
      },
    );

    testWidgets(
      'Close without recovering invokes closeAppOverride exactly once',
      (tester) async {
        var closeCalled = 0;
        await tester.pumpWidget(
          _buildStartupWrapper(
            prefs: prefs,
            logFileService: logFileService,
            locationService: locationService,
            schemaVersionProbeOverride: (_) =>
                (needsMigration: false, totalSteps: 0),
            initializerOverride: (_) async {
              throw sqlite3.SqliteException(776, 'readonly');
            },
            closeAppOverride: () => closeCalled++,
          ),
        );

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(TextButton, 'Close without recovering'),
        );
        await tester.pump();

        expect(closeCalled, 1);
      },
    );

    testWidgets(
      'recoverHotJournal returning false sets a specific error message on '
      'the recoveryFailed UI',
      (tester) async {
        // Write bytes that aren't a valid SQLite header at the db path.
        // sqlite3.open in readWrite mode will still create a handle, but the
        // subsequent PRAGMA user_version probe inside recoverHotJournal will
        // throw SQLITE_NOTADB — which recoverHotJournal catches and reports
        // as `false`, driving us into the `!recovered` branch of _runRecovery.
        final dbPath = p.join(tempDir.path, 'corrupt.db');
        File(dbPath).writeAsBytesSync(List<int>.filled(4096, 0xAB));
        locationService = _CustomPathLocationService(prefs, dbPath);

        await tester.pumpWidget(
          _buildStartupWrapper(
            prefs: prefs,
            logFileService: logFileService,
            locationService: locationService,
            schemaVersionProbeOverride: (_) =>
                (needsMigration: false, totalSteps: 0),
            initializerOverride: (_) async {
              throw sqlite3.SqliteException(776, 'readonly');
            },
          ),
        );

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('Database needs recovery'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Recover database'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Recovery did not complete'), findsOneWidget);
        // The specific message from the `!recovered` branch — NOT a stale
        // SqliteException message and NOT an exception `.toString()`.
        expect(
          find.textContaining('could not reopen the database'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'recovery catch block routes to recoveryFailed UI when getDatabasePath '
      'throws on the retry attempt',
      (tester) async {
        // First call → succeeds (lets the initializer throw 776 → recoveryRequired).
        // Second call (inside _runRecovery) → throws → the `catch` block in
        // _runRecovery fires, which is the only path that sets _errorMessage
        // alongside _state = recoveryFailed.
        final flaky = _FlakyLocationService(
          prefs,
          path: p.join(tempDir.path, 'test.db'),
          failAfter: 1,
        );
        await tester.pumpWidget(
          _buildStartupWrapper(
            prefs: prefs,
            logFileService: logFileService,
            locationService: flaky,
            schemaVersionProbeOverride: (_) =>
                (needsMigration: false, totalSteps: 0),
            initializerOverride: (_) async {
              throw sqlite3.SqliteException(776, 'readonly');
            },
          ),
        );

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // We should now be in recoveryRequired.
        expect(find.text('Database needs recovery'), findsOneWidget);

        // Tap Recover → _runRecovery calls getDatabasePath, which throws.
        await tester.tap(find.widgetWithText(FilledButton, 'Recover database'));
        await tester.pump();
        await tester.pump();

        // The recoveryFailed UI is rendered with the error message.
        expect(find.text('Recovery did not complete'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(
          find.textContaining('simulated location failure'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Try again'),
          findsOneWidget,
        );
        expect(find.widgetWithText(FilledButton, 'Close'), findsOneWidget);
      },
    );

    testWidgets('Try again on recoveryFailed UI re-invokes _runRecovery', (
      tester,
    ) async {
      final flaky = _FlakyLocationService(
        prefs,
        path: p.join(tempDir.path, 'test.db'),
        failAfter: 1,
      );
      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: flaky,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) async {
            throw sqlite3.SqliteException(776, 'readonly');
          },
        ),
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Drive into recoveryFailed.
      await tester.tap(find.widgetWithText(FilledButton, 'Recover database'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Recovery did not complete'), findsOneWidget);

      final callsBeforeRetry = flaky.calls;

      // Tap Try again — should run _runRecovery once more, which again
      // calls getDatabasePath (throws) and lands back on recoveryFailed.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
      await tester.pump();
      await tester.pump();

      // The location service was hit once more, confirming re-invocation.
      expect(flaky.calls, greaterThan(callsBeforeRetry));
      expect(find.text('Recovery did not complete'), findsOneWidget);
    });

    testWidgets('Close on recoveryFailed UI invokes closeAppOverride', (
      tester,
    ) async {
      var closeCalled = 0;
      final flaky = _FlakyLocationService(
        prefs,
        path: p.join(tempDir.path, 'test.db'),
        failAfter: 1,
      );
      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: flaky,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) async {
            throw sqlite3.SqliteException(776, 'readonly');
          },
          closeAppOverride: () => closeCalled++,
        ),
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Recover database'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Recovery did not complete'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pump();

      expect(closeCalled, 1);
    });

    testWidgets('tapping Recover database re-invokes the initializer and shows '
        'recovering state while the second attempt is pending', (tester) async {
      // First call throws the readonly-rollback exception that triggers
      // recovery. The second call (the one that recovery re-runs) never
      // completes, so the UI stays in the `recovering` state and we can
      // assert it. Letting the second call succeed would mount the full
      // app (which needs a real database) and fail the test harness.
      var calls = 0;
      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) async {
            calls++;
            if (calls == 1) {
              throw sqlite3.SqliteException(776, 'readonly');
            }
            await Completer<void>().future;
          },
        ),
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Database needs recovery'), findsOneWidget);
      expect(calls, 1);

      await tester.tap(find.widgetWithText(FilledButton, 'Recover database'));
      // Drive the recovery microtasks: setState(recovering),
      // getDatabasePath, recoverHotJournal (no-op for a nonexistent file),
      // _runInitialization re-entry, probe, initializer (pends).
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(calls, 2);
      expect(find.text('Recovering database...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Database needs recovery'), findsNothing);

      // Drain the 1-second splash-delay timer started by _runInitialization.
      await tester.pump(const Duration(seconds: 2));
    });
  });
}

/// A backup service whose `backupIfMigrationPending` always throws.
class _ThrowingBackupService extends PreMigrationBackupService {
  final Object error;
  _ThrowingBackupService({required super.preferences, required this.error})
    : super(
        livePathProvider: () async => '/tmp/test.db',
        backupsDirProvider: () async => '/tmp/test-backups',
      );

  @override
  Future<void> backupIfMigrationPending({
    required int stored,
    required int target,
    required String appVersion,
  }) async {
    throw error;
  }
}
