import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_draft_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/draft_conditions_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';

import '../../../../helpers/test_database.dart';

/// Open-Meteo, online or not.
class _Weather extends Fake implements WeatherService {
  bool online = true;
  final asked = <({double latitude, double longitude, DateTime entry})>[];

  @override
  Future<WeatherData?> fetchWeather({
    required double latitude,
    required double longitude,
    required DateTime date,
    required DateTime entryTime,
  }) async {
    asked.add((latitude: latitude, longitude: longitude, entry: entryTime));
    if (!online) return null;
    return const WeatherData(windSpeed: 4.5, airTemp: 24, humidity: 70);
  }
}

/// Weather and tide for a draft from where it went in (issue #637), filling
/// only what is empty; offline, the next app open tries again.
void main() {
  late DiveRepository dives;
  late DiveDraftRepository drafts;
  late _Weather weather;
  late List<({String diveId, GeoPoint at, DateTime entry})> tides;
  final now = DateTime.utc(2026, 7, 17, 12);
  const position = GeoPoint(-8.27, 115.59);

  DraftConditionsService service() => DraftConditionsService(
    dives: dives,
    drafts: drafts,
    weather: weather,
    recordTide: (dive, at) async =>
        tides.add((diveId: dive.id, at: at, entry: dive.entryTime!)),
    hasTide: (diveId) async => tides.any((t) => t.diveId == diveId),
    clock: () => now,
  );

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
    dives = DiveRepository();
    drafts = DiveDraftRepository(dives: dives);
    weather = _Weather();
    tides = [];
  });
  tearDown(tearDownTestDatabase);

  Future<String> surfaced({GeoPoint? at = position}) async {
    final draft = await drafts.createDraft(
      diverId: 'd1',
      entryTime: DateTime.utc(2026, 7, 17, 10),
      entryLocation: at,
    );
    await drafts.closeDraft(
      draft.id,
      exitTime: DateTime.utc(2026, 7, 17, 10, 45),
    );
    return draft.id;
  }

  test('fills weather and tide from the entry position and time', () async {
    final id = await surfaced();

    await service().fillPending(diverId: 'd1');

    final dive = (await dives.getDiveById(id))!;
    expect(dive.windSpeed, 4.5);
    expect(dive.airTemp, 24);
    expect(dive.weatherSource, WeatherSource.openMeteo);
    expect(weather.asked.single.latitude, position.latitude);
    expect(weather.asked.single.entry, DateTime.utc(2026, 7, 17, 10));
    expect(tides.single.diveId, id);
    expect(tides.single.at, position);
  });

  test('keeps an air temperature the diver typed', () async {
    final id = await surfaced();
    final typed = (await dives.getDiveById(id))!.copyWith(airTemp: 28);
    await dives.updateDive(typed);

    await service().fillPending(diverId: 'd1');

    final dive = (await dives.getDiveById(id))!;
    expect(dive.airTemp, 28);
    expect(dive.windSpeed, 4.5);
  });

  test('skips a draft with no position', () async {
    await surfaced(at: null);

    await service().fillPending(diverId: 'd1');

    expect(weather.asked, isEmpty);
    expect(tides, isEmpty);
  });

  test('skips a draft still in the water', () async {
    await drafts.createDraft(
      diverId: 'd1',
      entryTime: DateTime.utc(2026, 7, 17, 10),
      entryLocation: position,
    );

    await service().fillPending(diverId: 'd1');

    expect(weather.asked, isEmpty);
  });

  test('offline, it tries once, then again at the next app open', () async {
    final id = await surfaced();
    weather.online = false;
    final first = service();

    await first.fillPending(diverId: 'd1');
    await first.fillPending(diverId: 'd1');
    expect(weather.asked, hasLength(1));
    expect((await dives.getDiveById(id))!.weatherSource, isNull);

    weather.online = true;
    await service().fillPending(diverId: 'd1');

    expect(
      (await dives.getDiveById(id))!.weatherSource,
      WeatherSource.openMeteo,
    );
  });

  test('a filled draft is not asked about again', () async {
    await surfaced();
    await service().fillPending(diverId: 'd1');

    await service().fillPending(diverId: 'd1');

    expect(weather.asked, hasLength(1));
    expect(tides, hasLength(1));
  });
}
