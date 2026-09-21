import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/log_redactor.dart';
import 'package:submersion/features/media/data/services/media_health_report.dart';

void main() {
  final taken = DateTime.utc(2026, 7, 1, 10, 30);
  final row = MediaHealthRow(
    mediaId: 'm1',
    sourceType: 'localFile',
    originalFilename: 'reef.jpg',
    filePath: '/Volumes/photos/reef.jpg',
    pointer: '/Volumes/photos/reef.jpg',
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
      pointer: 'ABC-123',
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

  group('secrets never reach a rendered report', () {
    // The report is built to be pasted into a public bug thread and it
    // prints each row's locator verbatim, so it gets the same backstop the
    // persisted log has. Paths, device names and hashes must survive it.
    MediaHealthRow secretRow({String? pointer, String? queueError}) =>
        MediaHealthRow(
          mediaId: 'm9',
          sourceType: 'networkUrl',
          pointer: pointer,
          filePath: '/Volumes/photos/reef.jpg',
          takenAt: DateTime.utc(2026, 7, 1),
          isOrphaned: false,
          pending: false,
          resolverVerdict: 'available',
          queueError: queueError,
        );

    MediaHealthReport reportOf(MediaHealthRow row) => MediaHealthReport(
      generatedAt: DateTime.utc(2026, 7, 1),
      deviceId: 'dev-1',
      deviceName: "Eric's MacBook",
      rows: [row],
    );

    test('a signed URL pointer is masked in text and JSON', () {
      final row = secretRow(
        pointer: 'https://host/p.jpg?access_token=sk-live-abc123',
      );

      expect(row.toText(), isNot(contains('sk-live-abc123')));
      expect(row.toText(), contains(redactedPlaceholder));
      expect(row.toJson()['pointer'], isNot(contains('sk-live-abc123')));
      expect(
        reportOf(row).toText(),
        isNot(contains('sk-live-abc123')),
        reason: 'the whole-report rendering is what actually gets shared',
      );
    });

    test('a credential in the URL host is masked', () {
      final row = secretRow(pointer: 'https://eric:hunter2@host/p.jpg');

      expect(row.toText(), isNot(contains('hunter2')));
      expect(reportOf(row).toText(), isNot(contains('hunter2')));
    });

    test('a queue error carrying a token is masked', () {
      final row = secretRow(
        pointer: 'https://host/p.jpg',
        queueError: 'HttpException: 401 for signature=deadbeefcafe',
      );

      expect(row.toText(), isNot(contains('deadbeefcafe')));
    });

    test('paths, device names and hashes survive redaction', () {
      // The hash is the key the store names its objects by and the field a
      // backup investigation turns on, and it is a long high-entropy run,
      // which is the shape a future redactor rule could reach for.
      const hash =
          'a1b2c3d4e5f60718293a4b5c6d7e8f90'
          'a1b2c3d4e5f60718293a4b5c6d7e8f90';
      final row = MediaHealthRow(
        mediaId: 'm9',
        sourceType: 'localFile',
        pointer: '/Volumes/photos/reef.jpg',
        contentHash: hash,
        takenAt: DateTime.utc(2026, 7, 1),
        isOrphaned: false,
        pending: false,
        resolverVerdict: 'available',
      );
      final text = reportOf(row).toText();

      expect(text, contains('/Volumes/photos/reef.jpg'));
      expect(text, contains("Eric's MacBook"));
      expect(text, contains('dev-1'));
      expect(text, contains(hash), reason: 'the content hash must survive');
      expect(row.toJson()['content_hash'], hash);
    });
  });
}
