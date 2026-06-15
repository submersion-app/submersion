import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late ChangesetCodec codec;
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
    codec = ChangesetCodec(serializer);
  });
  tearDown(() => tearDownTestDatabase());

  test('changeset encode -> decode round-trips the payload', () async {
    final deviceId = await SyncRepository().getDeviceId();
    final payload = await serializer.exportChangeset(
      deviceId: deviceId,
      hlcWatermark: null,
      deletions: const [],
      seq: 3,
    );
    final bytes = codec.encodeChangeset(payload);
    final back = codec.decodeChangeset(bytes);
    expect(back.seq, 3);
    expect(serializer.validateChecksum(back), isTrue);
  });

  test('base encode (chunked) -> reassemble -> decode round-trips', () async {
    final deviceId = await SyncRepository().getDeviceId();
    final payload = await serializer.exportData(
      deviceId: deviceId,
      deletions: const [],
    );
    final parts = codec.encodeBaseParts(payload, partSize: 64);
    expect(parts.length, greaterThanOrEqualTo(1));
    final back = codec.decodeBaseParts(parts);
    expect(serializer.validateChecksum(back), isTrue);
  });
}
