part of 'media_identification_service.dart';

/// Where a run came from (issue #4876), kept beside the service it reads
/// for: the same library, so it shares the service's private state.
extension _RunOrigin on MediaIdentificationService {
  /// Moves the crops of [changed] that are named now into the logbook, so
  /// they sync (issue #4876).
  Future<int> _promoteNamed(
    String mediaId,
    List<MediaIdentification> changed,
  ) => _crops.promote(mediaId, [
    for (final i in changed)
      if (isNamed(i)) i.id,
  ]);

  /// Whether [run] was made on this device (issue #4876). With no run, or
  /// when this device's id cannot be read, it counts as this device's, as
  /// every run did before results synced.
  Future<bool> _madeHere(MediaIdentificationRun? run) async {
    if (run == null || run.analysedBy == null) return true;
    return _madeBy(run, await _deviceId());
  }

  /// The rows of [mediaId], [stored] under [run], that a refresh works from
  /// (issue #4876). On the device that made [run], leftovers of a run that
  /// lost a sync race, which the labels and readiness never count
  /// ([visibleRows]), are deleted now with their crops and embeddings: the
  /// next write here, rather than an analysis again for crops this device
  /// never had. Elsewhere every row is kept, so an analysis here replaces
  /// them all.
  Future<List<MediaIdentification>> _withoutLeftovers(
    String mediaId,
    MediaIdentificationRun? run,
    List<MediaIdentification> stored, {
    required bool madeHere,
    required int generation,
  }) async {
    final runId = run?.runId;
    if (!madeHere || runId == null) return stored;
    final visible = visibleRows(run, stored);
    if (visible.length == stored.length) return stored;
    // The rows shown, whatever goes: a leftover kept because a sync landed
    // since is no reason to analyse again.
    if (_databaseGeneration() != generation) return visible;
    final shown = {for (final i in visible) i.id};
    final gone = await _identifications.deleteLeftovers(mediaId, runId, [
      for (final i in stored)
        if (!shown.contains(i.id)) i.id,
    ]);
    await _embeddings.delete(gone);
    await _crops.delete(mediaId, gone);
    return visible;
  }
}

/// Whether [run] was made on the device whose sync id is [me]: with no id
/// to go by, it counts as this device's.
bool _madeBy(MediaIdentificationRun run, String? me) =>
    me == null || run.madeOn(me);

/// This device's sync id, or null when it cannot be read (no logbook open,
/// or a test with none): what a run records as its maker (issue #4876).
Future<String?> syncDeviceIdOrNull() async {
  try {
    return await SyncRepository().getDeviceId();
  } on Object {
    return null;
  }
}

/// [mediaId]'s identifications as shown ([visibleRows]) and as [level]
/// would suggest them, when the pack in force named them (issue #4721).
/// The run and rows are read in one snapshot, so the pack the run names is
/// the pack the rows were named with: a rename landing in between cannot
/// pair them wrongly.
///
/// [chosen] is the level the diver chose: with it, a run that kept its
/// pack's naming bars is named by them ([applyChosenLevel], issue #4876).
Future<List<MediaIdentification>> identificationsAtLevel(
  MediaIdentificationRepository repository,
  String mediaId,
  LevelInForce? level, {
  NamingLevel? chosen,
}) async {
  final (run, stored) = await repository.forMediaWithRun(mediaId);
  return applyChosenLevel(
    visibleRows(run, stored),
    run: run,
    chosen: chosen ?? level?.level,
    installed: level,
  );
}

/// [identification] with what naming found, including the label flags.
MediaIdentification _named(
  MediaIdentification identification,
  NamingResult result,
  NamingConfig naming,
) {
  final flags = namingFlags(result, naming);
  return identification.copyWith(
    openScore: result.openScore,
    candidates: result.candidates,
    locationLimited: result.locationLimited,
    suggestable: result.suggestable,
    confident: flags.confident,
    specific: flags.specific,
  );
}

/// [renamed] as [suggestableOnRename] allows, given [before]: a video
/// track keeps a suggestion only under the same name.
MediaIdentification _renamed(
  MediaIdentification before,
  MediaIdentification renamed,
) {
  final suggestable = suggestableOnRename(before: before, renamed: renamed);
  if (suggestable == renamed.suggestable) return renamed;
  return renamed.copyWith(
    suggestable: suggestable,
    confident: renamed.confident && suggestable,
  );
}
