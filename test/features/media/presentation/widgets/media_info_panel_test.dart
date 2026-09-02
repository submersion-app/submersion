import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/features/media/data/services/media_item_verifier.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_provenance.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/presentation/helpers/media_time_pinner.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_panel.dart';
import 'package:submersion/features/media/presentation/widgets/set_media_time_dialog.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_providers.dart';

MediaItem _item({
  MediaSourceType sourceType = MediaSourceType.platformGallery,
  String? platformAssetId = 'asset-1',
  String? localPath,
  String? originalFilename = 'reef.jpg',
  int? width = 4032,
  int? height = 3024,
  int? contentSizeBytes = 3 * 1024 * 1024,
  String? originDeviceId,
  bool isOrphaned = false,
  DateTime? lastVerifiedAt,
  DateTime? remoteUploadedAt,
  DateTime? remoteThumbUploadedAt,
}) => MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  sourceType: sourceType,
  platformAssetId: platformAssetId,
  localPath: localPath,
  originalFilename: originalFilename,
  width: width,
  height: height,
  contentSizeBytes: contentSizeBytes,
  originDeviceId: originDeviceId,
  isOrphaned: isOrphaned,
  lastVerifiedAt: lastVerifiedAt,
  remoteUploadedAt: remoteUploadedAt,
  remoteThumbUploadedAt: remoteThumbUploadedAt,
  takenAt: DateTime(2026, 3, 12, 9, 14),
  createdAt: DateTime(2026, 3, 12),
  updatedAt: DateTime(2026, 3, 12),
);

/// Reports a fixed result and records what it was asked to verify.
class _FakeVerifier implements MediaItemVerifier {
  _FakeVerifier(this.result, {this.onVerify});

  final VerifyResult result;

  /// Stands in for the row write the real verifier performs.
  final void Function()? onVerify;
  final List<String> verified = [];

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    verified.add(item.id);
    onVerify?.call();
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

class _CapturingQueue implements MediaTransferQueueRepository {
  final List<String> repairEnqueued = [];

  @override
  Future<int> enqueueRepairUpload({required String mediaId}) async {
    repairEnqueued.add(mediaId);
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

class _CapturingPinner implements MediaTimePinner {
  _CapturingPinner(this.applied);
  final List<MediaTimeChoice> applied;

  @override
  Future<void> apply(MediaItem item, MediaTimeChoice choice) async {
    applied.add(choice);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

void main() {
  late String? previousDefaultLocale;
  late MediaServingRecorder recorder;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    recorder = MediaServingRecorder();
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  Future<void> pump(
    WidgetTester tester,
    MediaItem item, {
    bool attached = true,
    QueueFacts? queue,
    MediaStoreIdentity? identity,
    String thisDevice = 'device-here',
    List<dynamic> extra = const [],

    /// Single-element holder so a test can swap the stored row mid-flight,
    /// which is what a persisted action really does.
    List<MediaItem>? liveRow,
  }) async {
    // Four stacked sections overflow a default 800x600 surface, and a
    // ListView does not build what is below the fold, so the Serving block
    // would simply not exist for the finders. A taller viewport is cheaper
    // and less brittle than scrolling to each assertion.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaStoreAttachedProvider.overrideWith((ref) async => attached),
          mediaQueueFactsProvider.overrideWith(
            (ref, id) => Stream.value(queue),
          ),
          mediaStoreIdentityProvider.overrideWith((ref) async => identity),
          currentDeviceIdProvider.overrideWith((ref) async => thisDevice),
          mediaServingRecorderProvider.overrideWithValue(recorder),
          // UnitFormatter reads the diver's date and time preferences, and
          // the real notifier wants SharedPreferences.
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          // The panel re-reads the row so persisted actions show up; without
          // an override this would reach for an uninitialised database.
          mediaByIdProvider.overrideWith(
            (ref, id) async => liveRow == null ? item : liveRow.first,
          ),
          ...extra.cast(),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(body: MediaInfoPanel(item: item)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('File block', () {
    testWidgets('renders filename, dimensions, size and taken date', (
      tester,
    ) async {
      await pump(tester, _item());

      expect(find.text('reef.jpg'), findsOneWidget);
      expect(find.text('4032 x 3024'), findsOneWidget);
      expect(find.text('3.0 MB'), findsOneWidget);
      // Via UnitFormatter, so a plain ASCII space rather than the U+202F
      // narrow no-break space raw intl jm formatting emits.
      expect(find.textContaining('2026'), findsWidgets);
    });

    testWidgets('renders Unknown for absent file facts', (tester) async {
      await pump(
        tester,
        _item(
          originalFilename: null,
          width: null,
          height: null,
          contentSizeBytes: null,
        ),
      );

      expect(find.text('Unknown'), findsWidgets);
    });
  });

  group('Origin block', () {
    testWidgets('renders the source label and the pointer', (tester) async {
      await pump(tester, _item());

      expect(find.text('Photo library'), findsWidgets);
      expect(find.text('asset-1'), findsOneWidget);
    });

    testWidgets('a missing row renders the missing status', (tester) async {
      await pump(tester, _item(isOrphaned: true));

      expect(find.text('Missing from this device'), findsOneWidget);
    });

    testWidgets('an unverified row renders the unchecked status', (
      tester,
    ) async {
      await pump(tester, _item());

      expect(find.text('Not checked yet'), findsOneWidget);
    });

    testWidgets('a verified row shows found plus the check date', (
      tester,
    ) async {
      await pump(tester, _item(lastVerifiedAt: DateTime(2026, 8, 1, 10)));

      expect(find.text('Found on this device'), findsOneWidget);
      expect(find.textContaining('Last checked'), findsOneWidget);
    });

    // Null originDeviceId means the source type does not track one, which is
    // true of five of the seven types. Claiming "This device" there would
    // assert a fact the app never recorded, on every gallery photo.
    testWidgets('omits the linked-on row when no device was recorded', (
      tester,
    ) async {
      await pump(tester, _item());

      expect(find.text('Linked on'), findsNothing);
    });

    testWidgets('names this device when the ids match', (tester) async {
      await pump(
        tester,
        _item(sourceType: MediaSourceType.localFile, originDeviceId: 'dev-a'),
        thisDevice: 'dev-a',
      );

      expect(find.text('This device'), findsOneWidget);
    });

    testWidgets('names another device when the ids differ', (tester) async {
      await pump(
        tester,
        _item(sourceType: MediaSourceType.localFile, originDeviceId: 'dev-b'),
        thisDevice: 'dev-a',
      );

      expect(find.text('Another device'), findsOneWidget);
    });
  });

  group('Backup block', () {
    testWidgets('an ineligible source says so instead of not backed up', (
      tester,
    ) async {
      await pump(
        tester,
        _item(sourceType: MediaSourceType.networkUrl, platformAssetId: null),
      );

      expect(
        find.text('This source is not eligible for backup'),
        findsOneWidget,
      );
      expect(find.text('Not backed up'), findsNothing);
    });

    testWidgets('no store connected renders the not-connected line ONCE', (
      tester,
    ) async {
      // findsOneWidget, not findsWidgets. The store row and the summary row
      // both fell back to this same string, so the panel printed it twice and
      // a one-or-more matcher could not see the difference.
      await pump(tester, _item(), attached: false);

      expect(find.text('No cloud store connected'), findsOneWidget);
    });

    testWidgets('a thumb-only row says the original was not sent', (
      tester,
    ) async {
      await pump(
        tester,
        _item(remoteThumbUploadedAt: DateTime(2026, 7, 1)),
        identity: const MediaStoreIdentity(
          providerType: 's3',
          displayHint: 'dive-media @ minio.host',
        ),
      );

      expect(find.text('dive-media @ minio.host'), findsOneWidget);
      expect(find.text('Thumbnail only, original not sent'), findsOneWidget);
    });

    testWidgets('an uploaded row shows the upload date', (tester) async {
      await pump(tester, _item(remoteUploadedAt: DateTime(2026, 7, 1, 8)));

      expect(find.text('Original uploaded'), findsOneWidget);
      expect(find.textContaining('Uploaded'), findsWidgets);
    });

    testWidgets('a failed queue row shows its error', (tester) async {
      await pump(
        tester,
        _item(),
        queue: const QueueFacts(state: 'failed', error: 'network down'),
      );

      expect(find.text('Upload failed: network down'), findsOneWidget);
    });

    testWidgets('a settled queue row adds no line', (tester) async {
      await pump(tester, _item(), queue: const QueueFacts(state: 'done'));

      expect(find.textContaining('Uploading'), findsNothing);
      expect(find.textContaining('Waiting'), findsNothing);
    });
  });

  group('Serving block', () {
    testWidgets('an unobserved item says not loaded yet', (tester) async {
      await pump(tester, _item());

      expect(find.text('Not loaded yet'), findsOneWidget);
    });

    testWidgets('a store-cache serving reads as local cache', (tester) async {
      recorder.record(
        'm1',
        thumbnail: false,
        servedFrom: ServedFrom.storeCache,
      );
      await pump(tester, _item());

      expect(find.text('Local cache, from the cloud store'), findsOneWidget);
    });

    testWidgets('a non-original tier is named alongside the source', (
      tester,
    ) async {
      recorder.record(
        'm1',
        thumbnail: false,
        servedFrom: ServedFrom.storeNetwork,
        servedTier: ServedTier.rendition,
      );
      await pump(tester, _item());

      expect(
        find.text('Downloaded from the cloud store (Compressed version)'),
        findsOneWidget,
      );
    });

    testWidgets('a store fallback adds the fallback note', (tester) async {
      recorder.record(
        'm1',
        thumbnail: false,
        servedFrom: ServedFrom.storeNetwork,
        storeFallbackUsed: true,
      );
      await pump(tester, _item());

      expect(
        find.textContaining('original source could not be reached'),
        findsOneWidget,
      );
    });

    testWidgets('a failed resolution reads as could not be loaded', (
      tester,
    ) async {
      recorder.record(
        'm1',
        thumbnail: false,
        failure: UnavailableKind.notFound,
        storeFallbackUsed: true,
      );
      await pump(tester, _item());

      expect(find.text('Could not be loaded'), findsOneWidget);
      // The fallback note explains where bytes CAME from, so it must not
      // appear when nothing was served.
      expect(
        find.textContaining('original source could not be reached'),
        findsNothing,
      );
    });

    // The whole point of the ListenableBuilder: a tile that resolves while
    // the panel is open must update it.
    testWidgets('refreshes when the recorder records', (tester) async {
      await pump(tester, _item());
      expect(find.text('Not loaded yet'), findsOneWidget);

      recorder.record('m1', thumbnail: false, servedFrom: ServedFrom.localDisk);
      await tester.pumpAndSettle();

      expect(find.text('Not loaded yet'), findsNothing);
      expect(find.text('Local file on this device'), findsOneWidget);
    });
  });

  // A persisted action has to change what the panel shows. The provenance
  // provider is keyed by the MediaItem VALUE, so invalidating it alone
  // recomputes from the same stale object and the Status row never moves.
  group('reflects persisted changes', () {
    testWidgets('Check now updates the status row from the re-read row', (
      tester,
    ) async {
      // The stored row starts unverified and becomes missing once the
      // verifier has run, exactly as the real write does.
      final row = [_item()];
      final verifier = _FakeVerifier(
        VerifyResult.notFound,
        onVerify: () => row[0] = _item(
          isOrphaned: true,
          lastVerifiedAt: DateTime(2026, 8, 2),
        ),
      );

      await pump(
        tester,
        _item(),
        liveRow: row,
        extra: [mediaItemVerifierProvider.overrideWithValue(verifier)],
      );

      // Seeded state, before any action.
      expect(find.text('Not checked yet'), findsOneWidget);

      await tester.tap(find.text('Check now'));
      await tester.pumpAndSettle();

      expect(find.text('Missing from this device'), findsOneWidget);
      expect(find.text('Not checked yet'), findsNothing);
    });
  });

  group('Actions', () {
    testWidgets('Check now is always offered', (tester) async {
      await pump(tester, _item());

      expect(find.text('Check now'), findsOneWidget);
    });

    testWidgets('Check now verifies and reports the result', (tester) async {
      final verifier = _FakeVerifier(VerifyResult.notFound);
      await pump(
        tester,
        _item(),
        extra: [mediaItemVerifierProvider.overrideWithValue(verifier)],
      );

      await tester.tap(find.text('Check now'));
      await tester.pumpAndSettle();

      expect(verifier.verified, ['m1']);
      expect(find.text('Source is missing'), findsOneWidget);
    });

    testWidgets('a recoverable check result reads as could not check', (
      tester,
    ) async {
      await pump(
        tester,
        _item(),
        extra: [
          mediaItemVerifierProvider.overrideWithValue(
            _FakeVerifier(VerifyResult.volumeOffline),
          ),
        ],
      );

      await tester.tap(find.text('Check now'));
      await tester.pumpAndSettle();

      // An unmounted volume is not a missing file, and saying so would push
      // the reader toward relinking something that is merely offline.
      expect(find.text('Could not check right now'), findsOneWidget);
      expect(find.text('Source is missing'), findsNothing);
    });

    testWidgets('Locate appears only for a missing local file', (tester) async {
      await pump(
        tester,
        _item(
          sourceType: MediaSourceType.localFile,
          platformAssetId: null,
          localPath: '/gone/reef.jpg',
          isOrphaned: true,
        ),
      );

      expect(find.text('Locate file...'), findsOneWidget);
    });

    // Picking a file for a gallery row would relink it to the wrong source
    // type, so the repair engine's file candidate is not offered there.
    testWidgets('Locate is absent for a missing gallery row', (tester) async {
      await pump(tester, _item(isOrphaned: true));

      expect(find.text('Locate file...'), findsNothing);
    });

    testWidgets('Locate is absent for a healthy local file', (tester) async {
      await pump(
        tester,
        _item(
          sourceType: MediaSourceType.localFile,
          platformAssetId: null,
          localPath: '/here/reef.jpg',
          lastVerifiedAt: DateTime(2026, 8, 1),
        ),
      );

      expect(find.text('Locate file...'), findsNothing);
    });

    testWidgets('Copy reference puts the pointer on the clipboard', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pump(tester, _item());
      await tester.tap(find.text('Copy reference'));
      await tester.pumpAndSettle();

      expect(copied, ['asset-1']);
      expect(find.text('Reference copied'), findsOneWidget);
    });

    testWidgets('Back up now is hidden when already fully backed up', (
      tester,
    ) async {
      await pump(tester, _item(remoteUploadedAt: DateTime(2026, 7)));

      expect(find.text('Back up now'), findsNothing);
    });

    testWidgets('Back up now is hidden when no store is attached', (
      tester,
    ) async {
      await pump(tester, _item(), attached: false);

      expect(find.text('Back up now'), findsNothing);
    });

    testWidgets('Back up now is hidden for an ineligible source', (
      tester,
    ) async {
      await pump(
        tester,
        _item(sourceType: MediaSourceType.networkUrl, platformAssetId: null),
      );

      expect(find.text('Back up now'), findsNothing);
    });

    testWidgets('Back up now enqueues a repair upload', (tester) async {
      final queue = _CapturingQueue();
      await pump(
        tester,
        _item(),
        extra: [
          mediaTransferQueueRepositoryProvider.overrideWithValue(queue),
          mediaStoreRuntimeProvider.overrideWith((ref) async => null),
        ],
      );

      await tester.tap(find.text('Back up now'));
      await tester.pumpAndSettle();

      expect(queue.repairEnqueued, ['m1']);
      expect(find.text('Queued for upload'), findsOneWidget);
    });

    // enqueueRepairUpload is what re-arms a terminally failed row, so the
    // only difference here is the label.
    testWidgets('the label reads Retry upload when the queue row failed', (
      tester,
    ) async {
      await pump(
        tester,
        _item(),
        queue: const QueueFacts(state: 'failed', error: 'network down'),
      );

      expect(find.text('Retry upload'), findsOneWidget);
      expect(find.text('Back up now'), findsNothing);
    });

    // The answer to "is it uploading" is already on screen, and a second
    // nudge would only re-enqueue what is already queued.
    testWidgets('no upload action while a transfer is in flight', (
      tester,
    ) async {
      await pump(
        tester,
        _item(),
        queue: const QueueFacts(state: 'transferring'),
      );

      expect(find.text('Back up now'), findsNothing);
      expect(find.text('Retry upload'), findsNothing);
    });
  });

  group('Time in dive (issue #1090)', () {
    final dive = domain.Dive(
      id: 'd1',
      dateTime: DateTime.utc(2026, 3, 12, 9),
      profile: const [
        domain.DiveProfilePoint(timestamp: 0, depth: 0),
        domain.DiveProfilePoint(timestamp: 600, depth: 20),
        domain.DiveProfilePoint(timestamp: 1800, depth: 0),
      ],
    );

    MediaItem linked({MediaEnrichment? enrichment}) => MediaItem(
      id: 'm1',
      diveId: 'd1',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      platformAssetId: 'asset-1',
      takenAt: DateTime(2026, 3, 12, 9, 14),
      createdAt: DateTime(2026, 3, 12),
      updatedAt: DateTime(2026, 3, 12),
      enrichment: enrichment,
    );

    MediaEnrichment enrichmentAt(
      int elapsedSeconds, {
      MatchConfidence confidence = MatchConfidence.exact,
    }) => MediaEnrichment(
      id: 'e1',
      mediaId: 'm1',
      diveId: 'd1',
      elapsedSeconds: elapsedSeconds,
      depthMeters: 12,
      matchConfidence: confidence,
      createdAt: DateTime(2026, 3, 12),
    );

    final diveOverride = diveProvider('d1').overrideWith((ref) async => dive);

    testWidgets('renders the automatic position as mm:ss', (tester) async {
      await pump(
        tester,
        linked(enrichment: enrichmentAt(750)),
        extra: [diveOverride],
      );

      expect(find.text('Time in dive'), findsOneWidget);
      expect(find.text('12:30'), findsOneWidget);
    });

    testWidgets('marks a manual position as set by the diver', (tester) async {
      await pump(
        tester,
        linked(
          enrichment: enrichmentAt(750, confidence: MatchConfidence.manual),
        ),
        extra: [diveOverride],
      );

      expect(find.text('12:30 (set manually)'), findsOneWidget);
    });

    testWidgets('renders Unknown for a position outside the dive window', (
      tester,
    ) async {
      await pump(
        tester,
        linked(
          enrichment: enrichmentAt(
            1879 * 60,
            confidence: MatchConfidence.estimated,
          ),
        ),
        extra: [diveOverride],
      );

      expect(find.text('Time in dive'), findsOneWidget);
      expect(find.text('1879:00'), findsNothing);
    });

    testWidgets('offers no row or action for an item with no dive', (
      tester,
    ) async {
      await pump(tester, _item());

      expect(find.text('Time in dive'), findsNothing);
      expect(find.text('Set time in dive'), findsNothing);
    });

    testWidgets('Set time in dive opens the dialog and applies the choice', (
      tester,
    ) async {
      final applied = <MediaTimeChoice>[];
      await pump(
        tester,
        linked(enrichment: enrichmentAt(750)),
        extra: [
          diveOverride,
          mediaTimePinnerProvider.overrideWithValue(_CapturingPinner(applied)),
        ],
      );

      await tester.tap(find.text('Set time in dive'));
      await tester.pumpAndSettle();
      expect(find.byType(SetMediaTimeDialog), findsOneWidget);

      await tester.enterText(find.byType(TextField), '5:00');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(applied, hasLength(1));
      expect((applied.single as MediaTimePinned).elapsedSeconds, 300);
    });
  });
}
