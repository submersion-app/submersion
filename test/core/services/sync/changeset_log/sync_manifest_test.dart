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

  test('round-trips schemaVersion', () {
    const manifest = SyncManifest(
      deviceId: 'dev-1',
      provider: 'icloud',
      headSeq: 3,
      updatedAt: 1234,
      schemaVersion: 136,
    );

    final back = SyncManifest.fromJson(manifest.toJson());

    expect(back.schemaVersion, 136);
  });

  test('writerSchemaVersion round-trips through JSON and defaults null', () {
    final manifest = SyncManifest.fromJson({
      'deviceId': 'd1',
      'provider': 'fake',
      'headSeq': 0,
      'updatedAt': 0,
      'schemaVersion': 137,
      'writerSchemaVersion': 153,
    });
    expect(manifest.schemaVersion, 137);
    expect(manifest.writerSchemaVersion, 153);
    expect(SyncManifest.fromJson(manifest.toJson()).writerSchemaVersion, 153);

    // A manifest written before the field existed parses as null.
    final legacy = SyncManifest.fromJson({
      'deviceId': 'd1',
      'provider': 'fake',
      'headSeq': 0,
      'updatedAt': 0,
    });
    expect(legacy.writerSchemaVersion, isNull);
  });

  test('legacy manifest without schemaVersion parses as null', () {
    final back = SyncManifest.fromJson({
      'deviceId': 'dev-1',
      'provider': 'icloud',
      'headSeq': 3,
      'updatedAt': 1234,
    });

    expect(back.schemaVersion, isNull);
  });

  test('round-trips deviceName', () {
    const manifest = SyncManifest(
      deviceId: 'dev-1',
      provider: 'icloud',
      headSeq: 3,
      updatedAt: 1234,
      deviceName: 'Erics-MacBook-Pro',
    );

    final back = SyncManifest.fromJson(manifest.toJson());

    expect(back.deviceName, 'Erics-MacBook-Pro');
  });

  test('legacy manifest without deviceName parses as null', () {
    // Peers on older builds publish no name; readers must fall back to the
    // device id rather than treating this as malformed.
    final back = SyncManifest.fromJson({
      'deviceId': 'dev-1',
      'provider': 'icloud',
      'headSeq': 3,
      'updatedAt': 1234,
    });

    expect(back.deviceName, isNull);
  });

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

  test('appliedPeerHlc round-trips and defaults to empty when absent', () {
    const m = SyncManifest(
      deviceId: 'dev-1',
      provider: 'fake',
      headSeq: 3,
      updatedAt: 999,
      appliedPeerHlc: {'peer-a': '00000000000010:000001:dev-1'},
    );
    final decoded = SyncManifest.fromBytes(m.toBytes());
    expect(decoded.appliedPeerHlc, {'peer-a': '00000000000010:000001:dev-1'});

    // An old-format manifest (field absent) must decode to an empty map:
    // "acknowledges nothing", which blocks GC.
    final legacy = SyncManifest.fromJson({
      'deviceId': 'dev-1',
      'provider': 'fake',
      'headSeq': 1,
      'updatedAt': 5,
    });
    expect(legacy.appliedPeerHlc, isEmpty);
  });
}
