import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/two_device_media_harness.dart';

void main() {
  late TwoDeviceMediaHarness h;
  final bytes = List<int>.generate(1024, (i) => (i * 5) % 251);

  setUp(() async => h = await TwoDeviceMediaHarness.create());
  tearDown(() => h.dispose());

  test(
    'S9: deleting a diver removes their media everywhere and queues the '
    'blob delete',
    () async {
      final dive = await h.a.createDive(diverId: 'diver1');
      final id = await h.a.linkFile(bytes, diveId: dive);
      await h.a.enqueueUpload(id);
      await h.a.drain();
      await h.a.sync();
      await h.b.sync();
      expect(await h.b.media(id), isNotNull);

      await h.a.deleteDiver('diver1');
      expect(
        await h.a.media(id),
        isNull,
        reason: "linked only to the deleted diver's dive",
      );
      final deletes = (await h.a.queue.allForTesting()).where(
        (e) => e.direction == 'delete',
      );
      expect(
        deletes,
        hasLength(1),
        reason: 'the uploaded copy must be scheduled for removal',
      );

      await h.a.sync();
      await h.b.sync();
      expect(
        await h.b.media(id),
        isNull,
        reason: 'the tombstone must reach the peer',
      );
    },
    skip:
        'Media sync program S9: turns green in slice 6 (diver delete cascade)',
  );
}
