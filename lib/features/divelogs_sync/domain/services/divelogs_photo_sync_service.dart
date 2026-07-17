import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/core/services/divelogs/divelogs_models.dart';
import 'package:submersion/features/divelogs_sync/domain/services/divelogs_sync_planner.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

class PhotoSyncResult {
  final int pulled;
  final int pulledDuplicates;
  final int skippedNoUrl;
  final int pushed;
  final String? error;

  const PhotoSyncResult({
    this.pulled = 0,
    this.pulledDuplicates = 0,
    this.skippedNoUrl = 0,
    this.pushed = 0,
    this.error,
  });

  bool get failed => error != null;
}

/// Create-only photo sync for matched dives (spec Phase 4).
///
/// Pull dedups by SHA-256 of the downloaded bytes against the dive's local
/// photos (there is no remote hash). Push is guarded by the only safe
/// create-only signal the API offers: a dive that has ZERO remote pictures.
/// Dependencies are function-injected so the service stays free of
/// repository/resolver plumbing and is fully unit-testable.
///
/// Certification scans are intentionally excluded: their download URLs are
/// undocumented and the API only accepts scans at certification creation
/// (revisit when Rainer answers).
class DivelogsPhotoSyncService {
  DivelogsPhotoSyncService({
    required DivelogsApiClient api,
    required Future<List<MediaItem>> Function(String diveId) getLocalMedia,
    required Future<Uint8List?> Function(MediaItem item) resolveLocalBytes,
    required Future<void> Function({
      required Uint8List bytes,
      required String filename,
      required String diveId,
      required DateTime takenAt,
    })
    attachToDive,
  }) : _api = api,
       _getLocalMedia = getLocalMedia,
       _resolveLocalBytes = resolveLocalBytes,
       _attachToDive = attachToDive;

  final DivelogsApiClient _api;
  final Future<List<MediaItem>> Function(String diveId) _getLocalMedia;
  final Future<Uint8List?> Function(MediaItem item) _resolveLocalBytes;
  final Future<void> Function({
    required Uint8List bytes,
    required String filename,
    required String diveId,
    required DateTime takenAt,
  })
  _attachToDive;

  Future<PhotoSyncResult> sync(
    List<DivelogsMatchedDive> pairs, {
    void Function(int done, int total)? onProgress,
  }) async {
    var pulled = 0;
    var duplicates = 0;
    var skippedNoUrl = 0;
    var pushed = 0;

    try {
      for (var i = 0; i < pairs.length; i++) {
        final pair = pairs[i];
        final remote = await _api.getPictures(pair.remoteId);
        final withUrl = remote.where((p) => p.url != null).toList();
        skippedNoUrl += remote.length - withUrl.length;

        final localPhotos = (await _getLocalMedia(
          pair.localDiveId,
        )).where((m) => m.mediaType == MediaType.photo).toList();
        final localHashes = <String>{};
        for (final item in localPhotos) {
          final bytes = await _resolveLocalBytes(item);
          if (bytes != null) localHashes.add(sha256.convert(bytes).toString());
        }

        // Pull.
        for (final picture in withUrl) {
          final bytes = await _api.downloadPictureBytes(picture.url!);
          final hash = sha256.convert(bytes).toString();
          if (localHashes.contains(hash)) {
            duplicates++;
            continue;
          }
          await _attachToDive(
            bytes: bytes,
            filename: _filenameFor(picture),
            diveId: pair.localDiveId,
            takenAt: pair.localTime,
          );
          localHashes.add(hash);
          pulled++;
        }

        // Push: only for dives with no remote pictures at all.
        if (remote.isEmpty && localPhotos.isNotEmpty) {
          for (final item in localPhotos) {
            final bytes = await _resolveLocalBytes(item);
            if (bytes == null) continue;
            await _api.postPicture(
              pair.remoteId,
              bytes: bytes,
              filename: item.originalFilename ?? '${item.id}.jpg',
            );
            pushed++;
          }
        }

        onProgress?.call(i + 1, pairs.length);
      }
    } on DivelogsApiException catch (e) {
      return PhotoSyncResult(
        pulled: pulled,
        pulledDuplicates: duplicates,
        skippedNoUrl: skippedNoUrl,
        pushed: pushed,
        error: e.message,
      );
    }

    return PhotoSyncResult(
      pulled: pulled,
      pulledDuplicates: duplicates,
      skippedNoUrl: skippedNoUrl,
      pushed: pushed,
    );
  }

  String _filenameFor(DivelogsPicture picture) {
    final segments = picture.url!.pathSegments;
    if (segments.isNotEmpty && segments.last.isNotEmpty) return segments.last;
    return 'divelogs_${picture.id ?? 'photo'}.jpg';
  }
}
