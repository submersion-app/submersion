// Shared harness for the Photos & videos page tests (issue #3482 phase 4).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/media_store_credentials_store.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_health_report.dart';
import 'package:submersion/features/media/data/services/media_health_reporter.dart';
import 'package:submersion/features/media_store/data/media_backfill_service.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';
import 'package:submersion/features/media_store/presentation/pages/photos_videos_page.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_upload_progress_provider.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart'
    show sharedPreferencesProvider;
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/providers/pending_setup_items_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../support/fake_keychain_storage.dart';

/// Counts detaches instead of touching a store.
class RecordingMediaStoreService extends MediaStoreService {
  RecordingMediaStoreService()
    : super(
        credentials: MediaStoreCredentialsStore(storage: InMemoryKeychain()),
        attachState: MediaStoreAttachState(),
        storesRepository: MediaStoresRepository(),
        mediaRepository: MediaRepository(),
      );

  int disconnectCalls = 0;

  /// Thrown by [disconnect] when set.
  Object? failure;

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    if (failure case final f?) throw f;
  }
}

/// Backfill double: returns a fixed count without touching a database.
class FakeBackfillService extends MediaBackfillService {
  FakeBackfillService()
    : super(
        mediaRepository: MediaRepository(),
        queue: MediaTransferQueueRepository(),
      );

  int calls = 0;

  /// Thrown by [enqueueAll] when set.
  Object? failure;

  @override
  Future<int> enqueueAll() async {
    calls++;
    if (failure case final f?) throw f;
    return 7;
  }
}

/// Answers a fixed library report and counts the asks.
class FakeLibraryReporter implements MediaHealthReporter {
  FakeLibraryReporter(this.report);
  final MediaHealthReport report;
  int libraryCalls = 0;

  @override
  Future<MediaHealthReport> forLibrary({bool probeStore = false}) async {
    libraryCalls++;
    return report;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

/// One test's doubles and the page under them.
class PhotosPageHarness {
  PhotosPageHarness._(this.prefs);

  static Future<PhotosPageHarness> create() async {
    SharedPreferences.setMockInitialValues({});
    return PhotosPageHarness._(await SharedPreferences.getInstance());
  }

  final SharedPreferences prefs;
  final service = RecordingMediaStoreService();
  final backfill = FakeBackfillService();

  /// The page. [statusHint] stands for "attached here, under that name";
  /// null is nothing attached. [copies], when given, answers the copies
  /// instead, read afresh on each rebuild of the provider, so a test can
  /// flip what is attached. Riverpod 3 does not export the Override type,
  /// so [extraOverrides] is dynamic (the weight_planner precedent); they
  /// must not override a provider overridden here, which Riverpod rejects.
  Widget app({
    bool apple = true,
    String? statusHint,
    PhotosCopies Function()? copies,
    MediaTransferSummary summary = const MediaTransferSummary(),
    List<dynamic> extraOverrides = const [],
  }) => ProviderScope(
    overrides: [
      mediaStoreRuntimeProvider.overrideWith((ref) async => null),
      mediaStoreCredentialsStoreProvider.overrideWithValue(
        MediaStoreCredentialsStore(storage: InMemoryKeychain()),
      ),
      mediaStoreServiceProvider.overrideWithValue(service),
      mediaBackfillServiceProvider.overrideWithValue(backfill),
      photosCopiesProvider.overrideWith(
        (ref) async =>
            copies?.call() ??
            (
              attached: statusHint != null,
              store: null,
              group: null,
              label: statusHint,
            ),
      ),
      photosStoreReachableProvider.overrideWithValue(true),
      mediaUploadProgressProvider.overrideWith(
        (ref) async => (copied: 0, total: 0),
      ),
      pendingSetupItemsProvider.overrideWith((ref) async => const []),
      sharedPreferencesProvider.overrideWithValue(prefs),
      mediaTransferSummaryProvider.overrideWith((ref) => Stream.value(summary)),
      isApplePlatformProvider.overrideWithValue(apple),
      ...extraOverrides,
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PhotosVideosPage(),
    ),
  );
}
