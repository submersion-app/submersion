import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/media_health_report.dart';

void main() {
  final taken = DateTime.utc(2026, 7, 1, 10, 30);
  final row = MediaHealthRow(
    mediaId: 'm1',
    sourceType: 'localFile',
    originalFilename: 'reef.jpg',
    filePath: '/Volumes/photos/reef.jpg',
    takenAt: taken,
    diveId: 'd1',
    originDeviceId: 'dev-a',
    originDeviceName: 'Device A',
    linkedHere: false,
    contentHash: 'abc',
    contentSizeBytes: 1024,
    remoteUploadedAt: taken,
    isOrphaned: false,
    hlc: '0001-0000-devA',
    pending: false,
    cacheMethod: 'unresolved',
    cacheAttempts: 2,
    cacheExpired: false,
    cacheNextRetryAt: taken.add(const Duration(days: 7)),
    resolverVerdict: 'fromOtherDevice',
    storeObjectExists: true,
    storeObjectTier: 'original',
    queueState: 'pending',
    queueAttempts: 3,
    queueNextAttemptAt: taken,
    queueWaiting: true,
    queueError: 'source unavailable on this device',
  );

  test('toJson uses snake_case keys and ISO 8601 UTC dates', () {
    final json = row.toJson();
    expect(json['media_id'], 'm1');
    expect(json['origin_device_id'], 'dev-a');
    expect(json['linked_here'], false);
    expect(json['taken_at'], '2026-07-01T10:30:00.000Z');
    expect(json['cache_next_retry_at'], '2026-07-08T10:30:00.000Z');
    expect(json['store_object_exists'], true);
    expect(json['store_object_tier'], 'original');
    expect(json['queue_attempts'], 3);
    expect(json.keys, everyElement(matches(RegExp(r'^[a-z_]+$'))));
  });

  test('toText renders one key per line with the derived wording', () {
    final text = row.toText();
    expect(text, contains('media_id: m1'));
    expect(text, contains('pointer: /Volumes/photos/reef.jpg'));
    expect(text, contains('origin_device: dev-a (Device A)'));
    expect(text, contains('resolver_verdict: fromOtherDevice'));
    expect(text, contains('store_object: exists as original'));
    expect(text, contains('cache: unresolved'));
    expect(text, contains('next retry 2026-07-08T10:30:00.000Z'));
    expect(text, contains('queue: pending'));
    expect(text, contains('waiting until 2026-07-01T10:30:00.000Z'));
    expect(text, contains('source unavailable on this device'));
  });

  test('an unknown origin, an unprobed store and no queue read plainly', () {
    final bare = MediaHealthRow(
      mediaId: 'm2',
      sourceType: 'platformGallery',
      platformAssetId: 'ABC-123',
      takenAt: taken,
      isOrphaned: false,
      pending: true,
      resolverVerdict: 'available',
    );
    final text = bare.toText();
    expect(text, contains('pointer: ABC-123'));
    expect(text, contains('origin_device: unknown'));
    expect(text, contains('store_object: not probed'));
    expect(text, contains('cache: none'));
    expect(text, contains('queue: none'));
    expect(text, contains('pending: true'));
    expect(text, contains('hlc: null'));
  });

  test('a local origin says so', () {
    final local = MediaHealthRow(
      mediaId: 'm3',
      sourceType: 'localFile',
      takenAt: taken,
      originDeviceId: 'dev-b',
      originDeviceName: 'Device B',
      linkedHere: true,
      isOrphaned: false,
      pending: false,
      resolverVerdict: 'available',
    );
    expect(
      local.toText(),
      contains('origin_device: dev-b (Device B) (this device)'),
    );
  });

  test('the report has a header and blank-line separated rows', () {
    final report = MediaHealthReport(
      generatedAt: taken,
      deviceId: 'dev-b',
      deviceName: 'Device B',
      attachedStoreId: 'store-1',
      markerStoreId: 'store-1',
      rows: [row, row],
    );
    final text = report.toText();
    expect(text, startsWith('Submersion media health report\n'));
    expect(text, contains('generated_at: 2026-07-01T10:30:00.000Z'));
    expect(text, contains('device: dev-b (Device B)'));
    expect(text, contains('attached_store: store-1'));
    expect(text, contains('marker_store: store-1'));
    expect(text, contains('rows: 2'));
    expect('\n\n'.allMatches(text).length, greaterThanOrEqualTo(2));
    final json = report.toJson();
    expect((json['rows'] as List).length, 2);
    expect(json['device_name'], 'Device B');
  });

  test('an unnamed device and a missing store read plainly', () {
    final report = MediaHealthReport(
      generatedAt: taken,
      deviceId: 'dev-b',
      rows: const [],
    );
    final text = report.toText();
    expect(text, contains('device: dev-b (unnamed)'));
    expect(text, contains('attached_store: none'));
    expect(text, contains('marker_store: none'));
  });
}
