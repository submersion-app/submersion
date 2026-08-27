import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_item_verifier.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

class _StubResolver implements MediaSourceResolver {
  _StubResolver(this._result);

  final VerifyResult _result;

  @override
  MediaSourceType get sourceType => MediaSourceType.localFile;

  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.notFound);

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) async => const UnavailableData(kind: UnavailableKind.notFound);

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;

  @override
  Future<VerifyResult> verify(MediaItem item) async => _result;
}

class _CapturingRepository implements MediaRepository {
  final List<MediaItem> written = [];

  @override
  Future<void> updateMedia(MediaItem item) async => written.add(item);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

MediaItem _item({bool isOrphaned = false}) => MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  localPath: '/photos/reef.jpg',
  isOrphaned: isOrphaned,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late _CapturingRepository repository;
  final stamp = DateTime.utc(2026, 8, 17, 12);

  setUp(() => repository = _CapturingRepository());

  MediaItemVerifier build(VerifyResult result) => MediaItemVerifier(
    registry: MediaSourceResolverRegistry({
      MediaSourceType.localFile: _StubResolver(result),
    }),
    repository: repository,
    now: () => stamp,
  );

  test(
    'an available result clears the orphan flag and stamps the date',
    () async {
      final result = await build(
        VerifyResult.available,
      ).verify(_item(isOrphaned: true));

      expect(result, VerifyResult.available);
      expect(repository.written.single.isOrphaned, isFalse);
      expect(repository.written.single.lastVerifiedAt, stamp);
    },
  );

  test('notFound sets the orphan flag and stamps the date', () async {
    final result = await build(VerifyResult.notFound).verify(_item());

    expect(result, VerifyResult.notFound);
    expect(repository.written.single.isOrphaned, isTrue);
    expect(repository.written.single.lastVerifiedAt, stamp);
  });

  // notFound is the ONLY positive finding. Everything below describes a
  // failure to REACH the source, which says nothing about whether the bytes
  // still exist, and the orphan flag is sticky and syncs.
  test('unauthenticated stamps the date but never orphans', () async {
    // Emitted when a Lightroom account is not connected
    // (connector_media_resolver.dart:67) and on a 401. Orphaning here would
    // empty a connector library because a token expired.
    final result = await build(
      VerifyResult.unauthenticated,
    ).verify(_item(isOrphaned: false));

    expect(result, VerifyResult.unauthenticated);
    expect(repository.written.single.isOrphaned, isFalse);
    expect(repository.written.single.lastVerifiedAt, stamp);
  });

  test('fromOtherDevice stamps the date but never orphans', () async {
    // "Not resolvable HERE" is not "absent". Orphaning would mark a row
    // missing on this device and sync that claim to the device the file
    // actually lives on.
    final result = await build(
      VerifyResult.fromOtherDevice,
    ).verify(_item(isOrphaned: false));

    expect(result, VerifyResult.fromOtherDevice);
    expect(repository.written.single.isOrphaned, isFalse);
    expect(repository.written.single.lastVerifiedAt, stamp);
  });

  test('neither clears an existing orphan flag', () async {
    await build(VerifyResult.fromOtherDevice).verify(_item(isOrphaned: true));

    expect(repository.written.single.isOrphaned, isTrue);
  });

  // volumeOffline and transientError are recoverable conditions, not dead
  // pointers. Flagging them would let a check mark a row missing while the
  // share is merely unmounted or the file is temporarily unreadable, and the
  // orphan flag is sticky, so the row would stay wrong after recovery.
  test(
    'volumeOffline stamps the date but leaves the orphan flag alone',
    () async {
      final result = await build(
        VerifyResult.volumeOffline,
      ).verify(_item(isOrphaned: false));

      expect(result, VerifyResult.volumeOffline);
      expect(repository.written.single.isOrphaned, isFalse);
      expect(repository.written.single.lastVerifiedAt, stamp);
    },
  );

  test('transientError does not clear an existing orphan flag', () async {
    await build(VerifyResult.transientError).verify(_item(isOrphaned: true));

    expect(repository.written.single.isOrphaned, isTrue);
    expect(repository.written.single.lastVerifiedAt, stamp);
  });

  // accessDenied is the one that used to arrive as notFound. A revoked photo
  // permission makes EVERY gallery row fail to resolve, so treating it as a
  // dead pointer marked an entire library orphaned, and markRecordPending
  // replicated that claim to every other device.
  test('accessDenied stamps the date but never orphans a row', () async {
    final result = await build(
      VerifyResult.accessDenied,
    ).verify(_item(isOrphaned: false));

    expect(result, VerifyResult.accessDenied);
    expect(repository.written.single.isOrphaned, isFalse);
    expect(repository.written.single.lastVerifiedAt, stamp);
  });

  test('accessDenied does not clear an existing orphan flag either', () async {
    // Symmetric to the transientError case: learning nothing must not move
    // the flag in either direction.
    await build(VerifyResult.accessDenied).verify(_item(isOrphaned: true));

    expect(repository.written.single.isOrphaned, isTrue);
    expect(repository.written.single.lastVerifiedAt, stamp);
  });

  // A row whose source type has no registered resolver is a programmer
  // error, but its blast radius has to stay one item, and nothing was
  // actually checked so nothing should be written.
  test(
    'an unregistered source type reports transientError and writes nothing',
    () async {
      final verifier = MediaItemVerifier(
        registry: MediaSourceResolverRegistry(const {}),
        repository: repository,
        now: () => stamp,
      );

      final result = await verifier.verify(_item());

      expect(result, VerifyResult.transientError);
      expect(repository.written, isEmpty);
    },
  );
}
