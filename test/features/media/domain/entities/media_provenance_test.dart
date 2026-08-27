import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_provenance.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/domain/media_backup_status.dart';

MediaItem _item({
  MediaSourceType sourceType = MediaSourceType.platformGallery,
  String? platformAssetId,
  String? localPath,
  String? filePath,
  String? bookmarkRef,
  String? url,
  String? remoteAssetId,
  String? contentHash,
  String? originDeviceId,
  bool isOrphaned = false,
  bool retainInLibrary = false,
  DateTime? lastVerifiedAt,
  DateTime? remoteUploadedAt,
  DateTime? remoteThumbUploadedAt,
  DateTime? remoteCompressedUploadedAt,
  MediaType mediaType = MediaType.photo,
}) => MediaItem(
  id: 'm1',
  mediaType: mediaType,
  sourceType: sourceType,
  platformAssetId: platformAssetId,
  localPath: localPath,
  filePath: filePath,
  bookmarkRef: bookmarkRef,
  url: url,
  remoteAssetId: remoteAssetId,
  contentHash: contentHash,
  originDeviceId: originDeviceId,
  isOrphaned: isOrphaned,
  retainInLibrary: retainInLibrary,
  lastVerifiedAt: lastVerifiedAt,
  remoteUploadedAt: remoteUploadedAt,
  remoteThumbUploadedAt: remoteThumbUploadedAt,
  remoteCompressedUploadedAt: remoteCompressedUploadedAt,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

MediaProvenance _of(
  MediaItem item, {
  bool storeAttached = true,
  QueueFacts? queue,
}) => MediaProvenance.from(item, storeAttached: storeAttached, queue: queue);

void main() {
  group('OriginFacts pointer', () {
    test('a gallery row reports its asset id', () {
      final p = _of(_item(platformAssetId: 'asset-1'));
      expect(p.origin.sourceType, MediaSourceType.platformGallery);
      expect(p.origin.pointer, 'asset-1');
    });

    test('a localFile row prefers localPath', () {
      final p = _of(
        _item(
          sourceType: MediaSourceType.localFile,
          localPath: '/photos/reef.jpg',
          bookmarkRef: 'bm-1',
        ),
      );
      expect(p.origin.pointer, '/photos/reef.jpg');
    });

    test('a localFile row falls back to filePath then bookmarkRef', () {
      expect(
        _of(
          _item(
            sourceType: MediaSourceType.localFile,
            filePath: '/legacy/reef.jpg',
          ),
        ).origin.pointer,
        '/legacy/reef.jpg',
      );
      expect(
        _of(
          _item(sourceType: MediaSourceType.localFile, bookmarkRef: 'bm-1'),
        ).origin.pointer,
        'bm-1',
      );
    });

    test('url-backed rows report the url', () {
      for (final type in [
        MediaSourceType.networkUrl,
        MediaSourceType.manifestEntry,
      ]) {
        expect(
          _of(
            _item(sourceType: type, url: 'https://x.test/a.jpg'),
          ).origin.pointer,
          'https://x.test/a.jpg',
        );
      }
    });

    test('a connector row reports its remote asset id', () {
      expect(
        _of(
          _item(
            sourceType: MediaSourceType.serviceConnector,
            remoteAssetId: 'lr-1',
          ),
        ).origin.pointer,
        'lr-1',
      );
    });

    test('a mediaStore row reports its content hash', () {
      expect(
        _of(
          _item(sourceType: MediaSourceType.mediaStore, contentHash: 'abc'),
        ).origin.pointer,
        'abc',
      );
    });

    test('a signature row has no meaningful pointer', () {
      expect(
        _of(_item(sourceType: MediaSourceType.signature)).origin.pointer,
        isNull,
      );
    });
  });

  group('OriginFacts health', () {
    test('an orphaned row reads missing', () {
      expect(_of(_item(isOrphaned: true)).origin.health, OriginHealth.missing);
    });

    test('a never-verified row reads neverVerified', () {
      expect(_of(_item()).origin.health, OriginHealth.neverVerified);
    });

    test('a verified row reads healthy and keeps its date', () {
      final when = DateTime.utc(2026, 8, 1);
      final origin = _of(_item(lastVerifiedAt: when)).origin;
      expect(origin.health, OriginHealth.healthy);
      expect(origin.lastVerifiedAt, when);
    });

    // In this codebase isOrphaned means the FILE is missing. The orphan
    // sweep's notion of an unlinked row is a different axis, and
    // retainInLibrary belongs to that one, not this one.
    test('retainInLibrary does not affect origin health', () {
      expect(
        _of(
          _item(retainInLibrary: true, lastVerifiedAt: DateTime.utc(2026)),
        ).origin.health,
        OriginHealth.healthy,
      );
      expect(
        _of(_item(retainInLibrary: true, isOrphaned: true)).origin.health,
        OriginHealth.missing,
      );
    });
  });

  group('BackupFacts', () {
    test('url and manifest rows are not eligible for backup', () {
      for (final type in [
        MediaSourceType.networkUrl,
        MediaSourceType.manifestEntry,
        MediaSourceType.mediaStore,
        MediaSourceType.signature,
      ]) {
        final backup = _of(_item(sourceType: type)).backup;
        expect(backup.eligible, isFalse, reason: '$type must be ineligible');
        expect(backup.tier, BackupTier.none);
      }
    });

    test('gallery, localFile and connector rows are eligible', () {
      for (final type in kUploadableSources) {
        expect(_of(_item(sourceType: type)).backup.eligible, isTrue);
      }
    });

    test('no stamps reads none', () {
      expect(_of(_item()).backup.tier, BackupTier.none);
    });

    test('a thumb stamp alone reads thumbOnly', () {
      final backup = _of(
        _item(remoteThumbUploadedAt: DateTime.utc(2026, 7)),
      ).backup;
      expect(backup.tier, BackupTier.thumbOnly);
      expect(backup.thumbUploadedAt, DateTime.utc(2026, 7));
    });

    test('a compressed stamp alone reads renditionOnly', () {
      expect(
        _of(
          _item(remoteCompressedUploadedAt: DateTime.utc(2026, 7)),
        ).backup.tier,
        BackupTier.renditionOnly,
      );
    });

    test('an original stamp reads full and outranks the others', () {
      expect(
        _of(
          _item(
            remoteUploadedAt: DateTime.utc(2026, 7),
            remoteThumbUploadedAt: DateTime.utc(2026, 7),
          ),
        ).backup.tier,
        BackupTier.full,
      );
    });

    // The tier readout is finer grained than isBackedUp but must never
    // disagree with it, since the upload pipeline gates on isBackedUp.
    test('tier agrees with isBackedUp for every stamp combination', () {
      for (final original in [null, DateTime.utc(2026)]) {
        for (final thumb in [null, DateTime.utc(2026)]) {
          for (final rendition in [null, DateTime.utc(2026)]) {
            final item = _item(
              sourceType: MediaSourceType.platformGallery,
              remoteUploadedAt: original,
              remoteThumbUploadedAt: thumb,
              remoteCompressedUploadedAt: rendition,
            );
            final tier = _of(item).backup.tier;
            final backedUp = isBackedUp(item);
            // isBackedUp ignores a thumb-only stamp for non-thumb-only media,
            // so thumbOnly is the one tier that may read "not backed up".
            if (tier == BackupTier.full || tier == BackupTier.renditionOnly) {
              expect(backedUp, isTrue, reason: 'tier $tier');
            }
            if (tier == BackupTier.none) {
              expect(backedUp, isFalse, reason: 'tier $tier');
            }
          }
        }
      }
    });

    test('storeAttached is carried through', () {
      expect(_of(_item(), storeAttached: false).backup.storeAttached, isFalse);
      expect(_of(_item()).backup.storeAttached, isTrue);
    });

    test('a failed queue row carries its state and error', () {
      final backup = _of(
        _item(),
        queue: const QueueFacts(state: 'failed', error: 'network down'),
      ).backup;
      expect(backup.queueState, 'failed');
      expect(backup.queueError, 'network down');
    });

    test('no queue row leaves the queue fields null', () {
      final backup = _of(_item()).backup;
      expect(backup.queueState, isNull);
      expect(backup.queueError, isNull);
    });
  });

  group('ServingFacts', () {
    test('an absent observation is unobserved', () {
      final facts = ServingFacts.from(null);
      expect(facts.observed, isFalse);
      expect(facts.servedFrom, isNull);
      expect(identical(facts, ServingFacts.unobserved), isTrue);
    });

    test('carries the observation through', () {
      final facts = ServingFacts.from(
        ServingObservation(
          servedFrom: ServedFrom.storeCache,
          servedTier: ServedTier.thumbnail,
          failure: null,
          storeFallbackUsed: true,
          observedAt: DateTime.utc(2026, 8, 16),
        ),
      );
      expect(facts.observed, isTrue);
      expect(facts.servedFrom, ServedFrom.storeCache);
      expect(facts.servedTier, ServedTier.thumbnail);
      expect(facts.storeFallbackUsed, isTrue);
      expect(facts.observedAt, DateTime.utc(2026, 8, 16));
    });

    test('a failed observation is observed but has no source', () {
      final facts = ServingFacts.from(
        ServingObservation(
          servedFrom: null,
          servedTier: ServedTier.original,
          failure: UnavailableKind.notFound,
          storeFallbackUsed: true,
          observedAt: DateTime.utc(2026),
        ),
      );
      expect(facts.observed, isTrue);
      expect(facts.servedFrom, isNull);
      expect(facts.failure, UnavailableKind.notFound);
    });
  });
}
