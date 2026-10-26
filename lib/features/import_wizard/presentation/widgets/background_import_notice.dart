import 'package:submersion/features/import_wizard/presentation/providers/import_job_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// What the app tells the diver when an import that ran on after its wizard
/// closed has ended (#3554), since it has no summary page to end on.
String backgroundImportNotice(
  AppLocalizations l10n,
  ImportJobOutcome outcome,
) => switch (outcome.kind) {
  ImportJobOutcomeKind.finished => l10n.universalImport_background_finished(
    outcome.importedDives,
  ),
  ImportJobOutcomeKind.stopped => l10n.universalImport_background_stopped(
    outcome.importedDives,
  ),
  ImportJobOutcomeKind.failed => l10n.universalImport_background_failed,
};
