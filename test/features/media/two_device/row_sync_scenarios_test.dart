import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/two_device_media_harness.dart';

void main() {
  late TwoDeviceMediaHarness h;
  final bytes = List<int>.generate(1024, (i) => (i * 13) % 251);

  setUp(() async => h = await TwoDeviceMediaHarness.create());
  tearDown(() => h.dispose());

  test(
    'S1: a pending row on B still receives the upload stamps A published',
    () async {
      final dive = await h.a.createDive();
      final id = await h.a.linkFile(bytes, diveId: dive);
      await h.a.sync();
      await h.b.sync();
      // B touches the row before A's stamps land.
      await h.b.setManualElapsed(id, 30);
      expect(await h.b.isPending(id), isTrue);

      await h.a.enqueueUpload(id);
      await h.a.drain();
      await h.a.sync();
      await h.b.sync();

      final onB = await h.b.media(id);
      expect(
        onB!.remoteUploadedAt,
        isNotNull,
        reason: 'the peer update must merge into the pending row, not skip',
      );
      expect(onB.contentHash, isNotNull);
      expect(
        onB.manualElapsedSeconds,
        30,
        reason: 'the local edit must survive the merge',
      );
    },
  );

  test(
    'S2: Check all on a healthy foreign library marks nothing pending',
    () async {
      final dive = await h.a.createDive();
      final id = await h.a.linkFile(bytes, diveId: dive);
      await h.a.sync();
      await h.b.sync();
      // Publish clears B's own marks from the pull; now the library is at
      // rest.
      await h.b.sync();
      expect(await h.b.isPending(id), isFalse);

      final outcome = await h.b.verifyAll();
      expect(
        outcome.inconclusive,
        1,
        reason: "B cannot read A's file: inconclusive, not missing",
      );
      expect(
        await h.b.isPending(id),
        isFalse,
        reason: 'an inconclusive verify must not write the row',
      );
    },
  );

  test(
    'S3: an older edit arriving later does not overwrite the newer one',
    () async {
      final dive = await h.a.createDive();
      final id = await h.a.linkFile(bytes, diveId: dive);
      await h.a.sync();
      await h.b.sync();

      await h.b.setManualElapsed(id, 50); // older edit, offline
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await h.a.setManualElapsed(id, 100); // newer edit
      await h.a.sync();
      await h.b.sync(); // B publishes its stale 50
      await h.a.sync(); // A pulls it

      expect(
        (await h.a.media(id))!.manualElapsedSeconds,
        100,
        reason: "A's row is not pending, so today the blind upsert takes 50",
      );
      expect(
        (await h.b.media(id))!.manualElapsedSeconds,
        100,
        reason: 'B must converge on the newer value too',
      );
    },
  );
}
