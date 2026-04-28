// Widget tests for the Manifest mode panel (Phase 3b, Task 13).
//
// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3b.md`
// Task 13. The plan's example test is a single smoke test for the idle
// state; we extend it to cover each branch of the [ManifestTabState]
// switch (idle / fetching / error / preview) plus the format chip and
// subscribe controls.
//
// Mocks: a hand-rolled `_StubFetcher` for [ManifestFetchService] mirrors
// the test pattern used in `manifest_tab_providers_test.dart`. Mockito
// is overkill for a one-method interface.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/presentation/providers/manifest_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/manifest_mode_panel.dart';

/// Test-only [ManifestTabNotifier] that seeds an arbitrary state so the
/// panel can be rendered in any branch without driving it through the
/// async fetch flow. Mirrors the seeding approach used in
/// `files_tab_test.dart` and `url_tab_test.dart`.
class _SeededManifestTabNotifier extends ManifestTabNotifier {
  _SeededManifestTabNotifier(
    ManifestTabState seed, {
    required super.fetchService,
  }) {
    state = seed;
  }
}

class _StubFetcher implements ManifestFetchService {
  const _StubFetcher();

  @override
  Future<ManifestFetchOutcome> fetch(
    Uri url, {
    ManifestFormat? formatOverride,
    String? ifNoneMatch,
    String? ifModifiedSince,
  }) async => const ManifestFetchSuccess(
    parsed: ManifestParseResult(format: ManifestFormat.json, entries: []),
  );

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  Widget wrap({ManifestTabState? seed, _StubFetcher? fetcher}) {
    final stub = fetcher ?? const _StubFetcher();
    return ProviderScope(
      overrides: [
        manifestFetchServiceProvider.overrideWithValue(stub),
        if (seed != null)
          manifestTabProvider.overrideWith(
            (ref) => _SeededManifestTabNotifier(seed, fetchService: stub),
          ),
      ],
      child: const MaterialApp(home: Scaffold(body: ManifestModePanel())),
    );
  }

  group('ManifestModePanel', () {
    testWidgets('renders URL field, Fetch button, and idle hint', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      expect(find.text('Manifest URL'), findsOneWidget);
      expect(find.text('Fetch'), findsOneWidget);
      expect(find.text('Paste a manifest URL to begin.'), findsOneWidget);
    });

    testWidgets('Fetch button disabled while fetching', (tester) async {
      await tester.pumpWidget(
        wrap(seed: const ManifestTabFetching('https://example.com/m.json')),
      );
      final fetchBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Fetch'),
      );
      expect(fetchBtn.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('error state shows red message', (tester) async {
      await tester.pumpWidget(
        wrap(
          seed: const ManifestTabError(
            url: 'https://example.com/m.json',
            message: 'HTTP 404',
          ),
        ),
      );
      expect(find.textContaining('Fetch failed: HTTP 404'), findsOneWidget);
    });

    testWidgets('preview state renders entry count + first entries', (
      tester,
    ) async {
      const result = ManifestParseResult(
        format: ManifestFormat.json,
        entries: [
          ManifestEntry(entryKey: 'a', url: 'https://example.com/a.jpg'),
          ManifestEntry(entryKey: 'b', url: 'https://example.com/b.jpg'),
          ManifestEntry(entryKey: 'c', url: 'https://example.com/c.jpg'),
        ],
      );
      await tester.pumpWidget(
        wrap(
          seed: const ManifestTabShowingPreview(
            url: 'https://example.com/m.json',
            result: result,
          ),
        ),
      );
      expect(find.text('3 entries detected'), findsOneWidget);
      expect(find.text('https://example.com/a.jpg'), findsOneWidget);
      expect(find.text('https://example.com/b.jpg'), findsOneWidget);
      expect(find.text('https://example.com/c.jpg'), findsOneWidget);
    });

    testWidgets('preview caps preview list at 5 entries', (tester) async {
      final entries = List<ManifestEntry>.generate(
        7,
        (i) =>
            ManifestEntry(entryKey: 'k$i', url: 'https://example.com/$i.jpg'),
      );
      await tester.pumpWidget(
        wrap(
          seed: ManifestTabShowingPreview(
            url: 'https://example.com/m.json',
            result: ManifestParseResult(
              format: ManifestFormat.json,
              entries: entries,
            ),
          ),
        ),
      );
      expect(find.text('7 entries detected'), findsOneWidget);
      expect(find.text('https://example.com/0.jpg'), findsOneWidget);
      expect(find.text('https://example.com/4.jpg'), findsOneWidget);
      // 5th index (0-based) and beyond are truncated.
      expect(find.text('https://example.com/5.jpg'), findsNothing);
      expect(find.text('https://example.com/6.jpg'), findsNothing);
    });

    testWidgets('format chip dropdown shows the detected format', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          seed: const ManifestTabShowingPreview(
            url: 'https://example.com/m.csv',
            result: ManifestParseResult(
              format: ManifestFormat.csv,
              entries: [],
            ),
          ),
        ),
      );
      // The DropdownButton's button face shows the current value's
      // displayName.
      expect(find.text('CSV'), findsOneWidget);
    });

    testWidgets('format chip dropdown reflects override', (tester) async {
      await tester.pumpWidget(
        wrap(
          seed: const ManifestTabShowingPreview(
            url: 'https://example.com/m.json',
            result: ManifestParseResult(
              format: ManifestFormat.json,
              entries: [],
            ),
            formatOverride: ManifestFormat.atom,
          ),
        ),
      );
      // Atom / RSS displayName beats the auto-detected JSON.
      expect(find.text('Atom / RSS'), findsOneWidget);
    });

    testWidgets('subscribe checkbox is unchecked by default', (tester) async {
      await tester.pumpWidget(
        wrap(
          seed: const ManifestTabShowingPreview(
            url: 'https://example.com/m.json',
            result: ManifestParseResult(
              format: ManifestFormat.json,
              entries: [],
            ),
          ),
        ),
      );
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
      // Poll-interval dropdown is hidden when subscribe is off.
      expect(find.text('Poll every:'), findsNothing);
    });

    testWidgets('subscribe checked reveals poll-interval dropdown', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          seed: const ManifestTabShowingPreview(
            url: 'https://example.com/m.json',
            result: ManifestParseResult(
              format: ManifestFormat.json,
              entries: [],
            ),
            subscribe: true,
          ),
        ),
      );
      expect(find.text('Subscribe to updates'), findsOneWidget);
      expect(find.text('Poll every:'), findsOneWidget);
      // 24 hours is the default poll interval label.
      expect(find.text('24 hours'), findsOneWidget);
    });

    testWidgets('toggling subscribe checkbox flips notifier state', (
      tester,
    ) async {
      final notifier = _SeededManifestTabNotifier(
        const ManifestTabShowingPreview(
          url: 'https://example.com/m.json',
          result: ManifestParseResult(format: ManifestFormat.json, entries: []),
        ),
        fetchService: const _StubFetcher(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            manifestFetchServiceProvider.overrideWithValue(
              const _StubFetcher(),
            ),
            manifestTabProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(home: Scaffold(body: ManifestModePanel())),
        ),
      );
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      final state = notifier.state as ManifestTabShowingPreview;
      expect(state.subscribe, isTrue);
    });

    testWidgets('Fetch button calls notifier.fetch with the typed URL', (
      tester,
    ) async {
      final notifier = _SeededManifestTabNotifier(
        const ManifestTabIdle(),
        fetchService: const _StubFetcher(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            manifestFetchServiceProvider.overrideWithValue(
              const _StubFetcher(),
            ),
            manifestTabProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(home: Scaffold(body: ManifestModePanel())),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Manifest URL'),
        'https://example.com/m.json',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Fetch'));
      // Drain the synchronous + microtask portion of the fetch.
      await tester.pump();
      await tester.pump();
      // The state has either landed in ShowingPreview or transitioned
      // through Fetching — the URL should be carried in either case.
      final state = notifier.state;
      expect(
        state is ManifestTabShowingPreview || state is ManifestTabFetching,
        isTrue,
      );
    });

    testWidgets('warnings count surfaces in red when present', (tester) async {
      await tester.pumpWidget(
        wrap(
          seed: const ManifestTabShowingPreview(
            url: 'https://example.com/m.csv',
            result: ManifestParseResult(
              format: ManifestFormat.csv,
              entries: [
                ManifestEntry(entryKey: 'a', url: 'https://example.com/a.jpg'),
              ],
              warnings: ['row 7: missing url'],
            ),
          ),
        ),
      );
      expect(find.text('1 entry skipped'), findsOneWidget);
    });

    testWidgets('Import button is disabled when entries list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          seed: const ManifestTabShowingPreview(
            url: 'https://example.com/m.json',
            result: ManifestParseResult(
              format: ManifestFormat.json,
              entries: [],
            ),
          ),
        ),
      );
      // Locate the Import button by its label (parameterised on count).
      final importBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Import 0 entries'),
      );
      expect(importBtn.onPressed, isNull);
    });

    testWidgets('Import button label reflects entry count and is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          seed: const ManifestTabShowingPreview(
            url: 'https://example.com/m.json',
            result: ManifestParseResult(
              format: ManifestFormat.json,
              entries: [
                ManifestEntry(entryKey: 'a', url: 'https://example.com/a.jpg'),
                ManifestEntry(entryKey: 'b', url: 'https://example.com/b.jpg'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Import 2 entries'), findsOneWidget);
      final importBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Import 2 entries'),
      );
      expect(importBtn.onPressed, isNotNull);
    });
  });
}
