import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/features/universal_import/data/services/macdive_db_reader.dart';

import '../../../../fixtures/macdive_sqlite/build_synthetic_db.dart';

void main() {
  late Uint8List bytes;

  setUpAll(() async {
    final path =
        '${Directory.systemTemp.path}/macdive_syn_${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final file = buildSyntheticMacDiveDb(path);
    bytes = Uint8List.fromList(await file.readAsBytes());
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
  });

  group('MacDiveDbReader.isMacDiveDb', () {
    test('returns true for synthetic MacDive-shaped db', () async {
      expect(await MacDiveDbReader.isMacDiveDb(bytes), isTrue);
    });

    test('returns false for a non-MacDive SQLite', () async {
      final tmp = File(
        '${Directory.systemTemp.path}/not_macdive_${DateTime.now().microsecondsSinceEpoch}.sqlite',
      );
      if (tmp.existsSync()) tmp.deleteSync();
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync();
      });

      final db = sqlite3.sqlite3.open(tmp.path);
      db.execute('CREATE TABLE foo (id INTEGER PRIMARY KEY);');
      db.dispose();

      final otherBytes = Uint8List.fromList(await tmp.readAsBytes());
      expect(await MacDiveDbReader.isMacDiveDb(otherBytes), isFalse);
    });

    test('returns false for a non-SQLite file', () async {
      final garbage = Uint8List.fromList(const [0, 1, 2, 3, 4, 5]);
      expect(await MacDiveDbReader.isMacDiveDb(garbage), isFalse);
    });
  });

  group('MacDiveDbReader.readAll', () {
    test('reads 3 dives, 2 sites, 2 buddies, 2 tags, 1 gear', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      expect(logbook.dives.length, 3);
      expect(logbook.sitesByPk.length, 2);
      expect(logbook.buddiesByPk.length, 2);
      expect(logbook.tagsByPk.length, 2);
      expect(logbook.gearByPk.length, 1);
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
      // Synthetic fixture used 738936000 = 2024-06-01 09:00:00 UTC.
      expect(dive1.rawDate!.year, 2024);
      expect(dive1.rawDate!.month, 6);
      expect(dive1.rawDate!.day, 1);
      expect(dive1.rawDate!.isUtc, isTrue);
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
        expect(logbook.certifications, isEmpty);
        expect(logbook.serviceRecords, isEmpty);
      },
    );
  });
}
