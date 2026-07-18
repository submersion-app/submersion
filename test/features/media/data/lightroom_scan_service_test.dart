import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart'
    show DiveProfilesCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/core/services/lightroom/lightroom_models.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/lightroom_connector_state.dart';
import 'package:submersion/features/media/data/services/lightroom_scan_service.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';

import '../../../helpers/test_database.dart';

class _FakeLightroomApi extends LightroomApiClient {
  _FakeLightroomApi({required this.assets, this.albumAssets = const {}})
    : super(auth: AdobeImsAuthManager());

  final List<LightroomAsset> assets;
  final Map<String, List<LightroomAsset>> albumAssets;
  final List<({DateTime? after, DateTime? before})> assetCalls = [];
  final List<String> albumCalls = [];

  @override
  Future<LightroomAssetPage> listAssets(
    String catalogId, {
    DateTime? capturedAfter,
    DateTime? capturedBefore,
    String? nextUrl,
  }) async {
    assetCalls.add((after: capturedAfter, before: capturedBefore));
    final inSpan = assets
        .where(
          (a) =>
              a.captureDate == null ||
              ((capturedAfter == null ||
                      !a.captureDate!.isBefore(capturedAfter)) &&
                  (capturedBefore == null ||
                      !a.captureDate!.isAfter(capturedBefore))),
        )
        .toList();
    return LightroomAssetPage(assets: inSpan);
  }

  @override
  Future<LightroomAssetPage> listAlbumAssets(
    String catalogId,
    String albumId, {
    String? nextUrl,
  }) async {
    albumCalls.add(albumId);
    return LightroomAssetPage(assets: albumAssets[albumId] ?? const []);
  }
}

void main() {
  late MediaRepository mediaRepository;
  late DiveRepository diveRepository;
  late LightroomConnectorState state;
  late List<String> enqueued;

  final account = ConnectedAccount(
    id: 'acct1',
    kind: AccountKind.adobeLightroom,
    label: 'Eric',
    accountIdentifier: 'cat1',
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    mediaRepository = MediaRepository();
    diveRepository = DiveRepository();
    state = LightroomConnectorState(prefs: prefs, accountId: account.id);
    enqueued = [];
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  LightroomScanService service(_FakeLightroomApi api) => LightroomScanService(
    api: api,
    mediaRepository: mediaRepository,
    diveRepository: diveRepository,
    enqueueUpload: enqueued.add,
    now: () => DateTime.utc(2026, 7, 11, 12),
  );

  Future<Dive> createDive({required DateTime entry, required DateTime exit}) =>
      diveRepository.createDive(
        Dive(id: '', dateTime: entry, entryTime: entry, exitTime: exit),
      );

  LightroomAsset image(String id, DateTime? captured) => LightroomAsset(
    id: id,
    subtype: 'image',
    captureDate: captured,
    fileName: '$id.jpg',
  );

  test('mergeWindows merges overlapping windows and keeps disjoint spans', () {
    final bounds = [
      DiveBounds(
        diveId: 'A',
        entryTime: DateTime.utc(2026, 7, 1, 10),
        exitTime: DateTime.utc(2026, 7, 1, 11),
      ),
      // B's pre-buffer (12:30 - 30m = 12:00) touches A's post-buffer
      // (11:00 + 60m = 12:00): one merged span.
      DiveBounds(
        diveId: 'B',
        entryTime: DateTime.utc(2026, 7, 1, 12, 30),
        exitTime: DateTime.utc(2026, 7, 1, 13, 30),
      ),
      DiveBounds(
        diveId: 'C',
        entryTime: DateTime.utc(2026, 7, 3, 10),
        exitTime: DateTime.utc(2026, 7, 3, 11),
      ),
    ];
    final spans = LightroomScanService.mergeWindows(bounds);
    expect(spans, hasLength(2));
    expect(spans[0].start, DateTime.utc(2026, 7, 1, 9, 30));
    expect(spans[0].end, DateTime.utc(2026, 7, 1, 14, 30));
    expect(spans[1].start, DateTime.utc(2026, 7, 3, 9, 30));
    expect(spans[1].end, DateTime.utc(2026, 7, 3, 12));
  });

  test('catalog scan sends a single cursor - captured_before only, never '
      'captured_after (Adobe 400s on both)', () async {
    final dive = await createDive(
      entry: DateTime.utc(2026, 7, 1, 10),
      exit: DateTime.utc(2026, 7, 1, 11),
    );
    final api = _FakeLightroomApi(
      assets: [image('lr1', DateTime.utc(2026, 7, 1, 10, 30))],
    );
    await service(api).scanDives(account: account, dives: [dive], state: state);

    expect(api.assetCalls, isNotEmpty);
    for (final call in api.assetCalls) {
      expect(call.after, isNull, reason: 'captured_after must not be sent');
      expect(call.before, isNotNull);
    }
  });

  test('scan early-stops when the pager returns an asset older than the '
      'window start (nothing attaches)', () async {
    final dive = await createDive(
      entry: DateTime.utc(2026, 7, 1, 10),
      exit: DateTime.utc(2026, 7, 1, 11),
    );
    // Window is [09:30, 12:00]; this asset predates the start. The listing is
    // newest-first, so crossing below the start means every later asset is
    // older too -- the scan stops here and attaches nothing.
    final api = _FakeLightroomApi(
      assets: [image('old', DateTime.utc(2026, 7, 1, 9))],
    );
    final summary = await service(
      api,
    ).scanDives(account: account, dives: [dive], state: state);

    expect(summary.attached, 0);
    expect(api.assetCalls, isNotEmpty);
  });

  test('confident match attaches a connector media row with enrichment and '
      'enqueues an upload', () async {
    final dive = await createDive(
      entry: DateTime.utc(2026, 7, 1, 10),
      exit: DateTime.utc(2026, 7, 1, 11),
    );
    final db = DatabaseService.instance.database;
    for (final (ts, depth) in [(0, 0.0), (1800, 18.0), (3600, 0.0)]) {
      await db
          .into(db.diveProfiles)
          .insert(
            DiveProfilesCompanion(
              id: Value('p$ts'),
              diveId: Value(dive.id),
              isPrimary: const Value(true),
              timestamp: Value(ts),
              depth: Value(depth),
            ),
          );
    }

    final asset = LightroomAsset(
      id: 'lr1',
      subtype: 'image',
      captureDate: DateTime.utc(2026, 7, 1, 10, 30),
      fileName: 'reef.jpg',
      latitude: 4.5,
      longitude: 55.5,
    );
    final api = _FakeLightroomApi(assets: [asset]);
    final summary = await service(
      api,
    ).scanDives(account: account, dives: [dive], state: state);

    expect(summary.attached, 1);
    expect(summary.examined, 1);

    final media = await mediaRepository.getMediaForDive(dive.id);
    expect(media, hasLength(1));
    final item = media.single;
    expect(item.sourceType, MediaSourceType.serviceConnector);
    expect(item.remoteAssetId, 'lr1');
    expect(item.connectorAccountId, 'acct1');
    expect(item.originalFilename, 'reef.jpg');
    expect(item.latitude, 4.5);
    // The repository maps takenAt back through the local zone; the instant
    // is what must survive.
    expect(
      item.takenAt.millisecondsSinceEpoch,
      DateTime.utc(2026, 7, 1, 10, 30).millisecondsSinceEpoch,
    );
    expect(item.enrichment, isNotNull);
    expect(item.enrichment!.depthMeters, 18.0);
    expect(enqueued, [item.id]);
  });

  test('video asset attaches with duration and enqueues', () async {
    final dive = await createDive(
      entry: DateTime.utc(2026, 7, 1, 10),
      exit: DateTime.utc(2026, 7, 1, 11),
    );
    final api = _FakeLightroomApi(
      assets: [
        LightroomAsset(
          id: 'vid1',
          subtype: 'video',
          captureDate: DateTime.utc(2026, 7, 1, 10, 15),
          fileName: 'clip.mp4',
          videoDurationSeconds: 42,
        ),
      ],
    );
    final summary = await service(
      api,
    ).scanDives(account: account, dives: [dive], state: state);

    expect(summary.attached, 1);
    final item = (await mediaRepository.getMediaForDive(dive.id)).single;
    expect(item.mediaType, domain.MediaType.video);
    expect(item.durationSeconds, 42);
    expect(enqueued, [item.id]);
  });

  test('ambiguous match creates one suggestion per candidate dive and no '
      'media row', () async {
    final diveA = await createDive(
      entry: DateTime.utc(2026, 7, 1, 10),
      exit: DateTime.utc(2026, 7, 1, 11),
    );
    final diveB = await createDive(
      entry: DateTime.utc(2026, 7, 1, 12, 30),
      exit: DateTime.utc(2026, 7, 1, 13, 30),
    );
    final api = _FakeLightroomApi(
      assets: [image('surface1', DateTime.utc(2026, 7, 1, 12))],
    );
    final summary = await service(
      api,
    ).scanDives(account: account, dives: [diveA, diveB], state: state);

    expect(summary.attached, 0);
    expect(summary.suggested, 1);
    expect(await mediaRepository.getMediaForDive(diveA.id), isEmpty);
    expect(await mediaRepository.getMediaForDive(diveB.id), isEmpty);
    final forA = await mediaRepository.getPendingSuggestionsForDive(diveA.id);
    final forB = await mediaRepository.getPendingSuggestionsForDive(diveB.id);
    expect(forA, hasLength(1));
    expect(forB, hasLength(1));
    expect(forA.single.remoteAssetId, 'surface1');
    expect(forA.single.connectorAccountId, 'acct1');
    expect(enqueued, isEmpty);
  });

  test('already linked and already suggested assets are skipped', () async {
    final dive = await createDive(
      entry: DateTime.utc(2026, 7, 1, 10),
      exit: DateTime.utc(2026, 7, 1, 11),
    );
    await mediaRepository.createMedia(
      domain.MediaItem(
        id: '',
        diveId: dive.id,
        mediaType: domain.MediaType.photo,
        takenAt: DateTime.utc(2026, 7, 1, 10, 30),
        createdAt: DateTime.utc(2026, 7, 1),
        updatedAt: DateTime.utc(2026, 7, 1),
        sourceType: MediaSourceType.serviceConnector,
        connectorAccountId: 'other-device-acct',
        remoteAssetId: 'linked1',
      ),
    );
    await mediaRepository.createPendingSuggestion(
      domain.PendingPhotoSuggestion(
        id: '',
        diveId: dive.id,
        platformAssetId: 'suggested1',
        takenAt: DateTime.utc(2026, 7, 1, 10, 40),
        createdAt: DateTime.utc(2026, 7, 1),
        connectorAccountId: 'acct1',
        remoteAssetId: 'suggested1',
      ),
    );

    final api = _FakeLightroomApi(
      assets: [
        image('linked1', DateTime.utc(2026, 7, 1, 10, 30)),
        image('suggested1', DateTime.utc(2026, 7, 1, 10, 40)),
      ],
    );
    final summary = await service(
      api,
    ).scanDives(account: account, dives: [dive], state: state);

    expect(summary.skippedExisting, 2);
    expect(summary.attached, 0);
    expect((await mediaRepository.getMediaForDive(dive.id)), hasLength(1));
    expect(enqueued, isEmpty);
  });

  test('asset without capture date is counted and skipped', () async {
    final dive = await createDive(
      entry: DateTime.utc(2026, 7, 1, 10),
      exit: DateTime.utc(2026, 7, 1, 11),
    );
    final api = _FakeLightroomApi(assets: [image('nodate', null)]);
    final summary = await service(
      api,
    ).scanDives(account: account, dives: [dive], state: state);

    expect(summary.skippedNoCaptureTime, 1);
    expect(summary.attached, 0);
  });

  test(
    'album filter routes through listAlbumAssets and still window-filters',
    () async {
      final dive = await createDive(
        entry: DateTime.utc(2026, 7, 1, 10),
        exit: DateTime.utc(2026, 7, 1, 11),
      );
      await state.setAlbumIds(['al1']);
      final api = _FakeLightroomApi(
        assets: [image('catalogOnly', DateTime.utc(2026, 7, 1, 10, 30))],
        albumAssets: {
          'al1': [
            image('inAlbum', DateTime.utc(2026, 7, 1, 10, 30)),
            image('outOfWindow', DateTime.utc(2026, 6, 1)),
          ],
        },
      );
      final summary = await service(
        api,
      ).scanDives(account: account, dives: [dive], state: state);

      expect(api.albumCalls, ['al1']);
      expect(api.assetCalls, isEmpty);
      expect(summary.attached, 1);
      final item = (await mediaRepository.getMediaForDive(dive.id)).single;
      expect(item.remoteAssetId, 'inAlbum');
    },
  );

  test(
    'confirmSuggestion attaches the dive and clears all candidate rows',
    () async {
      final diveA = await createDive(
        entry: DateTime.utc(2026, 7, 1, 10),
        exit: DateTime.utc(2026, 7, 1, 11),
      );
      final diveB = await createDive(
        entry: DateTime.utc(2026, 7, 1, 12, 30),
        exit: DateTime.utc(2026, 7, 1, 13, 30),
      );
      final api = _FakeLightroomApi(
        assets: [image('surface1', DateTime.utc(2026, 7, 1, 12))],
      );
      final svc = service(api);
      await svc.scanDives(
        account: account,
        dives: [diveA, diveB],
        state: state,
      );
      final suggestion = (await mediaRepository.getPendingSuggestionsForDive(
        diveB.id,
      )).single;

      await svc.confirmSuggestion(account: account, suggestion: suggestion);

      final item = (await mediaRepository.getMediaForDive(diveB.id)).single;
      expect(item.remoteAssetId, 'surface1');
      expect(item.sourceType, MediaSourceType.serviceConnector);
      expect(enqueued, [item.id]);
      expect(
        await mediaRepository.getPendingSuggestionsForDive(diveA.id),
        isEmpty,
      );
      expect(
        await mediaRepository.getPendingSuggestionsForDive(diveB.id),
        isEmpty,
      );
    },
  );

  test(
    'poll scans dives within the lookback window and stamps lastPollAt',
    () async {
      // now is fixed at 2026-07-11; a dive 5 days earlier is inside the
      // 90-day lookback.
      final dive = await createDive(
        entry: DateTime.utc(2026, 7, 6, 10),
        exit: DateTime.utc(2026, 7, 6, 11),
      );
      final api = _FakeLightroomApi(
        assets: [image('recent1', DateTime.utc(2026, 7, 6, 10, 30))],
      );
      final summary = await service(api).poll(account: account, state: state);

      expect(summary.attached, 1);
      expect((await mediaRepository.getMediaForDive(dive.id)), hasLength(1));
      expect(await state.lastPollAt(), DateTime.utc(2026, 7, 11, 12));
    },
  );
}
