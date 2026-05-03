// Tests for the Manifest tab StateNotifier (Phase 3b, Task 13).
//
// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3b.md`
// Task 13. The plan's example test code uses a hand-rolled `_FakeFetcher`
// that ad-hoc accepts/rejects fetches; we keep that pattern (the
// `ManifestFetchService` API surface is small enough that the mockito
// boilerplate is overkill).
//
// Deviations from the plan:
//
// - Tests reach the existing `manifestFetchServiceProvider` from
//   `media_resolver_providers.dart` (not a re-declared one in
//   `manifest_tab_providers.dart`). See the deviation note in
//   `manifest_tab_providers.dart`.
// - The fake records the last `formatOverride` it received so the
//   `changeFormatOverride` test can assert the parameter was forwarded
//   without needing a full mockito setup.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/presentation/providers/manifest_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';

void main() {
  group('ManifestTabNotifier', () {
    test('starts in Idle', () {
      final container = ProviderContainer(
        overrides: [
          manifestFetchServiceProvider.overrideWithValue(
            _FakeFetcher.success(empty: true),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(manifestTabProvider), isA<ManifestTabIdle>());
    });

    test(
      'fetch transitions Idle -> Fetching -> ShowingPreview on success',
      () async {
        final fetcher = _FakeFetcher.success(empty: false);
        final container = ProviderContainer(
          overrides: [manifestFetchServiceProvider.overrideWithValue(fetcher)],
        );
        addTearDown(container.dispose);
        final notifier = container.read(manifestTabProvider.notifier);
        final future = notifier.fetch('https://example.com/m.json');
        // Synchronously, before the await resolves, the state has flipped
        // to Fetching.
        expect(container.read(manifestTabProvider), isA<ManifestTabFetching>());
        await future;
        final state = container.read(manifestTabProvider);
        expect(state, isA<ManifestTabShowingPreview>());
        expect(
          (state as ManifestTabShowingPreview).result.entries,
          hasLength(1),
        );
        expect(state.url, 'https://example.com/m.json');
      },
    );

    test('fetch trims whitespace before validating', () async {
      final fetcher = _FakeFetcher.success(empty: false);
      final container = ProviderContainer(
        overrides: [manifestFetchServiceProvider.overrideWithValue(fetcher)],
      );
      addTearDown(container.dispose);
      await container
          .read(manifestTabProvider.notifier)
          .fetch('  https://example.com/m.json  ');
      expect(
        container.read(manifestTabProvider),
        isA<ManifestTabShowingPreview>(),
      );
      expect(
        (container.read(manifestTabProvider) as ManifestTabShowingPreview).url,
        'https://example.com/m.json',
      );
    });

    test('fetch transitions to Error on invalid URL', () async {
      final container = ProviderContainer(
        overrides: [
          manifestFetchServiceProvider.overrideWithValue(
            _FakeFetcher.failure(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(manifestTabProvider.notifier).fetch('not-a-url');
      final state = container.read(manifestTabProvider);
      expect(state, isA<ManifestTabError>());
      expect((state as ManifestTabError).message, contains('Invalid'));
    });

    test('fetch transitions to Error on HTTP failure', () async {
      final container = ProviderContainer(
        overrides: [
          manifestFetchServiceProvider.overrideWithValue(
            _FakeFetcher.failure(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(manifestTabProvider.notifier)
          .fetch('https://example.com/m');
      final state = container.read(manifestTabProvider);
      expect(state, isA<ManifestTabError>());
      expect((state as ManifestTabError).message, 'boom');
    });

    test('fetch transitions to Error on 401 with sign-in hint', () async {
      final container = ProviderContainer(
        overrides: [
          manifestFetchServiceProvider.overrideWithValue(
            _FakeFetcher.unauthorized(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(manifestTabProvider.notifier)
          .fetch('https://example.com/m');
      final state = container.read(manifestTabProvider);
      expect(state, isA<ManifestTabError>());
      expect((state as ManifestTabError).message, contains('Unauthorized'));
    });

    test('fetch transitions to Error on 304 not-modified', () async {
      final container = ProviderContainer(
        overrides: [
          manifestFetchServiceProvider.overrideWithValue(
            _FakeFetcher.notModified(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(manifestTabProvider.notifier)
          .fetch('https://example.com/m');
      final state = container.read(manifestTabProvider);
      expect(state, isA<ManifestTabError>());
      expect((state as ManifestTabError).message, contains('unchanged'));
    });

    test('changeFormatOverride re-parses with the new format', () async {
      final fetcher = _FakeFetcher.success(empty: false);
      final container = ProviderContainer(
        overrides: [manifestFetchServiceProvider.overrideWithValue(fetcher)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(manifestTabProvider.notifier);
      await notifier.fetch('https://example.com/m.json');
      await notifier.changeFormatOverride(ManifestFormat.csv);
      expect(fetcher.lastFormatOverride, ManifestFormat.csv);
      final state = container.read(manifestTabProvider);
      expect(state, isA<ManifestTabShowingPreview>());
      expect(
        (state as ManifestTabShowingPreview).formatOverride,
        ManifestFormat.csv,
      );
    });

    test(
      'changeFormatOverride preserves subscribe + poll interval flags',
      () async {
        final fetcher = _FakeFetcher.success(empty: false);
        final container = ProviderContainer(
          overrides: [manifestFetchServiceProvider.overrideWithValue(fetcher)],
        );
        addTearDown(container.dispose);
        final notifier = container.read(manifestTabProvider.notifier);
        await notifier.fetch('https://example.com/m.json');
        notifier.setSubscribe(true);
        notifier.setPollInterval(3600);
        await notifier.changeFormatOverride(ManifestFormat.atom);
        final state =
            container.read(manifestTabProvider) as ManifestTabShowingPreview;
        expect(state.subscribe, isTrue);
        expect(state.pollIntervalSeconds, 3600);
        expect(state.formatOverride, ManifestFormat.atom);
      },
    );

    test('changeFormatOverride is a no-op outside ShowingPreview', () async {
      final fetcher = _FakeFetcher.success(empty: false);
      final container = ProviderContainer(
        overrides: [manifestFetchServiceProvider.overrideWithValue(fetcher)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(manifestTabProvider.notifier);
      await notifier.changeFormatOverride(ManifestFormat.csv);
      expect(container.read(manifestTabProvider), isA<ManifestTabIdle>());
      expect(fetcher.lastFormatOverride, isNull);
    });

    test('setSubscribe toggles subscribe flag in preview', () async {
      final fetcher = _FakeFetcher.success(empty: false);
      final container = ProviderContainer(
        overrides: [manifestFetchServiceProvider.overrideWithValue(fetcher)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(manifestTabProvider.notifier);
      await notifier.fetch('https://example.com/m.json');
      expect(
        (container.read(manifestTabProvider) as ManifestTabShowingPreview)
            .subscribe,
        isFalse,
      );
      notifier.setSubscribe(true);
      expect(
        (container.read(manifestTabProvider) as ManifestTabShowingPreview)
            .subscribe,
        isTrue,
      );
    });

    test('setSubscribe is a no-op outside preview', () {
      final container = ProviderContainer(
        overrides: [
          manifestFetchServiceProvider.overrideWithValue(
            _FakeFetcher.failure(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(manifestTabProvider.notifier).setSubscribe(true);
      expect(container.read(manifestTabProvider), isA<ManifestTabIdle>());
    });

    test('setPollInterval updates the interval seconds', () async {
      final fetcher = _FakeFetcher.success(empty: false);
      final container = ProviderContainer(
        overrides: [manifestFetchServiceProvider.overrideWithValue(fetcher)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(manifestTabProvider.notifier);
      await notifier.fetch('https://example.com/m.json');
      expect(
        (container.read(manifestTabProvider) as ManifestTabShowingPreview)
            .pollIntervalSeconds,
        86400,
      );
      notifier.setPollInterval(3600);
      expect(
        (container.read(manifestTabProvider) as ManifestTabShowingPreview)
            .pollIntervalSeconds,
        3600,
      );
    });

    test('reset returns to Idle', () async {
      final container = ProviderContainer(
        overrides: [
          manifestFetchServiceProvider.overrideWithValue(
            _FakeFetcher.failure(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(manifestTabProvider.notifier);
      await notifier.fetch('https://x/m');
      expect(container.read(manifestTabProvider), isA<ManifestTabError>());
      notifier.reset();
      expect(container.read(manifestTabProvider), isA<ManifestTabIdle>());
    });

    test(
      'commit transitions ShowingPreview -> Committing -> Idle on success',
      () async {
        final container = ProviderContainer(
          overrides: [
            manifestFetchServiceProvider.overrideWithValue(
              _FakeFetcher.success(empty: false),
            ),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(manifestTabProvider.notifier);
        await notifier.fetch('https://example.com/m.json');
        var saw = false;
        await notifier.commit(
          onCommit: (preview) async {
            saw = true;
            expect(preview.result.entries, hasLength(1));
            expect(preview.url, 'https://example.com/m.json');
          },
        );
        expect(saw, isTrue);
        expect(container.read(manifestTabProvider), isA<ManifestTabIdle>());
      },
    );

    test('commit transitions to Error on callback failure', () async {
      final container = ProviderContainer(
        overrides: [
          manifestFetchServiceProvider.overrideWithValue(
            _FakeFetcher.success(empty: false),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(manifestTabProvider.notifier);
      await notifier.fetch('https://example.com/m.json');
      await notifier.commit(onCommit: (_) async => throw 'kaboom');
      final state = container.read(manifestTabProvider);
      expect(state, isA<ManifestTabError>());
      expect((state as ManifestTabError).url, 'https://example.com/m.json');
      expect(state.message, contains('kaboom'));
    });

    test('commit is a no-op outside ShowingPreview', () async {
      final container = ProviderContainer(
        overrides: [
          manifestFetchServiceProvider.overrideWithValue(
            _FakeFetcher.success(empty: false),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(manifestTabProvider.notifier);
      var called = false;
      // Idle -> commit should do nothing.
      await notifier.commit(
        onCommit: (_) async {
          called = true;
        },
      );
      expect(called, isFalse);
      expect(container.read(manifestTabProvider), isA<ManifestTabIdle>());
    });

    test(
      'commit forwards subscribe + pollIntervalSeconds to onCommit',
      () async {
        final container = ProviderContainer(
          overrides: [
            manifestFetchServiceProvider.overrideWithValue(
              _FakeFetcher.success(empty: false),
            ),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(manifestTabProvider.notifier);
        await notifier.fetch('https://example.com/m.json');
        notifier.setSubscribe(true);
        notifier.setPollInterval(3600);
        ManifestTabShowingPreview? captured;
        await notifier.commit(
          onCommit: (preview) async {
            captured = preview;
          },
        );
        expect(captured, isNotNull);
        expect(captured!.subscribe, isTrue);
        expect(captured!.pollIntervalSeconds, 3600);
      },
    );
  });
}

/// Hand-rolled fake for [ManifestFetchService] — small enough that
/// the mockito boilerplate is overkill.
class _FakeFetcher implements ManifestFetchService {
  _FakeFetcher.success({required this.empty})
    : _failure = false,
      _unauthorized = false,
      _notModified = false;
  _FakeFetcher.failure()
    : empty = true,
      _failure = true,
      _unauthorized = false,
      _notModified = false;
  _FakeFetcher.unauthorized()
    : empty = true,
      _failure = false,
      _unauthorized = true,
      _notModified = false;
  _FakeFetcher.notModified()
    : empty = true,
      _failure = false,
      _unauthorized = false,
      _notModified = true;

  final bool empty;
  final bool _failure;
  final bool _unauthorized;
  final bool _notModified;
  ManifestFormat? lastFormatOverride;

  @override
  Future<ManifestFetchOutcome> fetch(
    Uri url, {
    ManifestFormat? formatOverride,
    String? ifNoneMatch,
    String? ifModifiedSince,
  }) async {
    lastFormatOverride = formatOverride;
    if (_unauthorized) {
      return const ManifestFetchFailure(
        statusCode: 401,
        message: 'Unauthorized',
      );
    }
    if (_failure) return const ManifestFetchFailure(message: 'boom');
    if (_notModified) return const ManifestFetchNotModified();
    final entries = empty
        ? <ManifestEntry>[]
        : const [ManifestEntry(entryKey: 'a', url: 'https://x/a.jpg')];
    return ManifestFetchSuccess(
      parsed: ManifestParseResult(
        format: formatOverride ?? ManifestFormat.json,
        entries: entries,
      ),
    );
  }

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
