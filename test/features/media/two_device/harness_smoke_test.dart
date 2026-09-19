import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

import '../../../helpers/two_device_media_harness.dart';

void main() {
  late TwoDeviceMediaHarness h;

  setUp(() async => h = await TwoDeviceMediaHarness.create());
  tearDown(() => h.dispose());

  test(
    'S0: a file linked and uploaded on A is served from the store on B',
    () async {
      final bytes = List<int>.generate(2048, (i) => (i * 7) % 251);
      final dive = await h.a.createDive();
      final id = await h.a.linkFile(bytes, diveId: dive);
      await h.a.enqueueUpload(id);
      await h.a.drain();
      await h.a.sync();
      await h.b.sync();

      final onB = await h.b.media(id);
      expect(onB, isNotNull, reason: 'the row must arrive by sync');
      expect(onB!.contentHash, isNotNull);
      expect(onB.remoteUploadedAt, isNotNull);

      final tile = await h.b.tile(id);
      expect(tile.storeFallbackUsed, isTrue);
      expect(tile.data, isA<FileData>());
      expect(await (tile.data as FileData).file.readAsBytes(), bytes);
      expect(await h.b.tileOutcome(id), TileOutcome.store);
    },
  );

  test('S0b: the two devices have distinct ids and the same store', () async {
    expect(h.a.deviceId, isNot(h.b.deviceId));
    expect(h.storeId, isNotEmpty);
  });
}
