import 'dart:async';

import 'package:flutter/services.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/media_health_report.dart';
import 'package:submersion/features/media/data/services/media_health_reporter.dart';
import 'package:submersion/features/media/data/services/media_item_verifier.dart';
import 'package:submersion/features/media/data/services/photo_access_actions.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/providers/photo_access_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_provenance.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/features/media/presentation/providers/media_health_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import '../../../../helpers/fake_photo_picker_service.dart';
import 'media_info_panel_harness.dart';

const _item = infoPanelItem;

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

/// Answers a fixed one-row report for whatever item it is asked about.
class _FakeReporter implements MediaHealthReporter {
  _FakeReporter(this.report);
  final MediaHealthReport report;
  final List<String> asked = [];

  @override
  Future<MediaHealthReport> forItem(
    MediaItem item, {
    bool probeStore = false,
  }) async {
    asked.add('${item.id}:$probeStore');
    return report;
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
    Stream<Map<String, String>>? peerNames,
    List<dynamic> extra = const [],
    List<MediaItem>? liveRow,
    EditSession<PhotoRecord>? sitting,
  }) => pumpInfoPanel(
    tester,
    item,
    recorder: recorder,
    attached: attached,
    queue: queue,
    identity: identity,
    thisDevice: thisDevice,
    peerNames: peerNames,
    extra: extra,
    liveRow: liveRow,
    sitting: sitting,
  );

  /// The photo's sitting, which Locate holds its relink in (issue #4527).
  EditSession<PhotoRecord> sittingOver(MediaItem item) {
    final sitting = EditSession<PhotoRecord>(
      PhotoRecord(item: item, species: const [], people: const []),
    );
    addTearDown(sitting.dispose);
    return sitting;
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

  // Under limited photo access a gallery photo may be outside what the user
  // allowed, so the panel offers the two ways back (spec 6.3).
  group('Limited photo access', () {
    testWidgets('a gallery row offers full access and the selection', (
      tester,
    ) async {
      await pump(
        tester,
        _item(),
        extra: [galleryAccessLimitedProvider.overrideWith((ref) async => true)],
      );

      expect(find.text('Allow full access'), findsOneWidget);
      expect(find.text('Choose photo again'), findsOneWidget);
    });

    // Coming back from the selection sheet re-reads the access state, so
    // the buttons go once the user has granted what the photo needs.
    testWidgets('an action refreshes the access state', (tester) async {
      var reads = 0;
      await pump(
        tester,
        _item(),
        extra: [
          galleryAccessLimitedProvider.overrideWith((ref) async {
            reads++;
            return true;
          }),
          photoAccessActionsProvider.overrideWithValue(_NoopAccessActions()),
          assetResolutionServiceProvider.overrideWithValue(
            AssetResolutionService(
              cacheRepository: LocalAssetCacheRepository(),
              photoPickerService: FakePhotoPickerService(),
            ),
          ),
        ],
      );
      expect(reads, 1);

      await tester.tap(find.text('Choose photo again'));
      await tester.pumpAndSettle();

      expect(reads, 2);
    });

    testWidgets('full access offers neither', (tester) async {
      await pump(
        tester,
        _item(),
        extra: [
          galleryAccessLimitedProvider.overrideWith((ref) async => false),
        ],
      );

      expect(find.text('Allow full access'), findsNothing);
    });

    testWidgets('a file row offers neither', (tester) async {
      await pump(
        tester,
        _item(
          sourceType: MediaSourceType.localFile,
          platformAssetId: null,
          localPath: 'reef.jpg',
        ),
        extra: [galleryAccessLimitedProvider.overrideWith((ref) async => true)],
      );

      expect(find.text('Allow full access'), findsNothing);
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

    testWidgets('Copy diagnostics puts the one-row report on the clipboard', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
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
      final reporter = _FakeReporter(
        MediaHealthReport(
          generatedAt: DateTime.utc(2026, 7, 1),
          deviceId: 'dev-a',
          attachedStoreId: 'store-1',
          markerStoreId: 'store-1',
          rows: [
            MediaHealthRow(
              mediaId: 'm1',
              sourceType: 'localFile',
              takenAt: DateTime.utc(2026, 7, 1),
              isOrphaned: false,
              pending: false,
              resolverVerdict: 'available',
            ),
          ],
        ),
      );
      await pump(
        tester,
        _item(sourceType: MediaSourceType.localFile, originDeviceId: 'dev-a'),
        thisDevice: 'dev-a',
        extra: [mediaHealthReporterProvider.overrideWithValue(reporter)],
      );

      await tester.ensureVisible(find.text('Copy diagnostics'));
      await tester.tap(find.text('Copy diagnostics'));
      await tester.pumpAndSettle();

      expect(reporter.asked, ['m1:true']);
      expect(copied.single, contains('attached_store: store-1'));
      expect(copied.single, contains('media_id: m1'));
      expect(find.text('Diagnostics copied'), findsOneWidget);
    });

    testWidgets('names another device when the ids differ', (tester) async {
      await pump(
        tester,
        _item(sourceType: MediaSourceType.localFile, originDeviceId: 'dev-b'),
        thisDevice: 'dev-a',
      );

      expect(find.text('Another device'), findsOneWidget);
    });

    testWidgets('shows the peer\'s published name when it is known', (
      tester,
    ) async {
      await pump(
        tester,
        _item(sourceType: MediaSourceType.localFile, originDeviceId: 'dev-b'),
        thisDevice: 'dev-a',
        peerNames: Stream.value(const {'dev-b': "Eric's MacBook"}),
      );

      expect(find.text("Eric's MacBook"), findsOneWidget);
      expect(find.text('Another device'), findsNothing);
    });

    testWidgets('updates in place when a sync learns the name', (tester) async {
      final names = StreamController<Map<String, String>>();
      addTearDown(names.close);
      await pump(
        tester,
        _item(sourceType: MediaSourceType.localFile, originDeviceId: 'dev-b'),
        thisDevice: 'dev-a',
        peerNames: names.stream,
      );
      expect(find.text('Another device'), findsOneWidget);

      names.add(const {'dev-b': "Eric's MacBook"});
      await tester.pumpAndSettle();

      expect(find.text("Eric's MacBook"), findsOneWidget);
      expect(find.text('Another device'), findsNothing);
    });

    // The verdict columns sync, and a device that cannot reach another
    // device's path writes nothing, so a verdict on a row linked elsewhere
    // was recorded there. Saying "this device" beside a Serving block that
    // reports the source unreachable contradicted it (issue #2458).
    group('verdict recorded on the linking device', () {
      testWidgets('found names the peer that linked it', (tester) async {
        await pump(
          tester,
          _item(
            sourceType: MediaSourceType.localFile,
            originDeviceId: 'dev-b',
            lastVerifiedAt: DateTime(2026, 8, 1, 10),
          ),
          thisDevice: 'dev-a',
          peerNames: Stream.value(const {'dev-b': "Eric's MacBook"}),
        );

        expect(find.text("Found on Eric's MacBook"), findsOneWidget);
        expect(find.text('Found on this device'), findsNothing);
      });

      testWidgets('found falls back to another device when unnamed', (
        tester,
      ) async {
        await pump(
          tester,
          _item(
            sourceType: MediaSourceType.localFile,
            originDeviceId: 'dev-b',
            lastVerifiedAt: DateTime(2026, 8, 1, 10),
          ),
          thisDevice: 'dev-a',
        );

        expect(find.text('Found on another device'), findsOneWidget);
        expect(find.text('Found on this device'), findsNothing);
      });

      testWidgets('missing names the peer that linked it', (tester) async {
        await pump(
          tester,
          _item(
            sourceType: MediaSourceType.localFile,
            originDeviceId: 'dev-b',
            isOrphaned: true,
          ),
          thisDevice: 'dev-a',
          peerNames: Stream.value(const {'dev-b': "Eric's MacBook"}),
        );

        expect(find.text("Missing from Eric's MacBook"), findsOneWidget);
        expect(find.text('Missing from this device'), findsNothing);
      });

      testWidgets('missing falls back to another device when unnamed', (
        tester,
      ) async {
        await pump(
          tester,
          _item(
            sourceType: MediaSourceType.localFile,
            originDeviceId: 'dev-b',
            isOrphaned: true,
          ),
          thisDevice: 'dev-a',
        );

        expect(find.text('Missing from another device'), findsOneWidget);
        expect(find.text('Missing from this device'), findsNothing);
      });

      testWidgets('a row linked here keeps the this-device wording', (
        tester,
      ) async {
        await pump(
          tester,
          _item(
            sourceType: MediaSourceType.localFile,
            originDeviceId: 'dev-a',
            lastVerifiedAt: DateTime(2026, 8, 1, 10),
          ),
          thisDevice: 'dev-a',
        );

        expect(find.text('Found on this device'), findsOneWidget);
      });
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
      final item = _item(
        sourceType: MediaSourceType.localFile,
        platformAssetId: null,
        localPath: '/gone/reef.jpg',
        isOrphaned: true,
      );
      await pump(tester, item, sitting: sittingOver(item));

      expect(find.text('Locate file...'), findsOneWidget);
    });

    // Picking a file for a gallery row would relink it to the wrong source
    // type, so the repair engine's file candidate is not offered there.
    testWidgets('Locate is absent for a missing gallery row', (tester) async {
      final item = _item(isOrphaned: true);
      await pump(tester, item, sitting: sittingOver(item));

      expect(find.text('Locate file...'), findsNothing);
    });

    testWidgets('Locate is absent for a healthy local file', (tester) async {
      final item = _item(
        sourceType: MediaSourceType.localFile,
        platformAssetId: null,
        localPath: '/here/reef.jpg',
        lastVerifiedAt: DateTime(2026, 8, 1),
      );
      await pump(tester, item, sitting: sittingOver(item));

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

      expect(find.text('Copy now'), findsNothing);
    });

    testWidgets('Back up now is hidden when no store is attached', (
      tester,
    ) async {
      await pump(tester, _item(), attached: false);

      expect(find.text('Copy now'), findsNothing);
    });

    testWidgets('Back up now is hidden for an ineligible source', (
      tester,
    ) async {
      await pump(
        tester,
        _item(sourceType: MediaSourceType.networkUrl, platformAssetId: null),
      );

      expect(find.text('Copy now'), findsNothing);
    });

    testWidgets('Copy now enqueues a repair upload', (tester) async {
      final queue = _CapturingQueue();
      await pump(
        tester,
        _item(),
        extra: [
          mediaTransferQueueRepositoryProvider.overrideWithValue(queue),
          mediaStoreRuntimeProvider.overrideWith((ref) async => null),
        ],
      );

      // The section's name follows the Photos page (issue #3482).
      expect(find.text('Copies in the cloud'), findsOneWidget);
      await tester.tap(find.text('Copy now'));
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
      expect(find.text('Copy now'), findsNothing);
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

      expect(find.text('Copy now'), findsNothing);
      expect(find.text('Retry upload'), findsNothing);
    });
  });
}

class _NoopAccessActions implements PhotoAccessActions {
  @override
  Future<void> openSettings() async {}

  @override
  Future<void> chooseMorePhotos() async {}
}
