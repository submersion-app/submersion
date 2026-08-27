import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/macdive_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/macdive_dive_mapper.dart';
import 'package:submersion/features/universal_import/data/services/macdive_raw_types.dart';

import '../../../../fixtures/macdive_sqlite/build_synthetic_db.dart';

void main() {
  late Uint8List bytes;

  setUpAll(() async {
    final path =
        '${Directory.systemTemp.path}/mdm_${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final file = buildSyntheticMacDiveDb(path);
    bytes = Uint8List.fromList(await file.readAsBytes());
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
  });

  group('MacDiveDiveMapper', () {
    test('produces 3 dives, 2 sites, 2 buddies, 2 tags, 2 gear', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      expect(payload.entitiesOf(ImportEntityType.dives).length, 3);
      expect(payload.entitiesOf(ImportEntityType.sites).length, 2);
      expect(payload.entitiesOf(ImportEntityType.buddies).length, 2);
      expect(payload.entitiesOf(ImportEntityType.tags).length, 2);
      expect(payload.entitiesOf(ImportEntityType.equipment).length, 2);
    });

    test('maps MacDive dive types onto Submersion type ids', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);

      // "Shore" slugs onto the built-in id; "Aquarium" is carried across as
      // a custom type (#912).
      final types = payload.entitiesOf(ImportEntityType.diveTypes);
      expect(types.map((t) => t['id']), containsAll(['shore', 'aquarium']));
      expect(
        types.firstWhere((t) => t['id'] == 'aquarium')['name'],
        'Aquarium',
      );

      final dives = payload.entitiesOf(ImportEntityType.dives);
      final dive1 = dives.firstWhere((d) => d['sourceUuid'] == 'dive-uuid-1');
      expect(dive1['diveTypeIds'], containsAll(['shore', 'aquarium']));
      final dive3 = dives.firstWhere((d) => d['sourceUuid'] == 'dive-uuid-3');
      expect(dive3.containsKey('diveTypeIds'), isFalse);
    });

    test('operator becomes a dive center and a per-dive ref', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);

      final centers = payload.entitiesOf(ImportEntityType.diveCenters);
      // Two dives share one operator, so it is deduplicated.
      expect(centers, hasLength(1));
      expect(centers.single['name'], 'Test Operator');
      expect(centers.single['uddfId'], 'Test Operator');
      expect(centers.single['country'], 'Mexico');

      final dive1 = payload
          .entitiesOf(ImportEntityType.dives)
          .firstWhere((d) => d['sourceUuid'] == 'dive-uuid-1');
      expect(dive1['diveCenterRef'], 'Test Operator');
      // The free-text column keeps its value too.
      expect(dive1['diveOperator'], 'Test Operator');
    });

    test('inactive MacDive gear imports as retired', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final gear = payload.entitiesOf(ImportEntityType.equipment);

      final active = gear.firstWhere((g) => g['name'] == 'Hydros Pro');
      expect(active.containsKey('status'), isFalse);
      expect(active.containsKey('isActive'), isFalse);

      final retired = gear.firstWhere((g) => g['name'] == 'Old Regs');
      expect(retired['status'], 'retired');
      // Both markers are needed: getActiveEquipment filters on each.
      expect(retired['isActive'], isFalse);
    });

    test('gear type strings map onto EquipmentType', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final gear = payload.entitiesOf(ImportEntityType.equipment);

      // "BCD - Wing" and "Reg - Longhose" match no enum name; without the
      // value mapper both would land as `other`.
      expect(gear.firstWhere((g) => g['name'] == 'Hydros Pro')['type'], 'bcd');
      expect(
        gear.firstWhere((g) => g['name'] == 'Old Regs')['type'],
        'regulator',
      );
    });

    test('gear price uses the key the importer reads', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final active = payload
          .entitiesOf(ImportEntityType.equipment)
          .firstWhere((g) => g['name'] == 'Hydros Pro');
      // `price` was silently dropped; `_importEquipment` reads purchasePrice.
      expect(active['purchasePrice'], 499.0);
      expect(active['purchaseCurrency'], 'USD');
      expect(active.containsKey('price'), isFalse);
    });

    test('certifications reach the payload', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final cert = payload.entitiesOf(ImportEntityType.certifications).single;
      expect(cert['name'], 'Rescue Scuba Diver');
      expect(cert['agency'], 'NAUI');
      expect(cert['cardNumber'], '2649227');
      expect(cert['instructorName'], 'Jose Salazar');
      expect(cert['issueDate'], isA<DateTime>());
      expect(cert['notes'], contains('Bamboo Reef'));
    });

    test('service records reference their gear by uddfId', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final record = payload.entitiesOf(ImportEntityType.serviceRecords).single;
      // Must match the equipment entity's uddfId so the importer can resolve
      // it through equipmentIdMapping.
      final gear = payload
          .entitiesOf(ImportEntityType.equipment)
          .firstWhere((g) => g['name'] == 'Hydros Pro');
      expect(record['equipmentRef'], gear['uddfId']);
      expect(record['provider'], 'Seals Watersports');
      expect(record['serviceDate'], isA<DateTime>());
    });

    test('a service record with no date is dropped, not carried', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(
        MacDiveRawLogbook(
          dives: logbook.dives,
          sitesByPk: logbook.sitesByPk,
          buddiesByPk: logbook.buddiesByPk,
          tagsByPk: logbook.tagsByPk,
          gearByPk: logbook.gearByPk,
          tanksByPk: logbook.tanksByPk,
          gasesByPk: logbook.gasesByPk,
          tankAndGases: logbook.tankAndGases,
          crittersByPk: logbook.crittersByPk,
          certifications: logbook.certifications,
          serviceRecords: [
            MacDiveRawServiceRecord(
              pk: 99,
              uuid: 'no-date',
              gearFk: logbook.gearByPk.keys.first,
              servicedBy: 'Someone',
            ),
          ],
          events: logbook.events,
          diveToBuddyPks: logbook.diveToBuddyPks,
          diveToTagPks: logbook.diveToTagPks,
          diveToGearPks: logbook.diveToGearPks,
          diveToCritterPks: logbook.diveToCritterPks,
          unitsPreference: logbook.unitsPreference,
        ),
      );

      // The importer requires a service date, so emitting a dateless record
      // would only inflate the count shown in the review step.
      expect(payload.entitiesOf(ImportEntityType.serviceRecords), isEmpty);
    });

    test('a multi-diver library is flagged and tagged by diver', () async {
      final payload = await MacDiveDiveMapper.toPayload(_multiDiverLogbook());

      // #912: several MacDive divers used to merge into one flat list with
      // no way to tell them apart.
      final warning = payload.warnings.singleWhere(
        (w) => w.message.contains('2 divers'),
      );
      expect(warning.severity, ImportWarningSeverity.warning);
      expect(warning.message, contains('Ann Lee'));
      expect(warning.message, contains('Bo Ray'));

      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives.firstWhere((d) => d['sourceUuid'] == 'dive-1')['tagRefs'], [
        'Ann Lee',
      ]);
      expect(dives.firstWhere((d) => d['sourceUuid'] == 'dive-2')['tagRefs'], [
        'Bo Ray',
      ]);
      // A dive with no diver link gets no diver tag.
      expect(
        dives
            .firstWhere((d) => d['sourceUuid'] == 'dive-3')
            .containsKey('tagRefs'),
        isFalse,
      );

      // The names are also emitted as tag entities so the refs resolve.
      expect(
        payload.entitiesOf(ImportEntityType.tags).map((t) => t['name']),
        containsAll(['Ann Lee', 'Bo Ray']),
      );
    });

    test('a single-diver library is not tagged or flagged', () async {
      final payload = await MacDiveDiveMapper.toPayload(
        _multiDiverLogbook(singleDiver: true),
      );
      expect(
        payload.warnings.where((w) => w.message.contains('divers')),
        isEmpty,
      );
      expect(payload.entitiesOf(ImportEntityType.tags), isEmpty);
      for (final dive in payload.entitiesOf(ImportEntityType.dives)) {
        expect(dive.containsKey('tagRefs'), isFalse);
      }
    });

    test('MacDive logbooks are reported as not imported', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final warning = payload.warnings.singleWhere(
        (w) => w.message.contains('Tropical'),
      );
      expect(warning.severity, ImportWarningSeverity.info);
      expect(warning.message, contains('saved searches'));
    });

    test('dive sourceUuid preserved', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      final uuids = dives.map((d) => d['sourceUuid']).toSet();
      expect(uuids, {'dive-uuid-1', 'dive-uuid-2', 'dive-uuid-3'});
    });

    test(
      'dive 1 has tagRefs [Reef, Photography] and buddies [Alice, Bob]',
      () async {
        final logbook = await MacDiveDbReader.readAll(bytes);
        final payload = await MacDiveDiveMapper.toPayload(logbook);
        final dive1 = payload
            .entitiesOf(ImportEntityType.dives)
            .firstWhere((d) => d['sourceUuid'] == 'dive-uuid-1');
        expect(dive1['tagRefs'], containsAll(['Reef', 'Photography']));
        expect(dive1['unmatchedBuddyNames'], containsAll(['Alice', 'Bob']));
      },
    );

    test('dive 3 has no buddies or tags', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final dive3 = payload
          .entitiesOf(ImportEntityType.dives)
          .firstWhere((d) => d['sourceUuid'] == 'dive-uuid-3');
      expect(dive3['tagRefs'], anyOf(isNull, isEmpty));
      expect(dive3['unmatchedBuddyNames'], anyOf(isNull, isEmpty));
    });

    test('dive 1 tanks include gas mix and pressures', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final dive1 = payload
          .entitiesOf(ImportEntityType.dives)
          .firstWhere((d) => d['sourceUuid'] == 'dive-uuid-1');
      final tanks = dive1['tanks'] as List?;
      expect(tanks, isNotNull);
      expect(tanks!.length, 1);
      final tank = tanks.first as Map<String, dynamic>;
      // Synthetic: AL80 + EAN32 + 3000 psi start / 1000 psi end.
      // Units preference is Metric in the fixture, so raw values
      // pass through as-is (3000 "bar", 1000 "bar") because the
      // Metric branch is a passthrough. This is intentional -
      // the synthetic fixture isn't testing unit conversion, the
      // unit-converter tests in M2 did that.
      expect(tank['startPressure'], 3000);
      expect(tank['endPressure'], 1000);
      // #517: volume and working pressure must use the same payload keys the
      // shared UddfEntityImporter._buildTanks reads (`volume` /
      // `workingPressure`), NOT `volumeL` / `workingPressureBar`. A mismatched
      // key silently drops the value, which zeroes out volume-based SAC
      // statistics even though the per-dive SAC (which has a volume fallback)
      // still renders.
      expect(tank['volume'], isNotNull);
      expect(tank['volume'] as num, greaterThan(0));
      expect(tank['workingPressure'], isNotNull);
      expect(tank['workingPressure'] as num, greaterThan(0));
      expect(tank.containsKey('volumeL'), isFalse);
      expect(tank.containsKey('workingPressureBar'), isFalse);
      // gasMix must be a `GasMix` object, not a Map — UddfEntityImporter does
      // `t['gasMix'] as GasMix?` and a Map cast would throw at runtime.
      // MacDive stores oxygen as a fraction (0.32); GasMix.o2 is a percent.
      expect(tank['gasMix'], isA<GasMix>());
      final gasMix = tank['gasMix'] as GasMix;
      expect(gasMix.o2, closeTo(32.0, 0.01));
      expect(gasMix.he, closeTo(0.0, 0.01));
    });

    test('sites: saltwater/freshwater mapped to enum names', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final sites = payload.entitiesOf(ImportEntityType.sites);
      final salt = sites.firstWhere((s) => s['name'] == 'Test Reef');
      final fresh = sites.firstWhere((s) => s['name'] == 'Freshwater Springs');
      expect(
        salt['waterType'],
        'salt',
        reason: 'MacDive "saltwater" -> WaterType.salt.name',
      );
      expect(fresh['waterType'], 'fresh');
    });

    test('sites: lat=0 lon=0 filtered to null', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final fresh = payload
          .entitiesOf(ImportEntityType.sites)
          .firstWhere((s) => s['name'] == 'Freshwater Springs');
      expect(fresh.containsKey('latitude'), isFalse);
      expect(fresh.containsKey('longitude'), isFalse);
    });

    test('no profile key when a dive has no ZRAWDATA', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      // The synthetic fixture carries no raw blobs, so the key stays absent -
      // matching macdive_xml_parser.dart's convention of omitting it when no
      // samples are available.
      for (final dive in payload.entitiesOf(ImportEntityType.dives)) {
        expect(dive.containsKey('profile'), isFalse);
      }
      // The only warning is about the smart logbook, not about profiles.
      expect(
        payload.warnings.where((w) => w.message.contains('profile')),
        isEmpty,
      );
    });

    test('ZRAWDATA is decompressed and parsed into profile samples', () async {
      final calls = <(String, String, int)>[];
      final payload = await MacDiveDiveMapper.toPayload(
        _rawDataLogbook(),
        parseRaw: (vendor, product, model, data) async {
          calls.add((vendor, product, data.length));
          return _parsedDive(
            samples: [
              pigeon.ProfileSample(
                timeSeconds: 0,
                depthMeters: 0.0,
                temperatureCelsius: 25.0,
                pressureBar: 200.0,
              ),
              pigeon.ProfileSample(
                timeSeconds: 10,
                depthMeters: 5.5,
                temperatureCelsius: 24.0,
                pressureBar: 198.0,
              ),
            ],
          );
        },
      );

      // Both Shearwater dives reached the parser; the manual dive did not.
      expect(calls, hasLength(2));
      expect(calls.first.$1, 'Shearwater');
      expect(calls.first.$2, 'Teric');
      // The raw blob was decompressed before parsing, not passed through.
      expect(calls.first.$3, isNot(_compressedFixture.length));

      final dives = payload.entitiesOf(ImportEntityType.dives);
      final withProfile = dives.where((d) => d.containsKey('profile')).toList();
      expect(withProfile, hasLength(2));

      final profile = withProfile.first['profile'] as List;
      expect(profile, hasLength(2));
      expect(profile[1]['depth'], 5.5);
      expect(profile[1]['temperature'], 24.0);
      expect(profile[1]['allTankPressures'], [
        {'pressure': 198.0, 'tankIndex': 0},
      ]);
      expect(payload.warnings, isEmpty);
    });

    test(
      'unrecognised computer counts toward one aggregated warning',
      () async {
        final payload = await MacDiveDiveMapper.toPayload(
          _rawDataLogbook(computer: 'Oceanic Matrix Master'),
          parseRaw: (v, p, m, d) async =>
              fail('parser must not be reached for an unknown model'),
        );

        expect(payload.warnings, hasLength(1));
        final w = payload.warnings.single;
        expect(w.severity, ImportWarningSeverity.info);
        expect(w.entityType, ImportEntityType.dives);
        expect(w.message, contains('2 dive'));
        expect(w.message.toLowerCase(), contains('xml'));
      },
    );

    test('missing platform channel warns once, not once per dive', () async {
      final payload = await MacDiveDiveMapper.toPayload(
        _rawDataLogbook(),
        parseRaw: (v, p, m, d) async =>
            throw MissingPluginException('no channel'),
      );

      expect(payload.warnings, hasLength(1));
      expect(payload.warnings.single.message, contains('this platform'));
    });

    test(
      'ZSAMPLES without ZRAWDATA warns about the unreadable format',
      () async {
        final payload = await MacDiveDiveMapper.toPayload(
          MacDiveRawLogbook(
            dives: [
              MacDiveRawDive(
                pk: 1,
                uuid: 'dive-1',
                computer: 'Oceanic Matrix Master',
                samplesBlob: Uint8List.fromList(List.filled(64, 0x42)),
              ),
            ],
            sitesByPk: const {},
            buddiesByPk: const {},
            tagsByPk: const {},
            gearByPk: const {},
            tanksByPk: const {},
            gasesByPk: const {},
            tankAndGases: const [],
            crittersByPk: const {},
            certifications: const [],
            serviceRecords: const [],
            events: const [],
            diveToBuddyPks: const {},
            diveToTagPks: const {},
            diveToGearPks: const {},
            diveToCritterPks: const {},
            unitsPreference: 'Metric',
          ),
        );

        expect(payload.warnings, hasLength(1));
        expect(payload.warnings.single.message, contains('1 dive'));
        expect(payload.warnings.single.message, contains('cannot read'));
      },
    );

    test('no warning when logbook has no ZRAWDATA', () async {
      const logbook = MacDiveRawLogbook(
        dives: [
          MacDiveRawDive(
            pk: 1,
            uuid: 'dive-1',
            computer: 'Manual',
            rawDataBlob: null,
          ),
        ],
        sitesByPk: {},
        buddiesByPk: {},
        tagsByPk: {},
        gearByPk: {},
        tanksByPk: {},
        gasesByPk: {},
        tankAndGases: [],
        crittersByPk: {},
        certifications: [],
        serviceRecords: [],
        events: [],
        diveToBuddyPks: {},
        diveToTagPks: {},
        diveToGearPks: {},
        diveToCritterPks: {},
        unitsPreference: 'Metric',
      );
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      expect(payload.warnings, isEmpty);
    });

    test('metadata includes source identifier and dive count', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      expect(payload.metadata['source'], 'macdive_sqlite');
      expect(payload.metadata['diveCount'], 3);
    });

    test('site entity carries sourceUuid from ZDIVESITE.ZUUID', () async {
      final logbook = await MacDiveDbReader.readAll(bytes);
      final payload = await MacDiveDiveMapper.toPayload(logbook);
      final salt = payload
          .entitiesOf(ImportEntityType.sites)
          .firstWhere((s) => s['name'] == 'Test Reef');
      expect(salt['sourceUuid'], 'site-uuid-1');
    });
  });
}

/// A Shearwater-compressed log, byte-identical to the fixture in
/// shearwater_raw_decompressor_test.dart, so this test exercises the real
/// decompression path rather than a stub.
final _compressedFixture = _hex(
  '8801e021780c040d010bc0e061e80c043d078387a03010f4'
  '520a0ca70360bdc02660351401c076a0b8183ac404f502e0'
  '20e9d80e079f05c1c1dff02438352501c0f280b8383acc04'
  'f702e020e9c80e03ba05c0c1d14026583301f600a420da70'
  '3609ec01406021e81c0c3d018087a0f070f406021eed4143'
  'c00000000000',
);

Uint8List _hex(String s) {
  final out = Uint8List(s.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// Two dives carrying a real compressed blob plus one manual dive with none.
MacDiveRawLogbook _rawDataLogbook({String computer = 'Shearwater Teric'}) {
  return MacDiveRawLogbook(
    dives: [
      MacDiveRawDive(
        pk: 1,
        uuid: 'dive-1',
        computer: computer,
        rawDataBlob: _compressedFixture,
      ),
      MacDiveRawDive(
        pk: 2,
        uuid: 'dive-2',
        computer: computer,
        rawDataBlob: _compressedFixture,
      ),
      const MacDiveRawDive(pk: 3, uuid: 'dive-3', computer: 'Manual'),
    ],
    sitesByPk: const {},
    buddiesByPk: const {},
    tagsByPk: const {},
    gearByPk: const {},
    tanksByPk: const {},
    gasesByPk: const {},
    tankAndGases: const [],
    crittersByPk: const {},
    certifications: const [],
    serviceRecords: const [],
    events: const [],
    diveToBuddyPks: const {},
    diveToTagPks: const {},
    diveToGearPks: const {},
    diveToCritterPks: const {},
    unitsPreference: 'Metric',
  );
}

/// Three dives across two MacDive divers, plus one dive with no diver link.
/// With [singleDiver] the second diver is removed, so the library looks like
/// the common one-diver case.
MacDiveRawLogbook _multiDiverLogbook({bool singleDiver = false}) {
  return MacDiveRawLogbook(
    dives: const [
      MacDiveRawDive(pk: 1, uuid: 'dive-1', diverFk: 1),
      MacDiveRawDive(pk: 2, uuid: 'dive-2', diverFk: 2),
      MacDiveRawDive(pk: 3, uuid: 'dive-3'),
    ],
    diversByPk: {
      1: const MacDiveRawDiver(
        pk: 1,
        uuid: 'diver-1',
        firstName: 'Ann',
        lastName: 'Lee',
      ),
      if (!singleDiver)
        2: const MacDiveRawDiver(
          pk: 2,
          uuid: 'diver-2',
          firstName: 'Bo',
          lastName: 'Ray',
        ),
    },
    sitesByPk: const {},
    buddiesByPk: const {},
    tagsByPk: const {},
    gearByPk: const {},
    tanksByPk: const {},
    gasesByPk: const {},
    tankAndGases: const [],
    crittersByPk: const {},
    certifications: const [],
    serviceRecords: const [],
    events: const [],
    diveToBuddyPks: const {},
    diveToTagPks: const {},
    diveToGearPks: const {},
    diveToCritterPks: const {},
    unitsPreference: 'Metric',
  );
}

pigeon.ParsedDive _parsedDive({required List<pigeon.ProfileSample> samples}) {
  return pigeon.ParsedDive(
    fingerprint: 'fp',
    dateTimeYear: 2026,
    dateTimeMonth: 3,
    dateTimeDay: 11,
    dateTimeHour: 14,
    dateTimeMinute: 9,
    dateTimeSecond: 18,
    maxDepthMeters: 25.4,
    avgDepthMeters: 17.6,
    durationSeconds: 3100,
    samples: samples,
    tanks: [],
    gasMixes: [],
    events: [],
  );
}
