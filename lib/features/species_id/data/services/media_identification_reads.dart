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
    final me = await _deviceId();
    return me == null || run.madeOn(me);
  }
}

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
