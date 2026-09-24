import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/two_device_media_harness.dart';

void main() {
  late TwoDeviceMediaHarness h;
  final bytes = List<int>.generate(1024, (i) => (i * 3) % 251);

  setUp(() async => h = await TwoDeviceMediaHarness.create());
  tearDown(() => h.dispose());

  test('S4: a foreign row whose stamps were lost is still served from the '
      'attached store', () async {
    final dive = await h.a.createDive();
    final id = await h.a.linkFile(bytes, diveId: dive);
    await h.a.enqueueUpload(id);
    await h.a.drain();
    await h.a.sync();
    await h.b.sync();
    await h.b.stripStoreStamps(id);

    expect(
      await h.b.tileOutcome(id),
      TileOutcome.store,
      reason: 'the bytes are in the store B is attached to',
    );
  });

  test(
    'S8: a throwing preflight suspends the worker with a visible reason',
    () async {
      final dive = await h.a.createDive();
      final id = await h.a.linkFile(bytes, diveId: dive);
      h.a.preflight = () async => throw StateError('marker unreadable');
      await h.a.enqueueUpload(id);
      await h.a.drain();

      expect(h.a.worker.isSuspended, isTrue);
      final summary = await h.a.queue.watchSummary().first;
      expect(
        summary.waitingReason,
        isNotNull,
        reason: 'the Transfers page must be able to say why nothing moves',
      );
    },
  );

  test(
    'S10: a row stranded in transferring by a kill is retried on relaunch',
    () async {
      final dive = await h.a.createDive();
      final id = await h.a.linkFile(bytes, diveId: dive);
      await h.a.enqueueUpload(id);
      final entry = (await h.a.queue.allForTesting()).single;
      await h.a.queue.markTransferring(entry.id); // the process died here

      await h.a.relaunch();
      await h.a.drain();

      expect(
        (await h.a.media(id))!.remoteUploadedAt,
        isNotNull,
        reason: 'drain must reclaim stranded rows before selecting pending',
      );
    },
  );
}
