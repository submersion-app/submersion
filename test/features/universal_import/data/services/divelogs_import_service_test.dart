import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/core/services/divelogs/divelogs_models.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
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
    Map<String, Object> picturesByDive = const {},
    Set<String> failingPictureDives = const {},
    bool forbidPictures = false,
  }) => DivelogsImportService(
    api: DivelogsApiClient(
      getBearerToken: () async => 't',
      onTokenRejected: () {},
      httpClient: MockClient((req) async {
        final path = req.url.path;
        if (path.startsWith('/api/pictures/')) {
          if (forbidPictures) fail('pictures requested: ${req.url}');
          final id = path.split('/').last;
          if (failingPictureDives.contains(id)) {
            return http.Response('boom', 500);
          }
          return http.Response(jsonEncode(picturesByDive[id] ?? []), 200);
        }
        switch (path) {
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

  Future<ImportPayload> payloadOf(DivelogsImportService s) async =>
      (await s.fetchLogbook(includePhotos: false)).payload;

  test('assembles payload with dives and deduped sites', () async {
    final payload = await payloadOf(
      service([diveJson(1), diveJson(2, time: '18:00:00')]),
    );

    expect(payload.entitiesOf(ImportEntityType.dives), hasLength(2));
    expect(payload.entitiesOf(ImportEntityType.sites), hasLength(1));
    expect(
      payload.entitiesOf(ImportEntityType.dives).first['sourceUuid'],
      'divelogs-1',
    );
    expect(payload.metadata['source'], 'divelogs.de');
    expect(payload.metadata['diveCount'], 2);
    expect(payload.warnings, isEmpty);
  });

  test('a later dive backfills a position its site lacked', () async {
    final payload = await payloadOf(
      service([
        {...diveJson(1), 'lat': 0, 'lng': 0},
        diveJson(2, time: '18:00:00'),
      ]),
    );
    final site = payload.entitiesOf(ImportEntityType.sites).single;
    expect(site['name'], 'Shinenead');
    expect(site['latitude'], 24.6);
    expect(site['longitude'], 35.1);
  });

  test('skipped dives become one coded warning with a count', () async {
    final result = await service([
      diveJson(1),
      {'id': 2},
      'not a map',
    ]).fetchLogbook(includePhotos: false);
    expect(result.skippedDives, 2);
    final warning = result.payload.warnings.single;
    expect(warning.code, ImportWarningCode.divesSkipped);
    expect(warning.count, 2);
  });

  group('gear and certification pull', () {
    test('maps gear rows into equipment entities', () async {
      final payload = await payloadOf(
        service(
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
        ),
      );

      final equipment = payload.entitiesOf(ImportEntityType.equipment);
      expect(equipment, hasLength(2));
      expect(equipment[0]['uddfId'], 'divelogs-gear-45');
      expect(equipment[0]['type'], EquipmentType.regulator);
      expect(equipment[0]['status'], EquipmentStatus.active);
      expect(equipment[1]['status'], EquipmentStatus.retired);
      expect(equipment[1]['isActive'], isFalse);
    });

    test('maps certification rows into certification entities', () async {
      final payload = await payloadOf(
        service(
          [diveJson(1)],
          certifications: [
            {
              'id': 123,
              'name': 'Open Water',
              'date': '2022-06-15',
              'org': 'PADI',
            },
          ],
        ),
      );

      final certs = payload.entitiesOf(ImportEntityType.certifications);
      expect(certs, hasLength(1));
      expect(certs.single['agency'], CertificationAgency.padi);
      expect(certs.single['issueDate'], DateTime.utc(2022, 6, 15));
      expect(certs.single['level'], CertificationLevel.openWater);
    });

    test('dive gearitems become equipmentRefs', () async {
      final payload = await payloadOf(
        service(
          [
            {
              ...diveJson(1),
              'gearitems': [45],
            },
          ],
          gear: [
            {'id': 45, 'name': 'Apex XTX50'},
          ],
        ),
      );

      expect(
        payload.entitiesOf(ImportEntityType.dives).single['equipmentRefs'],
        ['divelogs-gear-45'],
      );
    });

    test('gear failure degrades to a coded warning, dives survive', () async {
      final result = await service([
        diveJson(1),
      ], gearStatus: 500).fetchLogbook(includePhotos: false);
      expect(result.gearUnavailable, isTrue);
      expect(result.payload.entitiesOf(ImportEntityType.dives), hasLength(1));
      expect(result.payload.entitiesOf(ImportEntityType.equipment), isEmpty);
      expect(
        result.payload.warnings.map((w) => w.code),
        contains(ImportWarningCode.gearUnavailable),
      );
    });

    test('certification failure degrades to a coded warning', () async {
      final result = await service([
        diveJson(1),
      ], certStatus: 500).fetchLogbook(includePhotos: false);
      expect(result.certificationsUnavailable, isTrue);
      expect(result.payload.entitiesOf(ImportEntityType.dives), hasLength(1));
      expect(
        result.payload.warnings.map((w) => w.code),
        contains(ImportWarningCode.certificationsUnavailable),
      );
    });
  });

  group('photo listing', () {
    test('lists photos per dive keyed by source id when asked', () async {
      final progress = <(int, int)>[];
      final result =
          await service(
            [diveJson(1), diveJson(2, time: '16:00:00')],
            picturesByDive: {
              '1': [
                {'id': 10, 'url': 'https://divelogs.de/pics/u/1/reef.jpg'},
                {'id': 11, 'url': 'https://divelogs.de/pics/get?id=11'},
              ],
            },
          ).fetchLogbook(
            includePhotos: true,
            onPhotoListingProgress: (c, t) => progress.add((c, t)),
          );
      final photos = result.photosBySourceUuid['divelogs-1']!;
      expect(photos.map((p) => p.fileName), ['reef.jpg', 'divelogs-1-2.jpg']);
      expect(
        photos.first.url,
        Uri.parse('https://divelogs.de/pics/u/1/reef.jpg'),
      );
      expect(result.photosBySourceUuid.containsKey('divelogs-2'), isFalse);
      expect(result.photoCount, 2);
      expect(progress.last, (2, 2));
    });

    test('a picture row without a usable url is counted, not hidden', () async {
      final result = await service(
        [diveJson(1)],
        picturesByDive: {
          '1': [
            {'id': 10, 'url': 'reef.jpg'},
            {'id': 11, 'url': 'https://divelogs.de/pics/ok.jpg'},
          ],
        },
      ).fetchLogbook(includePhotos: true);
      expect(result.photoCount, 1);
      expect(result.photoListingFailures, 1);
    });

    test('listing failures are counted into one coded warning', () async {
      final result = await service(
        [diveJson(1), diveJson(2, time: '16:00:00')],
        failingPictureDives: {'1', '2'},
      ).fetchLogbook(includePhotos: true);
      expect(result.photoListingFailures, 2);
      final warning = result.payload.warnings.singleWhere(
        (w) => w.code == ImportWarningCode.photoListingsUnavailable,
      );
      expect(warning.count, 2);
    });

    test('photos are not requested when not asked', () async {
      final result = await service([
        diveJson(1),
      ], forbidPictures: true).fetchLogbook(includePhotos: false);
      expect(result.photoCount, 0);
      expect(result.photoListingFailures, 0);
    });
  });

  test('a /dives failure is fatal', () async {
    final failing = DivelogsImportService(
      api: DivelogsApiClient(
        getBearerToken: () async => 't',
        onTokenRejected: () {},
        httpClient: MockClient((_) async => http.Response('down', 503)),
      ),
    );
    await expectLater(
      failing.fetchLogbook(includePhotos: false),
      throwsA(isA<DivelogsApiException>()),
    );
  });

  test('remotePhotoFileName only keeps image or video names', () {
    String nameFor(String url, {int index = 0}) => remotePhotoFileName(
      DivelogsPicture(id: '9', url: Uri.parse(url)),
      remoteDiveId: '1',
      index: index,
    );
    expect(nameFor('https://x.de/pic.php?id=9'), 'divelogs-1-1.jpg');
    expect(nameFor('https://x.de/clip.MOV'), 'clip.MOV');
    expect(nameFor('https://x.de/clip.webm'), 'clip.webm');
    expect(nameFor('https://x.de/clip.mkv'), 'clip.mkv');
    expect(nameFor('https://x.de/clip.avi'), 'clip.avi');
    expect(nameFor('https://x.de/a%3Ab%3F.jpg'), 'a_b_.jpg');
    expect(nameFor('https://x.de/.jpg'), 'divelogs-1-1.jpg');
  });

  test('remotePhotoFileName keeps a hostile dive id inside the folder', () {
    final name = remotePhotoFileName(
      DivelogsPicture(id: '9', url: Uri.parse('https://x.de/get?id=9')),
      remoteDiveId: '../a/b\\c',
      index: 0,
    );
    expect(name, isNot(contains('/')));
    expect(name, isNot(contains('\\')));
    expect(name, 'divelogs-.._a_b_c-1.jpg');
  });

  test('remotePhotoFileName falls back when the url has no file name', () {
    expect(
      remotePhotoFileName(
        DivelogsPicture(id: '9', url: Uri.parse('https://x.de/a/b/pic.JPG')),
        remoteDiveId: '1',
        index: 0,
      ),
      'pic.JPG',
    );
    expect(
      remotePhotoFileName(
        DivelogsPicture(id: '9', url: Uri.parse('https://x.de/get?id=9')),
        remoteDiveId: '1',
        index: 3,
      ),
      'divelogs-1-4.jpg',
    );
  });

  test('fuzzy date/time match flags the pulled dive as duplicate', () async {
    final existingDive = Dive(
      id: 'existing-1',
      dateTime: DateTime.utc(2022, 9, 3, 14, 42),
      entryTime: DateTime.utc(2022, 9, 3, 14, 42),
      runtime: const Duration(seconds: 2808),
      maxDepth: 12,
    );
    final payload = await payloadOf(
      service([diveJson(1), diveJson(2, date: '2023-05-05')]),
    );

    final result = const ImportDuplicateChecker().check(
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
    );
    final match = result.diveMatches[0];
    expect(match, isNotNull);
    expect(match!.diveId, 'existing-1');
    expect(match.score, greaterThanOrEqualTo(0.7));
    expect(match.matchedExistingSource, isFalse);
    expect(result.diveMatches[1], isNull);
  });

  test('a lost session is not mistaken for a missing gear list', () async {
    final lost = DivelogsImportService(
      api: DivelogsApiClient(
        getBearerToken: () async => 't',
        onTokenRejected: () {},
        httpClient: MockClient((req) async {
          if (req.url.path == '/api/dives') {
            return http.Response(jsonEncode([diveJson(1)]), 200);
          }
          return http.Response('', 401);
        }),
      ),
    );
    await expectLater(
      lost.fetchLogbook(includePhotos: true),
      throwsA(isA<DivelogsUnauthorizedException>()),
    );
  });
}
