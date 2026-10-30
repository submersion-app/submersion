import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_fill_if_empty_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3491: an import fills a dive's details only where the dive has
/// none, so nothing written in Submersion is overwritten.
void main() {
  late AppDatabase db;
  late DiveFillIfEmptyRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Me', 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
      "updated_at) VALUES ('d1', 'diver-1', 1000, 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO dive_centers (id, diver_id, name, created_at, updated_at) "
      "VALUES ('c1', 'diver-1', 'Mine', 1000, 1000), "
      "('c2', 'diver-1', 'Other', 1000, 1000)",
    );
    repo = DiveFillIfEmptyRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Map<String, Object?>> dive() async =>
      (await db.customSelect("SELECT * FROM dives WHERE id = 'd1'").getSingle())
          .data;

  Future<void> setColumn(String sql) =>
      db.customStatement("UPDATE dives SET $sql WHERE id = 'd1'");

  group('linkDiveCenterIfNone', () {
    test('links a dive with no center', () async {
      expect(await repo.linkDiveCenterIfNone('d1', 'c1'), isTrue);
      expect((await dive())['dive_center_id'], 'c1');
    });

    test('leaves a dive that already has one', () async {
      await setColumn("dive_center_id = 'c2'");
      expect(await repo.linkDiveCenterIfNone('d1', 'c1'), isFalse);
      expect((await dive())['dive_center_id'], 'c2');
    });
  });

  group('fillVisibilityRangeIfEmpty', () {
    const range = VisibilityRange(minM: 15, maxM: 30);

    test('writes the range on a dive with no visibility', () async {
      expect(await repo.fillVisibilityRangeIfEmpty('d1', range), isTrue);
      final row = await dive();
      expect(row['visibility_min_meters'], 15);
      expect(row['visibility_max_meters'], 30);
      expect(row['visibility'], isNull);
    });

    for (final (label, sql) in [
      ('a measurement', 'visibility_meters = 8'),
      ('a range', 'visibility_min_meters = 5, visibility_max_meters = 10'),
      ('only an upper end', 'visibility_max_meters = 5'),
      ('a legacy band', "visibility = 'good'"),
    ]) {
      test('leaves a dive that already has $label', () async {
        await setColumn(sql);
        final before = await dive();
        expect(await repo.fillVisibilityRangeIfEmpty('d1', range), isFalse);
        final after = await dive();
        for (final column in [
          'visibility',
          'visibility_meters',
          'visibility_min_meters',
          'visibility_max_meters',
        ]) {
          expect(after[column], before[column], reason: column);
        }
      });
    }
  });

  test('a legacy unknown band counts as no visibility', () async {
    // The edit form treats it as empty, so the import does too.
    await setColumn("visibility = 'unknown'");

    expect(
      await repo.fillVisibilityRangeIfEmpty(
        'd1',
        const VisibilityRange(minM: 15, maxM: 30),
      ),
      isTrue,
    );
    final row = await dive();
    expect(row['visibility'], isNull);
    expect(row['visibility_min_meters'], 15);
  });

  group('fillCurrentStrengthIfEmpty', () {
    test('writes the strength on a dive with none', () async {
      expect(
        await repo.fillCurrentStrengthIfEmpty('d1', CurrentStrength.none),
        isTrue,
      );
      expect((await dive())['current_strength'], 'none');
    });

    test('leaves a dive that already has one', () async {
      await setColumn("current_strength = 'strong'");
      expect(
        await repo.fillCurrentStrengthIfEmpty('d1', CurrentStrength.none),
        isFalse,
      );
      expect((await dive())['current_strength'], 'strong');
    });
  });

  group('sync', () {
    // A write the diver's other devices should receive asks for a sync, as
    // the species and dive center writes in the same import do.
    Future<int> notificationsDuring(Future<void> Function() write) async {
      var count = 0;
      final sub = SyncEventBus.changes.listen((_) => count++);
      addTearDown(sub.cancel);
      await write();
      await Future<void>.delayed(Duration.zero);
      return count;
    }

    test('each write that changes the dive asks for a sync', () async {
      expect(
        await notificationsDuring(() => repo.linkDiveCenterIfNone('d1', 'c1')),
        1,
      );
      expect(
        await notificationsDuring(
          () => repo.addCustomFieldsIfMissing('d1', [
            (key: 'Suit', value: 'Drysuit'),
          ]),
        ),
        1,
      );
    });

    test('a write the guard refuses asks for nothing', () async {
      await setColumn("dive_center_id = 'c2'");

      expect(
        await notificationsDuring(() => repo.linkDiveCenterIfNone('d1', 'c1')),
        0,
      );
    });
  });

  group('addCustomFieldsIfMissing', () {
    Future<List<Map<String, Object?>>> fields() async => [
      for (final row
          in await db
              .customSelect(
                "SELECT field_key, field_value, sort_order "
                "FROM dive_custom_fields WHERE dive_id = 'd1' "
                'ORDER BY sort_order',
              )
              .get())
        row.data,
    ];

    test('adds only the labels the dive lacks, each once', () async {
      await db.customStatement(
        'INSERT INTO dive_custom_fields '
        '(id, dive_id, field_key, field_value, sort_order, created_at) '
        "VALUES ('f1', 'd1', 'suit', 'Wetsuit 5mm', 4, 1000)",
      );

      final added = await repo.addCustomFieldsIfMissing('d1', [
        (key: 'Suit', value: 'Drysuit'),
        (key: 'Environment', value: 'See'),
        (key: 'environment', value: 'Lake'),
      ]);

      expect(added, 1);
      expect(await fields(), [
        {'field_key': 'suit', 'field_value': 'Wetsuit 5mm', 'sort_order': 4},
        {'field_key': 'Environment', 'field_value': 'See', 'sort_order': 5},
      ]);
    });

    test('a label with stray spaces counts as present', () async {
      await db.customStatement(
        'INSERT INTO dive_custom_fields '
        '(id, dive_id, field_key, field_value, sort_order, created_at) '
        "VALUES ('f1', 'd1', ' Suit ', 'Wetsuit', 0, 1000)",
      );

      expect(
        await repo.addCustomFieldsIfMissing('d1', [
          (key: 'Suit', value: 'Drysuit'),
        ]),
        0,
      );
    });

    test('adding nothing leaves the dive untouched', () async {
      expect(await repo.addCustomFieldsIfMissing('d1', const []), 0);
      expect((await dive())['updated_at'], 1000);
    });

    test('a dive with no fields starts at sort order 0', () async {
      await repo.addCustomFieldsIfMissing('d1', [
        (key: 'Suit', value: 'Drysuit'),
        (key: 'Comfort', value: 'Optimal'),
      ]);

      expect((await fields()).map((f) => f['sort_order']), [0, 1]);
      expect((await dive())['updated_at'], isNot(1000));
    });
  });
}
