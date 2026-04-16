import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  /// Insert a minimal dive row and return its ID.
  Future<String> insertDive(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  /// Insert a minimal dive computer row and return its ID.
  Future<String> insertComputer(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value('Test Computer $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  /// Insert a DiveDataSources row with optional rawData.
  Future<String> insertSource({
    required String id,
    required String diveId,
    String? computerId,
    bool isPrimary = true,
    Uint8List? rawData,
    Uint8List? rawFingerprint,
  }) async {
    final now = DateTime.now();
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            sourceFormat: const Value('dive_computer'),
            rawData: Value(rawData),
            rawFingerprint: Value(rawFingerprint),
            importedAt: Value(now),
            createdAt: Value(now),
          ),
        );
    return id;
  }

  group('DiveDataSources blob persistence', () {
    test('stores and retrieves rawData blob byte-for-byte', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');

      // Create a non-trivial blob with various byte patterns
      final rawBytes = Uint8List.fromList([
        0x00, 0x01, 0x02, 0xFF, 0xFE, 0xAB, 0xCD, 0xEF, //
        0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80,
      ]);

      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        rawData: rawBytes,
        rawFingerprint: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
      );

      // Retrieve and verify byte-for-byte round-trip
      final row = await (db.select(
        db.diveDataSources,
      )..where((t) => t.id.equals('src-1'))).getSingle();

      expect(row.rawData, isNotNull);
      expect(row.rawData!.length, rawBytes.length);
      expect(row.rawData!, equals(rawBytes));

      // Also verify rawFingerprint round-trip
      expect(row.rawFingerprint, isNotNull);
      expect(
        row.rawFingerprint!,
        equals(Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF])),
      );
    });

    test('rawData is nullable and null by default', () async {
      await insertDive('dive-1');

      // Insert a source row without rawData
      await insertSource(id: 'src-1', diveId: 'dive-1');

      final row = await (db.select(
        db.diveDataSources,
      )..where((t) => t.id.equals('src-1'))).getSingle();

      expect(row.rawData, isNull);
      expect(row.rawFingerprint, isNull);
    });

    test('FK setNull: deleting DiveComputer sets computerId to null '
        'while preserving rawData', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');

      final blob = Uint8List.fromList(List.generate(256, (i) => i % 256));
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        rawData: blob,
      );

      // Verify the source has a computerId before delete
      var row = await (db.select(
        db.diveDataSources,
      )..where((t) => t.id.equals('src-1'))).getSingle();
      expect(row.computerId, equals('comp-1'));

      // Verify foreign keys are enabled
      final fkResult = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(fkResult.data['foreign_keys'], 1);

      // Delete the computer -- FK ON DELETE SET NULL should fire.
      await (db.delete(
        db.diveComputers,
      )..where((t) => t.id.equals('comp-1'))).go();

      // Re-read the source row
      row = await (db.select(
        db.diveDataSources,
      )..where((t) => t.id.equals('src-1'))).getSingle();

      // computerId should be null now
      expect(row.computerId, isNull);

      // rawData must still be intact
      expect(row.rawData, isNotNull);
      expect(row.rawData!.length, blob.length);
      expect(row.rawData!, equals(blob));
    });

    test(
      'cascade delete: deleting a Dive removes its DiveDataSources rows',
      () async {
        await insertDive('dive-1');
        await insertDive('dive-2');
        await insertComputer('comp-1');

        await insertSource(
          id: 'src-1',
          diveId: 'dive-1',
          computerId: 'comp-1',
          rawData: Uint8List.fromList([1, 2, 3]),
        );
        await insertSource(
          id: 'src-2',
          diveId: 'dive-1',
          computerId: 'comp-1',
          rawData: Uint8List.fromList([4, 5, 6]),
          isPrimary: false,
        );
        // A source for a different dive (should NOT be deleted)
        await insertSource(
          id: 'src-3',
          diveId: 'dive-2',
          computerId: 'comp-1',
          rawData: Uint8List.fromList([7, 8, 9]),
        );

        // Verify all three sources exist
        var allSources = await db.select(db.diveDataSources).get();
        expect(allSources.length, 3);

        // Delete dive-1 -- CASCADE should remove src-1 and src-2
        await (db.delete(db.dives)..where((t) => t.id.equals('dive-1'))).go();

        allSources = await db.select(db.diveDataSources).get();
        expect(allSources.length, 1);
        expect(allSources.first.id, 'src-3');
        expect(allSources.first.diveId, 'dive-2');
        // Verify the surviving source's blob is intact
        expect(allSources.first.rawData, equals(Uint8List.fromList([7, 8, 9])));
      },
    );
  });
}
