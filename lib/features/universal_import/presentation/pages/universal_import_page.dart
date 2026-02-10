import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/features/universal_import/presentation/widgets/field_mapping_step.dart';
import 'package:submersion/features/universal_import/presentation/widgets/file_selection_step.dart';
import 'package:submersion/features/universal_import/presentation/widgets/import_progress_step.dart';
import 'package:submersion/features/universal_import/presentation/widgets/import_review_step.dart';
import 'package:submersion/features/universal_import/presentation/widgets/import_summary_step.dart';
import 'package:submersion/features/universal_import/presentation/widgets/source_confirmation_step.dart';

/// Universal import wizard page.
///
/// Six-step process:
/// 0. File selection - Pick and auto-detect file format
/// 1. Source confirmation - Confirm detected app or override
/// 2. Field mapping - CSV only: map columns to Submersion fields
/// 3. Review & select - Choose which entities to import
/// 4. Importing - Progress indicator
/// 5. Summary - Show import results
class UniversalImportPage extends ConsumerWidget {
  const UniversalImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(universalImportNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Data'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close import wizard',
          onPressed: () {
            ref.read(universalImportNotifierProvider.notifier).reset();
            context.pop();
          },
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(currentStep: state.currentStep),
          Expanded(
            child: switch (state.currentStep) {
              ImportWizardStep.fileSelection => const FileSelectionStep(),
              ImportWizardStep.sourceConfirmation =>
                const SourceConfirmationStep(),
              ImportWizardStep.fieldMapping => const FieldMappingStep(),
              ImportWizardStep.review => const ImportReviewStep(),
              ImportWizardStep.importing => const ImportProgressStep(),
              ImportWizardStep.summary => const ImportSummaryStep(),
            },
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Step indicator
// =============================================================================

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final ImportWizardStep currentStep;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stepIndex = currentStep.index;

    // Condense 6 steps into 4 visible dots for a cleaner UI:
    // Select(0-1) -> Map(2) -> Review(3) -> Import(4-5)
    const labels = ['Select', 'Map', 'Review', 'Import'];
    final mappedStep = switch (currentStep) {
      ImportWizardStep.fileSelection ||
      ImportWizardStep.sourceConfirmation => 0,
      ImportWizardStep.fieldMapping => 1,
      ImportWizardStep.review => 2,
      ImportWizardStep.importing || ImportWizardStep.summary => 3,
    };
    // Treat summary as "completed all"
    final isSummary = currentStep == ImportWizardStep.summary;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= mappedStep
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
              ),
            _StepDot(
              step: i + 1,
              label: labels[i],
              isActive: i == mappedStep && !isSummary,
              isCompleted: i < mappedStep || isSummary,
              // Skip the map dot if the format doesn't need mapping
              isSkipped:
                  i == 1 &&
                  stepIndex > ImportWizardStep.fieldMapping.index &&
                  currentStep != ImportWizardStep.fieldMapping,
            ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.step,
    required this.label,
    required this.isActive,
    required this.isCompleted,
    this.isSkipped = false,
  });

  final int step;
  final String label;
  final bool isActive;
  final bool isCompleted;
  final bool isSkipped;

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
                  : colorScheme.outline,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 18, color: colorScheme.onPrimary)
                : isSkipped
                ? Icon(
                    Icons.remove,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  )
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
