import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

void main() {
  test('changeset header fields round-trip through json', () {
    const payload = SyncPayload(
      version: 2,
      exportedAt: 5,
      deviceId: 'dev',
      checksum: 'c',
      data: SyncData(),
      deletions: {},
      seq: 14,
      baseSeq: 12,
      sinceHlc: 'A',
      toHlc: 'B',
    );
    final back = SyncPayload.fromJson(payload.toJson());
    expect(back.seq, 14);
    expect(back.baseSeq, 12);
    expect(back.sinceHlc, 'A');
    expect(back.toHlc, 'B');
  });

  test('a base/legacy payload without header fields parses with nulls', () {
    final back = SyncPayload.fromJson(const {
      'version': 2,
      'exportedAt': 1,
      'deviceId': 'd',
      'checksum': 'c',
      'data': <String, dynamic>{},
      'deletions': <String, dynamic>{},
    });
    expect(back.seq, isNull);
    expect(back.baseSeq, isNull);
    expect(back.sinceHlc, isNull);
    expect(back.toHlc, isNull);
  });
}
