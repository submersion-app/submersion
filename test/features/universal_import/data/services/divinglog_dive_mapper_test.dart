import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_dive_mapper.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

DivingLogRawDive dive({
  int id = 1,
  String? uuid = 'uuid-1',
  String? place = 'Salt Pier',
  String? city = 'Kralendijk',
  String? country = 'Bonaire',
  int? placeId,
  String? buddy,
  String? divemaster,
  String? divesuit,
  String? comments,
  double? weightKg,
  int? visibilityCode,
  String? supplyType,
  List<DivingLogRawTank> tanks = const [],
  List<DivingLogRawSample> samples = const [],
}) => DivingLogRawDive(
  id: id,
  uuid: uuid,
  number: 42,
  diveDate: '2024-06-01',
  entryTime: '09:30',
  country: country,
  city: city,
  place: place,
  placeId: placeId,
  buddy: buddy,
  divemaster: divemaster,
  comments: comments,
  depthMeters: 18.5,
  diveTimeMinutes: 47,
  airTempCelsius: 29.0,
  waterTempCelsius: 27.0,
  weightKg: weightKg,
  divesuit: divesuit,
  computer: 'Perdix',
  visibilityCode: visibilityCode,
  supplyType: supplyType,
  tanks: tanks,
  samples: samples,
);

DivingLogLogbook book(
  List<DivingLogRawDive> dives, {
  Map<int, DivingLogRawPlace> places = const {},
}) => DivingLogLogbook(
  dives: dives,
  capabilities: const DivingLogCapabilities(tables: {}, columns: {}),
  placesById: places,
);

void main() {
  group('DivingLogDiveMapper.toPayload', () {
    test('maps the core dive fields', () {
      final payload = DivingLogDiveMapper.toPayload(book([dive()]));
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      expect(d['dateTime'], DateTime.utc(2024, 6, 1, 9, 30));
      expect(d['diveNumber'], 42);
      expect(d['maxDepth'], closeTo(18.5, 1e-9));
      expect(d['duration'], const Duration(minutes: 47));
      expect(d['airTemp'], closeTo(29.0, 1e-9));
      expect(d['waterTemp'], closeTo(27.0, 1e-9));
      expect(d['diveComputerModel'], 'Perdix');
      expect(d['sourceUuid'], 'uuid-1');
    });

    test('skips a dive with no readable date', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([const DivingLogRawDive(id: 1, diveDate: null)]),
      );
      expect(payload.entitiesOf(ImportEntityType.dives), isEmpty);
      expect(
        payload.warnings.where((w) => w.code == ImportWarningCode.divesSkipped),
        hasLength(1),
      );
    });

    test('defaults a missing entry time to midnight', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          const DivingLogRawDive(
            id: 1,
            diveDate: '2024-06-01',
            entryTime: null,
          ),
        ]),
      );
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      expect(d['dateTime'], DateTime.utc(2024, 6, 1));
    });

    test('a dive at a coordinate-only Place links to the site named from '
        'them', () {
      final payload = DivingLogDiveMapper.toPayload(
        book(
          [dive(place: null, city: null, country: null, placeId: 10)],
          places: {
            10: const DivingLogRawPlace(
              id: 10,
              latitude: 12.13,
              longitude: -68.28,
            ),
          },
        ),
      );

      final site = payload.entitiesOf(ImportEntityType.sites).single;
      expect(site['latitude'], closeTo(12.13, 1e-9));
      expect(
        payload.entitiesOf(ImportEntityType.dives).single['site']['uddfId'],
        site['uddfId'],
      );
    });

    test('collapses repeated dives at one place to a single site', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([dive(id: 1), dive(id: 2, uuid: 'uuid-2')]),
      );
      final sites = payload.entitiesOf(ImportEntityType.sites);
      expect(sites, hasLength(1));
      expect(sites.single['name'], 'Salt Pier');
      expect(sites.single['country'], 'Bonaire');
      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(
        dives.every((d) => d['site']['uddfId'] == sites.single['uddfId']),
        isTrue,
      );
    });

    test('keeps two different places apart', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([dive(id: 1), dive(id: 2, uuid: 'u2', place: 'Karpata')]),
      );
      expect(payload.entitiesOf(ImportEntityType.sites), hasLength(2));
    });

    test(
      'splits the buddy column and puts the divemaster in diveGuideRefs',
      () {
        final payload = DivingLogDiveMapper.toPayload(
          book([dive(buddy: 'Alice, Bob', divemaster: 'Carol')]),
        );
        final d = payload.entitiesOf(ImportEntityType.dives).single;
        expect(d['buddyRefs'], ['Alice', 'Bob']);
        expect(d['diveGuideRefs'], ['Carol']);
        final buddies = payload
            .entitiesOf(ImportEntityType.buddies)
            .map((b) => b['name'])
            .toList();
        expect(buddies, containsAll(['Alice', 'Bob', 'Carol']));
        expect(buddies, hasLength(3));
      },
    );

    test('does not duplicate a buddy who is also the divemaster', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([dive(buddy: 'Carol', divemaster: 'Carol')]),
      );
      expect(payload.entitiesOf(ImportEntityType.buddies), hasLength(1));
    });

    test('rounds a fractional Divetime to whole seconds', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          const DivingLogRawDive(
            id: 1,
            diveDate: '2024-06-01',
            entryTime: '09:30',
            diveTimeMinutes: 80.733333,
          ),
        ]),
      );
      expect(
        payload.entitiesOf(ImportEntityType.dives).single['duration'],
        const Duration(seconds: 4844),
      );
    });

    test('refs a differently cased buddy by the canonical entity id', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          dive(id: 1, buddy: 'Alice'),
          dive(id: 2, uuid: 'u2', buddy: 'alice'),
        ]),
      );
      final buddies = payload.entitiesOf(ImportEntityType.buddies);
      expect(buddies, hasLength(1));
      final id = buddies.single['uddfId'];
      for (final d in payload.entitiesOf(ImportEntityType.dives)) {
        expect(d['buddyRefs'], [id]);
      }
    });

    test('refs a differently cased tag by the canonical entity id', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          dive(id: 1, supplyType: 'Nitrox'),
          dive(id: 2, uuid: 'u2', supplyType: 'nitrox'),
        ]),
      );
      final tags = payload.entitiesOf(ImportEntityType.tags);
      expect(tags, hasLength(1));
      final id = tags.single['uddfId'];
      for (final d in payload.entitiesOf(ImportEntityType.dives)) {
        expect(d['tagRefs'], [id]);
      }
    });

    test('skips an out-of-range date instead of rolling it over', () {
      // DateTime.utc normalises 30 February to 1 March, which would file
      // the dive under a date the log never recorded.
      final payload = DivingLogDiveMapper.toPayload(
        book([
          const DivingLogRawDive(
            id: 1,
            diveDate: '2024-02-30',
            entryTime: '09:30',
          ),
        ]),
      );
      expect(payload.entitiesOf(ImportEntityType.dives), isEmpty);
      expect(
        payload.warnings.where((w) => w.code == ImportWarningCode.divesSkipped),
        hasLength(1),
      );
    });

    test('skips an out-of-range entry time instead of rolling it over', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          const DivingLogRawDive(
            id: 1,
            diveDate: '2024-06-01',
            entryTime: '25:00',
          ),
        ]),
      );
      expect(payload.entitiesOf(ImportEntityType.dives), isEmpty);
    });

    test('surfaces the reader schema notes as diagnostics', () {
      final payload = DivingLogDiveMapper.toPayload(
        DivingLogLogbook(
          dives: [dive()],
          capabilities: const DivingLogCapabilities(tables: {}, columns: {}),
          schemaNotes: const ['No Tank table, so something was lost.'],
        ),
      );
      expect(
        payload.warnings
            .where((w) => w.message.contains('No Tank table'))
            .length,
        1,
      );
    });

    test('ignores a profile tank id that matches no cylinder', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          dive(
            tanks: const [DivingLogRawTank(tankId: 0, o2Percent: 32.0)],
            samples: const [
              DivingLogRawSample(timeSeconds: 0, depthMeters: 20.0, tankId: 0),
              DivingLogRawSample(timeSeconds: 20, depthMeters: 6.0, tankId: 7),
            ],
          ),
        ]),
      );
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      expect(d.containsKey('gasSwitches'), isFalse);
    });

    test('routes a lone ppO2 reading to ppO2, not an O2 cell', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          dive(
            samples: const [
              DivingLogRawSample(
                timeSeconds: 0,
                depthMeters: 4.5,
                ppO2Cell1: 0.23,
              ),
            ],
          ),
        ]),
      );
      final point =
          (payload.entitiesOf(ImportEntityType.dives).single['profile'] as List)
              .single;
      expect(point['ppO2'], closeTo(0.23, 1e-9));
      expect(point.containsKey('o2Sensor1'), isFalse);
      expect(point.containsKey('setpoint'), isFalse);
    });

    test('keeps a real cell array on the o2Sensor fields', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          dive(
            samples: const [
              DivingLogRawSample(
                timeSeconds: 0,
                depthMeters: 20.0,
                ppO2Cell1: 1.12,
                ppO2Cell2: 1.13,
                ppO2Cell3: 1.14,
                setpoint: 1.1,
              ),
            ],
          ),
        ]),
      );
      final point =
          (payload.entitiesOf(ImportEntityType.dives).single['profile'] as List)
              .single;
      expect(point['o2Sensor1'], closeTo(1.12, 1e-9));
      expect(point['o2Sensor3'], closeTo(1.14, 1e-9));
      expect(point.containsKey('ppO2'), isFalse);
    });

    test('resolves a one-based source tank id to its position', () {
      // The reference logbook writes Tank.TankID = 1 while the profile's
      // packed tank ids are 0-based, so a switch must resolve by position.
      final payload = DivingLogDiveMapper.toPayload(
        book([
          dive(
            tanks: const [
              DivingLogRawTank(tankId: 1, o2Percent: 32.0),
              DivingLogRawTank(tankId: 2, o2Percent: 50.0),
            ],
            samples: const [
              DivingLogRawSample(
                timeSeconds: 0,
                depthMeters: 20.0,
                tankId: 0,
                pressureBar: 200.0,
              ),
              DivingLogRawSample(
                timeSeconds: 20,
                depthMeters: 6.0,
                tankId: 1,
                pressureBar: 150.0,
              ),
            ],
          ),
        ]),
      );
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      final switches = d['gasSwitches'] as List;
      expect(switches, hasLength(1));
      // Profile tank 1 is the second cylinder, whose source id is 2.
      expect(switches.single['tankRef'], 'divinglog:2');
      final profile = d['profile'] as List;
      expect((profile[0]['allTankPressures'] as List).single['tankIndex'], 0);
      expect((profile[1]['allTankPressures'] as List).single['tankIndex'], 1);
    });

    test('raises no OTU warning when the OTU field is all zeros', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          dive(
            samples: const [
              DivingLogRawSample(timeSeconds: 0, depthMeters: 4.5),
            ],
          ),
        ]),
      );
      expect(
        payload.warnings.where((w) => w.message.toLowerCase().contains('otu')),
        isEmpty,
      );
    });

    test('maps weight to weightUsed in kilograms', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([dive(weightKg: 5.0)]),
      );
      expect(
        payload.entitiesOf(ImportEntityType.dives).single['weightUsed'],
        closeTo(5.0, 1e-9),
      );
    });

    test('maps the visibility code onto the Visibility enum', () {
      for (final (code, expected) in [
        (1, 'good'),
        (2, 'moderate'),
        (3, 'poor'),
      ]) {
        final payload = DivingLogDiveMapper.toPayload(
          book([dive(visibilityCode: code)]),
        );
        expect(
          payload.entitiesOf(ImportEntityType.dives).single['visibility'],
          expected,
        );
      }
    });

    test('omits visibility for the unset code', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([dive(visibilityCode: 0)]),
      );
      expect(
        payload
            .entitiesOf(ImportEntityType.dives)
            .single
            .containsKey('visibility'),
        isFalse,
      );
    });

    test('puts the suit in notes rather than creating equipment', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([dive(divesuit: '3mm shorty', comments: 'lovely dive')]),
      );
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      expect(d['notes'], contains('lovely dive'));
      expect(d['notes'], contains('3mm shorty'));
      expect(payload.entitiesOf(ImportEntityType.equipment), isEmpty);
    });

    test('emits the supply type as a tag', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([dive(supplyType: 'Nitrox')]),
      );
      expect(payload.entitiesOf(ImportEntityType.dives).single['tagRefs'], [
        'Nitrox',
      ]);
      expect(
        payload.entitiesOf(ImportEntityType.tags).single['name'],
        'Nitrox',
      );
    });

    test('doubles the volume of a twinset', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          dive(
            tanks: const [
              DivingLogRawTank(tankId: 0, sizeLiters: 7.0, isDouble: true),
            ],
          ),
        ]),
      );
      final tanks =
          payload.entitiesOf(ImportEntityType.dives).single['tanks'] as List;
      expect(tanks.single['volume'], closeTo(14.0, 1e-9));
    });

    test('emits a gas switch when the profile tank id changes', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          dive(
            tanks: const [
              DivingLogRawTank(tankId: 0, o2Percent: 32.0),
              DivingLogRawTank(tankId: 1, o2Percent: 50.0),
            ],
            samples: const [
              DivingLogRawSample(timeSeconds: 0, depthMeters: 20.0, tankId: 0),
              DivingLogRawSample(timeSeconds: 20, depthMeters: 18.0, tankId: 0),
              DivingLogRawSample(timeSeconds: 40, depthMeters: 6.0, tankId: 1),
            ],
          ),
        ]),
      );
      final switches =
          payload.entitiesOf(ImportEntityType.dives).single['gasSwitches']
              as List;
      expect(switches, hasLength(1));
      expect(switches.single['timestamp'], 40);
      expect(switches.single['tankRef'], 'divinglog:1');
    });

    test('emits no gas switch when the tank never changes', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          dive(
            tanks: const [DivingLogRawTank(tankId: 0, o2Percent: 32.0)],
            samples: const [
              DivingLogRawSample(timeSeconds: 0, depthMeters: 20.0, tankId: 0),
              DivingLogRawSample(timeSeconds: 20, depthMeters: 18.0, tankId: 0),
            ],
          ),
        ]),
      );
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      expect(d.containsKey('gasSwitches'), isFalse);
    });

    test('maps profile samples and raises one OTU warning per file', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          dive(
            samples: const [
              DivingLogRawSample(
                timeSeconds: 0,
                depthMeters: 4.5,
                temperatureCelsius: 25.5,
                otu: 154.8,
                cns: 26.4,
              ),
              DivingLogRawSample(timeSeconds: 20, depthMeters: 9.0, otu: 160.0),
            ],
          ),
        ]),
      );
      final profile =
          payload.entitiesOf(ImportEntityType.dives).single['profile'] as List;
      expect(profile, hasLength(2));
      expect(profile.first['timestamp'], 0);
      expect(profile.first['depth'], closeTo(4.5, 1e-9));
      expect(profile.first['temperature'], closeTo(25.5, 1e-9));
      expect(profile.first['cns'], closeTo(26.4, 1e-9));
      expect(profile.first.containsKey('otu'), isFalse);
      expect(
        payload.warnings
            .where((w) => w.message.toLowerCase().contains('otu'))
            .length,
        1,
      );
    });
  });

  group('reference resolution', () {
    DivingLogLogbook wired() => const DivingLogLogbook(
      dives: [
        DivingLogRawDive(
          id: 1,
          diveDate: '2024-06-01',
          entryTime: '09:30',
          buddy: 'Ignored Text',
          buddyIds: [1],
          equipmentIds: [3],
          diveTypeIds: [5],
          placeId: 10,
          countryId: 30,
          shopId: 40,
          tripId: 50,
        ),
      ],
      capabilities: DivingLogCapabilities(tables: {}, columns: {}),
      buddiesById: {
        1: DivingLogRawBuddy(id: 1, firstName: 'Alice', lastName: 'Smith'),
      },
      placesById: {
        10: DivingLogRawPlace(
          id: 10,
          place: 'Salt Pier',
          latitude: 12.13,
          longitude: -68.28,
        ),
      },
      countryNamesById: {30: 'Bonaire'},
      equipmentById: {3: DivingLogRawEquipment(id: 3, object: 'Go Sport Fins')},
      tripsById: {50: DivingLogRawTrip(id: 50, name: 'Bonaire 2024')},
      shopsById: {40: DivingLogRawShop(id: 40, name: 'Dive Friends')},
      diveTypesById: {5: DivingLogRawDiveType(id: 5, name: 'Education')},
      certifications: [DivingLogRawCertification(id: 1, name: 'Rescue Diver')],
      speciesById: {
        99: DivingLogRawSpecies(id: 99, commonName: 'Giant Manta Ray'),
      },
      speciesIdsByLogId: {
        1: [99],
      },
      picturesByLogId: {
        1: [DivingLogRawPicture(id: 1, logId: 1, path: '/p/1.jpg')],
      },
    );

    test('emits every reference entity', () {
      final payload = DivingLogDiveMapper.toPayload(wired());
      expect(payload.entitiesOf(ImportEntityType.sites), hasLength(1));
      expect(payload.entitiesOf(ImportEntityType.buddies), hasLength(1));
      expect(payload.entitiesOf(ImportEntityType.equipment), hasLength(1));
      expect(payload.entitiesOf(ImportEntityType.trips), hasLength(1));
      expect(payload.entitiesOf(ImportEntityType.diveCenters), hasLength(1));
      expect(payload.entitiesOf(ImportEntityType.diveTypes), hasLength(1));
      expect(payload.entitiesOf(ImportEntityType.certifications), hasLength(1));
      expect(payload.entitiesOf(ImportEntityType.media), hasLength(1));
    });

    test('a dive with BuddyIDs ignores its free text buddy column', () {
      final payload = DivingLogDiveMapper.toPayload(wired());
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      expect(d['buddyRefs'], ['Alice Smith']);
      final names = payload
          .entitiesOf(ImportEntityType.buddies)
          .map((b) => b['name'])
          .toList();
      expect(names, ['Alice Smith']);
      expect(names, isNot(contains('Ignored Text')));
    });

    test('links the dive to its references by uddfId', () {
      final payload = DivingLogDiveMapper.toPayload(wired());
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      expect(d['equipmentRefs'], ['divinglog_gear_3']);
      expect(d['tripRef'], 'divinglog_trip_50');
      expect(d['diveCenterRef'], 'divinglog_shop_40');
      expect(d['diveTypeIds'], [DiveTypeEntity.generateSlug('Education')]);
      expect(d['site']['uddfId'], 'divinglog_site_bonaire|salt pier');
      expect(
        (d['sightings'] as List).single['speciesRef'],
        'species_giant_manta_ray',
      );
    });

    test('reports ids that match no record, once per kind', () {
      const book = DivingLogLogbook(
        dives: [
          DivingLogRawDive(
            id: 1,
            diveDate: '2024-06-01',
            buddyIds: [1, 99],
            equipmentIds: [42],
          ),
        ],
        capabilities: DivingLogCapabilities(tables: {}, columns: {}),
        buddiesById: {1: DivingLogRawBuddy(id: 1, firstName: 'Alice')},
      );
      final payload = DivingLogDiveMapper.toPayload(book);
      final messages = payload.warnings.map((w) => w.message).join(' ');
      expect(messages, contains('1 buddy reference(s)'));
      expect(messages, contains('1 equipment reference(s)'));
    });

    test('an unresolvable BuddyIDs does not fall back to the text', () {
      // Ids win means ids win. Falling back here would recreate the phase 1
      // duplicates precisely when the relational data is incomplete.
      const book = DivingLogLogbook(
        dives: [
          DivingLogRawDive(
            id: 1,
            diveDate: '2024-06-01',
            buddy: 'Alice, Bob',
            buddyIds: [99],
          ),
        ],
        capabilities: DivingLogCapabilities(tables: {}, columns: {}),
      );
      final payload = DivingLogDiveMapper.toPayload(book);
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      expect(d.containsKey('buddyRefs'), isFalse);
      expect(payload.entitiesOf(ImportEntityType.buddies), isEmpty);
      expect(
        payload.warnings.map((w) => w.message).join(' '),
        contains('1 buddy reference(s)'),
      );
    });

    test('does not call a deduplicated dive type reference unresolved', () {
      // diveTypeIdsFor collapses two ids that share a name into one slug,
      // so counting requested minus resolved would report a record missing
      // when nothing is missing at all.
      const book = DivingLogLogbook(
        dives: [
          DivingLogRawDive(id: 1, diveDate: '2024-06-01', diveTypeIds: [5, 6]),
        ],
        capabilities: DivingLogCapabilities(tables: {}, columns: {}),
        diveTypesById: {
          5: DivingLogRawDiveType(id: 5, name: 'Wreck'),
          6: DivingLogRawDiveType(id: 6, name: 'Wreck'),
        },
      );
      final payload = DivingLogDiveMapper.toPayload(book);
      expect(
        payload.entitiesOf(ImportEntityType.dives).single['diveTypeIds'],
        hasLength(1),
      );
      expect(
        payload.warnings.map((w) => w.message).join(' '),
        isNot(contains('dive type reference')),
      );
    });

    test('counts a repeated valid id once per id, not as a gap', () {
      const book = DivingLogLogbook(
        dives: [
          DivingLogRawDive(id: 1, diveDate: '2024-06-01', diveTypeIds: [5, 5]),
        ],
        capabilities: DivingLogCapabilities(tables: {}, columns: {}),
        diveTypesById: {5: DivingLogRawDiveType(id: 5, name: 'Wreck')},
      );
      final payload = DivingLogDiveMapper.toPayload(book);
      expect(
        payload.warnings.map((w) => w.message).join(' '),
        isNot(contains('dive type reference')),
      );
    });

    test('says references could not be resolved, not that rows are absent', () {
      // The count includes rows that exist but yield no entity, such as an
      // equipment row with a blank name, so "the file does not contain
      // them" would be untrue.
      const book = DivingLogLogbook(
        dives: [
          DivingLogRawDive(id: 1, diveDate: '2024-06-01', equipmentIds: [8]),
        ],
        capabilities: DivingLogCapabilities(tables: {}, columns: {}),
        equipmentById: {8: DivingLogRawEquipment(id: 8, object: '   ')},
      );
      final payload = DivingLogDiveMapper.toPayload(book);
      final messages = payload.warnings.map((w) => w.message).join(' ');
      expect(messages, contains('could not be resolved'));
      expect(messages, isNot(contains('does not contain')));
    });

    test('surfaces a buddy name collision as a diagnostic', () {
      const book = DivingLogLogbook(
        dives: [DivingLogRawDive(id: 1, diveDate: '2024-06-01')],
        capabilities: DivingLogCapabilities(tables: {}, columns: {}),
        buddiesById: {
          1: DivingLogRawBuddy(id: 1, firstName: 'Sam', lastName: 'Lee'),
          2: DivingLogRawBuddy(id: 2, firstName: 'Sam', lastName: 'Lee'),
        },
      );
      final payload = DivingLogDiveMapper.toPayload(book);
      expect(
        payload.warnings.map((w) => w.message).join(' '),
        contains('Sam Lee'),
      );
    });

    test('still uses the text column when a dive has no BuddyIDs', () {
      const book = DivingLogLogbook(
        dives: [
          DivingLogRawDive(id: 1, diveDate: '2024-06-01', buddy: 'Carol'),
        ],
        capabilities: DivingLogCapabilities(tables: {}, columns: {}),
      );
      final payload = DivingLogDiveMapper.toPayload(book);
      expect(payload.entitiesOf(ImportEntityType.dives).single['buddyRefs'], [
        'Carol',
      ]);
    });
  });
}
