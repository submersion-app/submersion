// Adapted from plan `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`
// Task 3. Deviations from the plan code:
//
// - `NetworkCredentialsService.headersFor` actually takes a `Uri` and returns
//   `Future<Map<String, String>?>` (nullable), not a `String` returning a
//   non-null map as the plan's test stub suggests. Tests stub the real
//   signature: `when(mockCreds.headersFor(any))` for the catch-all default
//   and `when(mockCreds.headersFor(argThat(_uriHasHost('private.example'))))`
//   for the per-host variant.
// - The plan's first test uses a strange
//   `listen(events.add).asFuture<NetworkScanProgress?>(null)` pattern. We
//   replace it with the simpler `await for ... in svc.scanAll()` loop used
//   by the rest of the tests; the assertion is the same (mockRepo's
//   `updateMedia` was called with the expected row).
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/host_rate_limiter.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_scan_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/network_scan_progress.dart';

import 'network_scan_service_test.mocks.dart';

@GenerateMocks([
  MediaRepository,
  NetworkCredentialsService,
  ManifestSubscriptionRepository,
])
void main() {
  late MockMediaRepository mockRepo;
  late MockNetworkCredentialsService mockCreds;
  late MockManifestSubscriptionRepository mockSubs;
  late HostRateLimiter limiter;

  setUp(() {
    mockRepo = MockMediaRepository();
    mockCreds = MockNetworkCredentialsService();
    mockSubs = MockManifestSubscriptionRepository();
    // Tests run with no spacing so we don't have to fakeAsync each one.
    limiter = HostRateLimiter(
      maxConcurrentPerHost: 4,
      minSpacing: Duration.zero,
    );
    when(mockCreds.headersFor(any)).thenAnswer((_) async => null);
    when(mockRepo.updateMedia(any)).thenAnswer((_) async {});
  });

  MediaItem row({
    required String id,
    required MediaSourceType type,
    String? url,
    String? subscriptionId,
    bool isOrphaned = false,
    DateTime? lastVerifiedAt,
  }) => MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: type,
    url: url,
    subscriptionId: subscriptionId,
    isOrphaned: isOrphaned,
    lastVerifiedAt: lastVerifiedAt,
    takenAt: DateTime(2024),
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  test('marks 200 responses as available and clears orphan flag', () async {
    when(mockRepo.getAllBySourceType(MediaSourceType.networkUrl)).thenAnswer(
      (_) async => [
        row(
          id: 'a',
          type: MediaSourceType.networkUrl,
          url: 'https://example.com/a.jpg',
          isOrphaned: true,
        ),
      ],
    );
    when(
      mockRepo.getAllBySourceType(MediaSourceType.manifestEntry),
    ).thenAnswer((_) async => []);

    final client = MockClient((req) async => http.Response('', 200));
    final svc = NetworkScanService(
      repository: mockRepo,
      credentials: mockCreds,
      subscriptions: mockSubs,
      rateLimiter: limiter,
      httpClientFactory: () => client,
    );

    final events = <NetworkScanProgress>[];
    await for (final p in svc.scanAll()) {
      events.add(p);
    }
    expect(events.last.phase, NetworkScanPhase.finished);
    expect(events.last.available, 1);
    expect(events.last.unreachable, 0);

    final captured = verify(mockRepo.updateMedia(captureAny)).captured;
    expect(captured.length, 1);
    final updated = captured.single as MediaItem;
    expect(updated.isOrphaned, false);
    expect(updated.lastVerifiedAt, isNotNull);
  });

  test('marks 404 responses as orphaned', () async {
    when(mockRepo.getAllBySourceType(MediaSourceType.networkUrl)).thenAnswer(
      (_) async => [
        row(
          id: 'b',
          type: MediaSourceType.networkUrl,
          url: 'https://example.com/missing.jpg',
        ),
      ],
    );
    when(
      mockRepo.getAllBySourceType(MediaSourceType.manifestEntry),
    ).thenAnswer((_) async => []);

    final client = MockClient((req) async => http.Response('', 404));
    final svc = NetworkScanService(
      repository: mockRepo,
      credentials: mockCreds,
      subscriptions: mockSubs,
      rateLimiter: limiter,
      httpClientFactory: () => client,
    );

    await svc.scanAll().drain<void>();

    final updated =
        (verify(mockRepo.updateMedia(captureAny)).captured.single) as MediaItem;
    expect(updated.isOrphaned, true);
    expect(updated.lastVerifiedAt, isNotNull);
  });

  test('falls back to range-GET when HEAD returns 405', () async {
    when(mockRepo.getAllBySourceType(MediaSourceType.networkUrl)).thenAnswer(
      (_) async => [
        row(
          id: 'c',
          type: MediaSourceType.networkUrl,
          url: 'https://noheadhost/a.jpg',
        ),
      ],
    );
    when(
      mockRepo.getAllBySourceType(MediaSourceType.manifestEntry),
    ).thenAnswer((_) async => []);

    var sawHead = false;
    var sawGet = false;
    final client = MockClient((req) async {
      if (req.method == 'HEAD') {
        sawHead = true;
        return http.Response('', 405);
      }
      sawGet = true;
      expect(req.headers['range'], 'bytes=0-0');
      return http.Response('x', 206);
    });
    final svc = NetworkScanService(
      repository: mockRepo,
      credentials: mockCreds,
      subscriptions: mockSubs,
      rateLimiter: limiter,
      httpClientFactory: () => client,
    );

    await svc.scanAll().drain<void>();
    expect(sawHead, isTrue);
    expect(sawGet, isTrue);

    final updated =
        (verify(mockRepo.updateMedia(captureAny)).captured.single) as MediaItem;
    expect(updated.isOrphaned, false);
  });

  test('isolates per-row exceptions; loop continues', () async {
    when(mockRepo.getAllBySourceType(MediaSourceType.networkUrl)).thenAnswer(
      (_) async => [
        row(
          id: 'ok',
          type: MediaSourceType.networkUrl,
          url: 'https://h1/ok.jpg',
        ),
        row(
          id: 'boom',
          type: MediaSourceType.networkUrl,
          url: 'https://h2/boom.jpg',
        ),
      ],
    );
    when(
      mockRepo.getAllBySourceType(MediaSourceType.manifestEntry),
    ).thenAnswer((_) async => []);

    final client = MockClient((req) async {
      if (req.url.host == 'h2') throw const FormatException('boom');
      return http.Response('', 200);
    });
    final svc = NetworkScanService(
      repository: mockRepo,
      credentials: mockCreds,
      subscriptions: mockSubs,
      rateLimiter: limiter,
      httpClientFactory: () => client,
    );

    final events = <NetworkScanProgress>[];
    await svc.scanAll().forEach(events.add);

    expect(events.last.phase, NetworkScanPhase.finished);
    expect(events.last.total, 2);
    expect(events.last.done, 2);
    expect(events.last.available, 1);
    expect(events.last.unreachable, 1);
    verify(mockRepo.updateMedia(any)).called(2);
  });

  test('skips rows with null url and counts them in skippedNoUrl', () async {
    when(mockRepo.getAllBySourceType(MediaSourceType.networkUrl)).thenAnswer(
      (_) async => [
        row(id: 'nu', type: MediaSourceType.networkUrl, url: null),
        row(
          id: 'ok',
          type: MediaSourceType.networkUrl,
          url: 'https://example.com/a.jpg',
        ),
      ],
    );
    when(
      mockRepo.getAllBySourceType(MediaSourceType.manifestEntry),
    ).thenAnswer((_) async => []);

    final client = MockClient((req) async => http.Response('', 200));
    final svc = NetworkScanService(
      repository: mockRepo,
      credentials: mockCreds,
      subscriptions: mockSubs,
      rateLimiter: limiter,
      httpClientFactory: () => client,
    );

    final events = <NetworkScanProgress>[];
    await svc.scanAll().forEach(events.add);

    final report = svc.lastReport!;
    expect(report.skippedNoUrl, 1);
    expect(report.total, 1);
    expect(report.available, 1);
    expect(report.unreachable, 0);
    verify(mockRepo.updateMedia(any)).called(1);
  });

  test('lastReport is populated synchronously on the finished event', () async {
    // Regression: previously `_lastReport` was assigned AFTER the
    // `finished` event was emitted, so a consumer reading
    // `service.lastReport` immediately on the finished event saw `null`.
    // The fix moves the assignment ahead of `controller.add(finished)`.
    when(mockRepo.getAllBySourceType(MediaSourceType.networkUrl)).thenAnswer(
      (_) async => [
        row(
          id: 'a',
          type: MediaSourceType.networkUrl,
          url: 'https://example.com/a.jpg',
        ),
      ],
    );
    when(
      mockRepo.getAllBySourceType(MediaSourceType.manifestEntry),
    ).thenAnswer((_) async => []);

    final client = MockClient((req) async => http.Response('', 200));
    final svc = NetworkScanService(
      repository: mockRepo,
      credentials: mockCreds,
      subscriptions: mockSubs,
      rateLimiter: limiter,
      httpClientFactory: () => client,
    );

    NetworkScanReport? reportOnFinished;
    await for (final p in svc.scanAll()) {
      if (p.phase == NetworkScanPhase.finished) {
        reportOnFinished = svc.lastReport;
      }
    }

    expect(
      reportOnFinished,
      isNotNull,
      reason:
          'lastReport must be assigned before the finished event is emitted',
    );
    expect(reportOnFinished!.total, 1);
    expect(reportOnFinished.available, 1);
  });

  test('looks up auth headers per host and forwards them', () async {
    when(mockRepo.getAllBySourceType(MediaSourceType.networkUrl)).thenAnswer(
      (_) async => [
        row(
          id: 'a',
          type: MediaSourceType.networkUrl,
          url: 'https://private.example/a.jpg',
        ),
      ],
    );
    when(
      mockRepo.getAllBySourceType(MediaSourceType.manifestEntry),
    ).thenAnswer((_) async => []);
    when(
      mockCreds.headersFor(
        argThat(predicate<Uri>((u) => u.host == 'private.example')),
      ),
    ).thenAnswer((_) async => {'Authorization': 'Bearer xyz'});

    final headersSeen = <Map<String, String>>[];
    final client = MockClient((req) async {
      headersSeen.add(Map.of(req.headers));
      return http.Response('', 200);
    });
    final svc = NetworkScanService(
      repository: mockRepo,
      credentials: mockCreds,
      subscriptions: mockSubs,
      rateLimiter: limiter,
      httpClientFactory: () => client,
    );

    await svc.scanAll().drain<void>();

    expect(headersSeen, isNotEmpty);
    expect(
      headersSeen.first['authorization'] ?? headersSeen.first['Authorization'],
      'Bearer xyz',
    );
  });
}
