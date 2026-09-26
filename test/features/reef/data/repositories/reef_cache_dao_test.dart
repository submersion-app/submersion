import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/reef/data/repositories/reef_cache_dao.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';

void main() {
  late LocalCacheDatabase db;
  late DateTime clock;
  late ReefCacheDao dao;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    clock = DateTime.utc(2026, 7, 25, 12);
    dao = ReefCacheDao(db, now: () => clock);
  });

  tearDown(() async => db.close());

  test('read returns null when nothing is cached', () async {
    final entry = await dao.read(ReefProviderId.habitat, '12.160,-68.280');
    expect(entry, isNull);
  });

  test('write then read round-trips payload and status', () async {
    await dao.write(
      provider: ReefProviderId.habitat,
      coordKey: '12.160,-68.280',
      status: ReefDataStatus.ok,
      payloadJson: '{"onReef":true}',
    );

    final entry = await dao.read(ReefProviderId.habitat, '12.160,-68.280');
    expect(entry, isNotNull);
    expect(entry!.status, ReefDataStatus.ok);
    expect(entry.payloadJson, '{"onReef":true}');
  });

  test('habitat never expires', () async {
    await dao.write(
      provider: ReefProviderId.habitat,
      coordKey: 'k',
      status: ReefDataStatus.ok,
      payloadJson: '{}',
    );
    clock = clock.add(const Duration(days: 3650));
    expect(await dao.read(ReefProviderId.habitat, 'k'), isNotNull);
  });

  test('current health expires after one day', () async {
    await dao.write(
      provider: ReefProviderId.health,
      coordKey: 'k',
      status: ReefDataStatus.ok,
      payloadJson: '{}',
    );
    clock = clock.add(const Duration(hours: 23));
    expect(await dao.read(ReefProviderId.health, 'k'), isNotNull);
    clock = clock.add(const Duration(hours: 2));
    expect(await dao.read(ReefProviderId.health, 'k'), isNull);
  });

  test('historical health never expires', () async {
    await dao.write(
      provider: ReefProviderId.health,
      coordKey: 'k',
      variant: '2019-03-15',
      status: ReefDataStatus.ok,
      payloadJson: '{}',
    );
    clock = clock.add(const Duration(days: 3650));
    final entry = await dao.read(
      ReefProviderId.health,
      'k',
      variant: '2019-03-15',
    );
    expect(entry, isNotNull);
  });

  test('empty results are cached under the normal ttl', () async {
    await dao.write(
      provider: ReefProviderId.protection,
      coordKey: 'k',
      status: ReefDataStatus.empty,
      payloadJson: '{}',
    );
    clock = clock.add(const Duration(days: 89));
    final entry = await dao.read(ReefProviderId.protection, 'k');
    expect(entry!.status, ReefDataStatus.empty);
  });

  test('failures expire after one hour regardless of provider ttl', () async {
    await dao.write(
      provider: ReefProviderId.habitat,
      coordKey: 'k',
      status: ReefDataStatus.unavailable,
      payloadJson: '{}',
    );
    clock = clock.add(const Duration(minutes: 59));
    expect(await dao.read(ReefProviderId.habitat, 'k'), isNotNull);
    clock = clock.add(const Duration(minutes: 2));
    expect(await dao.read(ReefProviderId.habitat, 'k'), isNull);
  });

  test('writing the same key twice replaces rather than throwing', () async {
    await dao.write(
      provider: ReefProviderId.species,
      coordKey: 'k',
      status: ReefDataStatus.ok,
      payloadJson: '{"n":1}',
    );
    await dao.write(
      provider: ReefProviderId.species,
      coordKey: 'k',
      status: ReefDataStatus.ok,
      payloadJson: '{"n":2}',
    );
    final entry = await dao.read(ReefProviderId.species, 'k');
    expect(entry!.payloadJson, '{"n":2}');
  });

  test('variants of the same coordinate do not collide', () async {
    await dao.write(
      provider: ReefProviderId.health,
      coordKey: 'k',
      status: ReefDataStatus.ok,
      payloadJson: '{"current":true}',
    );
    await dao.write(
      provider: ReefProviderId.health,
      coordKey: 'k',
      variant: '2019-03-15',
      status: ReefDataStatus.ok,
      payloadJson: '{"current":false}',
    );
    final current = await dao.read(ReefProviderId.health, 'k');
    final past = await dao.read(
      ReefProviderId.health,
      'k',
      variant: '2019-03-15',
    );
    expect(current!.payloadJson, '{"current":true}');
    expect(past!.payloadJson, '{"current":false}');
  });

  group('deleteExpired', () {
    Future<void> put(
      ReefProviderId provider,
      String coordKey, {
      String variant = '',
      ReefDataStatus status = ReefDataStatus.ok,
    }) => dao.write(
      provider: provider,
      coordKey: coordKey,
      variant: variant,
      status: status,
      payloadJson: '{}',
    );

    Future<int> rowCount() async =>
        (await db.select(db.reefDataCache).get()).length;

    test('deletes exactly the rows read would refuse', () async {
      await put(ReefProviderId.habitat, 'habitat');
      await put(ReefProviderId.health, 'current');
      await put(ReefProviderId.health, 'dated', variant: '2019-03-15');
      await put(ReefProviderId.protection, 'protection');
      await put(ReefProviderId.species, 'species');
      await put(
        ReefProviderId.habitat,
        'failed',
        status: ReefDataStatus.unavailable,
      );

      // Past the health and failure lifetimes, inside the others.
      clock = clock.add(const Duration(days: 2));
      expect(await dao.deleteExpired(), 2);

      expect(await dao.read(ReefProviderId.habitat, 'habitat'), isNotNull);
      expect(
        await dao.read(ReefProviderId.health, 'dated', variant: '2019-03-15'),
        isNotNull,
      );
      expect(
        await dao.read(ReefProviderId.protection, 'protection'),
        isNotNull,
      );
      expect(await dao.read(ReefProviderId.species, 'species'), isNotNull);
      expect(await rowCount(), 4);
    });

    test('keeps dated health readings and habitat however old', () async {
      await put(ReefProviderId.habitat, 'habitat');
      await put(ReefProviderId.health, 'dated', variant: '2019-03-15');
      clock = clock.add(const Duration(days: 3650));

      expect(await dao.deleteExpired(), 0);
      expect(await rowCount(), 2);
    });

    test('deletes a row whose provider this build does not know', () async {
      await db
          .into(db.reefDataCache)
          .insert(
            ReefDataCacheCompanion.insert(
              provider: 'retiredProvider',
              coordKey: 'k',
              payloadJson: '{}',
              status: 'ok',
              fetchedAt: clock.millisecondsSinceEpoch,
            ),
          );

      expect(await dao.deleteExpired(), 1);
      expect(await rowCount(), 0);
    });

    test('treats a status this build does not know as a failure', () async {
      // Habitat never expires when ok, so only the unavailable fallback's
      // one-hour failure lifetime can make this row expire.
      await db
          .into(db.reefDataCache)
          .insert(
            ReefDataCacheCompanion.insert(
              provider: ReefProviderId.habitat.name,
              coordKey: 'k',
              payloadJson: '{}',
              status: 'retiredStatus',
              fetchedAt: clock.millisecondsSinceEpoch,
            ),
          );

      expect(await dao.deleteExpired(), 0);
      clock = clock.add(ReefCacheDao.failureTtl);
      expect(await dao.deleteExpired(), 1);
      expect(await rowCount(), 0);
    });

    test('never deletes a row refetched while the sweep runs', () async {
      await put(ReefProviderId.health, 'k');
      clock = clock.add(const Duration(days: 2));

      // Issued before deleteExpired has read anything, so a snapshot taken
      // outside the delete transaction sees the expired row and then deletes
      // the fresh replacement by primary key.
      final sweep = dao.deleteExpired();
      final refetch = put(ReefProviderId.health, 'k');
      await Future.wait([sweep, refetch]);

      expect(await dao.read(ReefProviderId.health, 'k'), isNotNull);
    });

    test('an empty cache deletes nothing', () async {
      expect(await dao.deleteExpired(), 0);
    });
  });
}
