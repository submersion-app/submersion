import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Registers teardown disposal and hands back a dispose that runs at most once.
///
/// Both regression tests below have to dispose inside the body, because the
/// disposal IS the event under test. They still want the teardown safety net,
/// since a throw before that line would leak the container into whatever runs
/// next. Disposing twice is harmless in Riverpod today, which is why these
/// tests pass, but a regression test for a teardown bug should not be resting
/// on that.
void Function() _disposeOnce(ProviderContainer container) {
  var disposed = false;
  void dispose() {
    if (disposed) return;
    disposed = true;
    container.dispose();
  }

  addTearDown(dispose);
  return dispose;
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
      final disposeContainer = _disposeOnce(container);
      final resolver = container.read(localFileResolverProvider);

      disposeContainer();

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
  /// the tree comes down is normal, since the fetch cannot be cancelled, but
  /// the gate's budget timers were surviving the container that owned them,
  /// and the test binding fails teardown on any timer left pending. On a fast
  /// machine the resolution finished first and nothing showed; under CI load
  /// it did not, and an unrelated media widget test failed with two pending
  /// timers it had no way to see.
  ///
  /// Deliberately uses a localPath item and never pumps before disposing.
  /// Both details keep the test honest across platforms:
  ///
  ///   * localPath takes the desktop branch of `_resolveInner`, which every
  ///     platform runs. Keying off a bookmarkRef instead would stall only on
  ///     iOS and macOS, since `_usesSecurityScopedBookmarks` defaults to those
  ///     two, and would pass vacuously on the Linux shards that actually run
  ///     this suite.
  ///   * `run` arms the caller budget synchronously, before `_withSlot` has
  ///     reached its first await, so disposing in the same turn is guaranteed
  ///     to catch that one live. It is the only one: the slot budget is armed
  ///     a microtask later, once `_acquire` resumes, which a same-turn dispose
  ///     beats. That is enough, since one stray timer fails teardown, and
  ///     without the disposal guard the slot timer is then armed on an
  ///     already-disposed gate, which is the second timer the original CI
  ///     failure reported. Pumping first would let the resolution settle and
  ///     disarm the caller budget, which is the same vacuous pass by a
  ///     different route.
  testWidgets('a resolution still in flight at teardown leaves no timer', (
    tester,
  ) async {
    final container = ProviderContainer();
    final disposeContainer = _disposeOnce(container);

    unawaited(
      container
          .read(localFileResolverProvider)
          .resolve(
            MediaItem(
              id: 'm1',
              mediaType: MediaType.photo,
              sourceType: MediaSourceType.localFile,
              localPath: '/nonexistent/m1.jpg',
              takenAt: DateTime(2026),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ),
    );

    // What unmounting a ProviderScope does, and what the binding does for
    // every widget test before it checks for stray timers.
    disposeContainer();
  });
}
