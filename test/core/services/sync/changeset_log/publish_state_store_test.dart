import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';

void main() {
  late AppDatabase db;
  late PublishStateStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = PublishStateStore(db);
  });
  tearDown(() => db.close());

  test('get returns null before any publish', () async {
    expect(await store.get('s3'), isNull);
  });

  test('upsert round-trips and overwrites', () async {
    await store.upsert(
      const LocalPublishStatesCompanion(
        provider: Value('s3'),
        baseSeq: Value(10),
        headSeq: Value(12),
        publishedHlcHigh: Value('000000000000100:000000:dev'),
        changesetBytesSinceBase: Value(2048),
        updatedAt: Value(1),
      ),
    );
    var s = await store.get('s3');
    expect(s!.headSeq, 12);
    expect(s.publishedHlcHigh, '000000000000100:000000:dev');

    await store.upsert(
      const LocalPublishStatesCompanion(
        provider: Value('s3'),
        headSeq: Value(15),
        updatedAt: Value(2),
      ),
    );
    s = await store.get('s3');
    expect(s!.headSeq, 15);
  });

  test('resetForProvider clears only that provider', () async {
    await store.upsert(
      const LocalPublishStatesCompanion(
        provider: Value('s3'),
        updatedAt: Value(1),
      ),
    );
    await store.upsert(
      const LocalPublishStatesCompanion(
        provider: Value('icloud'),
        updatedAt: Value(1),
      ),
    );
    await store.resetForProvider('s3');
    expect(await store.get('s3'), isNull);
    expect(await store.get('icloud'), isNotNull);
  });

  group('markAdoptedPendingBase (deferred self-base marker)', () {
    test('writes a null-baseSeq marker carrying the adopted hlc', () async {
      await store.markAdoptedPendingBase('s3', '000000000000200:000000:dev');
      final s = await store.get('s3');
      expect(s, isNotNull);
      expect(s!.baseSeq, isNull);
      expect(s.publishedHlcHigh, '000000000000200:000000:dev');
    });

    test('overwrites a pre-existing base row to an unambiguous marker', () async {
      // A row already carrying base metadata (a prior publish). The marker must
      // reset baseSeq (and the related base fields) back to NULL/0, not leave
      // the stale values -- otherwise a non-null baseSeq would defeat the
      // deferral signal even though we just adopted.
      await store.upsert(
        const LocalPublishStatesCompanion(
          provider: Value('s3'),
          baseSeq: Value(7),
          basePartCount: Value(3),
          baseBytes: Value(999),
          headSeq: Value(9),
          publishedHlcHigh: Value('000000000000100:000000:dev'),
          changesetBytesSinceBase: Value(4096),
          updatedAt: Value(1),
        ),
      );

      await store.markAdoptedPendingBase('s3', '000000000000300:000000:dev');

      final s = await store.get('s3');
      expect(s!.baseSeq, isNull);
      expect(s.basePartCount, isNull);
      expect(s.baseBytes, isNull);
      expect(s.headSeq, 0);
      expect(s.changesetBytesSinceBase, 0);
      expect(s.publishedHlcHigh, '000000000000300:000000:dev');
    });

    test('accepts a null adopted hlc (adopted an empty library)', () async {
      await store.markAdoptedPendingBase('s3', null);
      final s = await store.get('s3');
      expect(s!.baseSeq, isNull);
      expect(s.publishedHlcHigh, isNull);
    });
  });
}
