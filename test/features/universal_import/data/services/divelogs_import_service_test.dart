import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/divelogs_import_service.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';

void main() {
  Map<String, dynamic> diveJson(
    int id, {
    String date = '2022-09-03',
    String time = '14:42:00',
  }) => {
    'id': id,
    'date': date,
    'time': time,
    'duration': 2808,
    'maxdepth': 12,
    'divesite': 'Shinenead',
    'lat': 24.6,
    'lng': 35.1,
  };

  DivelogsImportService service(
    Object dives, {
    Object gear = const [],
    Object geartypes = const [],
    Object certifications = const [],
    int gearStatus = 200,
    int certStatus = 200,
  }) => DivelogsImportService(
    api: DivelogsApiClient(
      getBearerToken: () async => 't',
      onTokenRejected: () {},
      httpClient: MockClient((req) async {
        switch (req.url.path) {
          case '/api/dives':
            return http.Response(jsonEncode(dives), 200);
          case '/api/gear':
            return http.Response(jsonEncode(gear), gearStatus);
          case '/api/geartypes':
            return http.Response(jsonEncode(geartypes), 200);
          case '/api/certifications':
            return http.Response(jsonEncode(certifications), certStatus);
        }
        fail('unexpected request ${req.url}');
      }),
    ),
  );

  test('assembles payload with dives and deduped sites', () async {
    final payload = await service([
      diveJson(1),
      diveJson(2, time: '18:00:00'),
    ]).fetchAllDives();

    expect(payload.entitiesOf(ImportEntityType.dives), hasLength(2));
    expect(payload.entitiesOf(ImportEntityType.sites), hasLength(1));
    expect(
      payload.entitiesOf(ImportEntityType.dives).first['sourceUuid'],
      'divelogs:1',
    );
    expect(payload.metadata['source'], 'divelogs.de');
    expect(payload.metadata['diveCount'], 2);
    expect(payload.warnings, isEmpty);
  });

  test('surfaces skipped dives as a warning', () async {
    final payload = await service([
      diveJson(1),
      {'date': '2022-01-01'},
    ]).fetchAllDives();

    expect(payload.entitiesOf(ImportEntityType.dives), hasLength(1));
    expect(payload.warnings, hasLength(1));
    expect(payload.warnings.single.severity, ImportWarningSeverity.warning);
    expect(
      payload.warnings.single.message,
      '1 dive could not be read from divelogs.de and was skipped.',
    );
  });

  group('gear and certification pull', () {
    test('maps gear rows into equipment entities', () async {
      final payload = await service(
        [diveJson(1)],
        gear: [
          {'id': 45, 'name': 'Apex XTX50', 'geartype': 1},
          {
            'id': 46,
            'name': 'Old BCD',
            'geartype': 2,
            'discarddate': '2020-01-01',
          },
        ],
        geartypes: [
          {'id': 1, 'name': 'Regulator'},
          {'id': 2, 'name': 'Jacket'},
        ],
      ).fetchAllDives();

      final equipment = payload.entitiesOf(ImportEntityType.equipment);
      expect(equipment, hasLength(2));
      expect(equipment[0]['uddfId'], 'divelogs-gear-45');
      expect(equipment[0]['type'], EquipmentType.regulator);
      expect(equipment[0]['status'], EquipmentStatus.active);
      expect(equipment[1]['status'], EquipmentStatus.retired);
      expect(equipment[1]['isActive'], isFalse);
    });

    test('maps certification rows into certification entities', () async {
      final payload = await service(
        [diveJson(1)],
        certifications: [
          {
            'id': 123,
            'name': 'Open Water',
            'date': '2022-06-15',
            'org': 'PADI',
          },
        ],
      ).fetchAllDives();

      final certs = payload.entitiesOf(ImportEntityType.certifications);
      expect(certs, hasLength(1));
      expect(certs.single['agency'], CertificationAgency.padi);
      expect(certs.single['issueDate'], DateTime.utc(2022, 6, 15));
      expect(certs.single['level'], CertificationLevel.openWater);
    });

    test('dive gearitems become equipmentRefs', () async {
      final payload = await service(
        [
          {
            ...diveJson(1),
            'gearitems': [45],
          },
        ],
        gear: [
          {'id': 45, 'name': 'Apex XTX50'},
        ],
      ).fetchAllDives();

      expect(
        payload.entitiesOf(ImportEntityType.dives).single['equipmentRefs'],
        ['divelogs-gear-45'],
      );
    });

    test('gear fetch failure degrades to a warning, dives survive', () async {
      final payload = await service([
        diveJson(1),
      ], gearStatus: 500).fetchAllDives();

      expect(payload.entitiesOf(ImportEntityType.dives), hasLength(1));
      expect(payload.entitiesOf(ImportEntityType.equipment), isEmpty);
      expect(
        payload.warnings.map((w) => w.message),
        anyElement(contains('Gear')),
      );
    });

    test('certification fetch failure degrades to a warning', () async {
      final payload = await service([
        diveJson(1),
      ], certStatus: 500).fetchAllDives();

      expect(payload.entitiesOf(ImportEntityType.dives), hasLength(1));
      expect(
        payload.warnings.map((w) => w.message),
        anyElement(contains('Certifications')),
      );
    });
  });

  group('duplicate checker integration', () {
    final existingDive = Dive(
      id: 'existing-1',
      dateTime: DateTime.utc(2022, 9, 3, 14, 42),
      entryTime: DateTime.utc(2022, 9, 3, 14, 42),
      runtime: const Duration(seconds: 2808),
      maxDepth: 12,
    );

    ImportDuplicateResult check(
      payload, {
      Map<String, String> existingSourceUuidByDiveId = const {},
    }) => const ImportDuplicateChecker().check(
      payload: payload,
      existingDives: [existingDive],
      existingSites: const [],
      existingTrips: const [],
      existingEquipment: const [],
      existingBuddies: const [],
      existingDiveCenters: const [],
      existingCertifications: const [],
      existingTags: const [],
      existingDiveTypes: const [],
      existingSourceUuidByDiveId: existingSourceUuidByDiveId,
    );

    test('fuzzy date/time match flags the pulled dive as duplicate', () async {
      final payload = await service([
        diveJson(1),
        diveJson(2, date: '2023-05-05'),
      ]).fetchAllDives();

      final result = check(payload);
      final match = result.diveMatches[0];
      expect(match, isNotNull);
      expect(match!.diveId, 'existing-1');
      expect(match.score, greaterThanOrEqualTo(0.7));
      expect(match.matchedExistingSource, isFalse);
      expect(
        result.diveMatches[1],
        isNull,
        reason: 'the 2023 dive matches nothing',
      );
    });

    test('second pull is a Pass-0 exact source match', () async {
      final payload = await service([diveJson(1)]).fetchAllDives();

      final result = check(
        payload,
        existingSourceUuidByDiveId: {'existing-1': 'divelogs:1'},
      );
      expect(result.diveMatches[0]?.matchedExistingSource, isTrue);
      expect(result.diveMatches[0]?.score, 1.0);
    });
  });
}
