import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_dive_mapper.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

DivingLogRawDive dive({
  int id = 1,
  String? uuid = 'uuid-1',
  String? place = 'Salt Pier',
  String? city = 'Kralendijk',
  String? country = 'Bonaire',
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

DivingLogLogbook book(List<DivingLogRawDive> dives) => DivingLogLogbook(
  dives: dives,
  capabilities: const DivingLogCapabilities(tables: {}, columns: {}),
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
}
