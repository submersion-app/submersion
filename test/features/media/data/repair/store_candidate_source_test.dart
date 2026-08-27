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
}) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  originalFilename: '$id.jpg',
  contentHash: contentHash,
  remoteUploadedAt: remoteUploadedAt,
  isOrphaned: true,
  takenAt: DateTime(2026, 6, 1),
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 6, 1),
);

void main() {
  final stamped = broken(
    'a',
    contentHash: 'H1',
    remoteUploadedAt: DateTime.utc(2026),
  );

  test('stamped rows qualify; HEAD verifies against the object key', () async {
    final seenKeys = <String>[];
    final source = StoreCandidateSource(
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
    final source = StoreCandidateSource(head: (key) async => null);
    final harvest = await source.harvest([stamped]);
    expect(harvest.byFilename['a.jpg']!.single.verified, isFalse);
  });

  test('no head function still qualifies stamped rows, unverified', () async {
    final source = StoreCandidateSource(head: null);
    final harvest = await source.harvest([stamped]);
    expect(harvest.byFilename['a.jpg']!.single.verified, isFalse);
  });

  test('a throwing HEAD is best-effort, not fatal', () async {
    final source = StoreCandidateSource(
      head: (key) async => throw Exception('offline'),
    );
    final harvest = await source.harvest([stamped]);
    expect(harvest.byFilename['a.jpg']!.single.verified, isFalse);
  });
}
