import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/divelogs/divelogs_models.dart';

void main() {
  Map<String, dynamic> minimal() => {
    'id': 4711,
    'date': '2022-09-03',
    'time': '14:42:00',
    'duration': 2808,
    'maxdepth': 12,
  };

  test('parses mandatory fields', () {
    final dive = DivelogsDive.fromJson(minimal());
    expect(dive.id, '4711');
    expect(dive.dateTime, DateTime.utc(2022, 9, 3, 14, 42));
    expect(dive.durationSeconds, 2808);
    expect(dive.maxDepth, 12.0);
    expect(dive.samples, isEmpty);
    expect(dive.tanks, isEmpty);
  });

  test('throws FormatException when a mandatory field is missing', () {
    final json = minimal()..remove('maxdepth');
    expect(() => DivelogsDive.fromJson(json), throwsFormatException);
  });

  test('parses mixed sampledata (bare depths and {d,t} objects)', () {
    final dive = DivelogsDive.fromJson({
      ...minimal(),
      'samplerate': 10,
      'sampledata': [
        {'d': 1, 't': 13},
        10,
        {'d': 17, 't': 12},
        0,
      ],
    });
    expect(dive.sampleRateSeconds, 10);
    expect(dive.samples, hasLength(4));
    expect(dive.samples[0].depth, 1.0);
    expect(dive.samples[0].temperature, 13.0);
    expect(dive.samples[1].depth, 10.0);
    expect(dive.samples[1].temperature, isNull);
  });

  test('parses tanks', () {
    final dive = DivelogsDive.fromJson({
      ...minimal(),
      'tanks': [
        {
          'o2': 28,
          'he': 0,
          'start_pressure': 214.56,
          'end_pressure': 103,
          'vol': 12,
          'wp': 200,
          'dbltank': false,
          'tankname': 'Main',
        },
      ],
    });
    expect(dive.tanks, hasLength(1));
    final tank = dive.tanks.single;
    expect(tank.o2, 28.0);
    expect(tank.startPressure, 214.56);
    expect(tank.endPressure, 103.0);
    expect(tank.volume, 12.0);
    expect(tank.workingPressure, 200.0);
    expect(tank.name, 'Main');
  });

  test('parses optional metadata fields', () {
    final dive = DivelogsDive.fromJson({
      ...minimal(),
      'meandepth': 7.9,
      'buddy': 'Buddy',
      'divesite': 'Shinenead',
      'location': 'Aegypten, Rotes Meer',
      'lat': 24.669683,
      'lng': 35.125225,
      'notes': 'nice dive',
      'weather': 'sunny',
      'visibility': 'good',
      'airtemp': 28,
      'depthtemp': 21,
      'surfacetemp': 26,
      'weights': 4,
      'surface_interval': 3600,
      'dc_model': 'Suunto D6',
    });
    expect(dive.meanDepth, 7.9);
    expect(dive.buddy, 'Buddy');
    expect(dive.siteName, 'Shinenead');
    expect(dive.latitude, closeTo(24.669683, 1e-9));
    expect(dive.depthTemp, 21.0);
    expect(dive.weightsKg, 4.0);
    expect(dive.surfaceIntervalSeconds, 3600);
    expect(dive.dcModel, 'Suunto D6');
  });

  group('DivelogsGearItem', () {
    test('parses fields with wall-clock UTC dates', () {
      final gear = DivelogsGearItem.fromJson({
        'id': 45,
        'name': 'Apex XTX50',
        'geartype': 1,
        'purchasedate': '2007-05-12',
        'last_servicedate': '2024-01-02',
        'discarddate': null,
      })!;
      expect(gear.id, '45');
      expect(gear.name, 'Apex XTX50');
      expect(gear.geartypeId, 1);
      expect(gear.purchaseDate, DateTime.utc(2007, 5, 12));
      expect(gear.lastServiceDate, DateTime.utc(2024, 1, 2));
      expect(gear.discardDate, isNull);
    });

    test('returns null without id or name', () {
      expect(DivelogsGearItem.fromJson({'name': 'X'}), isNull);
      expect(DivelogsGearItem.fromJson({'id': 1}), isNull);
    });
  });

  group('DivelogsCertification', () {
    test('parses fields', () {
      final cert = DivelogsCertification.fromJson({
        'id': 123,
        'name': 'Open Water Diver',
        'date': '2022-06-15',
        'org': 'PADI',
      })!;
      expect(cert.id, '123');
      expect(cert.name, 'Open Water Diver');
      expect(cert.date, DateTime.utc(2022, 6, 15));
      expect(cert.org, 'PADI');
    });

    test('returns null without a name', () {
      expect(DivelogsCertification.fromJson({'id': 1}), isNull);
    });
  });

  group('DivelogsPicture', () {
    test('picks the first absolute http(s) url from known keys', () {
      final pic = DivelogsPicture.fromJson({
        'id': 5,
        'url': 'https://divelogs.de/pics/5.jpg',
      })!;
      expect(pic.id, '5');
      expect(pic.url, Uri.parse('https://divelogs.de/pics/5.jpg'));
    });

    test('falls back through link/href/imageurl', () {
      final pic = DivelogsPicture.fromJson({
        'id': 6,
        'link': 'http://divelogs.de/pics/6.jpg',
      })!;
      expect(pic.url, Uri.parse('http://divelogs.de/pics/6.jpg'));
    });

    test('keeps the row but null url for a bare filename', () {
      final pic = DivelogsPicture.fromJson({'id': 7, 'url': '7.jpg'})!;
      expect(pic.id, '7');
      expect(pic.url, isNull);
    });

    test('returns null when neither id nor any url key is present', () {
      expect(DivelogsPicture.fromJson({'foo': 'bar'}), isNull);
    });

    test('reads the absolute path divelogs.de sends', () {
      final pic = DivelogsPicture.fromJson({
        'id': '8',
        'path': 'https://www.divelogs.de/pictures/u/4711-1.jpg',
      })!;
      expect(pic.id, '8');
      expect(
        pic.url,
        Uri.parse('https://www.divelogs.de/pictures/u/4711-1.jpg'),
      );
    });

    test('resolves a site-relative path against base', () {
      final pic = DivelogsPicture.fromJson({
        'id': 9,
        'path': '/pictures/u/4711-1.jpg',
      }, base: Uri.parse('https://divelogs.de/api'))!;
      expect(pic.url, Uri.parse('https://divelogs.de/pictures/u/4711-1.jpg'));
    });

    test('resolves neither a relative path without base nor a bare name', () {
      final base = Uri.parse('https://divelogs.de/api');
      expect(
        DivelogsPicture.fromJson({'id': 9, 'path': '/pictures/u/1.jpg'})!.url,
        isNull,
      );
      expect(
        DivelogsPicture.fromJson({'id': 9, 'path': '1.jpg'}, base: base)!.url,
        isNull,
      );
    });

    test('drops a protocol-relative path rather than resolving it', () {
      final pic = DivelogsPicture.fromJson({
        'id': 9,
        'path': '//elsewhere.example/1.jpg',
      }, base: Uri.parse('https://divelogs.de/api'))!;
      expect(pic.url, isNull);
    });
  });

  group('DivelogsPicture link checks', () {
    test('drops an http(s) link without a host', () {
      for (final path in ['https:/pictures/u/1.jpg', 'http:foo']) {
        final pic = DivelogsPicture.fromJson({'id': 1, 'path': path})!;
        expect(pic.url, isNull, reason: path);
      }
    });

    test('a blank path is no picture, like a blank id', () {
      expect(DivelogsPicture.fromJson({'path': ''}), isNull);
      expect(DivelogsPicture.fromJson({'path': '  ', 'id': ''}), isNull);
    });
  });

  group('DivelogsPicture.listFromJson', () {
    final base = Uri.parse('https://divelogs.de/api');
    Map<String, Object> row(int id) => {
      'id': id,
      'path': 'https://divelogs.de/pictures/u/$id.jpg',
    };

    test('null lists no pictures', () {
      expect(DivelogsPicture.listFromJson(null), isEmpty);
    });

    test('reads an array, a wrapper and a PHP object', () {
      for (final raw in [
        [row(1), row(2)],
        {
          'pictures': [row(1), row(2)],
        },
        {'4': row(1), '7': row(2)},
      ]) {
        final pics = DivelogsPicture.listFromJson(raw, base: base)!;
        expect(pics.map((p) => p.id), ['1', '2'], reason: '$raw');
      }
    });

    test('keeps a row that is not an object as a picture without a link', () {
      final pics = DivelogsPicture.listFromJson([row(1), 'junk'])!;
      expect(pics, hasLength(2));
      expect(pics.last.url, isNull);
    });

    test('returns null for a value of no known shape', () {
      expect(DivelogsPicture.listFromJson('junk'), isNull);
      expect(DivelogsPicture.listFromJson(42), isNull);
    });
  });

  test('DivelogsDive knows whether /dives listed its pictures', () {
    Map<String, dynamic> dive() => {
      'date': '2022-09-03',
      'time': '14:42:00',
      'duration': 2808,
      'maxdepth': 12,
    };
    expect(DivelogsDive.fromJson(dive()).picturesListed, isFalse);
    expect(
      DivelogsDive.fromJson(dive()..['pictures'] = null).picturesListed,
      isTrue,
    );
    expect(
      DivelogsDive.fromJson(dive()..['pictures'] = 'junk').picturesListed,
      isFalse,
    );
  });

  test('DivelogsDive parses inline pictures', () {
    final dive = DivelogsDive.fromJson({
      'id': 4711,
      'date': '2022-09-03',
      'time': '14:42:00',
      'duration': 2808,
      'maxdepth': 12,
      'pictures': [
        {'id': '1', 'path': 'https://www.divelogs.de/pictures/u/4711-1.jpg'},
        {'id': '2', 'path': '/pictures/u/4711-2.jpg'},
        'junk',
      ],
    }, pictureBase: Uri.parse('https://divelogs.de/api'));
    // The junk row stays, as a picture without a link, so it is counted.
    expect(dive.pictures.map((p) => p.id), ['1', '2', null]);
    expect(dive.pictures.map((p) => p.url), [
      Uri.parse('https://www.divelogs.de/pictures/u/4711-1.jpg'),
      Uri.parse('https://divelogs.de/pictures/u/4711-2.jpg'),
      null,
    ]);
  });

  test('DivelogsDive without pictures has none', () {
    final dive = DivelogsDive.fromJson({
      'date': '2022-09-03',
      'time': '14:42:00',
      'duration': 2808,
      'maxdepth': 12,
      'pictures': null,
    });
    expect(dive.pictures, isEmpty);
  });

  test('DivelogsDive parses gearitems as string ids', () {
    final dive = DivelogsDive.fromJson({
      'id': 1,
      'date': '2022-09-03',
      'time': '10:00:00',
      'duration': 60,
      'maxdepth': 5,
      'gearitems': [45, 62],
    });
    expect(dive.gearItemIds, ['45', '62']);
  });

  test('a dive without a time is unreadable, not moved to midnight', () {
    expect(
      () => DivelogsDive.fromJson({
        'id': 1,
        'date': '2022-09-03',
        'duration': 2808,
        'maxdepth': 12,
      }),
      throwsFormatException,
    );
  });

  group('blank remote ids are treated as absent', () {
    Map<String, dynamic> dive(Object id) => {
      'id': id,
      'date': '2022-09-03',
      'time': '14:42:00',
      'duration': 2808,
      'maxdepth': 12,
    };

    test('a dive keeps no id, so no shared source id is made', () {
      expect(DivelogsDive.fromJson(dive('')).id, isNull);
      expect(DivelogsDive.fromJson(dive('  ')).id, isNull);
      expect(DivelogsDive.fromJson(dive(4711)).id, '4711');
      expect(DivelogsDive.fromJson(dive(' 12 ')).id, '12');
    });

    test('a gear row without a real id is unusable', () {
      expect(DivelogsGearItem.fromJson({'id': '', 'name': 'Reg'}), isNull);
      expect(DivelogsGearItem.fromJson({'id': 45, 'name': 'Reg'})!.id, '45');
    });

    test('a certification falls back to having no id', () {
      expect(
        DivelogsCertification.fromJson({'id': ' ', 'name': 'Open Water'})!.id,
        isNull,
      );
    });

    test('a picture with only a blank id and no link is not a row', () {
      expect(DivelogsPicture.fromJson({'id': ''}), isNull);
    });
  });
}
