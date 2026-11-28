import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Issue #5001. A diver_settings row from a peer older than v396 carries no
/// Dives, Buddies or Trips flag switch, only the single `showCountryFlags`
/// that covered every flag. For a row new to this device the column default
/// would turn flags on that the diver had turned off; each switch takes the
/// payload's own `showCountryFlags` instead. A row this device already holds
/// keeps its own switches.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  const switchColumns = [
    'show_dive_country_flags',
    'show_buddy_country_flags',
    'show_trip_country_flags',
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertRow(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: id,
            diverId: 'diver-$id',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// A wire payload for settings row [id] as a pre-v396 peer sends it.
  Future<Map<String, dynamic>> legacyPayload(
    String id, {
    required bool flags,
  }) async {
    await insertRow(id);
    final exported = await serializer.fetchRecord('diverSettings', id);
    await (db.delete(db.diverSettings)..where((t) => t.id.equals(id))).go();
    return Map<String, dynamic>.from(exported!)
      ..remove('showDiveCountryFlags')
      ..remove('showBuddyCountryFlags')
      ..remove('showTripCountryFlags')
      ..['showCountryFlags'] = flags;
  }

  Future<Map<String, Object?>> stored(String id) async =>
      (await db
              .customSelect(
                'SELECT show_country_flags, ${switchColumns.join(', ')} '
                "FROM diver_settings WHERE id = '$id'",
              )
              .getSingle())
          .data;

  test(
    'a new row from an older peer with flags off arrives with every switch off',
    () async {
      await serializer.upsertRecord(
        'diverSettings',
        await legacyPayload('ds1', flags: false),
      );
      expect(await stored('ds1'), {
        'show_country_flags': 0,
        for (final c in switchColumns) c: 0,
      });
    },
  );

  test('the batch path derives the same', () async {
    await serializer.upsertRecords('diverSettings', [
      await legacyPayload('ds1', flags: false),
      await legacyPayload('ds2', flags: true),
    ]);
    expect(await stored('ds1'), {
      'show_country_flags': 0,
      for (final c in switchColumns) c: 0,
    });
    expect(await stored('ds2'), {
      'show_country_flags': 1,
      for (final c in switchColumns) c: 1,
    });
  });

  test(
    'a row this device already holds keeps its own section switches',
    () async {
      final payload = await legacyPayload('ds1', flags: true);
      await insertRow('ds1');
      await db.customStatement(
        "UPDATE diver_settings SET show_dive_country_flags = 0 WHERE id = 'ds1'",
      );
      await serializer.upsertRecord('diverSettings', payload);
      expect(await stored('ds1'), {
        'show_country_flags': 1,
        'show_dive_country_flags': 0,
        'show_buddy_country_flags': 1,
        'show_trip_country_flags': 1,
      });
    },
  );

  test('a full payload is applied as sent', () async {
    await insertRow('ds1');
    final payload = Map<String, dynamic>.from(
      (await serializer.fetchRecord('diverSettings', 'ds1'))!,
    );
    await (db.delete(db.diverSettings)..where((t) => t.id.equals('ds1'))).go();
    payload
      ..['showCountryFlags'] = false
      ..['showDiveCountryFlags'] = true
      ..['showBuddyCountryFlags'] = false
      ..['showTripCountryFlags'] = true;
    await serializer.upsertRecord('diverSettings', payload);
    expect(await stored('ds1'), {
      'show_country_flags': 0,
      'show_dive_country_flags': 1,
      'show_buddy_country_flags': 0,
      'show_trip_country_flags': 1,
    });
  });
}
