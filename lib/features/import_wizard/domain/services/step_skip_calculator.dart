import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';

/// Calculates the next page index by skipping steps whose auto-advance
/// condition is already met.
///
/// Returns the index of the next step that still needs user input, or
/// [reviewIndex] if all remaining acquisition steps can be skipped.
/// Populates [skippedSteps] with the steps that were auto-advanced over
/// so callers can run their [onBeforeAdvance] callbacks.
int calculateNextPage({
  required int currentPage,
  required int reviewIndex,
  required List<WizardStepDef> steps,
  required bool Function(WizardStepDef step) isAutoAdvanceReady,
  List<WizardStepDef>? skippedSteps,
}) {
  var nextPage = currentPage + 1;
  while (nextPage < reviewIndex) {
    final nextStep = steps[nextPage];
    final autoProvider = nextStep.canAutoAdvance;
    if (autoProvider != null && nextStep.autoAdvance) {
      if (isAutoAdvanceReady(nextStep)) {
        skippedSteps?.add(nextStep);
        nextPage++;
        continue;
      }
    }
    break;
  }
  return nextPage;
}
