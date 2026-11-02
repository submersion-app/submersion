import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/thumbnail_generator.dart';
import 'package:submersion/features/media_store/domain/media_backup_status.dart';

/// One-time repair for PDF thumbs uploaded before the whole-page render fix
/// (issue #3996), which hold a crop of the page. A device without the PDF has
/// nothing else to draw a tile from, so the crop would stay there for good:
/// the upload pipeline never revisits a stamped row, and head() would keep
/// the old object if it did.
///
/// So, once per device: render every PDF this device imported again, overwrite
/// its stored thumb, and stamp the row. The stamp syncs, and it is how a peer
/// learns its cached copy is the old one (MediaStoreResolver). The PDF itself
/// is not uploaded again.
///
/// Runs beside the transfer queue rather than in it. The pipeline would stage
/// and hash the whole PDF to replace a few kilobytes, and a PDF that has since
/// moved would show in Transfers as a failed upload the diver cannot act on.
///
/// Flagged in SharedPreferences like [MediaOriginRepublishSweep]: set only
/// after a whole pass, so a store failure retries next launch. A PDF that
/// cannot be rendered does not hold the flag back, since a later launch has
/// no better chance of reading it; it keeps the thumb it has.
class PdfThumbRefreshSweep {
  PdfThumbRefreshSweep({
    required MediaRepository mediaRepository,
    required ThumbnailGenerator thumbnails,
    required MediaObjectStore store,
    required String storeId,
    required Future<String> Function() deviceId,
    required Future<bool> Function() mayUpload,
    required Future<bool> Function() takesOver,
    required SharedPreferences prefs,
    DateTime Function()? now,
  }) : _mediaRepository = mediaRepository,
       _thumbnails = thumbnails,
       _store = store,
       _storeId = storeId,
       _deviceId = deviceId,
       _mayUpload = mayUpload,
       _takesOver = takesOver,
       _prefs = prefs,
       _now = now ?? DateTime.now;

  static const String doneFlagKey = 'media_pdf_thumb_refresh_v1';

  /// Whether this device has already done the repair. Cheap, so callers can
  /// ask before building anything the sweep would need.
  static bool isDone(SharedPreferences prefs) =>
      prefs.getBool(doneFlagKey) ?? false;

  final MediaRepository _mediaRepository;
  final ThumbnailGenerator _thumbnails;
  final MediaObjectStore _store;
  final String _storeId;
  final Future<String> Function() _deviceId;

  /// The transfer queue's own holds, asked before any work: offline, a
  /// cellular policy, or a store that fails its marker check.
  final Future<bool> Function() _mayUpload;

  /// Asked inside the stamp's transaction, as the pipeline's stamps do: a
  /// device can move the library to another store during a pass.
  final Future<bool> Function() _takesOver;
  final SharedPreferences _prefs;
  final DateTime Function() _now;
  final _log = LoggerService.forClass(PdfThumbRefreshSweep);

  /// Runs the repair and returns how many thumbs it replaced, or null when
  /// it already ran, was held, or could not finish (logged; the flag stays
  /// unset so the next launch retries).
  Future<int?> run() async {
    if (isDone(_prefs)) return null;
    try {
      if (!await _mayUpload()) return null;
      final rows = await _mediaRepository.getDocumentsWithStoredThumbOwnedBy(
        await _deviceId(),
      );
      var refreshed = 0;
      for (final row in rows) {
        if (await _refresh(stampsInStore(row, _storeId))) refreshed++;
      }
      await _prefs.setBool(doneFlagKey, true);
      _log.info('PDF thumb refresh done: replaced $refreshed');
      return refreshed;
    } on Object catch (e, stackTrace) {
      _log.error(
        'PDF thumb refresh failed; will retry next launch',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<bool> _refresh(MediaItem item) async {
    final hash = item.contentHash;
    if (!item.isPdf || item.remoteThumbUploadedAt == null || hash == null) {
      return false;
    }
    final thumb = await _thumbnails.generateFor(item);
    if (thumb == null) return false;
    try {
      await _store.putFile(
        StoreKeys.thumbKey(hash),
        thumb,
        contentType: 'image/jpeg',
      );
      return await _mediaRepository.stampRemoteThumbUploaded(
        item.id,
        uploadedAt: _now(),
        storeId: _storeId,
        takesOver: _takesOver,
      );
    } finally {
      if (await thumb.exists()) await thumb.delete();
    }
  }
}
