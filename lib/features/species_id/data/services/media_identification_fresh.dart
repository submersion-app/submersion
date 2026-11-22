part of 'media_identification_service.dart';

/// Analysing again from the start (issue #4825), and naming again, kept
/// beside the queue they run in: the same library, so they share the
/// service's private state.
extension _FreshRuns on MediaIdentificationService {
  /// Brings [stored]'s dismissals back before a fresh run
  /// ([reopenDismissed]), and returns the rows as they then stand. Null
  /// when another logbook opened meanwhile: nothing is written, and the job
  /// is over.
  Future<List<MediaIdentification>?> _reopen(
    _Job job,
    List<MediaIdentification> stored,
  ) async {
    final changed = reopenDismissed(stored, now: _now().toUtc());
    if (_databaseGeneration() != job.generation) {
      job.outcome = RunItemOutcome.skipped;
      return null;
    }
    if (changed.isEmpty) return stored;
    await _identifications.updateDecisions(changed);
    return _identifications.forMedia(job.item.id);
  }

  /// [_onItemSettled] for [job]'s item, its failure logged and swallowed.
  /// A run's items are left to the run, which applies them together, and
  /// nothing is applied after a fresh request (issue #4825).
  Future<void> _settled(_Job job) async {
    // Still fresh: it stopped before its fresh start (a file that cannot
    // be read); it was asked for fresh all the same.
    if (job.fromRun || job.fresh || job.wasFresh) return;
    final item = job.item;
    try {
      await _onItemSettled(item, job.generation);
    } on Object catch (e) {
      _log.debug('Could not auto-apply species on ${item.id}', error: e);
    }
  }

  Future<void> _rename(
    LoadedPack pack,
    MediaIdentificationRun run,
    List<MediaIdentification> undecided,
    Map<String, Float32List> embeddings,
    int? cell,
    int generation,
  ) async {
    final results = await nameCrops(pack, [
      for (final i in undecided)
        (embedding: embeddings[i.id]!, shorterSide: i.boxShorterSide),
    ], cell);
    final naming = pack.pack.manifest.naming;
    final changed = [
      for (var k = 0; k < undecided.length; k++)
        _renamed(undecided[k], _named(undecided[k], results[k], naming)),
    ];
    if (_databaseGeneration() != generation) return;
    final written = await _identifications.updateNames(
      changed,
      run: run.copyWith(
        packVersion: pack.pack.manifest.packVersion,
        locationCell: () => cell,
        namingBars: () => NamingBars.fromNaming(naming),
      ),
    );
    // Only what was written: nothing when a run synced in meanwhile, whose
    // rows these crops are not (issue #4876).
    await _promoteNamed(run.mediaId, [
      for (final c in changed)
        if (written.contains(c.id)) c,
    ]);
  }
}
