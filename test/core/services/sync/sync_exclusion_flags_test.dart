import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../../helpers/test_database.dart';

/// Regression guard for the statistics-exclusion flags crossing sync.
///
/// `SyncDataSerializer._exportDives` serialises via Drift's generated
/// `toJson()`, so these flags ride along with no hand plumbing. That is
/// precisely why this test exists: the serializer's own comment records that a
/// hand-maintained map silently dropped bottomTime and GPS once before. If
/// someone reintroduces a column allowlist, this fails instead of the flags
/// quietly failing to reach the diver's other device.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Dive> insertAndRead({
    required bool excludedFromStats,
    required bool excludedFromGasStats,
  }) async {
    final at = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diveDateTime: Value(at),
            excludedFromStats: Value(excludedFromStats),
            excludedFromGasStats: Value(excludedFromGasStats),
            createdAt: Value(at),
            updatedAt: Value(at),
          ),
        );
    return (db.select(db.dives)..where((t) => t.id.equals('d1'))).getSingle();
  }

  test('both flags appear in the serialised payload', () async {
    final row = await insertAndRead(
      excludedFromStats: true,
      excludedFromGasStats: true,
    );
    final json = row.toJson();
    expect(json.containsKey('excludedFromStats'), isTrue);
    expect(json.containsKey('excludedFromGasStats'), isTrue);
    expect(json['excludedFromStats'], isTrue);
    expect(json['excludedFromGasStats'], isTrue);
  });

  test('the flags survive a serialise/deserialise round trip', () async {
    // Asymmetric on purpose: a bug that reads one flag into the other's slot
    // would pass if both were set the same way.
    final row = await insertAndRead(
      excludedFromStats: false,
      excludedFromGasStats: true,
    );
    final restored = Dive.fromJson(row.toJson());
    expect(restored.excludedFromStats, isFalse);
    expect(restored.excludedFromGasStats, isTrue);
  });

  test('an unflagged dive round-trips as included', () async {
    final row = await insertAndRead(
      excludedFromStats: false,
      excludedFromGasStats: false,
    );
    final restored = Dive.fromJson(row.toJson());
    expect(restored.excludedFromStats, isFalse);
    expect(restored.excludedFromGasStats, isFalse);
  });
}
