import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';
import 'package:submersion/features/dive_import/data/services/dive_resync_orchestrator.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

/// Shared [ImportedFileRepository]; overridable so tests can point it at their
/// own database.
final importedFileRepositoryProvider = Provider<ImportedFileRepository>(
  (ref) => ImportedFileRepository(),
);

/// Provider for the [DiveResyncOrchestrator] singleton.
final diveResyncOrchestratorProvider = Provider<DiveResyncOrchestrator>((ref) {
  final db = DatabaseService.instance.database;
  return DiveResyncOrchestrator(
    db: db,
    importedFiles: ref.watch(importedFileRepositoryProvider),
  );
});

/// Whether [diveId] has a stored original file it can be resynced from, still
/// held HERE.
///
/// `imported_file_id` syncs as part of its dive, while the row it names is a
/// top-level entity with its own clock and its own place in the changeset, so
/// a device can legitimately hold the reference without holding the bytes --
/// the file row has not arrived yet, or the peer that wrote the reference is
/// below the schema floor. Gating on the reference alone would offer the
/// action there, so the row lookup is part of the answer.
final diveHasImportedFileProvider = FutureProvider.family<bool, String>((
  ref,
  diveId,
) async {
  final importedFiles = ref.watch(importedFileRepositoryProvider);
  ref.invalidateSelfWhen(
    ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
  );
  // The detail tick covers `dive_data_sources` but not `imported_files`, and
  // the two arrive independently: a sync that applies the reference first
  // leaves this provider holding a false nothing would ever recompute.
  ref.invalidateSelfWhen(importedFiles.watchImportedFilesChanges());
  final db = DatabaseService.instance.database;
  final source =
      await (db.select(db.diveDataSources)
            ..where((t) => t.diveId.equals(diveId))
            ..where((t) => t.isPrimary.equals(true))
            ..limit(1))
          .getSingleOrNull();
  final storedFileId = source?.importedFileId;
  if (storedFileId == null) return false;
  return importedFiles.exists(storedFileId);
});
