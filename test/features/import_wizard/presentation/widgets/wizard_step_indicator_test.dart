import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/wizard_step_indicator.dart';

void main() {
  const labels = ['Select', 'Review', 'Import', 'Done'];

  Widget buildTestWidget({
    List<String> stepLabels = labels,
    int currentStep = 0,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: WizardStepIndicator(labels: stepLabels, currentStep: currentStep),
      ),
    );
  }

  group('WizardStepIndicator', () {
    testWidgets('renders correct number of dots based on step count', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Each step dot is a Container with a circle decoration.
      // We can find them by their label texts.
      expect(find.text('Select'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('renders correct number of dots for different step counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(stepLabels: ['Step A', 'Step B', 'Step C']),
      );

      expect(find.text('Step A'), findsOneWidget);
      expect(find.text('Step B'), findsOneWidget);
      expect(find.text('Step C'), findsOneWidget);
    });

    testWidgets('shows step numbers for active and future steps', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(currentStep: 1));

      // Step 1 (index 0) is completed -> shows checkmark, no "1" text
      // Step 2 (index 1) is active -> shows "2"
      // Step 3 (index 2) is future -> shows "3"
      // Step 4 (index 3) is future -> shows "4"
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('shows step number 1 for first active step', (tester) async {
      await tester.pumpWidget(buildTestWidget(currentStep: 0));

      // All steps 1-4 should show numbers when currentStep is 0
      // (none are completed)
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('shows checkmark icons for completed steps', (tester) async {
      await tester.pumpWidget(buildTestWidget(currentStep: 2));

      // Steps at index 0 and 1 are completed — they should show check icons
      expect(find.byIcon(Icons.check), findsNWidgets(2));
    });

    testWidgets('shows no checkmarks when on first step', (tester) async {
      await tester.pumpWidget(buildTestWidget(currentStep: 0));

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('shows checkmarks for all but last step when on last step', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(currentStep: 3));

      // Steps 0, 1, 2 are completed; step 3 is active
      expect(find.byIcon(Icons.check), findsNWidgets(3));
    });

    testWidgets('renders label text for each step', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('active step label is rendered', (tester) async {
      await tester.pumpWidget(buildTestWidget(currentStep: 1));

      // The 'Review' label (index 1) should be visible
      expect(find.text('Review'), findsOneWidget);
    });

    testWidgets('connecting lines are rendered between dots', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // For 4 steps there should be 3 connecting line Containers.
      // We verify the widget builds without error and has the right structure.
      // The connecting lines use Expanded widgets between step dots.
      final expandedWidgets = tester.widgetList<Expanded>(
        find.byType(Expanded),
      );
      // There should be (stepCount - 1) = 3 Expanded connecting lines
      expect(expandedWidgets.length, equals(labels.length - 1));
    });

    testWidgets('works with two steps', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(stepLabels: ['Start', 'End'], currentStep: 0),
      );

      expect(find.text('Start'), findsOneWidget);
      expect(find.text('End'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      final expandedWidgets = tester.widgetList<Expanded>(
        find.byType(Expanded),
      );
      expect(expandedWidgets.length, equals(1));
    });
  });
}
