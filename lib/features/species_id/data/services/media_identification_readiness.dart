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
    // A video's tracks group by species as the cap groups them, which a
    // tag of another species than the app's guess changes (issue #5032).
    final videos = [
      for (final m in items)
        if (m.mediaType == MediaType.video && runs.containsKey(m.id)) m.id,
    ];
    final tags = videos.isEmpty
        ? const <String, List<TaggedSpecies>>{}
        : await _identifications.taggedSpeciesFor(videos);
    for (final item in items) {
      final run = runs[item.id];
      if (run == null) continue;
      final cell = _regionCell(manifest, locationOf(item));
      final madeHere = run.analysedBy == null || _madeBy(run, me);
      // Embeddings only choose between naming again and looking again,
      // never whether there is something to do.
      bool nothingToDo({required bool crops}) =>
          item.mediaType == MediaType.video
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
      // Missing crops only ever add work, so an item with work even with
      // its crops counted present has work: its crops on disk are not read
      // (issue #5127, where a whole logbook is counted).
      if (!nothingToDo(crops: true)) continue;
      final crops = await _cropsPresent(_crops, item.id, [
        for (final i in visibleRows(
          run,
          stored[item.id] ?? const <MediaIdentification>[],
        ))
          if (!i.isPending) i,
      ], tags: tags[item.id] ?? const []);
      if (nothingToDo(crops: crops)) current.add(item.id);
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
///
/// A video keeps only a few crops of each species (issue #5032), so a
/// track's crop counts per group ([cropGroupKey]): a group with an
/// undecided track needs a crop on at least one of its tracks, never on
/// every one, or a video would be scanned again for crops the cap dropped.
/// A claimed track asks for none: its crop may be one the cap dropped.
Future<bool> _cropsPresent(
  IdentificationCropStore crops,
  String mediaId,
  List<MediaIdentification> named, {
  List<TaggedSpecies> tags = const [],
}) async {
  final undecided = [
    for (final i in named)
      if (i.decision == IdentificationDecision.undecided) i,
  ];
  final present = named.any((i) => i.isTrack)
      ? await _groupsCropped(crops, mediaId, named, tags, [
          // A fish claimed from the frame is often one whose crop the cap
          // dropped; claiming it must not scan the whole video again.
          for (final i in undecided)
            if (i.claimedSpeciesId == null) i,
        ])
      : await crops.allPresent(mediaId, [for (final i in undecided) i.id]);
  return present &&
      (undecided.length == named.length ||
          await crops.wasAnalysedHere(mediaId));
}

/// Whether every group of [named] tracks holding one of [undecided] has a
/// crop on at least one of its tracks.
Future<bool> _groupsCropped(
  IdentificationCropStore crops,
  String mediaId,
  List<MediaIdentification> named,
  List<TaggedSpecies> tags,
  List<MediaIdentification> undecided,
) async {
  if (undecided.isEmpty) return true;
  final present = await crops.presentAmong(mediaId, [
    for (final i in named) i.id,
  ]);
  final cropped = {
    for (final i in named)
      if (present.contains(i.id)) cropGroupKey(i, tags: tags),
  };
  return undecided.every((i) => cropped.contains(cropGroupKey(i, tags: tags)));
}
