import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Finds the gallery asset a linked row stands for on this device. Production
/// passes [AssetResolutionService.resolveAssetId].
typedef LinkedAssetResolver = Future<ResolutionResult> Function(MediaItem item);

/// Answers "is this gallery asset already linked?" on the device asking.
///
/// A row's synced `platformAssetId` is the PhotoKit local identifier of the
/// device that linked it, and Apple gives every device its own identifier for
/// the same photo, even within one iCloud Photo Library. Comparing gallery
/// assets against the synced id alone misses every photo linked on another
/// device, so each gallery scan or pick offered them again and importing
/// created duplicate rows (issue #885). This class also counts the id each
/// row resolves to here, through the same [AssetResolutionService] tiers and
/// per-device cache that display the row.
class LinkedGalleryAssets {
  /// A null [resolve] consults nothing on this device: only synced ids count,
  /// and the burst rule never applies.
  const LinkedGalleryAssets({LinkedAssetResolver? resolve})
    : _resolve = resolve;

  final LinkedAssetResolver? _resolve;

  static final _log = LoggerService.forClass(LinkedGalleryAssets);

  /// Every gallery asset id on this device that [linked] rows already stand
  /// for: each row's synced id, plus the id it resolves to here.
  ///
  /// For surfaces that mark linked assets before the candidates are known
  /// (the photo picker, the trip scan). Without candidates there is nothing
  /// to skip resolution for and no burst rule to apply, so every row is
  /// resolved; the import itself still goes through [withoutLinked].
  Future<Set<String>> idsOnThisDevice(Iterable<MediaItem> linked) async {
    final ids = <String>{};
    for (final row in linked) {
      final syncedId = row.platformAssetId;
      if (syncedId == null) continue;
      ids.add(syncedId);
      final localId = _resolvedId(await _tryResolve(row));
      if (localId != null) ids.add(localId);
    }
    return ids;
  }

  /// [candidates] minus every asset that [linked] rows already stand for.
  ///
  /// A row whose synced id is itself a candidate needs no lookup, which is
  /// every row on the device that linked it. Only the rest are resolved, and
  /// only until every candidate is accounted for.
  ///
  /// Rows the gallery was consulted for but that did not land on a candidate
  /// then go through the burst rule: see [_claimBursts].
  Future<List<AssetInfo>> withoutLinked({
    required List<AssetInfo> candidates,
    required Iterable<MediaItem> linked,
  }) async {
    final candidateIds = {for (final c in candidates) c.id};
    final claimed = <String>{};
    final notYetMatched = <MediaItem>[];
    for (final row in linked) {
      final syncedId = row.platformAssetId;
      if (syncedId == null) continue;
      if (candidateIds.contains(syncedId)) {
        claimed.add(syncedId);
      } else {
        notYetMatched.add(row);
      }
    }

    final burstPool = <MediaItem>[];
    for (final row in notYetMatched) {
      if (claimed.length == candidateIds.length) break;
      final result = await _tryResolve(row);
      final localId = _resolvedId(result);
      if (localId != null && candidateIds.contains(localId)) {
        claimed.add(localId);
      } else if (localId != null ||
          result?.status == ResolutionStatus.unavailable) {
        // The gallery was consulted and either found no unique match (a
        // burst, typically), or the row maps to an asset this scan did not
        // return. The resolver trusts its cache without re-proving it, so
        // the latter can be a stale id for a photo that is right here.
        burstPool.add(row);
      }
      // Otherwise nothing was learned: no resolver, the resolver failed, or
      // the gallery could not be consulted. A row nobody looked at must not
      // hide a photo.
    }

    final remaining = candidates.where((c) => !claimed.contains(c.id)).toList();
    claimed.addAll(_claimBursts(remaining, burstPool));
    return candidates.where((c) => !claimed.contains(c.id)).toList();
  }

  /// The burst rule, for rows the gallery was consulted for that did not
  /// resolve to a candidate.
  ///
  /// Frames shot in the same second at the same size cannot be told apart by
  /// capture time and dimensions, so the resolver refuses to bind any of
  /// them. What can still be decided is whether they are all linked already:
  /// when at least as many such rows match a frame (second + size) as
  /// there are candidates for it, every candidate is accounted for. With
  /// fewer rows than candidates at least one frame is new and there is no
  /// telling which, so all of them are offered.
  ///
  /// A row whose two readings of its stored time (see
  /// [AssetResolutionService.captureSecondsOf]) land on two different frames
  /// is counted towards neither.
  static Set<String> _claimBursts(
    List<AssetInfo> remaining,
    List<MediaItem> rows,
  ) {
    if (remaining.isEmpty || rows.isEmpty) return const {};

    final byFrame = <(int, int, int), List<AssetInfo>>{};
    for (final c in remaining) {
      byFrame.putIfAbsent(_frameOf(c), () => []).add(c);
    }

    final rowsPerFrame = <(int, int, int), int>{};
    for (final row in rows) {
      final width = row.width;
      final height = row.height;
      if (width == null || height == null) continue;
      // Looked up by key rather than tested against every frame: a trip scan
      // can return thousands of candidates.
      final frames = [
        for (final second in AssetResolutionService.captureSecondsOf(row))
          if (byFrame.containsKey((second, width, height)))
            (second, width, height),
      ];
      if (frames.length == 1) {
        rowsPerFrame.update(frames.single, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    return {
      for (final MapEntry(key: frame, value: rows) in rowsPerFrame.entries)
        if (rows >= byFrame[frame]!.length)
          for (final c in byFrame[frame]!) c.id,
    };
  }

  /// A candidate's frame: capture second and pixel size, in the same terms
  /// as [AssetResolutionService.captureSecondsOf]. photo_manager reports
  /// whole seconds, so the division drops nothing.
  static (int, int, int) _frameOf(AssetInfo c) =>
      (c.createDateTime.millisecondsSinceEpoch ~/ 1000, c.width, c.height);

  static String? _resolvedId(ResolutionResult? result) =>
      result?.status == ResolutionStatus.resolved ? result?.localAssetId : null;

  /// Resolves [row], or returns null when there is no resolver or it fails.
  /// A failure only costs this row its local id; it must not abort a scan or
  /// an import that is otherwise fine.
  Future<ResolutionResult?> _tryResolve(MediaItem row) async {
    final resolve = _resolve;
    if (resolve == null) return null;
    try {
      return await resolve(row);
    } catch (e, stackTrace) {
      _log.warning(
        'Could not resolve linked media ${row.id} on this device',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
