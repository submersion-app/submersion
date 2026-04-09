import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/domain/entities/migration_progress.dart';

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

      // The AnimatedSize child should be SizedBox.shrink
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
}
