part of 'media_identification_service.dart';

/// What processing an item would do, read without doing it (issue #4727).
extension Readiness on MediaIdentificationService {
  /// The media among [items] that processing would leave as they are:
  /// looked at with [manifest]'s models for the region [locationOf] gives,
  /// their crops on this device, and a video scanned to its end. A Find
  /// species run finds nothing to do on these, so the dive's card says all
  /// checked only when processing agrees.
  ///
  /// [read] is the items' runs and rows as the caller has read them already
  /// ([MediaIdentificationRepository.forMediaIdsWithRuns]), so they are not
  /// read twice; without it they are read here.
  Future<Set<String>> upToDate(
    List<MediaItem> items, {
    required SpeciesPackManifest manifest,
    required GeoPoint? Function(MediaItem item) locationOf,
    (
      Map<String, MediaIdentificationRun>,
      Map<String, List<MediaIdentification>>,
    )?
    read,
  }) async {
    final ids = [for (final m in items) m.id];
    final (runs, stored) =
        read ??
        await _identifications.forMediaIdsWithRuns(ids, withPaths: false);
    final current = <String>{};
    // Read once for every item, and only when some run names its maker.
    final me = runs.values.any((r) => r.analysedBy != null)
        ? await _deviceId()
        : null;
    for (final item in items) {
      final run = runs[item.id];
      if (run == null) continue;
      final cell = _regionCell(manifest, locationOf(item));
      final madeHere = run.analysedBy == null || _madeBy(run, me);
      final crops = await _cropsPresent(_crops, item.id, [
        for (final i in visibleRows(
          run,
          stored[item.id] ?? const <MediaIdentification>[],
        ))
          if (!i.isPending) i,
      ]);
      // Embeddings only choose between naming again and looking again,
      // never whether there is something to do.
      final nothingToDo = item.mediaType == MediaType.video
          ? decideVideoRefresh(
                  run: run,
                  packVersion: manifest.packVersion,
                  detectorId: _runDetectorId(manifest, video: true),
                  classifierId: manifest.classifier.embeddingId,
                  cell: cell,
                  cropsPresent: crops,
                  embeddingsPresent: true,
                  madeHere: madeHere,
                ) ==
                VideoRefreshAction.none
          : decideRefresh(
                  run: run,
                  packVersion: manifest.packVersion,
                  detectorId: _runDetectorId(manifest, video: false),
                  classifierId: manifest.classifier.embeddingId,
                  cell: cell,
                  cropsPresent: crops,
                  embeddingsPresent: true,
                  madeHere: madeHere,
                ) ==
                RefreshAction.none;
      if (nothingToDo) current.add(item.id);
    }
    return current;
  }
}

/// The detector id a current run holds: the pack's detector set, and for
/// a video the tracker version too ([videoRunDetectorId]). One rule for
/// processing and for what counts as up to date.
String _runDetectorId(SpeciesPackManifest manifest, {required bool video}) =>
    video ? videoRunDetectorId(manifest.detectorSetId) : manifest.detectorSetId;

/// [location]'s cell in [manifest]'s region grid. A position that is not a
/// number (a bad EXIF read) is no position: the item is named without a
/// region rather than not at all.
int? _regionCell(SpeciesPackManifest manifest, GeoPoint? location) =>
    location == null ||
        !location.latitude.isFinite ||
        !location.longitude.isFinite
    ? null
    : RegionGrid(
        cellDegrees: manifest.region.cellDegrees,
      ).cellOf(location.latitude, location.longitude);

/// Whether the crops of [named] that processing needs are on this device.
/// A suggestion's crop must be here. A decided identification's crop is
/// restored by analysing once on this device (after a restore onto a new
/// one); if that analysis could not bring it back, it stays without one
/// rather than the item being analysed at every opening.
Future<bool> _cropsPresent(
  IdentificationCropStore crops,
  String mediaId,
  List<MediaIdentification> named,
) async {
  final undecided = [
    for (final i in named)
      if (i.decision == IdentificationDecision.undecided) i.id,
  ];
  return await crops.allPresent(mediaId, undecided) &&
      (undecided.length == named.length ||
          await crops.wasAnalysedHere(mediaId));
}
