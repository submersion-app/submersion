import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_location.dart';
import 'package:submersion/features/species_id/data/services/dive_species_run.dart';
import 'package:submersion/features/species_id/data/services/run_media_resolvers.dart';
import 'package:submersion/features/species_id/domain/entities/species_batch.dart';

/// Counts what Find species over many dives will do, without running the
/// models (issue #5127): which dives have something to do, how many photos
/// and videos it will look at, and how many of those it would download.
///
/// Works in chunks of [chunkSize] dives, so a logbook of thousands keeps
/// only one chunk's media in memory, and reports after each chunk, so the
/// confirmation fills in while it counts. Cancelling the stream stops it
/// after the chunk in progress.
class SpeciesBatchPlanner {
  SpeciesBatchPlanner({
    required Future<Map<String, List<MediaItem>>> Function(List<String> diveIds)
    mediaForDives,
    required Future<Map<String, DiveLocation>> Function(List<String> diveIds)
    placesOf,
    required Future<Set<String>> Function(
      List<MediaItem> items,
      GeoPoint? Function(MediaItem item) locationOf,
    )
    upToDate,
    required Future<Set<String>> Function(List<String> mediaIds)
    withOpenSuggestions,
    required bool Function() canApply,
    required Future<bool> Function(MediaItem item) libraryOriginalHere,
    bool Function(String path)? fileExists,
    this.chunkSize = 250,
  }) : _mediaForDives = mediaForDives,
       _placesOf = placesOf,
       _upToDate = upToDate,
       _withOpenSuggestions = withOpenSuggestions,
       _canApply = canApply,
       _libraryOriginalHere = libraryOriginalHere,
       _fileExists = fileExists;

  final Future<Map<String, List<MediaItem>>> Function(List<String>)
  _mediaForDives;
  final Future<Map<String, DiveLocation>> Function(List<String>) _placesOf;
  final Future<Set<String>> Function(
    List<MediaItem>,
    GeoPoint? Function(MediaItem),
  )
  _upToDate;
  final Future<Set<String>> Function(List<String>) _withOpenSuggestions;
  final bool Function() _canApply;
  final Future<bool> Function(MediaItem) _libraryOriginalHere;
  final bool Function(String)? _fileExists;
  final int chunkSize;

  /// The plan for [diveIds], growing chunk by chunk; the last one is whole.
  /// Always yields at least once.
  Stream<SpeciesBatchPlan> plan(List<String> diveIds) async* {
    var plan = const SpeciesBatchPlan();
    if (diveIds.isEmpty) {
      yield plan;
      return;
    }
    // Asked once: the setting does not change while it counts.
    final canApply = _canApply();
    for (var start = 0; start < diveIds.length; start += chunkSize) {
      final end = start + chunkSize < diveIds.length
          ? start + chunkSize
          : diveIds.length;
      final chunk = diveIds.sublist(start, end);
      final counted = await _planChunk(chunk, canApply: canApply);
      plan = SpeciesBatchPlan(
        dives: [...plan.dives, ...counted.dives],
        notOnDevice: plan.notOnDevice + counted.notOnDevice,
        divesAsked: end,
      );
      yield plan;
    }
  }

  Future<SpeciesBatchPlan> _planChunk(
    List<String> chunk, {
    required bool canApply,
  }) async {
    final byDive = await _mediaForDives(chunk);
    final looked = {
      for (final id in chunk)
        id: [
          for (final m in byDive[id] ?? const <MediaItem>[])
            if (m.mediaType == MediaType.photo ||
                m.mediaType == MediaType.video)
              m,
        ],
    };
    final withMedia = [
      for (final id in chunk)
        if (looked[id]!.isNotEmpty) id,
    ];
    if (withMedia.isEmpty) return const SpeciesBatchPlan();

    final places = await _placesOf(withMedia);
    final diveOf = {
      for (final id in withMedia)
        for (final m in looked[id]!) m.id: id,
    };
    final all = [for (final id in withMedia) ...looked[id]!];
    final current = await _upToDate(all, (m) {
      final place = places[diveOf[m.id]];
      return mediaLocation(
        m,
        siteLocation: place?.site,
        entryLocation: place?.entry,
      );
    });
    // Only an up to date dive needs this: one with work runs anyway.
    final open = canApply
        ? await _withOpenSuggestions([
            for (final m in all)
              if (current.contains(m.id)) m.id,
          ])
        : const <String>{};

    final dives = <PlannedDive>[];
    for (final id in withMedia) {
      final items = looked[id]!;
      final toLookAt = items.where((m) => !current.contains(m.id)).length;
      final canTag = items.any((m) => open.contains(m.id));
      if (toLookAt == 0 && !canTag) continue;
      dives.add(
        PlannedDive(diveId: id, items: items.length, toLookAt: toLookAt),
      );
    }
    final notOnDevice = await notOnDeviceCount(
      [for (final d in dives) ...looked[d.diveId]!],
      checked: current,
      libraryOriginalHere: _libraryOriginalHere,
      fileExists: _fileExists,
    );
    return SpeciesBatchPlan(dives: dives, notOnDevice: notOnDevice);
  }
}
