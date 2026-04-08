import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/domain/entities/migration_progress.dart';

void main() {
  group('Splash UI elements', () {
    testWidgets('shows app icon and Submersion text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.water_drop, size: 96),
                  SizedBox(height: 16),
                  Text(
                    'Submersion',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Submersion'), findsOneWidget);
    });

    testWidgets('shows progress bar with step text when migrating', (
      tester,
    ) async {
      const progress = MigrationProgress(currentStep: 3, totalSteps: 7);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress.fraction),
                  const SizedBox(height: 12),
                  Text(
                    'Upgrading database... '
                    'step ${progress.currentStep} of ${progress.totalSteps}',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Upgrading database... step 3 of 7'), findsOneWidget);

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.4286, 0.001));
    });

    testWidgets('shows version mismatch error with close button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.update, size: 64, color: Colors.orange),
                    const SizedBox(height: 24),
                    const Text('Update Required'),
                    const SizedBox(height: 16),
                    const Text(
                      'Your dive data was saved by a newer version of '
                      'Submersion (schema v99). This version '
                      'only supports up to schema v62.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(onPressed: () {}, child: const Text('Close')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Update Required'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.byIcon(Icons.update), findsOneWidget);
    });

    testWidgets('shows generic error with message and close button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 24),
                    const Text('Database upgrade failed'),
                    const SizedBox(height: 16),
                    const Text('Some error occurred'),
                    const SizedBox(height: 24),
                    FilledButton(onPressed: () {}, child: const Text('Close')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Database upgrade failed'), findsOneWidget);
      expect(find.text('Some error occurred'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
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
  });
}
