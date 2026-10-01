import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/dive_import/data/services/missing_computer_attacher.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';

import '../../../../core/services/export/uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import '../../../../helpers/fake_hosts.dart';
import '../../../../helpers/test_database.dart';

/// A dive imported before the importer kept every computer gains the ones it
/// lacks from a fresh parse of its file, and only those (issue #2672).
void main() {
  late AppDatabase db;

  setUp(() async {
    serveFakeHost('api.open-meteo.com');
    serveFakeHost('nominatim.openstreetmap.org');
    db = await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  String computer({required String model, String? serial, double depth = 30}) =>
      '''
  <divecomputer model='$model'>
  <depth max='$depth m' mean='18.0 m' />
  ${serial == null ? '' : "<extradata key='Serial' value='$serial' />"}
  <event time='20:00 min' type='8' name='bookmark' />
  <sample time='0:00 min' depth='0.0 m' pressure0='200.0 bar' />
  <sample time='10:00 min' depth='$depth m' />
  <sample time='40:00 min' depth='0.0 m' pressure0='60.0 bar' />
  </divecomputer>''';

  Future<Map<String, dynamic>> parse(String computers) async {
    final xml =
        '''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-03-10' time='09:00:00' duration='40:00 min'>
  <cylinder size='11.1 l' workpressure='207.0 bar' description='AL80' o2='32.0%' />
$computers
</dive>
</dives>
</divelog>
''';
    final payload = await SubsurfaceXmlParser().parse(
      Uint8List.fromList(utf8.encode(xml)),
    );
    return payload.entitiesOf(ImportEntityType.dives).single;
  }

  /// Imports [dive] as the importer did before it kept further computers.
  Future<String> importTheOldWay(Map<String, dynamic> dive) async {
    final old = Map<String, dynamic>.of(dive)..remove('additionalComputers');
    final data = UddfImportResult(dives: [old]);
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: await createTestDiver(),
    );
    return (await DiveRepository().getAllDives()).single.id;
  }

  Future<int> attach(String diveId, Map<String, dynamic> dive) =>
      MissingComputerAttacher(db: db).attach(
        diveId: diveId,
        diveData: dive,
        sourceFileName: 'log.ssrf',
        sourceFileFormat: 'subsurfaceXml',
      );

  Future<List<DiveDataSourcesData>> sourcesOf(String diveId) =>
      (db.select(db.diveDataSources)
            ..where((t) => t.diveId.equals(diveId))
            ..orderBy([(t) => OrderingTerm.desc(t.isPrimary)]))
          .get();

  final perdixAndTeric =
      '${computer(model: 'Shearwater Perdix', serial: 'SN-A')}\n'
      '${computer(model: 'Shearwater Teric', serial: 'SN-B', depth: 30.4)}';

  test('adds the computer an older import lacks', () async {
    final dive = await parse(perdixAndTeric);
    final diveId = await importTheOldWay(dive);
    expect(await sourcesOf(diveId), hasLength(1));

    expect(await attach(diveId, dive), 1);

    final rows = await sourcesOf(diveId);
    expect(rows.map((r) => r.computerModel), [
      'Shearwater Perdix',
      'Shearwater Teric',
    ]);
    expect(rows[1].isPrimary, isFalse);
    expect(rows[1].computerId, isNotNull);
    expect(rows[1].computerId, isNot(rows[0].computerId));
    final profiles = await DiveRepository().getProfilesByDataSource(diveId);
    expect(profiles[rows[1].id]!.points.map((p) => p.depth), [0.0, 30.4, 0.0]);
  });

  test('a second run adds nothing', () async {
    final dive = await parse(perdixAndTeric);
    final diveId = await importTheOldWay(dive);

    await attach(diveId, dive);
    expect(await attach(diveId, dive), 0);

    expect(await sourcesOf(diveId), hasLength(2));
  });

  test('a dive that already has every computer is left alone', () async {
    final dive = await parse(perdixAndTeric);
    final data = UddfImportResult(dives: [dive]);
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: await createTestDiver(),
    );
    final diveId = (await DiveRepository().getAllDives()).single.id;

    expect(await attach(diveId, dive), 0);
    expect(await sourcesOf(diveId), hasLength(2));
  });

  test('two computers of one model with no serial gain exactly one', () async {
    // Both carry the same identity, so "is it already there" has to count
    // them: the dive holds one, the file holds two.
    final dive = await parse(
      '${computer(model: 'Shearwater Perdix')}\n'
      '${computer(model: 'Shearwater Perdix', depth: 30.4)}',
    );
    final diveId = await importTheOldWay(dive);

    expect(await attach(diveId, dive), 1);
    expect(await attach(diveId, dive), 0);

    final rows = await sourcesOf(diveId);
    expect(rows, hasLength(2));
    expect(rows[1].computerId, isNull);
  });

  test('rows a Combine left on one computer count once', () async {
    // Two provenance rows sharing a registered computer read as one source,
    // so they hold one identity, not two: the dive still lacks the second
    // computer of an unserialised pair.
    final dive = await parse(
      '${computer(model: 'Shearwater Perdix')}\n'
      '${computer(model: 'Shearwater Perdix', depth: 30.4)}',
    );
    final diveId = await importTheOldWay(dive);
    final primary = (await sourcesOf(diveId)).single;
    expect(primary.computerId, isNotNull);
    await db
        .into(db.diveDataSources)
        .insert(
          primary
              .toCompanion(false)
              .copyWith(
                id: const Value('combined-half'),
                isPrimary: const Value(false),
              ),
        );

    expect(await attach(diveId, dive), 1);
  });

  test('re-bases the computer onto the dive it joins', () async {
    // The same dive read from a file whose clock put it two minutes later:
    // the added computer's samples land where they happened on this dive.
    final dive = await parse(perdixAndTeric);
    final diveId = await importTheOldWay(dive);
    final later = Map<String, dynamic>.of(dive)
      ..['dateTime'] = (dive['dateTime'] as DateTime).add(
        const Duration(minutes: 2),
      );

    await attach(diveId, later);

    final rows = await sourcesOf(diveId);
    expect(rows[1].timeOffsetSeconds, 120);
    final profiles = await DiveRepository().getProfilesByDataSource(diveId);
    expect(profiles[rows[1].id]!.points.first.timestamp, 120);
  });

  group('attachToMatch', () {
    Future<MatchAttachment> attachToMatch(
      String diveId,
      Map<String, dynamic> dive, {
      DiveRepository? diveRepository,
    }) => MissingComputerAttacher(db: db, diveRepository: diveRepository)
        .attachToMatch(
          targetDiveId: diveId,
          diveData: dive,
          sourceFileName: 'log.ssrf',
          sourceFileFormat: 'subsurfaceXml',
        );

    test('a match holding the first computer gains the rest', () async {
      final dive = await parse(perdixAndTeric);
      final diveId = await importTheOldWay(dive);

      expect(await attachToMatch(diveId, dive), MatchAttachment.attached);
      expect(await sourcesOf(diveId), hasLength(2));
    });

    test('a match that already has every computer is not this path', () async {
      // Nothing to attach, so the normal consolidation decides, exactly as
      // it did before this path existed.
      final dive = await parse(perdixAndTeric);
      final data = UddfImportResult(dives: [dive]);
      await UddfEntityImporter().import(
        data: data,
        selections: UddfImportSelections.selectAll(data),
        repositories: buildRepositories(),
        diverId: await createTestDiver(),
      );
      final diveId = (await DiveRepository().getAllDives()).single.id;

      expect(await attachToMatch(diveId, dive), MatchAttachment.notApplicable);
    });

    test('a match without the first computer is not this path', () async {
      // Another computer's recording of the dive: a normal fold's case.
      final other = await parse(computer(model: 'Suunto D5', serial: 'SN-C'));
      final diveId = await importTheOldWay(other);
      final dive = await parse(perdixAndTeric);

      expect(await attachToMatch(diveId, dive), MatchAttachment.notApplicable);
      expect(await sourcesOf(diveId), hasLength(1));
    });

    test('a computer that could not be written is incomplete', () async {
      // The incoming copy then holds the only copy of that computer, so the
      // caller must keep it rather than delete it as consolidated.
      final dive = await parse(perdixAndTeric);
      final diveId = await importTheOldWay(dive);

      expect(
        await attachToMatch(
          diveId,
          dive,
          diveRepository: _FailingAdditionalComputers(),
        ),
        MatchAttachment.incomplete,
      );
      expect(await sourcesOf(diveId), hasLength(1));
    });

    test('an incoming dive with one computer is not this path', () async {
      final dive = await parse(
        computer(model: 'Shearwater Perdix', serial: 'SN-A'),
      );
      final diveId = await importTheOldWay(dive);

      expect(await attachToMatch(diveId, dive), MatchAttachment.notApplicable);
    });
  });

  test('a parse with no further computers adds nothing', () async {
    final dive = await parse(
      computer(model: 'Shearwater Perdix', serial: 'SN-A'),
    );
    final diveId = await importTheOldWay(dive);

    expect(await attach(diveId, dive), 0);
    expect(await sourcesOf(diveId), hasLength(1));
  });
}

/// Refuses every further computer, as a database error would.
class _FailingAdditionalComputers implements DiveRepository {
  @override
  Future<void> saveAdditionalComputerReading({
    required DiveDataSourcesCompanion reading,
    required List<DiveProfilePoint> profile,
    Map<String, List<({int timestamp, double pressure})>> tankPressures =
        const {},
    List<ProfileEvent> events = const [],
  }) async => throw StateError('unwritable');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
