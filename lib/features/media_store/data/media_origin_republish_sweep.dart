import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_item_verifier.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// What one run of [MediaOriginRepublishSweep] did.
typedef MediaOriginRepublishOutcome = ({
  /// Own rows that carried the "missing" flag and were re-checked.
  int rechecked,

  /// Of those, rows whose file turned out to be present, so the flag came off.
  int unflagged,

  /// Own store-stamped rows marked pending so peers receive the stamps again.
  int republished,
});

/// One-time repair for libraries damaged before the origin-device fix.
///
/// Until `LocalFileResolver` honoured `originDeviceId`, a device that merely
/// rendered another device's local-file row flagged it "missing". That write
/// made the row locally pending, and sync's merge skips a peer's copy of any
/// pending row, so the importing device's cloud stamps (`remoteUploadedAt`
/// and friends) were dropped on arrival and never re-sent. The importing
/// device still has the stamps, and usually the peer's flag as well.
///
/// So, once per device: re-check every own row that carries the flag (a
/// present file clears it, through the verifier's own write discipline), and
/// mark every own store-stamped row pending so the next changeset carries
/// the stamps to every peer. Peers apply them as long as nothing is pending
/// on their side, which the resolver fix guarantees for rows they do not own.
///
/// Rows another device imported are left alone in both steps: this device
/// cannot read them and has nothing of theirs to republish.
///
/// Flagged in SharedPreferences like `AccountStartupMigration`: the flag is
/// set only after both steps succeed, so a failed launch retries. Every step
/// is idempotent (a re-check writes the same verdict; a republish only bumps
/// the row's clock).
class MediaOriginRepublishSweep {
  MediaOriginRepublishSweep({
    required MediaRepository mediaRepository,
    required MediaItemVerifier verifier,
    required Future<String> Function() deviceId,
    required SharedPreferences prefs,
  }) : _mediaRepository = mediaRepository,
       _verifier = verifier,
       _deviceId = deviceId,
       _prefs = prefs;

  static const String doneFlagKey = 'media_origin_republish_v1';

  /// Whether this device has already done the repair. Cheap, so callers can
  /// ask before building anything the sweep would need.
  static bool isDone(SharedPreferences prefs) =>
      prefs.getBool(doneFlagKey) ?? false;

  final MediaRepository _mediaRepository;
  final MediaItemVerifier _verifier;
  final Future<String> Function() _deviceId;
  final SharedPreferences _prefs;
  final _log = LoggerService.forClass(MediaOriginRepublishSweep);

  /// Runs the repair, or returns null when it already ran or could not
  /// complete (logged; the flag stays unset so the next launch retries).
  Future<MediaOriginRepublishOutcome?> run() async {
    if (isDone(_prefs)) return null;
    try {
      final me = await _deviceId();

      final flagged = await _mediaRepository.getOrphanedMediaOwnedBy(me);
      var unflagged = 0;
      for (final item in flagged) {
        // verify never throws by contract; it persists the verdict itself.
        if (await _verifier.verify(item) == VerifyResult.available) {
          unflagged++;
        }
      }

      final republished = await _mediaRepository.republishForSync(
        await _mediaRepository.getStoreStampedMediaIdsOwnedBy(me),
      );

      await _prefs.setBool(doneFlagKey, true);
      final outcome = (
        rechecked: flagged.length,
        unflagged: unflagged,
        republished: republished,
      );
      _log.info(
        'Origin republish done: rechecked ${outcome.rechecked}, '
        'unflagged ${outcome.unflagged}, republished ${outcome.republished}',
      );
      return outcome;
    } on Object catch (e, stackTrace) {
      _log.error(
        'Origin republish failed; will retry next launch',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
