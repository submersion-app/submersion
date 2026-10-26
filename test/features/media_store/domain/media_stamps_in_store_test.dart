// Issue #3482 phase 4: stamps made in another store say nothing about the
// attached one, so every reader sees an item through the attached store.

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_provenance.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/domain/media_backup_status.dart';

void main() {
  final at = DateTime.utc(2026);

  MediaItem item({String? store}) => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    filePath: '/tmp/a.jpg',
    takenAt: at,
    createdAt: at,
    updatedAt: at,
    remoteUploadedAt: at,
    remoteThumbUploadedAt: at,
    remoteCompressedUploadedAt: at,
    compressedLevel: 'high',
    compressedSizeBytes: 10,
    remoteStoreId: store,
  );

  test('stamps made in another store are dropped', () {
    final seen = stampsInStore(item(store: 'store-a'), 'store-b');
    expect(seen.remoteUploadedAt, isNull);
    expect(seen.remoteThumbUploadedAt, isNull);
    expect(seen.remoteCompressedUploadedAt, isNull);
    expect(seen.compressedLevel, isNull);
    expect(isBackedUp(item(store: 'store-a'), storeId: 'store-b'), isFalse);
  });

  test('this store\'s and unclaimed stamps stand', () {
    expect(
      stampsInStore(item(store: 'store-b'), 'store-b').remoteUploadedAt,
      at,
    );
    expect(stampsInStore(item(), 'store-b').remoteUploadedAt, at);
    expect(isBackedUp(item(), storeId: 'store-b'), isTrue);
  });

  test('with no store attached the stamps stand', () {
    expect(stampsInStore(item(store: 'store-a'), null).remoteUploadedAt, at);
  });

  test('the info panel does not call another store\'s copy backed up', () {
    final facts = BackupFacts.from(
      item(store: 'store-a'),
      storeAttached: true,
      storeId: 'store-b',
      queue: null,
    );
    expect(facts.backedUp, isFalse);
    expect(facts.tier, BackupTier.none);
    expect(facts.originalUploadedAt, isNull);
  });

  // Issue #3569: only the library's announced store takes over rows stamped
  // in another store, so two devices on different stores never trade them.
  test(
    'a row is stamped elsewhere only when another store holds its stamps',
    () {
      expect(stampedElsewhere(item(store: 'store-a'), 'store-b'), isTrue);
      expect(stampedElsewhere(item(store: 'store-b'), 'store-b'), isFalse);
      expect(stampedElsewhere(item(), 'store-b'), isFalse);
      expect(stampedElsewhere(item(store: 'store-a'), null), isFalse);
      final cleared = item(store: 'store-a').copyWith(
        remoteUploadedAt: null,
        remoteThumbUploadedAt: null,
        remoteCompressedUploadedAt: null,
      );
      expect(stampedElsewhere(cleared, 'store-b'), isFalse);
    },
  );

  test('only the announced store takes over', () {
    expect(takesOverStores('store-b', 'store-b'), isTrue);
    expect(takesOverStores('store-a', 'store-b'), isFalse);
    expect(takesOverStores('store-a', null), isTrue);
  });
}
