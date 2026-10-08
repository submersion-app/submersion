import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/certifications/data/repositories/dive_activity_repository.dart';

/// The activity index behind certification currency (issue #2267): three
/// aggregates over the diver's logged dives, read as wall-clock calendar
/// days exactly as the last-dive chip reads them.
void main() {
  late AppDatabase db;
  late DiveActivityRepository repository;
  var seq = 0;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(logStatements: true));
    DatabaseService.instance.setTestDatabase(db);
    repository = DiveActivityRepository();
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.resetForTesting();
  });

  Future<void> dive(
    DateTime wallClock, {
    String diver = 'me',
    String mode = 'oc',
    List<String> types = const [],
    bool planned = false,
    DateTime? legacyDate,
  }) async {
    final id = 'd${seq++}';
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: Value(diver),
            diveDateTime: (legacyDate ?? wallClock).millisecondsSinceEpoch,
            entryTime: Value(wallClock.millisecondsSinceEpoch),
            diveMode: Value(mode),
            isPlanned: Value(planned),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    for (final t in types) {
      await db
          .into(db.diveDiveTypes)
          .insert(
            DiveDiveTypesCompanion.insert(
              id: '$id-$t',
              diveId: id,
              diveTypeId: t,
              createdAt: 0,
            ),
          );
    }
  }

  test('the last dive overall, per type and per mode', () async {
    await dive(DateTime.utc(2025, 3, 4, 10), mode: 'ccr', types: ['cave']);
    await dive(DateTime.utc(2025, 8, 1, 9), types: ['technical']);
    await dive(DateTime.utc(2024, 1, 1, 9), mode: 'ccr', types: ['cave']);

    final index = await repository.buildIndex(diverId: 'me');
    expect(index.lastDiveAt, DateTime(2025, 8, 1));
    expect(index.lastDiveByTypeId, {
      'cave': DateTime(2025, 3, 4),
      'technical': DateTime(2025, 8, 1),
    });
    expect(index.lastDiveByMode[DiveMode.ccr], DateTime(2025, 3, 4));
    expect(index.lastDiveByMode[DiveMode.oc], DateTime(2025, 8, 1));
  });

  test('planned dives never count', () async {
    await dive(DateTime.utc(2025, 3, 4, 10));
    await dive(DateTime.utc(2026, 9, 1, 10), planned: true, types: ['cave']);

    final index = await repository.buildIndex(diverId: 'me');
    expect(index.lastDiveAt, DateTime(2025, 3, 4));
    expect(index.lastDiveByTypeId, isEmpty);
  });

  test("another diver's dives never count", () async {
    await dive(DateTime.utc(2025, 3, 4, 10));
    await dive(DateTime.utc(2026, 1, 1, 10), diver: 'other', mode: 'ccr');

    final index = await repository.buildIndex(diverId: 'me');
    expect(index.lastDiveAt, DateTime(2025, 3, 4));
    expect(index.lastDiveByMode.keys, [DiveMode.oc]);
  });

  test('entry time wins over the legacy date when both exist', () async {
    await dive(
      DateTime.utc(2025, 3, 4, 10),
      legacyDate: DateTime.utc(2020, 1, 1),
    );
    final index = await repository.buildIndex(diverId: 'me');
    expect(index.lastDiveAt, DateTime(2025, 3, 4));
  });

  test('a dive at 23:55 keeps its own calendar day', () async {
    await dive(DateTime.utc(2025, 3, 4, 23, 55));
    final index = await repository.buildIndex(diverId: 'me');
    expect(index.lastDiveAt, DateTime(2025, 3, 4));
  });

  test('no dives gives an empty index', () async {
    final index = await repository.buildIndex(diverId: 'me');
    expect(index.lastDiveAt, isNull);
    expect(index.lastDiveByTypeId, isEmpty);
    expect(index.lastDiveByMode, isEmpty);
  });

  Future<int> statementsToBuild() async {
    final logged = <String>[];
    await runZoned(
      () => repository.buildIndex(diverId: 'me'),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );
    return logged.where((l) => l.startsWith('Drift: Sent')).length;
  }

  test('the same statements whether one dive or fifty', () async {
    await dive(DateTime.utc(2025, 3, 4, 10), types: ['cave']);
    final one = await statementsToBuild();
    for (var i = 0; i < 49; i++) {
      await dive(DateTime.utc(2025, 1, 1 + i, 10), types: ['wreck', 'cave']);
    }
    final fifty = await statementsToBuild();
    expect(one, 3);
    expect(fifty, one);
  });
}
