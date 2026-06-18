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
}
