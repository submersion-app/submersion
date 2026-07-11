import 'package:flutter/material.dart';

/// A reusable step indicator widget for multi-step wizards.
///
/// Displays a horizontal row of numbered dots connected by lines. Each dot
/// shows a step number for active/future steps and a checkmark for completed
/// steps. A label is rendered below each dot.
class WizardStepIndicator extends StatelessWidget {
  const WizardStepIndicator({
    super.key,
    required this.labels,
    required this.currentStep,
  });

  /// The label to display below each step dot.
  final List<String> labels;

  /// The zero-based index of the currently active step.
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= currentStep
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
              ),
            _WizardStepDot(
              step: i + 1,
              label: labels[i],
              isActive: i == currentStep,
              isCompleted: i < currentStep,
            ),
          ],
        ],
      ),
    );
  }
}

class _WizardStepDot extends StatelessWidget {
  const _WizardStepDot({
    required this.step,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  final int step;
  final String label;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isCompleted
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: isActive || isCompleted
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: isActive
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
