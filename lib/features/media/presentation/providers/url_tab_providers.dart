// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3a.md`
// Task 14. Deviations from the plan code:
//
// - `commit()` returns `Future<List<String>>` and `undoCommit` takes
//   `List<String>` (not `int`) to match the schema-driven String-id
//   adaptation already applied in Task 12 (`NetworkFetchPipeline.ingest`
//   returns `Future<List<String>>` and `MediaRepository.deleteMedia`
//   takes a `String` id).
// - `undoCommit` deletes via `MediaRepository.deleteMedia(id)` rather than
//   the plan's `_pipeline.deleteIds(ids)` — the pipeline does not expose a
//   `deleteIds` method, and the Phase 2 `FilesTabNotifier.undoCommit`
//   already routes undo through the repository the same way.
// - `MediaRepository` is therefore a third constructor dependency
//   alongside `pipeline` + `credentials`, all marked `required`.
// - Supporting providers (`networkCredentialsRepositoryProvider`,
//   `networkCredentialsServiceProvider`, `httpClientProvider`,
//   `networkUrlResolverProvider`, `urlMetadataExtractorProvider`,
//   `networkFetchPipelineProvider`) are co-located in this file rather
//   than a sibling `network_providers.dart`, since they are consumed
//   solely by the URL tab right now. Phase 3c may extract them when the
//   Settings page also needs them.
import 'package:equatable/equatable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/repositories/network_credentials_repository.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/data/services/network_url_resolver.dart';
import 'package:submersion/features/media/data/services/url_metadata_extractor.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/utils/url_validator.dart';
import 'package:submersion/features/media/domain/entities/extracted_metadata.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

/// Two-mode segmented control for the URL tab. URLs is the bulk paste-and-add
/// flow (Phase 3a). Manifest mode is a Phase 3b placeholder card.
enum UrlTabMode { urls, manifest }

/// State for the URL tab in the photo picker.
///
/// Holds the current segmented-control mode, the staged draft lines (each
/// validated independently via [UrlValidator]), the auto-match-by-date
/// preference, the IDs returned by the most recent [UrlTabNotifier.commit]
/// (used by undo), the last user-visible error string, and the set of
/// hostnames currently flagged as 401-unauthenticated by the resolver
/// (drives the "Sign in" badge).
class UrlTabState extends Equatable {
  const UrlTabState({
    this.mode = UrlTabMode.urls,
    this.draftLines = const [],
    this.autoMatchByDate = true,
    this.committedIds = const [],
    this.lastError,
    this.unauthenticatedHosts = const {},
  });

  final UrlTabMode mode;
  final List<String> draftLines;
  final bool autoMatchByDate;
  final List<String> committedIds;
  final String? lastError;
  final Set<String> unauthenticatedHosts;

  UrlTabState copyWith({
    UrlTabMode? mode,
    List<String>? draftLines,
    bool? autoMatchByDate,
    List<String>? committedIds,
    String? lastError,
    bool clearLastError = false,
    Set<String>? unauthenticatedHosts,
  }) {
    return UrlTabState(
      mode: mode ?? this.mode,
      draftLines: draftLines ?? this.draftLines,
      autoMatchByDate: autoMatchByDate ?? this.autoMatchByDate,
      committedIds: committedIds ?? this.committedIds,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      unauthenticatedHosts: unauthenticatedHosts ?? this.unauthenticatedHosts,
    );
  }

  @override
  List<Object?> get props => [
    mode,
    draftLines,
    autoMatchByDate,
    committedIds,
    lastError,
    unauthenticatedHosts,
  ];
}

/// Notifier for the URL tab.
///
/// Phase 3a actions:
/// - [setMode] flips between URLs and Manifest segments.
/// - [setDraft] replaces the draft line list (multi-line text field).
/// - [appendSingle] appends a single URL from the "Add URL" entry.
/// - [setAutoMatchByDate] toggles the auto-match-by-date preference.
/// - [commit] parses each draft line via [UrlValidator], collects the OK
///   URIs, and forwards them to [NetworkFetchPipeline.ingest]. Returns the
///   created IDs and clears the draft list on success.
/// - [undoCommit] takes the list of IDs returned by [commit] and deletes
///   each row via [MediaRepository.deleteMedia], mirroring the Phase 2
///   `FilesTabNotifier.undoCommit` undo path.
/// - [saveCredentials] forwards a sign-in sheet payload to
///   [NetworkCredentialsService.save] and clears the host from
///   [UrlTabState.unauthenticatedHosts] so the "Sign in" badge disappears.
class UrlTabNotifier extends StateNotifier<UrlTabState> {
  UrlTabNotifier({
    required NetworkFetchPipeline pipeline,
    required NetworkCredentialsService credentials,
    required MediaRepository mediaRepository,
  }) : _pipeline = pipeline,
       _credentials = credentials,
       _mediaRepository = mediaRepository,
       super(const UrlTabState());

  final NetworkFetchPipeline _pipeline;
  final NetworkCredentialsService _credentials;
  final MediaRepository _mediaRepository;

  void setMode(UrlTabMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setDraft(String text) {
    final lines = text.split('\n');
    state = state.copyWith(draftLines: lines);
  }

  void appendSingle(String url) {
    state = state.copyWith(draftLines: [...state.draftLines, url]);
  }

  void setAutoMatchByDate(bool value) {
    state = state.copyWith(autoMatchByDate: value);
  }

  /// Parses each non-empty draft line, ingests the OK URIs through the
  /// fetch pipeline, and returns the new row IDs. Stamps
  /// [UrlTabState.committedIds] for the undo path and clears
  /// [UrlTabState.draftLines] so the UI returns to its blank-canvas state.
  ///
  /// Empty lines are dropped silently. Invalid lines are also dropped from
  /// the ingest call — the UI is expected to disable the "Add" button when
  /// any line fails validation, so reaching here with invalid lines is
  /// degenerate (we still skip them defensively rather than throw).
  Future<List<String>> commit() async {
    final uris = <Uri>[];
    for (final raw in state.draftLines) {
      final result = UrlValidator.parse(raw);
      if (result is UrlValidationOk) {
        uris.add(result.uri);
      }
    }
    final ids = await _pipeline.ingest(uris, autoMatch: state.autoMatchByDate);
    state = state.copyWith(committedIds: ids, draftLines: const []);
    return ids;
  }

  /// Reverses a prior [commit] by deleting each row by id. Mirrors
  /// `FilesTabNotifier.undoCommit` — the pipeline does not expose a
  /// `deleteIds` helper, so we go through the repository.
  Future<void> undoCommit(List<String> ids) async {
    for (final id in ids) {
      await _mediaRepository.deleteMedia(id);
    }
    state = state.copyWith(committedIds: const []);
  }

  /// Persists credentials for [hostname] via
  /// [NetworkCredentialsService.save] and removes the host from the
  /// `unauthenticatedHosts` set so the "Sign in" badge clears.
  Future<void> saveCredentials({
    required String hostname,
    required String authType,
    String? username,
    String? password,
    String? token,
    String? displayName,
  }) async {
    await _credentials.save(
      hostname: hostname,
      authType: authType,
      username: username,
      password: password,
      token: token,
      displayName: displayName,
    );
    final next = {...state.unauthenticatedHosts}..remove(hostname);
    state = state.copyWith(unauthenticatedHosts: next);
  }
}

// -----------------------------------------------------------------------
// Supporting Riverpod providers
// -----------------------------------------------------------------------

/// Singleton [http.Client] for network media fetches. Tests override this
/// with `package:http`'s `MockClient`.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Default [FlutterSecureStorage] handle used by [NetworkCredentialsService].
final flutterSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// Drift-backed metadata repository for [NetworkCredentialsService].
final networkCredentialsRepositoryProvider =
    Provider<NetworkCredentialsRepository>(
      (ref) =>
          NetworkCredentialsRepository(db: DatabaseService.instance.database),
    );

/// Singleton [NetworkCredentialsService] composing the credentials
/// repository and the platform secure-storage handle.
final networkCredentialsServiceProvider = Provider<NetworkCredentialsService>(
  (ref) => NetworkCredentialsService(
    repository: ref.watch(networkCredentialsRepositoryProvider),
    storage: ref.watch(flutterSecureStorageProvider),
  ),
);

/// Singleton [NetworkUrlResolver] composing the shared HTTP client and
/// the credentials service (for `Authorization` headers).
final networkUrlResolverProvider = Provider<NetworkUrlResolver>(
  (ref) => NetworkUrlResolver(
    client: ref.watch(httpClientProvider),
    credentials: ref.watch(networkCredentialsServiceProvider),
  ),
);

/// Singleton [UrlMetadataExtractor].
///
/// The bytes-based EXIF callback is currently a no-op stub returning an
/// empty [ExtractedMetadata]: the file-based [ExifExtractor] in
/// `data/services/exif_extractor.dart` operates on `File`, not `Uint8List`,
/// and Phase 3a does not yet introduce an in-process bytes-based EXIF
/// codec. Width/height/takenAt for URL items therefore fall back to the
/// HTTP `Last-Modified` header populated by [NetworkUrlResolver]. A
/// follow-up task in Phase 3b/3c is expected to add a real bytes
/// extractor; the [UrlMetadataExtractor] tests already inject their own
/// `ExifExtractFn` via the constructor, so they are unaffected.
final urlMetadataExtractorProvider = Provider<UrlMetadataExtractor>(
  (ref) => UrlMetadataExtractor(
    resolver: ref.watch(networkUrlResolverProvider),
    // TODO(media): wire a bytes-based EXIF extractor in Phase 3b/3c.
    exifExtract: (bytes) async => const ExtractedMetadata(),
  ),
);

/// Singleton [NetworkFetchPipeline]. Pulls [AppDatabase] directly from
/// [DatabaseService] (the same lazy-singleton pattern used by
/// [MediaRepository]); Riverpod is not yet wired up to manage the database
/// instance.
final networkFetchPipelineProvider = Provider<NetworkFetchPipeline>((ref) {
  return NetworkFetchPipeline(
    db: DatabaseService.instance.database,
    extractor: ref.watch(urlMetadataExtractorProvider),
  );
});

/// StateNotifierProvider for the URL tab. Composes the fetch pipeline
/// (commit), credentials service (sign-in sheet), and media repository
/// (undo path).
final urlTabNotifierProvider =
    StateNotifierProvider<UrlTabNotifier, UrlTabState>(
      (ref) => UrlTabNotifier(
        pipeline: ref.watch(networkFetchPipelineProvider),
        credentials: ref.watch(networkCredentialsServiceProvider),
        mediaRepository: ref.watch(mediaRepositoryProvider),
      ),
    );
