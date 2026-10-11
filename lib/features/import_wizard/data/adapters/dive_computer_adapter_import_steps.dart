part of 'dive_computer_adapter.dart';

/// Outcome of a single `DiveComputerAdapter._consolidateDive` call.
///
/// Used by `DiveComputerAdapter.performImport` to keep the import summary
/// accurate when a consolidation cannot complete, instead of throwing and
/// aborting the rest of the import loop.
enum _ConsolidateOutcome {
  /// The download was imported and successfully folded into the target.
  consolidated,

  /// Skipped without importing: the target dive already has data from the
  /// same computer, which [DiveConsolidationService.apply] would always
  /// reject with `ArgumentError('sameComputer...')`.
  skippedSameComputer,

  /// The download was imported as a standalone dive and KEPT that way: the
  /// fold refused because the PRE-EXISTING target holds a series this build
  /// cannot decode. The download itself is sound, so deleting it would lose
  /// it for good.
  keptStandalone,

  /// The download was imported as a standalone dive, but folding it into
  /// the target failed unexpectedly. The orphaned standalone dive was
  /// deleted to avoid stranding it.
  failed,
}

/// What a `_consolidateDive` call did, plus the id of the standalone dive it
/// left behind (only [_ConsolidateOutcome.keptStandalone] leaves one).
typedef _ConsolidateResult = ({_ConsolidateOutcome outcome, String? diveId});

/// The adapter's per-dive import steps: folding a download into the dive it
/// matches, and the computer bookkeeping after an import. Kept beside the
/// adapter so that file stays within reach of the size limit.
extension _DiveComputerAdapterImportSteps on DiveComputerAdapter {
  /// Consolidate a downloaded dive as a secondary computer reading on an
  /// existing dive.
  ///
  /// Imports the download as a standalone new dive first, persisting every
  /// sample column, tanks, pressures, events, and the raw-data
  /// `dive_data_sources` row via [DiveImportService.importSingleDiveAsNew] /
  /// `importProfile`, then folds it into [targetDiveId] via
  /// [DiveConsolidationService.apply]. This gives full-fidelity
  /// consolidation instead of a hand-rolled copy that would drop heart
  /// rate, O2 sensors, CNS/TTS samples, tanks, and events.
  ///
  /// The import and the fold are NOT atomic (there is no cross-table
  /// transaction spanning both repository calls), so this method guards
  /// both failure modes rather than letting either strand a dangling dive:
  ///
  /// - **Predictable failure (pre-validated, nothing imported):**
  ///   [DiveConsolidationService.apply] always throws `ArgumentError`
  ///   ("sameComputer...") when the secondary shares [targetDiveId]'s
  ///   `computerId`. Checking that up front avoids importing a dive that is
  ///   guaranteed to fail the fold.
  /// - **Refusal about the TARGET (kept):** [UnreadableSeriesException] says
  ///   the pre-existing target dive holds a profile or pressure series this
  ///   build cannot decode, so `apply` refused before writing anything. The
  ///   download is not at fault and is the only copy of this dive: the
  ///   fingerprint advances past it on the way out of `performImport`, so
  ///   deleting it would lose it for good. It is kept standalone instead.
  /// - **Unexpected failure (compensated):** if the import succeeds but
  ///   `apply` throws for any other reason, the freshly-imported dive is
  ///   deleted via [DiveRepository.bulkDeleteDives] (tombstone-honoring)
  ///   instead of being left as a bare, unconsolidated duplicate.
  ///
  /// Returns a [_ConsolidateResult] describing what happened so the caller
  /// can adjust the import summary's counters instead of aborting the loop.
  Future<_ConsolidateResult> _consolidateDive(
    DownloadedDive dive,
    String targetDiveId,
    DiveComputer comp, {
    required bool retainSourceDiveNumber,
  }) async {
    final targetComputerId = await _diveRepository.getComputerIdForDive(
      targetDiveId,
    );
    if (targetComputerId != null && targetComputerId == comp.id) {
      return (outcome: _ConsolidateOutcome.skippedSameComputer, diveId: null);
    }

    String? newDiveId;
    try {
      newDiveId = await _importService.importSingleDiveAsNew(
        dive,
        computerId: comp.id,
        diverId: _diverId,
        descriptorVendor: _descriptorVendor,
        descriptorProduct: _descriptorProduct,
        descriptorModel: _descriptorModel,
        libdivecomputerVersion: _libdivecomputerVersion,
        retainSourceDiveNumber: retainSourceDiveNumber,
      );
      await _consolidationService.apply(
        targetDiveId: targetDiveId,
        secondaryDiveIds: [newDiveId],
      );
      return (outcome: _ConsolidateOutcome.consolidated, diveId: newDiveId);
    } on UnreadableSeriesException catch (e) {
      final keptId = newDiveId;
      if (keptId != null) {
        DiveComputerAdapter._log.warning(
          'Kept downloaded dive $keptId standalone instead of folding it '
          'into $targetDiveId: that dive holds ${e.seriesIds.length} '
          'series this build cannot decode',
        );
        return (outcome: _ConsolidateOutcome.keptStandalone, diveId: keptId);
      }
      // Nothing was imported, so there is nothing to keep or compensate.
      DiveComputerAdapter._log.error(
        'Consolidation fold refused for $targetDiveId',
        error: e,
      );
      return (outcome: _ConsolidateOutcome.failed, diveId: null);
    } catch (e, st) {
      DiveComputerAdapter._log.error(
        'Consolidation fold failed for dive into $targetDiveId',
        error: e,
        stackTrace: st,
      );
      if (newDiveId != null) {
        try {
          await _diveRepository.bulkDeleteDives([newDiveId]);
        } catch (deleteError, deleteStack) {
          // The compensating delete failed too. Log it and fall through
          // rather than rethrow, so the import loop still processes the
          // remaining dives instead of aborting on a stranded standalone
          // dive.
          DiveComputerAdapter._log.error(
            'Compensating delete failed for orphaned dive $newDiveId',
            error: deleteError,
            stackTrace: deleteStack,
          );
        }
      }
      return (outcome: _ConsolidateOutcome.failed, diveId: null);
    }
  }

  /// Update computer dive count, last download, and fingerprint after import.
  Future<void> _updateComputerAfterImport(
    DiveComputer comp,
    int importedCount,
    List<DownloadedDive> importedDives,
  ) async {
    if (importedCount > 0) {
      await _computerRepository.incrementDiveCount(comp.id, by: importedCount);
    }

    await _computerRepository.updateLastDownload(comp.id);

    final resumeFingerprint = selectResumeFingerprint(
      importedDives,
      downloadComplete: !_downloadInterrupted,
      deliversOldestFirst: _deliversOldestFirst,
    );
    if (resumeFingerprint != null) {
      await _computerRepository.updateLastFingerprint(
        comp.id,
        resumeFingerprint,
      );
    }
  }
}
