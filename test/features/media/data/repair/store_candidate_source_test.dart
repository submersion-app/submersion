import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/services/repair/store_candidate_source.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

MediaItem broken(
  String id, {
  String? contentHash,
  DateTime? remoteUploadedAt,
  String? remoteStoreId,
}) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  originalFilename: '$id.jpg',
  contentHash: contentHash,
  remoteUploadedAt: remoteUploadedAt,
  remoteStoreId: remoteStoreId,
  isOrphaned: true,
  takenAt: DateTime(2026, 6, 1),
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 6, 1),
);

Future<String?> attachedToB() async => 'store-b';

void main() {
  final stamped = broken(
    'a',
    contentHash: 'H1',
    remoteUploadedAt: DateTime.utc(2026),
  );

  test('stamped rows qualify; HEAD verifies against the object key', () async {
    final seenKeys = <String>[];
    final source = StoreCandidateSource(
      attachedStoreId: attachedToB,
      head: (key) async {
        seenKeys.add(key);
        return StoreObjectInfo(
          key: key,
          sizeBytes: 9,
          lastModified: DateTime.utc(2026),
        );
      },
    );

    final harvest = await source.harvest([stamped, broken('unstamped')]);

    final candidate = harvest.byFilename['a.jpg']!.single;
    expect(candidate.isStore, isTrue);
    expect(candidate.verified, isTrue);
    expect(harvest.byFilename.containsKey('unstamped.jpg'), isFalse);
    expect(seenKeys.single, StoreKeys.objectKey('H1', extension: 'jpg'));
  });

  test('a missing object leaves the candidate unverified', () async {
    final source = StoreCandidateSource(
      attachedStoreId: attachedToB,
      head: (key) async => null,
    );
    final harvest = await source.harvest([stamped]);
    expect(harvest.byFilename['a.jpg']!.single.verified, isFalse);
  });

  test('no head function still qualifies stamped rows, unverified', () async {
    final source = StoreCandidateSource(
      attachedStoreId: attachedToB,
      head: null,
    );
    final harvest = await source.harvest([stamped]);
    expect(harvest.byFilename['a.jpg']!.single.verified, isFalse);
  });

  test('a throwing HEAD is best-effort, not fatal', () async {
    final source = StoreCandidateSource(
      attachedStoreId: attachedToB,
      head: (key) async => throw Exception('offline'),
    );
    final harvest = await source.harvest([stamped]);
    expect(harvest.byFilename['a.jpg']!.single.verified, isFalse);
  });

  group('stamps are read through the attached store (issue #3482)', () {
    MediaItem ownedBy(String? store) => broken(
      'a',
      contentHash: 'H1',
      remoteUploadedAt: DateTime.utc(2026),
      remoteStoreId: store,
    );

    Future<StoreObjectInfo?> found(String key) async => StoreObjectInfo(
      key: key,
      sizeBytes: 9,
      lastModified: DateTime.utc(2026),
    );

    test('a row stamped only for another store is not a candidate', () async {
      final heads = <String>[];
      final source = StoreCandidateSource(
        attachedStoreId: attachedToB,
        head: (key) async {
          heads.add(key);
          return null;
        },
      );

      final harvest = await source.harvest([ownedBy('store-a')]);

      expect(harvest.byFilename, isEmpty);
      expect(heads, isEmpty, reason: 'no HEAD for a row that cannot qualify');
    });

    test('a row stamped for the attached store still qualifies', () async {
      final source = StoreCandidateSource(
        attachedStoreId: attachedToB,
        head: found,
      );
      final harvest = await source.harvest([ownedBy('store-b')]);
      expect(harvest.byFilename['a.jpg']!.single.verified, isTrue);
    });

    test('a stamp naming no store stands for the attached store', () async {
      final source = StoreCandidateSource(
        attachedStoreId: attachedToB,
        head: found,
      );
      final harvest = await source.harvest([ownedBy(null)]);
      expect(harvest.byFilename['a.jpg']!.single.isStore, isTrue);
    });

    test('a detached device has no store candidates at all', () async {
      final source = StoreCandidateSource(
        attachedStoreId: () async => null,
        head: found,
      );
      final harvest = await source.harvest([ownedBy(null), ownedBy('store-a')]);
      expect(harvest.byFilename, isEmpty);
    });
  });
}
