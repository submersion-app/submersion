// Failing widget tests for the URL tab + sign-in sheet (Phase 3a, Task 13).
//
// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3a.md`.
//
// These tests intentionally fail at compile time until Task 14 lands the
// providers (`url_tab_providers.dart`) and Task 15 lands the widget
// (`url_tab.dart`) and sign-in sheet. They drive the contract for both:
//
// - Mode segmented control (URLs / Manifest); the Manifest body renders
//   the [ManifestModePanel] (Phase 3b Task 13 swap).
// - Multi-line text field per-line validation via `UrlValidator`.
// - "Add URL" single-line entry that appends to the staged set.
// - Auto-match-by-date checkbox is on by default.
// - "Add" button disabled when staged set is empty or has any invalid lines.
// - Tapping "Add" calls `commit()` and shows a success snackbar with "Undo".
// - Tapping "Undo" calls `undoCommit(ids)`.
// - On a 401 (unauthenticated host) a "Sign in" badge appears; tapping it
//   opens the sign-in sheet.
// - Saving the sign-in sheet calls `NetworkCredentialsService.save(...)`.
//
// Adaptation deviations from the plan code:
//
// - Plan uses `Future<List<int>>` for `commit` / `undoCommit`; we use
//   `Future<List<String>>` to match the schema-driven String-id adaptation
//   already applied to `MediaRepository` and `NetworkFetchPipeline.ingest`
//   (Phase 3a Task 12).
// - Plan calls `_pipeline.deleteIds(ids)` from `undoCommit`; we instead
//   route undo through `MediaRepository.deleteMedia(id)` per Task 14's
//   instructions, mirroring the Phase 2 `FilesTabNotifier.undoCommit`.
// - Mocks are generated via `@GenerateMocks` rather than hand-rolled stubs,
//   matching the prevailing pattern in this test directory (e.g.
//   `files_tab_providers_test.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/network_signin_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/url_tab.dart';

import 'url_tab_test.mocks.dart';

/// Stub fetcher used by the Manifest mode tab tests so the widget can
/// be pumped without a real HTTP stack. The Manifest mode body itself
/// is exercised in `manifest_mode_panel_test.dart`.
class _StubManifestFetcher implements ManifestFetchService {
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

/// Test-only notifier that seeds an arbitrary initial [UrlTabState] so the
/// widget can be rendered in any branch without driving it through the
/// async commit / sign-in flow. Mirrors the seeding approach used in
/// `files_tab_test.dart`.
class _SeededUrlTabNotifier extends UrlTabNotifier {
  _SeededUrlTabNotifier(
    UrlTabState seed, {
    required super.pipeline,
    required super.credentials,
    required super.mediaRepository,
  }) {
    state = seed;
  }
}

@GenerateMocks([
  NetworkFetchPipeline,
  NetworkCredentialsService,
  MediaRepository,
])
void main() {
  late MockNetworkFetchPipeline pipeline;
  late MockNetworkCredentialsService credentials;
  late MockMediaRepository repo;

  setUp(() {
    pipeline = MockNetworkFetchPipeline();
    credentials = MockNetworkCredentialsService();
    repo = MockMediaRepository();
    // The Task 16 [NetworkThumbnail] inside [UrlReviewPane] reads
    // `credentials.headersFor(...)`; stub it once for every test so the
    // widget can paint without a `MissingStubError`. Returning `null`
    // means "no auth header needed".
    when(credentials.headersFor(any)).thenAnswer((_) async => null);
  });

  Widget wrap(Widget child, {UrlTabState? seed}) {
    return ProviderScope(
      overrides: [
        // Override the credentials provider so [NetworkThumbnail] does
        // not try to construct the real service (which reaches into the
        // not-initialized [DatabaseService] in tests).
        networkCredentialsServiceProvider.overrideWithValue(credentials),
        // Override the manifest fetch service so the Manifest mode body
        // (Phase 3b, Task 13) does not try to construct the real
        // service — the Manifest mode tab tests only assert visible
        // chrome here; behavior is covered in
        // `manifest_mode_panel_test.dart`.
        manifestFetchServiceProvider.overrideWithValue(_StubManifestFetcher()),
        if (seed != null)
          urlTabNotifierProvider.overrideWith(
            (ref) => _SeededUrlTabNotifier(
              seed,
              pipeline: pipeline,
              credentials: credentials,
              mediaRepository: repo,
            ),
          )
        else
          urlTabNotifierProvider.overrideWith(
            (ref) => UrlTabNotifier(
              pipeline: pipeline,
              credentials: credentials,
              mediaRepository: repo,
            ),
          ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('renders mode segmented control with URLs default', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const UrlTab()));
    // Both segments are present.
    expect(find.text('URLs'), findsOneWidget);
    expect(find.text('Manifest'), findsOneWidget);
    // Manifest mode is NOT active by default — the Phase 3b panel is
    // hidden, the multi-line URL field is visible.
    expect(find.text('Manifest URL'), findsNothing);
    expect(find.byType(TextField), findsAtLeastNWidgets(1));
  });

  testWidgets('Manifest mode body renders the ManifestModePanel', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const UrlTab(), seed: const UrlTabState(mode: UrlTabMode.manifest)),
    );
    // The panel surfaces a "Manifest URL" labeled field and a "Fetch"
    // button (see Phase 3b Task 13).
    expect(find.text('Manifest URL'), findsOneWidget);
    expect(find.text('Fetch'), findsOneWidget);
  });

  testWidgets('per-line validation marks invalid URL inline', (tester) async {
    await tester.pumpWidget(
      wrap(
        const UrlTab(),
        seed: const UrlTabState(
          draftLines: ['https://example.com/a.jpg', 'not-a-url'],
        ),
      ),
    );
    // First line ok, second line invalid → error text visible.
    expect(find.textContaining('absolute'), findsOneWidget);
  });

  testWidgets('Add URL single-line entry appends to staged set', (
    tester,
  ) async {
    final notifier = _SeededUrlTabNotifier(
      const UrlTabState(),
      pipeline: pipeline,
      credentials: credentials,
      mediaRepository: repo,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Once the URL is appended the review pane renders
          // [NetworkThumbnail], which reads the credentials provider.
          networkCredentialsServiceProvider.overrideWithValue(credentials),
          urlTabNotifierProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: Scaffold(body: UrlTab())),
      ),
    );

    // Find the dedicated "Add URL" single-line input and submit a URL.
    final addUrlField = find.widgetWithText(TextField, 'Add URL');
    expect(addUrlField, findsOneWidget);
    await tester.enterText(addUrlField, 'https://example.com/single.jpg');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(
      notifier.state.draftLines,
      contains('https://example.com/single.jpg'),
    );
  });

  testWidgets('autoMatchByDate checkbox is on by default', (tester) async {
    await tester.pumpWidget(wrap(const UrlTab()));
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
  });

  testWidgets('Add button disabled when staged set is empty', (tester) async {
    await tester.pumpWidget(wrap(const UrlTab()));
    final addButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add'),
    );
    expect(addButton.onPressed, isNull);
  });

  testWidgets('Add button disabled when any invalid line', (tester) async {
    await tester.pumpWidget(
      wrap(
        const UrlTab(),
        seed: const UrlTabState(
          draftLines: ['https://example.com/a.jpg', 'not-a-url'],
        ),
      ),
    );
    final addButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add'),
    );
    expect(addButton.onPressed, isNull);
  });

  testWidgets('committing calls notifier.commit and shows undo snack', (
    tester,
  ) async {
    when(
      pipeline.ingest(any, autoMatch: anyNamed('autoMatch')),
    ).thenAnswer((_) async => ['id-1', 'id-2']);

    await tester.pumpWidget(
      wrap(
        const UrlTab(),
        seed: const UrlTabState(
          draftLines: [
            'https://example.com/a.jpg',
            'https://example.com/b.jpg',
          ],
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(pipeline.ingest(any, autoMatch: anyNamed('autoMatch'))).called(1);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('undo calls notifier.undoCommit(ids)', (tester) async {
    when(
      pipeline.ingest(any, autoMatch: anyNamed('autoMatch')),
    ).thenAnswer((_) async => ['id-1', 'id-2']);
    when(repo.deleteMedia(any)).thenAnswer((_) async {});

    await tester.pumpWidget(
      wrap(
        const UrlTab(),
        seed: const UrlTabState(
          draftLines: [
            'https://example.com/a.jpg',
            'https://example.com/b.jpg',
          ],
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(repo.deleteMedia('id-1')).called(1);
    verify(repo.deleteMedia('id-2')).called(1);
  });

  testWidgets('401 surfaces Sign in badge', (tester) async {
    await tester.pumpWidget(
      wrap(
        const UrlTab(),
        seed: const UrlTabState(unauthenticatedHosts: {'example.com'}),
      ),
    );
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('tapping Sign in opens the sign-in sheet', (tester) async {
    await tester.pumpWidget(
      wrap(
        const UrlTab(),
        seed: const UrlTabState(unauthenticatedHosts: {'example.com'}),
      ),
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.byType(NetworkSignInSheet), findsOneWidget);
  });

  testWidgets('saving sign-in sheet calls credentials.save()', (tester) async {
    when(
      credentials.save(
        hostname: anyNamed('hostname'),
        authType: anyNamed('authType'),
        username: anyNamed('username'),
        password: anyNamed('password'),
        token: anyNamed('token'),
        displayName: anyNamed('displayName'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      wrap(
        const UrlTab(),
        seed: const UrlTabState(unauthenticatedHosts: {'example.com'}),
      ),
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    // Fill in basic-auth fields and save.
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'eric');
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'hunter2',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(
      credentials.save(
        hostname: 'example.com',
        authType: 'basic',
        username: 'eric',
        password: 'hunter2',
        token: anyNamed('token'),
        displayName: anyNamed('displayName'),
      ),
    ).called(1);
  });
}
