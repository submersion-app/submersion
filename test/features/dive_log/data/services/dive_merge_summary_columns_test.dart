import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// The combined dive's summary columns describe the whole dive, not its first
/// segment (issue #4136).
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiveMergeService service;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    service = DiveMergeService(diveRepo);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedSegment(
    String id, {
    required DateTime entry,
    double? waterTemp,
    double? cnsEnd,
    double? otu,
  }) async {
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        diverId: 'diver1',
        dateTime: entry,
        entryTime: entry,
        runtime: const Duration(minutes: 25),
        maxDepth: 20,
        waterTemp: waterTemp,
      ),
    );
    // cns_end and otu have no field on the domain entity, so a download
    // writes them on the row directly.
    await (db.update(db.dives)..where((t) => t.id.equals(id))).write(
      DivesCompanion(cnsEnd: Value(cnsEnd), otu: Value(otu)),
    );
  }

  Future<Dive> mergedRow(String id) =>
      (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

  final first = DateTime.utc(2021, 8, 1, 11, 47);
  final second = DateTime.utc(2021, 8, 1, 12, 15);

  test('water temperature is the coldest segment\'s', () async {
    await seedSegment('a', entry: first, waterTemp: 16);
    await seedSegment('b', entry: second, waterTemp: 8);
    final outcome = await service.apply(['a', 'b']);
    expect((await mergedRow(outcome.mergedDive.id)).waterTemp, 8);
  });

  test('CNS at the end comes from the last segment that has one', () async {
    await seedSegment('a', entry: first, cnsEnd: 12);
    await seedSegment('b', entry: second, cnsEnd: 21);
    final outcome = await service.apply(['b', 'a']);
    expect((await mergedRow(outcome.mergedDive.id)).cnsEnd, 21);
  });

  test('OTU adds up every segment\'s dose', () async {
    await seedSegment('a', entry: first, otu: 30);
    await seedSegment('b', entry: second, otu: 45);
    await seedSegment('c', entry: second.add(const Duration(minutes: 40)));
    final outcome = await service.apply(['a', 'b', 'c']);
    expect((await mergedRow(outcome.mergedDive.id)).otu, 75);
  });

  test('a planned segment adds no CNS or OTU', () async {
    await seedSegment('a', entry: first, cnsEnd: 12, otu: 30);
    await seedSegment('b', entry: second, cnsEnd: 40, otu: 40);
    await (db.update(db.dives)..where((t) => t.id.equals('b'))).write(
      const DivesCompanion(isPlanned: Value(true)),
    );
    final outcome = await service.apply(['a', 'b']);
    final row = await mergedRow(outcome.mergedDive.id);
    expect(row.cnsEnd, 12);
    expect(row.otu, 30);
  });

  test('CNS and OTU stay empty when no segment has them', () async {
    await seedSegment('a', entry: first);
    await seedSegment('b', entry: second);
    final outcome = await service.apply(['a', 'b']);
    final row = await mergedRow(outcome.mergedDive.id);
    expect(row.cnsEnd, isNull);
    expect(row.otu, isNull);
  });
}
