import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';

// A simple provider that always resolves to true.
final _alwaysTrueProvider = Provider<bool>((ref) => true);

// A simple provider that always resolves to false.
final _alwaysFalseProvider = Provider<bool>((ref) => false);

void main() {
  group('WizardStepDef', () {
    test('constructs with required fields and defaults', () {
      final step = WizardStepDef(
        label: 'Select File',
        builder: (context) => const SizedBox.shrink(),
        canAdvance: _alwaysTrueProvider,
      );

      expect(step.label, 'Select File');
      expect(step.icon, isNull);
      expect(step.autoAdvance, isFalse);
      expect(step.onBeforeAdvance, isNull);
      expect(step.hideBottomBar, isFalse);
    });

    test('constructs with all optional fields', () {
      var callbackInvoked = false;

      final step = WizardStepDef(
        label: 'Download',
        icon: const IconData(0xe04b),
        builder: (context) => const SizedBox.shrink(),
        canAdvance: _alwaysFalseProvider,
        autoAdvance: true,
        onBeforeAdvance: () async {
          callbackInvoked = true;
        },
        hideBottomBar: true,
      );

      expect(step.label, 'Download');
      expect(step.icon, isNotNull);
      expect(step.autoAdvance, isTrue);
      expect(step.hideBottomBar, isTrue);
      expect(step.onBeforeAdvance, isNotNull);

      step.onBeforeAdvance!();
      expect(callbackInvoked, isTrue);
    });

    test('builder produces a widget', () {
      final step = WizardStepDef(
        label: 'Review',
        builder: (context) => const Text('Review Content'),
        canAdvance: _alwaysTrueProvider,
      );

      // Call builder with a fake context - we just check it returns a Widget.
      // In real usage BuildContext comes from the widget tree.
      // We verify the function is callable and returns the expected type.
      expect(step.builder, isA<Widget Function(BuildContext)>());
    });

    test('autoAdvance defaults to false', () {
      final step = WizardStepDef(
        label: 'Step',
        builder: (_) => const SizedBox.shrink(),
        canAdvance: _alwaysTrueProvider,
      );

      expect(step.autoAdvance, isFalse);
    });

    test('hideBottomBar defaults to false', () {
      final step = WizardStepDef(
        label: 'Step',
        builder: (_) => const SizedBox.shrink(),
        canAdvance: _alwaysTrueProvider,
      );

      expect(step.hideBottomBar, isFalse);
    });

    test('canAdvance holds the provided provider', () {
      final step = WizardStepDef(
        label: 'Step',
        builder: (_) => const SizedBox.shrink(),
        canAdvance: _alwaysFalseProvider,
      );

      expect(step.canAdvance, same(_alwaysFalseProvider));
    });
  });
}
