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
}
