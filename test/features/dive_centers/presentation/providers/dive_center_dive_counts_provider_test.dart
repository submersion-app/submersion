import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart'
    as domain;
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

const _centerCount = 200;

String _idOf(int index) => 'c$index';

/// Runs [body] with a reader of how many dive count statements drift has sent
/// so far. The whole test belongs in here: a provider refreshed by a change
/// tick runs in the zone it subscribed from, so a zone opened only around the
/// write would see none of the reads under test. Seeding belongs in here too,
/// or the logging database prints every statement to the test output.
Future<void> _withCountReads(
  Future<void> Function(int Function() reads) body,
) async {
  final logged = <String>[];
  await runZoned(
    () => body(
      // A long statement reaches the zone as several print calls.
      () => logged
          .join()
          .split('Drift: Sent')
          .where(
            (statement) =>
                statement.contains('COUNT(*)') &&
                statement.contains('dive_center_id'),
          )
          .length,
    ),
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => logged.add(line),
    ),
  );
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(
      NativeDatabase.memory(
        setup: registerAppSqlFunctions,
        logStatements: true,
      ),
    );
    DatabaseService.instance.setTestDatabase(db);
  });

  tearDown(tearDownTestDatabase);

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> seedCenters() async {
    final at = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    await db.batch((batch) {
      batch.insertAll(db.diveCenters, [
        for (var i = 0; i < _centerCount; i++)
          DiveCentersCompanion(
            id: Value(_idOf(i)),
            name: Value('Center $i'),
            createdAt: Value(at),
            updatedAt: Value(at),
          ),
      ]);
    });
  }

  /// A dive at the seeded center [centerId], written straight to the database
  /// the way a sync writes it.
  Future<void> writeDiveAt(String centerId) => DiveRepository().createDive(
    domain.Dive(
      id: '',
      dateTime: DateTime(2024, 1, 1, 10),
      diveCenter: domain.DiveCenter(
        id: centerId,
        name: centerId,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    ),
  );

  /// Listens to every center's count, as a table of all of them would, and
  /// waits for the first values.
  Future<void> watchEveryCenter(ProviderContainer container) async {
    final subscriptions = [
      for (var i = 0; i < _centerCount; i++)
        container.listen(diveCenterDiveCountProvider(_idOf(i)), (_, _) {}),
    ];
    addTearDown(() {
      for (final subscription in subscriptions) {
        subscription.close();
      }
    });
    await Future.wait([
      for (var i = 0; i < _centerCount; i++)
        container.read(diveCenterDiveCountProvider(_idOf(i)).future),
    ]);
  }

  /// Polls until center [centerId] reads [expected], then holds on long enough
  /// for a second refresh, had one been queued, to have run.
  Future<void> settleOn(
    ProviderContainer container,
    String centerId,
    int expected,
  ) async {
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final count = await container.read(
        diveCenterDiveCountProvider(centerId).future,
      );
      if (count == expected) break;
    }
    await Future<void>.delayed(
      DiveRepository.changeTickDebounce + const Duration(milliseconds: 200),
    );
  }

  group('dive center counts', () {
    test('every center shares one query on a cold read', () async {
      final container = makeContainer();

      await _withCountReads((reads) async {
        await seedCenters();
        await watchEveryCenter(container);

        expect(reads(), 1);
      });
    });

    test('one dive write refreshes the counts once', () async {
      final container = makeContainer();

      await _withCountReads((reads) async {
        await seedCenters();
        await watchEveryCenter(container);
        final coldReads = reads();

        await writeDiveAt(_idOf(7));
        await settleOn(container, _idOf(7), 1);

        expect(reads() - coldReads, 1);
        expect(
          await container.read(diveCenterDiveCountProvider(_idOf(7)).future),
          1,
        );
      });
    });

    test('a changed count never reads as unknown', () async {
      final container = makeContainer();

      await _withCountReads((_) async {
        await seedCenters();
        final seen = <int?>[];
        final subscription = container.listen(
          diveCenterDiveCountProvider(_idOf(5)),
          (_, next) => seen.add(next.valueOrNull),
        );
        addTearDown(subscription.close);
        await container.read(diveCenterDiveCountProvider(_idOf(5)).future);
        seen.clear();

        await writeDiveAt(_idOf(5));
        await settleOn(container, _idOf(5), 1);

        expect(seen, isNot(contains(null)));
        expect(seen.last, 1);
      });
    });

    test('a center with no dives reads zero', () async {
      final container = makeContainer();

      await _withCountReads((_) async {
        await seedCenters();
        expect(
          await container.read(diveCenterDiveCountProvider(_idOf(3)).future),
          0,
        );
      });
    });

    test('a dive at one center leaves other centers untouched', () async {
      final container = makeContainer();

      await _withCountReads((_) async {
        await seedCenters();
        await writeDiveAt(_idOf(2));
        final changedCenter = container.listen(
          diveCenterDiveCountProvider(_idOf(1)),
          (_, _) {},
        );
        addTearDown(changedCenter.close);
        var otherCenterChanges = 0;
        final otherCenter = container.listen(
          diveCenterDiveCountProvider(_idOf(2)),
          (_, _) => otherCenterChanges++,
        );
        addTearDown(otherCenter.close);
        await container.read(diveCenterDiveCountProvider(_idOf(2)).future);
        otherCenterChanges = 0;

        await writeDiveAt(_idOf(1));
        await settleOn(container, _idOf(1), 1);

        expect(otherCenterChanges, 0);
      });
    });
  });
}
