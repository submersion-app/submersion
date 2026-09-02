import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/presentation/pages/media_import_review_page.dart';
import 'package:submersion/features/media/presentation/providers/manifest_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_import_suggestion_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/manifest_mode_panel.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// `Override` is not exported from flutter_riverpod's public barrel; the
// shared test helper re-types it for widget tests.
import '../../../../helpers/mock_providers.dart' show Override;

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

/// Resolves every entry as-is and records what gets inserted.
class _FakePipeline implements NetworkFetchPipeline {
  final List<List<NetworkInsertRequest>> inserted = [];

  @override
  Future<List<ResolvedNetworkMedia>> resolveManifestEntries(
    List<ManifestEntry> entries,
  ) async => [
    for (final e in entries)
      ResolvedNetworkMedia(uri: Uri.parse(e.url), entry: e),
  ];

  @override
  Future<List<String>> insertResolved(
    List<NetworkInsertRequest> requests, {
    String? subscriptionId,
  }) async {
    inserted.add(requests);
    return [for (var i = 0; i < requests.length; i++) 'm$i'];
  }

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Records subscription writes without a database.
class _FakeSubRepo implements ManifestSubscriptionRepository {
  final List<({String url, bool isActive})> created = [];
  final List<String> deleted = [];

  @override
  Future<ManifestSubscription> createSubscription({
    required String manifestUrl,
    required ManifestFormat format,
    String? displayName,
    int pollIntervalSeconds = 86400,
    bool isActive = true,
    String? credentialsHostId,
  }) async {
    created.add((url: manifestUrl, isActive: isActive));
    return ManifestSubscription(
      id: 'sub-1',
      manifestUrl: manifestUrl,
      format: format,
      pollIntervalSeconds: pollIntervalSeconds,
      isActive: isActive,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );
  }

  @override
  Future<void> deleteById(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingCoordinator implements MediaDeletionCoordinator {
  final List<String> deleted = [];

  @override
  Future<void> deleteMultipleMedia(List<String> ids) async =>
      deleted.addAll(ids);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // No takenAt: the review shows "No matching dive" and never touches a
  // dive repository, which keeps that test free of that provider.
  const entry = ManifestEntry(
    entryKey: 'k1',
    url: 'https://feed.example.com/a.jpg',
  );

  final matchedTakenAt = DateTime.utc(2024, 6, 1, 12);
  final matchedEntry = ManifestEntry(
    entryKey: 'k1',
    url: 'https://feed.example.com/a.jpg',
    takenAt: matchedTakenAt,
  );

  Widget host(
    _FakePipeline pipeline, {
    ManifestEntry seedEntry = entry,
    List<Override> extraOverrides = const [],
  }) {
    const stub = _StubFetcher();
    return ProviderScope(
      overrides: [
        manifestFetchServiceProvider.overrideWithValue(stub),
        networkFetchPipelineProvider.overrideWithValue(pipeline),
        // The review page renders [NetworkThumbnail] for each entry, which
        // reads the credentials provider; the real one reaches into the
        // not-initialized [DatabaseService] in tests.
        networkCredentialsServiceProvider.overrideWithValue(_FakeCreds()),
        manifestTabProvider.overrideWith(
          (ref) => _SeededManifestTabNotifier(
            ManifestTabShowingPreview(
              url: 'https://feed.example.com/m.json',
              result: ManifestParseResult(
                format: ManifestFormat.json,
                entries: [seedEntry],
              ),
            ),
            fetchService: stub,
          ),
        ),
        ...extraOverrides,
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ManifestModePanel()),
      ),
    );
  }

  testWidgets('Import opens the review and inserts nothing until confirmed', (
    tester,
  ) async {
    final pipeline = _FakePipeline();
    await tester.pumpWidget(host(pipeline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import 1 entry'));
    await tester.pumpAndSettle();

    expect(find.byType(MediaImportReviewPage), findsOneWidget);
    expect(find.text('No matching dive'), findsOneWidget);
    expect(pipeline.inserted, isEmpty);
  });

  testWidgets('confirming creates the subscription, inserts, and undoes', (
    tester,
  ) async {
    final pipeline = _FakePipeline();
    final subRepo = _FakeSubRepo();
    final coordinator = _RecordingCoordinator();
    await tester.pumpWidget(
      host(
        pipeline,
        seedEntry: matchedEntry,
        extraOverrides: [
          importSuggestionProvider(matchedTakenAt).overrideWith(
            (ref) async => const ImportSuggestion(
              match: TimestampMatch(
                kind: TimestampMatchKind.confident,
                diveId: 'd9',
              ),
              diveNumber: 9,
            ),
          ),
          manifestSubscriptionRepositoryProvider.overrideWithValue(subRepo),
          mediaDeletionCoordinatorProvider.overrideWithValue(coordinator),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import 1 entry'));
    await tester.pumpAndSettle();
    expect(find.text('Link to #9'), findsOneWidget);

    await tester.tap(find.text('Import 1 items'));
    // Plain pumps: settling would run the snackbar's dismissal to the end.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // One sentinel subscription (Subscribe was off) and one linked insert.
    expect(subRepo.created, [
      (url: 'https://feed.example.com/m.json', isActive: false),
    ]);
    expect(pipeline.inserted, hasLength(1));
    expect(pipeline.inserted.single.single.diveId, 'd9');

    // Snackbars queue: the review's own result snackbar runs first, and the
    // panel's confirmation only surfaces once it has dismissed.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Imported 1 entry'), findsOneWidget);

    // Undo removes the rows AND the sentinel subscription. Invoked through
    // the action's callback: the queued bar's slide-in leaves the tap
    // target below the test viewport at this frame.
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pump();
    expect(coordinator.deleted, ['m0']);
    expect(subRepo.deleted, ['sub-1']);
    await tester.pumpAndSettle();
  });
}

class _FakeCreds implements NetworkCredentialsService {
  @override
  Future<Map<String, String>?> headersFor(Uri uri) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} not stubbed in _FakeCreds',
  );
}
