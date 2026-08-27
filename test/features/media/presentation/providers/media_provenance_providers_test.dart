import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_provenance.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

MediaItem _item({
  MediaSourceType sourceType = MediaSourceType.platformGallery,
  DateTime? remoteUploadedAt,
}) => MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  sourceType: sourceType,
  platformAssetId: 'asset-1',
  remoteUploadedAt: remoteUploadedAt,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _FakeStoresRepository implements MediaStoresRepository {
  _FakeStoresRepository(this._active, {Stream<void>? changes})
    : _changes = changes ?? const Stream<void>.empty();

  final MediaStoreDescriptor? _active;
  final Stream<void> _changes;

  @override
  Future<MediaStoreDescriptor?> getActive() async => _active;

  /// The identity provider subscribes to this so connecting or disconnecting
  /// a store refreshes the panel instead of serving a stale descriptor.
  @override
  Stream<void> watchStoresChanges() => _changes;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

/// Returns whatever the supplied closure yields at call time, so a test can
/// change the answer between reads.
class _MutableStoresRepository implements MediaStoresRepository {
  _MutableStoresRepository(this._active, {required Stream<void> changes})
    : _changes = changes;

  final MediaStoreDescriptor? Function() _active;
  final Stream<void> _changes;

  @override
  Future<MediaStoreDescriptor?> getActive() async => _active();

  @override
  Stream<void> watchStoresChanges() => _changes;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

// Riverpod 3 does not export the `Override` type, so extra overrides travel
// as dynamic and are cast at the call site.
ProviderContainer _container({
  bool attached = true,
  QueueFacts? queue,
  List<dynamic> extra = const [],
}) {
  final c = ProviderContainer(
    overrides: [
      mediaStoreAttachedProvider.overrideWith((ref) async => attached),
      mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(queue)),
      ...extra.cast(),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('composes row facts with the attached flag', () async {
    final c = _container();
    // Prime the async dependencies the synchronous provider reads through.
    await c.read(mediaStoreAttachedProvider.future);

    final p = c.read(mediaProvenanceProvider(_item()));

    expect(p.origin.sourceType, MediaSourceType.platformGallery);
    expect(p.origin.pointer, 'asset-1');
    expect(p.backup.storeAttached, isTrue);
    expect(p.backup.eligible, isTrue);
    expect(p.backup.tier, BackupTier.none);
  });

  test('reports the queue row when one exists', () async {
    final c = _container(
      queue: const QueueFacts(state: 'failed', error: 'network down'),
    );
    await c.read(mediaStoreAttachedProvider.future);
    c.listen(mediaQueueFactsProvider('m1'), (_, _) {});
    await Future<void>.delayed(Duration.zero);

    final p = c.read(mediaProvenanceProvider(_item()));

    expect(p.backup.queueState, 'failed');
    expect(p.backup.queueError, 'network down');
  });

  test('a detached store still yields provenance', () async {
    final c = _container(attached: false);
    await c.read(mediaStoreAttachedProvider.future);

    expect(
      c.read(mediaProvenanceProvider(_item())).backup.storeAttached,
      false,
    );
  });

  // This is the guard that keeps the PR 3 grid badge affordable. Building the
  // media store runtime does a keychain read, constructs the object store,
  // kicks a transfer-queue drain and can trigger an auto verify sweep, which
  // is exactly why mediaStoreAttachedProvider exists. If a later change makes
  // this provider reach for the runtime, a throwing override turns that into
  // a test failure instead of a stuttering grid nobody traces back here.
  test('does not build the media store runtime', () async {
    final c = _container(
      extra: [
        mediaStoreRuntimeProvider.overrideWith(
          (ref) async => throw StateError('runtime must not be built'),
        ),
      ],
    );
    await c.read(mediaStoreAttachedProvider.future);

    expect(() => c.read(mediaProvenanceProvider(_item())), returnsNormally);
    expect(c.read(mediaProvenanceProvider(_item())).origin.pointer, 'asset-1');
  });

  group('mediaStoreIdentityProvider', () {
    test('is null when no store is attached', () async {
      final c = _container(
        extra: [
          mediaStoresRepositoryProvider.overrideWithValue(
            _FakeStoresRepository(null),
          ),
        ],
      );

      expect(await c.read(mediaStoreIdentityProvider.future), isNull);
    });

    test('reports the active descriptor provider type and hint', () async {
      final c = _container(
        extra: [
          mediaStoresRepositoryProvider.overrideWithValue(
            _FakeStoresRepository((
              id: 's1',
              providerType: 's3',
              displayHint: 'dive-media @ minio.host',
              lastSweepAt: null,
            )),
          ),
        ],
      );

      final identity = await c.read(mediaStoreIdentityProvider.future);

      expect(identity!.providerType, 's3');
      expect(identity.displayHint, 'dive-media @ minio.host');
    });

    // Without a change-tick subscription this provider would keep serving
    // whatever store was attached when it first resolved, so connecting a
    // store would leave the panel reporting "no cloud store connected"
    // indefinitely. The architecture contract test catches the missing
    // subscription; this proves the wiring actually re-reads.
    test('re-reads the descriptor when the stores table changes', () async {
      final changes = StreamController<void>.broadcast();
      addTearDown(changes.close);
      var current = <MediaStoreDescriptor?>[null].first;
      final repo = _MutableStoresRepository(
        () => current,
        changes: changes.stream,
      );
      final c = _container(
        extra: [mediaStoresRepositoryProvider.overrideWithValue(repo)],
      );
      final sub = c.listen(mediaStoreIdentityProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await c.read(mediaStoreIdentityProvider.future), isNull);

      current = (
        id: 's1',
        providerType: 'dropbox',
        displayHint: 'Dropbox',
        lastSweepAt: null,
      );
      changes.add(null);
      await Future<void>.delayed(Duration.zero);

      final identity = await c.read(mediaStoreIdentityProvider.future);
      expect(identity?.providerType, 'dropbox');
    });
  });

  test(
    'an unprimed attached flag reads as not attached rather than throwing',
    () {
      // The provider must never surface a loading state to a tile: a grid
      // builds synchronously and cannot await anything.
      final c = _container();

      final p = c.read(mediaProvenanceProvider(_item()));

      expect(p.backup.storeAttached, isFalse);
      expect(p.origin.pointer, 'asset-1');
    },
  );
}
