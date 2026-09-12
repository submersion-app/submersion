// Issue #1735: a dive's entry and exit GPS must survive a real UDDF export
// followed by a real import into a clean database.
//
// Two gaps lost it. The exporters wrote coordinates only onto each
// `<source>` record, never onto the `<dive>`, so a fix that lives only on the
// dive row (GPS track matching, a manual edit) never reached the file. And
// the importer read the `<source>` coordinates into the data source rows
// only, never onto the dive, so even a fix that did reach the file was not
// shown after a restore.
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain_dive;
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    show GeoPoint;
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:xml/xml.dart';

import '../../../../helpers/test_database.dart';

const _diverId = 'diver-gps-round-trip';
const _diveId = 'dive-gps-1';

ImportRepositories _repositories() => ImportRepositories(
  tripRepository: TripRepository(),
  equipmentRepository: EquipmentRepository(),
  equipmentSetRepository: EquipmentSetRepository(),
  buddyRepository: BuddyRepository(),
  diveCenterRepository: DiveCenterRepository(),
  certificationRepository: CertificationRepository(),
  tagRepository: TagRepository(),
  diveTypeRepository: DiveTypeRepository(),
  siteRepository: SiteRepository(),
  diveRepository: DiveRepository(),
  tankPressureRepository: TankPressureRepository(),
  courseRepository: CourseRepository(),
  diveComputerRepository: DiveComputerRepository(),
);

Future<void> _createDiver() async {
  final now = DateTime.now();
  await DiverRepository().createDiver(
    domain.Diver(
      id: _diverId,
      name: 'Test Diver',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

domain_dive.Dive _dive({GeoPoint? entry, GeoPoint? exit}) => domain_dive.Dive(
  id: _diveId,
  diveNumber: 1,
  dateTime: DateTime(2025, 10, 13, 11, 24),
  bottomTime: const Duration(minutes: 45),
  maxDepth: 24.0,
  entryLocation: entry,
  exitLocation: exit,
  tanks: const [],
  profile: const [],
  gear: looseGear(const []),
  notes: '',
  photoIds: const [],
  sightings: const [],
  weights: const [],
  tags: const [],
);

DiveSourceExport _source({
  required String id,
  required int ordinal,
  required bool isPrimary,
  double? entryLatitude,
  double? entryLongitude,
  double? exitLatitude,
  double? exitLongitude,
}) {
  final stamp = DateTime(2025, 10, 13, 18);
  return DiveSourceExport(
    id: id,
    diveId: _diveId,
    ordinal: ordinal,
    isPrimary: isPrimary,
    importedAt: stamp,
    createdAt: stamp.add(Duration(seconds: ordinal)),
    computerModel: 'Computer $ordinal',
    computerSerial: 'SN-$ordinal',
    mergeSourceSlot: ordinal,
    entryLatitude: entryLatitude,
    entryLongitude: entryLongitude,
    exitLatitude: exitLatitude,
    exitLongitude: exitLongitude,
  );
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await _createDiver();
  });

  tearDown(() async => tearDownTestDatabase());

  /// Imports [xml] into a clean database, the way a restore onto a new
  /// device would, and returns the single restored dive row.
  Future<Dive> restore(String xml) async {
    await tearDownTestDatabase();
    db = await setUpTestDatabase();
    await _createDiver();

    final parsed = await ExportService().importAllDataFromUddf(xml);
    await UddfEntityImporter().import(
      data: parsed,
      selections: const UddfImportSelections(dives: {0}),
      repositories: _repositories(),
      diverId: _diverId,
    );
    return (db.select(db.dives)..limit(1)).getSingle();
  }

  Future<String> fullBackup(
    domain_dive.Dive dive, [
    List<DiveSourceExport> sources = const [],
  ]) => UddfFullExportService().generateAllDataXmlForTest(
    dives: [dive],
    dataSources: sources,
  );

  group('export', () {
    test('writes the dive GPS beside entrytype and exittype', () async {
      final xml = await fullBackup(
        _dive(
          entry: const GeoPoint(29.500852, 34.917877),
          exit: const GeoPoint(29.501234, 34.918765),
        ),
      );
      final dive = XmlDocument.parse(xml).findAllElements('dive').single;
      final before = dive.findElements('informationbeforedive').single;
      final after = dive.findElements('informationafterdive').single;

      expect(before.getElement('entrylatitude')?.innerText, '29.500852');
      expect(before.getElement('entrylongitude')?.innerText, '34.917877');
      expect(after.getElement('exitlatitude')?.innerText, '29.501234');
      expect(after.getElement('exitlongitude')?.innerText, '34.918765');
      // Each fix belongs to one side of the dive only, so a reader that
      // looks in the wrong container cannot pass by finding both there.
      expect(before.getElement('exitlatitude'), isNull);
      expect(after.getElement('entrylatitude'), isNull);
    });

    test('writes no GPS elements for a dive without a fix', () async {
      final xml = await fullBackup(_dive());
      final dive = XmlDocument.parse(xml).findAllElements('dive').single;
      for (final name in const [
        'entrylatitude',
        'entrylongitude',
        'exitlatitude',
        'exitlongitude',
      ]) {
        expect(dive.findAllElements(name), isEmpty, reason: name);
      }
    });
  });

  group('restore', () {
    test(
      'a fix that lives only on the dive row survives a full backup',
      () async {
        // Track matching and manual edits write the dive row and no source
        // row, so before the fix nothing in the file carried this at all.
        final restored = await restore(
          await fullBackup(
            _dive(
              entry: const GeoPoint(29.500852, 34.917877),
              exit: const GeoPoint(29.501234, 34.918765),
            ),
          ),
        );

        expect(restored.entryLatitude, closeTo(29.500852, 1e-9));
        expect(restored.entryLongitude, closeTo(34.917877, 1e-9));
        expect(restored.exitLatitude, closeTo(29.501234, 1e-9));
        expect(restored.exitLongitude, closeTo(34.918765, 1e-9));
      },
    );

    test('a dives-only export carries the dive GPS too', () async {
      final xml = await UddfExportService().generateDivesUddfContent([
        _dive(
          entry: const GeoPoint(-8.274, 115.593),
          exit: const GeoPoint(-8.275, 115.594),
        ),
      ]);

      final restored = await restore(xml);

      expect(restored.entryLatitude, closeTo(-8.274, 1e-9));
      expect(restored.entryLongitude, closeTo(115.593, 1e-9));
      expect(restored.exitLatitude, closeTo(-8.275, 1e-9));
      expect(restored.exitLongitude, closeTo(115.594, 1e-9));
    });

    test('a backup whose dive carries no GPS takes it from the primary '
        'source', () async {
      // Every backup written before the fix has this shape: coordinates on
      // the <source> records only. The secondary is listed first and holds
      // different coordinates, so taking the first entry instead of the
      // primary one fails here.
      final restored = await restore(
        await fullBackup(_dive(), [
          _source(
            id: 'src-secondary',
            ordinal: 0,
            isPrimary: false,
            entryLatitude: 10.0,
            entryLongitude: 20.0,
            exitLatitude: 10.5,
            exitLongitude: 20.5,
          ),
          _source(
            id: 'src-primary',
            ordinal: 1,
            isPrimary: true,
            entryLatitude: 29.500852584838867,
            entryLongitude: 34.917877197265625,
            exitLatitude: 29.5012,
            exitLongitude: 34.9187,
          ),
        ]),
      );

      expect(restored.entryLatitude, closeTo(29.500852584838867, 1e-12));
      expect(restored.entryLongitude, closeTo(34.917877197265625, 1e-12));
      expect(restored.exitLatitude, closeTo(29.5012, 1e-12));
      expect(restored.exitLongitude, closeTo(34.9187, 1e-12));
    });

    test(
      'a source fix still applies when the primary source has none',
      () async {
        final restored = await restore(
          await fullBackup(_dive(), [
            _source(id: 'src-primary', ordinal: 0, isPrimary: true),
            _source(
              id: 'src-secondary',
              ordinal: 1,
              isPrimary: false,
              entryLatitude: 10.0,
              entryLongitude: 20.0,
            ),
          ]),
        );

        expect(restored.entryLatitude, closeTo(10.0, 1e-12));
        expect(restored.entryLongitude, closeTo(20.0, 1e-12));
        expect(restored.exitLatitude, isNull);
        expect(restored.exitLongitude, isNull);
      },
    );

    test("the dive's own GPS is restored as it was, never topped up from a "
        'source', () async {
      // The diver corrected the entry pin and has no exit on the dive row.
      // The source still holds the computer's original entry and an exit;
      // restoring either would show a fix the diver never had.
      final restored = await restore(
        await fullBackup(_dive(entry: const GeoPoint(29.6, 34.95)), [
          _source(
            id: 'src-primary',
            ordinal: 0,
            isPrimary: true,
            entryLatitude: 29.5,
            entryLongitude: 34.9,
            exitLatitude: 29.51,
            exitLongitude: 34.91,
          ),
        ]),
      );

      expect(restored.entryLatitude, closeTo(29.6, 1e-12));
      expect(restored.entryLongitude, closeTo(34.95, 1e-12));
      expect(restored.exitLatitude, isNull);
      expect(restored.exitLongitude, isNull);
    });

    test('the restored source rows keep their own coordinates', () async {
      await restore(
        await fullBackup(_dive(entry: const GeoPoint(29.6, 34.95)), [
          _source(
            id: 'src-primary',
            ordinal: 0,
            isPrimary: true,
            entryLatitude: 29.5,
            entryLongitude: 34.9,
          ),
        ]),
      );

      final source = await db.select(db.diveDataSources).getSingle();
      expect(source.entryLatitude, closeTo(29.5, 1e-12));
      expect(source.entryLongitude, closeTo(34.9, 1e-12));
    });

    test('a half-written dive fix is ignored rather than stored', () async {
      // A latitude with no longitude is not a position. It must not count as
      // "the dive has GPS" either, or it would block the source fallback.
      final xml =
          (await fullBackup(_dive(), [
            _source(
              id: 'src-primary',
              ordinal: 0,
              isPrimary: true,
              entryLatitude: 29.5,
              entryLongitude: 34.9,
            ),
          ])).replaceFirst(
            '</informationbeforedive>',
            '<entrylatitude>12.0</entrylatitude></informationbeforedive>',
          );

      final restored = await restore(xml);

      expect(restored.entryLatitude, closeTo(29.5, 1e-12));
      expect(restored.entryLongitude, closeTo(34.9, 1e-12));
    });
  });

  group('validation', () {
    Future<String> withDiveFix(String latitude, String longitude) async =>
        (await fullBackup(_dive())).replaceFirst(
          '</informationbeforedive>',
          '<entrylatitude>$latitude</entrylatitude>'
              '<entrylongitude>$longitude</entrylongitude>'
              '</informationbeforedive>',
        );

    for (final (label, lat, lng) in const [
      ('a latitude past a pole', '90.5', '10.0'),
      ('a longitude past the antimeridian', '10.0', '-180.5'),
      ('a NaN latitude', 'NaN', '10.0'),
      ('an infinite longitude', '10.0', 'Infinity'),
      ('a non-numeric latitude', 'north', '10.0'),
    ]) {
      test('a dive fix with $label is not stored', () async {
        final restored = await restore(await withDiveFix(lat, lng));
        expect(restored.entryLatitude, isNull);
        expect(restored.entryLongitude, isNull);
      });
    }

    test('a dive fix on the poles and the antimeridian is kept', () async {
      final restored = await restore(await withDiveFix('-90', '180'));
      expect(restored.entryLatitude, -90);
      expect(restored.entryLongitude, 180);
    });

    test('an out-of-range source fix is skipped for the next one', () async {
      final restored = await restore(
        await fullBackup(_dive(), [
          _source(
            id: 'src-primary',
            ordinal: 0,
            isPrimary: true,
            entryLatitude: 200.0,
            entryLongitude: 20.0,
          ),
          _source(
            id: 'src-secondary',
            ordinal: 1,
            isPrimary: false,
            entryLatitude: 12.0,
            entryLongitude: 22.0,
          ),
        ]),
      );

      expect(restored.entryLatitude, closeTo(12.0, 1e-12));
      expect(restored.entryLongitude, closeTo(22.0, 1e-12));
    });
  });

  test('restored GPS reaches the Dive the Surface GPS card reads', () async {
    await restore(await fullBackup(_dive(entry: const GeoPoint(29.5, 34.9))));

    final dive = (await DiveRepository().getAllDives(diverId: _diverId)).single;
    expect(dive.entryLocation, const GeoPoint(29.5, 34.9));
    expect(dive.exitLocation, isNull);
  });
}
