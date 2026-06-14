import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';

void main() {
  SyncManifest sample() => const SyncManifest(
    deviceId: 'dev-1',
    provider: 's3',
    baseSeq: 12,
    basePartCount: 3,
    baseBytes: 24,
    baseChecksum: 'sha256:abc',
    basePartChecksums: ['sha256:p0', 'sha256:p1', 'sha256:p2'],
    headSeq: 15,
    publishedHlcHigh: '000000000000100:000000:dev-1',
    epochId: 'epoch-1',
    uploadNonce: 'nonce-1',
    updatedAt: 999,
  );

  test('toBytes -> fromBytes round-trips every field', () {
    final m = sample();
    final back = SyncManifest.fromBytes(m.toBytes());
    expect(back.deviceId, 'dev-1');
    expect(back.baseSeq, 12);
    expect(back.basePartChecksums, ['sha256:p0', 'sha256:p1', 'sha256:p2']);
    expect(back.headSeq, 15);
    expect(back.publishedHlcHigh, '000000000000100:000000:dev-1');
    expect(back.uploadNonce, 'nonce-1');
    expect(back.formatVersion, 1);
  });

  test('fromJson tolerates a missing base (a device with only changesets)', () {
    final back = SyncManifest.fromJson({
      'formatVersion': 1,
      'deviceId': 'dev-1',
      'provider': 's3',
      'headSeq': 0,
      'updatedAt': 1,
    });
    expect(back.baseSeq, isNull);
    expect(back.basePartChecksums, isEmpty);
    expect(back.headSeq, 0);
  });
}
