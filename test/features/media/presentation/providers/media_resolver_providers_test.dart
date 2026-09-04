import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_files_diagnostics_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';

/// Stub diagnostics service used to drive the FutureProvider tests in this
/// file. We override `localFilesDiagnosticsServiceProvider` so the providers
/// under test resolve to this stub instead of touching the real DB / platform
/// channel.
class _StubDiagnosticsService implements LocalFilesDiagnosticsService {
  _StubDiagnosticsService({this.uriUsage = 0, this.diagnosis});

  final int uriUsage;
  final LocalFilesDiagnostics? diagnosis;

  @override
  Future<int> androidUriUsage() async => uriUsage;

  @override
  Future<LocalFilesDiagnostics> diagnose() async {
    return diagnosis ??
        const LocalFilesDiagnostics(total: 0, available: 0, unavailable: 0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

/// Stalls resolution inside the fetch gate. The bookmark read is the first
/// await [LocalFileResolver] makes for an item with no local path, and it sits
/// inside the gate, so a resolution parked here is one holding a slot with
/// both budget timers armed, the state a media tile is in whenever its
/// source is slow.
class _StalledBookmarkStorage extends LocalBookmarkStorage {
  @override
  Future<Uint8List?> read(String bookmarkRef) => Completer<Uint8List?>().future;
}

void main() {
  test(
    'androidUriUsageProvider delegates to service.androidUriUsage',
    () async {
      final container = ProviderContainer(
        overrides: [
          localFilesDiagnosticsServiceProvider.overrideWithValue(
            _StubDiagnosticsService(uriUsage: 7),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(androidUriUsageProvider.future);
      expect(result, 7);
    },
  );

  test('localFilesDiagnosticsProvider delegates to service.diagnose', () async {
    const expected = LocalFilesDiagnostics(
      total: 5,
      available: 3,
      unavailable: 2,
    );
    final container = ProviderContainer(
      overrides: [
        localFilesDiagnosticsServiceProvider.overrideWithValue(
          _StubDiagnosticsService(diagnosis: expected),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(localFilesDiagnosticsProvider.future);
    expect(result, expected);
  });

  /// The resolver's fetch gate arms a slot budget and a caller budget per
  /// resolution, and both outlive the fetch they bound. A container that goes
  /// away mid-resolution, which is every widget test that mounts a media
  /// tile, must not leave them armed: the binding fails teardown on any
  /// timer the tree left behind, and that is a flake nothing in the test can
  /// see or prevent.
  test(
    'disposing the container stops the local file resolver fetching',
    () async {
      final container = ProviderContainer();
      final resolver = container.read(localFileResolverProvider);

      container.dispose();

      final data = await resolver.resolve(
        MediaItem(
          id: 'm1',
          mediaType: MediaType.photo,
          sourceType: MediaSourceType.localFile,
          localPath: '/nonexistent/m1.jpg',
          takenAt: DateTime(2026),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );

      // Answered from the disposed gate without touching the filesystem: no
      // fetch was started, so no budget timer was armed to bound it.
      expect(
        data,
        isA<UnavailableData>().having(
          (d) => d.kind,
          'kind',
          UnavailableKind.stillFetching,
        ),
      );
    },
  );

  /// The one that bit us. A tile whose resolution has not landed by the time
  /// the tree comes down is normal, since the fetch cannot be cancelled, but the
  /// gate's budget timers were surviving the container that owned them, and
  /// the test binding fails teardown on any timer left pending. On a fast
  /// machine the resolution finished first and nothing showed; under CI load
  /// it did not, and an unrelated media widget test failed with two pending
  /// timers it had no way to see.
  testWidgets('a resolution still in flight at teardown leaves no timer', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        localBookmarkStorageProvider.overrideWith(
          (ref) => _StalledBookmarkStorage(),
        ),
      ],
    );
    unawaited(
      container
          .read(localFileResolverProvider)
          .resolve(
            MediaItem(
              id: 'm1',
              mediaType: MediaType.photo,
              sourceType: MediaSourceType.localFile,
              bookmarkRef: 'ref-1',
              takenAt: DateTime(2026),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ),
    );
    await tester.pump();

    // What unmounting a ProviderScope does, and what the binding does for
    // every widget test before it checks for stray timers.
    container.dispose();
  });
}
