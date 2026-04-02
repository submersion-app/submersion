import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';
import 'package:submersion/features/import_wizard/domain/services/step_skip_calculator.dart';

/// Dummy provider for steps that should always show as "ready".
final _readyProvider = Provider<bool>((ref) => true);

/// Dummy provider for steps that should always show as "not ready".
final _notReadyProvider = Provider<bool>((ref) => false);

WizardStepDef _step({
  String label = 'Step',
  bool autoAdvance = false,
  ProviderListenable<bool>? canAutoAdvance,
}) {
  return WizardStepDef(
    label: label,
    builder: (_) => const SizedBox.shrink(),
    canAdvance: _readyProvider,
    autoAdvance: autoAdvance,
    canAutoAdvance: canAutoAdvance,
  );
}

void main() {
  group('calculateNextPage', () {
    test('returns currentPage + 1 when next step has no auto-advance', () {
      final steps = [_step(), _step(), _step()];

      final result = calculateNextPage(
        currentPage: 0,
        reviewIndex: 3,
        steps: steps,
        isAutoAdvanceReady: (_) => false,
      );

      expect(result, 1);
    });

    test('skips step when autoAdvance is true and provider is ready', () {
      final steps = [
        _step(),
        _step(autoAdvance: true, canAutoAdvance: _readyProvider),
        _step(),
      ];

      final result = calculateNextPage(
        currentPage: 0,
        reviewIndex: 3,
        steps: steps,
        isAutoAdvanceReady: (_) => true,
      );

      expect(result, 2);
    });

    test('skips multiple consecutive ready steps', () {
      final steps = [
        _step(),
        _step(autoAdvance: true, canAutoAdvance: _readyProvider),
        _step(autoAdvance: true, canAutoAdvance: _readyProvider),
        _step(),
      ];

      final result = calculateNextPage(
        currentPage: 0,
        reviewIndex: 4,
        steps: steps,
        isAutoAdvanceReady: (_) => true,
      );

      expect(result, 3);
    });

    test('stops at step where autoAdvance is false', () {
      final steps = [
        _step(),
        _step(autoAdvance: true, canAutoAdvance: _readyProvider),
        _step(autoAdvance: false),
        _step(),
      ];

      final result = calculateNextPage(
        currentPage: 0,
        reviewIndex: 4,
        steps: steps,
        isAutoAdvanceReady: (_) => true,
      );

      expect(result, 2);
    });

    test('stops at step where provider is not ready', () {
      final steps = [
        _step(),
        _step(autoAdvance: true, canAutoAdvance: _readyProvider),
        _step(autoAdvance: true, canAutoAdvance: _notReadyProvider),
        _step(),
      ];

      final result = calculateNextPage(
        currentPage: 0,
        reviewIndex: 4,
        steps: steps,
        isAutoAdvanceReady: (step) => step.canAutoAdvance == _readyProvider,
      );

      expect(result, 2);
    });

    test('returns reviewIndex when all steps can be skipped', () {
      final steps = [
        _step(),
        _step(autoAdvance: true, canAutoAdvance: _readyProvider),
        _step(autoAdvance: true, canAutoAdvance: _readyProvider),
      ];

      final result = calculateNextPage(
        currentPage: 0,
        reviewIndex: 3,
        steps: steps,
        isAutoAdvanceReady: (_) => true,
      );

      expect(result, 3);
    });

    test(
      'stops at step with no canAutoAdvance even if autoAdvance is true',
      () {
        final steps = [
          _step(),
          _step(
            autoAdvance: true,
          ), // autoAdvance but no canAutoAdvance provider
          _step(),
        ];

        final result = calculateNextPage(
          currentPage: 0,
          reviewIndex: 3,
          steps: steps,
          isAutoAdvanceReady: (_) => true,
        );

        expect(result, 1);
      },
    );

    test('populates skippedSteps with auto-advanced steps', () {
      final steps = [
        _step(label: 'A'),
        _step(label: 'B', autoAdvance: true, canAutoAdvance: _readyProvider),
        _step(label: 'C', autoAdvance: true, canAutoAdvance: _readyProvider),
        _step(label: 'D'),
      ];

      final skipped = <WizardStepDef>[];
      calculateNextPage(
        currentPage: 0,
        reviewIndex: 4,
        steps: steps,
        isAutoAdvanceReady: (_) => true,
        skippedSteps: skipped,
      );

      expect(skipped.map((s) => s.label).toList(), ['B', 'C']);
    });
  });
}
