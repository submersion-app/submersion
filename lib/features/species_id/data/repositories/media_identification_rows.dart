part of 'media_identification_repository.dart';

// Row mapping for the marine life tables, beside the repository that
// reads and writes them.

MediaIdentificationRun _runFromRow(MediaIdentificationRunRow row) =>
    MediaIdentificationRun(
      mediaId: row.mediaId,
      packVersion: row.packVersion,
      detectorId: row.detectorId,
      classifierId: row.classifierId,
      locationCell: row.locationCell,
      analysedAt: _time(row.analysedAt),
      imageWidth: row.imageWidth,
      imageHeight: row.imageHeight,
      detectionCount: row.detectionCount,
      scannedMs: row.scannedMs,
      videoDurationMs: row.videoDurationMs,
      scannedRanges: _ranges(row.scannedRanges),
      analysedBy: row.analysedBy,
      runId: row.runId,
      namingBars: NamingBars.fromJson(row.namingBars),
    );

/// The stored stretches, or null when there are none or they cannot be
/// read: the run's scanned_ms mark then applies.
ScannedRanges? _ranges(Uint8List? bytes) {
  if (bytes == null) return null;
  try {
    return decodeScannedRanges(bytes);
  } on FormatException catch (e) {
    MediaIdentificationRepository._log.warning(
      'Unreadable scanned stretches, using the mark',
      error: e,
    );
    return null;
  }
}

MediaIdentificationRunsCompanion _runToCompanion(MediaIdentificationRun run) =>
    MediaIdentificationRunsCompanion.insert(
      mediaId: run.mediaId,
      packVersion: run.packVersion,
      detectorId: run.detectorId,
      classifierId: run.classifierId,
      locationCell: Value(run.locationCell),
      analysedAt: run.analysedAt.millisecondsSinceEpoch,
      imageWidth: run.imageWidth,
      imageHeight: run.imageHeight,
      detectionCount: run.detectionCount,
      scannedMs: Value(run.scannedMs),
      videoDurationMs: Value(run.videoDurationMs),
      scannedRanges: Value(
        run.scannedRanges == null
            ? null
            : encodeScannedRanges(run.scannedRanges!),
      ),
      // Absent rather than null when unknown: a write never clears where a
      // run came from, its run id or its bars.
      analysedBy: Value.absentIfNull(run.analysedBy),
      runId: Value.absentIfNull(run.runId),
      namingBars: Value.absentIfNull(run.namingBars?.toJson()),
    );

MediaIdentification _fromRow(
  MediaIdentificationRow row, {
  bool withPath = true,
}) => MediaIdentification(
  id: row.id,
  mediaId: row.mediaId,
  box: IdentificationBox(
    x: row.boxX,
    y: row.boxY,
    width: row.boxWidth,
    height: row.boxHeight,
  ),
  boxPixelWidth: row.boxPixelWidth,
  boxPixelHeight: row.boxPixelHeight,
  detectorScore: row.detectorScore,
  openScore: row.openScore,
  candidates: _decodeCandidates(row.candidatesJson),
  locationLimited: row.locationLimited,
  suggestable: row.suggestable,
  decision: IdentificationDecision.values.firstWhere(
    (d) => d.name == row.decision,
    orElse: () => IdentificationDecision.undecided,
  ),
  decidedSpeciesId: row.decidedSpeciesId,
  decidedAt: row.decidedAt == null ? null : _time(row.decidedAt!),
  createdAt: _time(row.createdAt),
  startMs: row.startMs,
  endMs: row.endMs,
  bestMs: row.bestMs,
  path: withPath ? _decodePath(row) : const [],
  claimedSpeciesId: row.claimedSpeciesId,
  confident: row.confident,
  specific: row.specific,
  runId: row.runId,
);

MediaIdentificationsCompanion _toCompanion(MediaIdentification i) =>
    MediaIdentificationsCompanion.insert(
      id: i.id,
      mediaId: i.mediaId,
      boxX: i.box.x,
      boxY: i.box.y,
      boxWidth: i.box.width,
      boxHeight: i.box.height,
      boxPixelWidth: i.boxPixelWidth,
      boxPixelHeight: i.boxPixelHeight,
      detectorScore: i.detectorScore,
      openScore: i.openScore,
      candidatesJson: jsonEncode([for (final c in i.candidates) c.toJson()]),
      locationLimited: i.locationLimited,
      suggestable: i.suggestable,
      decision: i.decision.name,
      decidedSpeciesId: Value(i.decidedSpeciesId),
      decidedAt: Value(i.decidedAt?.millisecondsSinceEpoch),
      createdAt: i.createdAt.millisecondsSinceEpoch,
      startMs: Value(i.startMs),
      endMs: Value(i.endMs),
      bestMs: Value(i.bestMs),
      trackPath: Value(i.isTrack ? encodeTrackPath(i.startMs!, i.path) : null),
      claimedSpeciesId: Value(i.claimedSpeciesId),
      confident: Value(i.confident),
      specific: Value(i.specific),
      runId: Value.absentIfNull(i.runId),
    );

/// The ids among [insert] whose decision fields this write changes (issue
/// #4876): a new row carrying something the diver said, or a stored one
/// whose decision, decided species or time, or claim differs. Only these
/// move the decision clock: a row written again as it was (a video chunk
/// continuing a decided track) must not outrank a decision made on another
/// device meanwhile. Read before the write, in its transaction.
Future<List<String>> _decisionsChanged(
  AppDatabase db,
  List<MediaIdentification> insert,
) async {
  if (insert.isEmpty) return const [];
  final table = db.mediaIdentifications;
  final stored =
      <
        String,
        ({String decision, String? decided, int? at, String? claimed})
      >{};
  final ids = [for (final i in insert) i.id];
  for (final slice in ids.slices(MediaIdentificationRepository._slice)) {
    final rows =
        await (db.selectOnly(table)
              ..addColumns([
                table.id,
                table.decision,
                table.decidedSpeciesId,
                table.decidedAt,
                table.claimedSpeciesId,
              ])
              ..where(table.id.isIn(slice)))
            .get();
    for (final r in rows) {
      stored[r.read(table.id)!] = (
        decision: r.read(table.decision)!,
        decided: r.read(table.decidedSpeciesId),
        at: r.read(table.decidedAt),
        claimed: r.read(table.claimedSpeciesId),
      );
    }
  }
  bool changed(MediaIdentification i) {
    final before = stored[i.id];
    if (before == null) return i.saidByDiver;
    return before.decision != i.decision.name ||
        before.decided != i.decidedSpeciesId ||
        before.at != i.decidedAt?.millisecondsSinceEpoch ||
        before.claimed != i.claimedSpeciesId;
  }

  return [
    for (final i in insert)
      if (changed(i)) i.id,
  ];
}

/// A path that cannot be read keeps its row with no path, which draws no
/// label: the rest of what was found stays usable.
List<TrackSample> _decodePath(MediaIdentificationRow row) {
  final bytes = row.trackPath;
  final start = row.startMs;
  if (bytes == null || start == null) return const [];
  try {
    return decodeTrackPath(start, bytes);
  } on FormatException catch (e) {
    MediaIdentificationRepository._log.debug(
      'Unreadable track path on ${row.id}',
      error: e,
    );
    return const [];
  }
}

/// A row whose JSON cannot be read keeps its place with no candidates,
/// which the rules never suggest.
List<NamedCandidate> _decodeCandidates(String json) {
  try {
    final list = jsonDecode(json);
    if (list is! List) return const [];
    return [
      for (final entry in list)
        if (entry is Map)
          NamedCandidate.fromJson(entry.cast<String, Object?>()),
    ];
  } on Object {
    return const [];
  }
}

DateTime _time(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
