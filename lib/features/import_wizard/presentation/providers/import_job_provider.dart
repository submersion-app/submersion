import 'package:flutter/foundation.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/import_wizard/data/services/import_provider_invalidator.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';

/// The import running in the app, if any, owned by the root container so it
/// outlives the wizard that started it (#3554).
///
/// The wizard starts the job and reports into it; the job holds the one
/// cancellation token, refreshes the imported lists when the import ends
/// whether or not the wizard is still open, and records how a job that ran
/// on without its wizard ended, for the app to tell the diver.
final importJobProvider = NotifierProvider<ImportJobNotifier, ImportJobState>(
  ImportJobNotifier.new,
);

/// How an import that ran on after its wizard closed ended.
enum ImportJobOutcomeKind { finished, stopped, failed }

@immutable
class ImportJobOutcome {
  const ImportJobOutcome({required this.kind, required this.importedDives});

  final ImportJobOutcomeKind kind;

  /// Dives the import wrote before it ended.
  final int importedDives;
}

@immutable
class ImportJobState {
  const ImportJobState({
    this.isRunning = false,
    this.isAttached = false,
    this.continuesWithoutWizard = false,
    this.isCancellationRequested = false,
    this.phase,
    this.current = 0,
    this.total = 0,
    this.backgroundOutcome,
  });

  final bool isRunning;

  /// Whether the wizard that started the job is still open. Only then does
  /// leaving a wizard ask about the job: a job that already runs on alone
  /// belongs to no wizard on screen.
  final bool isAttached;

  /// Whether the job may keep going once its wizard closes. A job that may
  /// not is cancelled when the wizard goes away.
  final bool continuesWithoutWizard;

  final bool isCancellationRequested;
  final ImportPhase? phase;
  final int current;
  final int total;

  /// How the last job that outlived its wizard ended; a new value per job.
  final ImportJobOutcome? backgroundOutcome;

  ImportJobState copyWith({
    bool? isAttached,
    bool? isCancellationRequested,
    ImportPhase? phase,
    int? current,
    int? total,
  }) => ImportJobState(
    isRunning: isRunning,
    isAttached: isAttached ?? this.isAttached,
    continuesWithoutWizard: continuesWithoutWizard,
    isCancellationRequested:
        isCancellationRequested ?? this.isCancellationRequested,
    phase: phase ?? this.phase,
    current: current ?? this.current,
    total: total ?? this.total,
    backgroundOutcome: backgroundOutcome,
  );
}

class ImportJobNotifier extends Notifier<ImportJobState> {
  ImportCancellationToken? _token;

  @override
  ImportJobState build() => const ImportJobState();

  /// Starts a job and returns its cancellation token, or null while another
  /// import is still running: a second import could not see the first one's
  /// unwritten dives as duplicates, so it is refused rather than run beside
  /// it.
  ImportCancellationToken? start({required bool continuesWithoutWizard}) {
    if (state.isRunning) return null;
    final token = ImportCancellationToken();
    _token = token;
    state = ImportJobState(
      isRunning: true,
      isAttached: true,
      continuesWithoutWizard: continuesWithoutWizard,
      backgroundOutcome: state.backgroundOutcome,
    );
    return token;
  }

  /// Records progress of the job [token] belongs to.
  void report(
    ImportCancellationToken token,
    ImportPhase phase,
    int current,
    int total,
  ) {
    if (!identical(token, _token)) return;
    state = state.copyWith(phase: phase, current: current, total: total);
  }

  /// Asks the running job to stop after its current work item.
  void cancel() {
    final token = _token;
    if (token == null || token.isCancelled) return;
    token.cancel();
    state = state.copyWith(isCancellationRequested: true);
  }

  /// The wizard that started the job [token] belongs to has closed. A job
  /// that may not continue without it is cancelled, as leaving always did.
  void detach(ImportCancellationToken token) {
    if (!identical(token, _token)) return;
    state = state.copyWith(isAttached: false);
    if (!state.continuesWithoutWizard) cancel();
  }

  /// Ends the job [token] belongs to. [result] is what it wrote, or null when
  /// it threw. The lists of what it imported are refreshed either way, so a
  /// job that outlived its wizard still shows its dives; after a throw that
  /// is every import list, since the importer may have written some entities
  /// before it failed.
  void finish(
    ImportCancellationToken token, {
    UnifiedImportResult? result,
    ImportSourceType? sourceType,
  }) {
    if (!identical(token, _token)) return;
    _token = null;
    _refreshImported(result, sourceType);
    final ranOnAlone = !state.isAttached;
    state = ImportJobState(
      backgroundOutcome: ranOnAlone
          ? _outcomeOf(result, cancelled: token.isCancelled)
          : state.backgroundOutcome,
    );
  }

  void _refreshImported(
    UnifiedImportResult? result,
    ImportSourceType? sourceType,
  ) {
    // A computer download may have created a computer record even when every
    // dive was skipped.
    if (sourceType == ImportSourceType.diveComputer ||
        sourceType == ImportSourceType.suuntoCloud ||
        sourceType == ImportSourceType.suuntoFile ||
        sourceType == ImportSourceType.garminCloud) {
      ref.invalidate(allDiveComputersProvider);
    }
    invalidateImportRelatedProviders(
      (provider) => ref.invalidate(provider),
      result == null
          ? ImportEntityType.values.toSet()
          : result.importedCounts.entries
                .where((e) => e.value > 0)
                .map((e) => e.key)
                .toSet(),
    );
  }

  static ImportJobOutcome _outcomeOf(
    UnifiedImportResult? result, {
    required bool cancelled,
  }) {
    final dives = result?.importedCounts[ImportEntityType.dives] ?? 0;
    final kind = switch (result) {
      null => ImportJobOutcomeKind.failed,
      UnifiedImportResult(errorMessage: final String _) when dives == 0 =>
        ImportJobOutcomeKind.failed,
      UnifiedImportResult(errorMessage: final String _) =>
        ImportJobOutcomeKind.stopped,
      _ when cancelled => ImportJobOutcomeKind.stopped,
      _ => ImportJobOutcomeKind.finished,
    };
    return ImportJobOutcome(kind: kind, importedDives: dives);
  }
}
