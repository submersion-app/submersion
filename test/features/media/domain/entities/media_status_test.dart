import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_provenance.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/entities/media_status.dart';

MediaStatus _status({
  MediaSourceType sourceType = MediaSourceType.platformGallery,
  bool missing = false,
  bool uploaded = false,
  bool thumbOnly = false,
  bool storeAttached = true,
  String? queueState,
}) {
  final item = MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: sourceType,
    platformAssetId: 'asset-1',
    isOrphaned: missing,
    lastVerifiedAt: DateTime.utc(2026),
    remoteUploadedAt: uploaded ? DateTime.utc(2026, 7) : null,
    remoteThumbUploadedAt: thumbOnly ? DateTime.utc(2026, 7) : null,
    takenAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  return mediaStatusFor(
    MediaProvenance.from(
      item,
      storeAttached: storeAttached,
      queue: queueState == null ? null : QueueFacts(state: queueState),
    ),
  );
}

void main() {
  test('a healthy backed-up row is silent', () {
    expect(_status(uploaded: true), MediaStatus.none);
  });

  test('a healthy unbacked row with no store attached is silent', () {
    // Nothing to nag about: there is nowhere to back it up to.
    expect(_status(storeAttached: false), MediaStatus.none);
  });

  test('a healthy unbacked row with a store attached reads notBackedUp', () {
    expect(_status(), MediaStatus.notBackedUp);
  });

  group('broken', () {
    test('a missing row with no backup is broken', () {
      expect(_status(missing: true), MediaStatus.broken);
    });

    test('broken outranks a failed transfer', () {
      expect(_status(missing: true, queueState: 'failed'), MediaStatus.broken);
    });

    // The eligibility gate sits BELOW broken, so a dead URL still reports
    // that it is dead rather than going silent.
    test('a missing ineligible row is still broken', () {
      expect(
        _status(sourceType: MediaSourceType.networkUrl, missing: true),
        MediaStatus.broken,
      );
    });

    // Unlike everything below it, broken does not need a store: an item
    // nothing can display is broken whether or not a store is configured.
    test('broken renders with no store attached', () {
      expect(_status(missing: true, storeAttached: false), MediaStatus.broken);
    });

    // A thumbnail is not a backup. BackupTier.thumbOnly is non-none, so
    // inferring coverage from the tier would report a photo as cloud-only
    // when only its thumbnail ever reached the store, and the original is
    // gone for good. isBackedUp is the pipeline's own predicate and says
    // false here, which is what the ladder must follow.
    test('a missing row with only a thumbnail uploaded is broken', () {
      expect(_status(missing: true, thumbOnly: true), MediaStatus.broken);
    });

    // Backed up but unreachable is not "cloud only", it is unviewable.
    test('a missing backed-up row with no store attached is broken', () {
      expect(
        _status(missing: true, uploaded: true, storeAttached: false),
        MediaStatus.broken,
      );
    });
  });

  group('eligibility gate', () {
    test('a healthy ineligible row is silent even with a store attached', () {
      // A URL row is not eligible for backup, which is a different statement
      // from being un-backed-up, and nagging about it would be wrong.
      for (final type in [
        MediaSourceType.networkUrl,
        MediaSourceType.manifestEntry,
        MediaSourceType.mediaStore,
        MediaSourceType.signature,
      ]) {
        expect(_status(sourceType: type), MediaStatus.none, reason: '$type');
      }
    });

    test('an ineligible row ignores a queue row', () {
      expect(
        _status(
          sourceType: MediaSourceType.networkUrl,
          queueState: 'transferring',
        ),
        MediaStatus.none,
      );
    });
  });

  group('transfer states outrank the settled ones', () {
    test('failed', () {
      expect(_status(queueState: 'failed'), MediaStatus.transferFailed);
    });

    test('transferring', () {
      expect(_status(queueState: 'transferring'), MediaStatus.transferring);
    });

    test('pending', () {
      expect(_status(queueState: 'pending'), MediaStatus.queued);
    });

    // Otherwise an in-flight upload would render as cloud_off, and the
    // transfer glyph would never appear at all.
    test('a transfer outranks notBackedUp', () {
      expect(
        _status(queueState: 'transferring'),
        isNot(MediaStatus.notBackedUp),
      );
    });

    test('a settled queue row falls through to the resting state', () {
      expect(_status(queueState: 'done'), MediaStatus.notBackedUp);
      expect(_status(queueState: 'done', uploaded: true), MediaStatus.none);
    });
  });

  group('the ladder follows isBackedUp, not the tier', () {
    test('a thumb-only row still reads notBackedUp', () {
      expect(_status(thumbOnly: true), MediaStatus.notBackedUp);
    });

    test('a compressed rendition does count as backed up', () {
      // isBackedUp accepts the rendition stamp, so the badge must too.
      expect(_status(uploaded: true), MediaStatus.none);
    });
  });

  group('cloudOnly', () {
    test('a missing but backed-up row with a store attached is cloudOnly', () {
      expect(_status(missing: true, uploaded: true), MediaStatus.cloudOnly);
    });

    test('cloudOnly and notBackedUp are mutually exclusive', () {
      // One requires an upload stamp and the other requires its absence, so
      // their relative order in the ladder can never matter.
      expect(_status(missing: true, uploaded: true), MediaStatus.cloudOnly);
      expect(_status(missing: false), MediaStatus.notBackedUp);
    });
  });
}
