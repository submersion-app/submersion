import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/features/universal_import/data/services/macdive_db_reader.dart';

import '../../../../fixtures/macdive_sqlite/build_synthetic_db.dart';

void main() {
  late Uint8List bytes;

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('macdive_syn_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = buildSyntheticMacDiveDb(
      p.join(dir.path, 'macdive_syn.sqlite'),
    );
    bytes = Uint8List.fromList(await file.readAsBytes());
  });

  group('MacDiveDbReader.isMacDiveDb', () {
    test('returns true for synthetic MacDive-shaped db', () async {
      expect(await MacDiveDbReader.isMacDiveDb(bytes), isTrue);
    });

    test('returns false for a non-MacDive SQLite', () async {
      final dir = Directory.systemTemp.createTempSync('not_macdive_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final tmp = File(p.join(dir.path, 'not_macdive.sqlite'));

      final db = sqlite3.sqlite3.open(tmp.path);
      db.execute('CREATE TABLE foo (id INTEGER PRIMARY KEY);');
      db.close();

      final otherBytes = Uint8List.fromList(await tmp.readAsBytes());
      expect(await MacDiveDbReader.isMacDiveDb(otherBytes), isFalse);
    });

    test('returns false for a non-SQLite file', () async {
      final garbage = Uint8List.fromList(const [0, 1, 2, 3, 4, 5]);
      expect(await MacDiveDbReader.isMacDiveDb(garbage), isFalse);
    });
  });

  group('MacDiveDbReader.readAll', () {
    test('reads 3 dives, 2 sites, 2 buddies, 2 tags, 2 gear', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      expect(logbook.dives.length, 3);
      expect(logbook.sitesByPk.length, 2);
      expect(logbook.buddiesByPk.length, 2);
      expect(logbook.tagsByPk.length, 2);
      expect(logbook.gearByPk.length, 2);
    });

    test('reads dive types and their junction', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      expect(
        logbook.diveTypesByPk.values.map((t) => t.name),
        containsAll(['Shore', 'Aquarium']),
      );
      // Dive 1 has both types; dive 3 has none.
      expect(logbook.diveToDiveTypePks[1], hasLength(2));
      expect(logbook.diveToDiveTypePks[3], isNull);
    });

    test('reads the gear disabled flag', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      expect(logbook.gearByPk[1]!.disabled, isFalse);
      expect(logbook.gearByPk[2]!.disabled, isTrue);
    });

    test('reads certifications with card number and shop', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final cert = logbook.certifications.single;
      expect(cert.name, 'Rescue Scuba Diver');
      expect(cert.agency, 'NAUI');
      expect(cert.diverNumber, '2649227');
      expect(cert.instructorShop, 'Bamboo Reef');
      expect(cert.attained, isNotNull);
    });

    test('reads service records keyed to their gear item', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final record = logbook.serviceRecords.single;
      expect(record.gearFk, 1);
      expect(record.servicedBy, 'Seals Watersports');
    });

    test('reads logbooks and flags smart groups', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final log = logbook.diveLogsByPk.values.single;
      expect(log.name, 'Tropical');
      // A non-empty ZPREDICATE means membership is computed, not stored.
      expect(log.isSmart, isTrue);
    });

    test('reads 2 tanks, 2 gases, 3 tank-and-gas junctions', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      expect(logbook.tanksByPk.length, 2);
      expect(logbook.gasesByPk.length, 2);
      expect(logbook.tankAndGases.length, 3);
    });

    test(
      'dive-to-buddy junction: dive 1 -> Alice+Bob, dive 2 -> Bob, dive 3 -> none',
      () async {
        final logbook = await MacDiveDbReader.readAll(bytes);
        expect(logbook.diveToBuddyPks[1], containsAll([1, 2]));
        expect(logbook.diveToBuddyPks[2], [2]);
        expect(logbook.diveToBuddyPks[3] ?? const [], isEmpty);
      },
    );

    test(
      'dive-to-tag junction: dive 1 -> Reef+Photography, dive 2 -> Reef',
      () async {
        final logbook = await MacDiveDbReader.readAll(bytes);
        expect(logbook.diveToTagPks[1], containsAll([1, 2]));
        expect(logbook.diveToTagPks[2], [1]);
      },
    );

    test('dive-to-gear junction: dive 1 -> Hydros Pro', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      expect(logbook.diveToGearPks[1], [1]);
    });

    test('unitsPreference read from ZMETADATA', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      expect(logbook.unitsPreference, 'Metric');
    });

    test('ZRAWDATE converted from NSDate seconds to UTC DateTime', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final dive1 = logbook.dives.firstWhere((d) => d.pk == 1);
      expect(dive1.rawDate, isNotNull);
      // Synthetic fixture used 738936000 = 2024-06-01 12:00:00 UTC.
      expect(dive1.rawDate!.year, 2024);
      expect(dive1.rawDate!.month, 6);
      expect(dive1.rawDate!.day, 1);
      expect(dive1.rawDate!.isUtc, isTrue);
    });

    test('ZRAWDATE gets back the seconds ZIDENTIFIER keeps (#2509)', () async {
      // ZRAWDATE is stored to the minute; the identifier MacDive keeps
      // beside it still has the seconds the computer reported.
      final dir = Directory.systemTemp.createTempSync('macdive_seconds_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = buildSyntheticMacDiveDb(p.join(dir.path, 'seconds.sqlite'));
      final db = sqlite3.sqlite3.open(file.path);
      db.execute(
        "UPDATE ZDIVE SET ZIDENTIFIER = '20240601090017-ABC' WHERE Z_PK = 1",
      );
      db.close();

      final logbook = await MacDiveDbReader.readAll(
        Uint8List.fromList(await file.readAsBytes()),
      );
      final dive1 = logbook.dives.firstWhere((d) => d.pk == 1);
      // The fixture's ZRAWDATE is 12:00Z; the identifier reads 09:00:17, a
      // wall clock three hours west of UTC.
      expect(dive1.rawDate, DateTime.utc(2024, 6, 1, 12, 0, 17));
    });

    test('string columns trim to null when empty', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final dive2 = logbook.dives.firstWhere((d) => d.pk == 2);
      // Fixture deliberately left dive 2's notes as NULL.
      expect(dive2.notes, isNull);
    });

    test(
      'absent tables (ZCRITTER empty) produce empty lists, not crash',
      () async {
        final logbook = await MacDiveDbReader.readAll(bytes);
        expect(logbook.crittersByPk, isEmpty);
        expect(logbook.events, isEmpty);
        expect(logbook.diversByPk, isEmpty);
      },
    );
  });

  group('divers (#1893)', () {
    late Uint8List diverBytes;

    setUpAll(() async {
      final dir = Directory.systemTemp.createTempSync('mdr_divers_');
      try {
        final file = buildSyntheticMacDiveDb(
          p.join(dir.path, 'mdr_divers.sqlite'),
          includeDivers: true,
        );
        diverBytes = Uint8List.fromList(await file.readAsBytes());
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('reads the diver profile columns', () async {
      final logbook = await MacDiveDbReader.readAll(diverBytes);
      final ann = logbook.diversByPk[1]!;
      expect(ann.fullName, 'Ann Lee');
      expect(ann.email, 'ann@example.com');
      expect(ann.phone, isNull);
      expect(ann.mobile, '555-0101');
      expect(ann.emergencyContact, 'Sam Lee');
      expect(ann.bloodType, 'O+');
      expect(ann.danNumber, 'DAN-123');
    });

    test('links dives and certifications to their diver', () async {
      final logbook = await MacDiveDbReader.readAll(diverBytes);
      final byPk = {for (final d in logbook.dives) d.pk: d};
      expect(byPk[1]!.diverFk, 1);
      expect(byPk[2]!.diverFk, 1);
      expect(byPk[3]!.diverFk, isNull);
      expect(logbook.certifications.single.diverFk, 2);
    });
  });

  // Each call copies the bytes to a temp file of its own. A temp name built
  // from the clock could be shared by calls started in the same microsecond,
  // and then one call deleted or overwrote the file another was reading.
  group('MacDiveDbReader concurrent calls', () {
    const calls = 50;

    test('every concurrent format check recognises the database', () async {
      final results = await Future.wait([
        for (var i = 0; i < calls; i++) MacDiveDbReader.isMacDiveDb(bytes),
      ]);

      expect(results, everyElement(isTrue));
    });

    test('every concurrent read returns all three dives', () async {
      final results = await Future.wait([
        for (var i = 0; i < calls; i++) MacDiveDbReader.readAll(bytes),
      ]);

      expect(results.map((l) => l.dives.length), everyElement(3));
    });
  });
}
