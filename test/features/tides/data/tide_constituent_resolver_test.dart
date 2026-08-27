import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/tide/entities/tide_constituent.dart';
import 'package:submersion/core/tide/tide_calculator.dart';
import 'package:submersion/features/tides/data/repositories/noaa_station_cache_repository.dart';
import 'package:submersion/features/tides/data/services/noaa_station_index.dart';
import 'package:submersion/features/tides/data/services/noaa_station_service.dart';
import 'package:submersion/features/tides/data/services/tide_constituent_resolver.dart';
import 'package:submersion/features/tides/data/services/tide_data_service.dart';

const _harconBody = '''
{"HarmonicConstituents":[
  {"name":"M2","amplitude":0.576,"phase_GMT":208.2},
  {"name":"S2","amplitude":0.137,"phase_GMT":216.2},
  {"name":"K1","amplitude":0.37,"phase_GMT":225.4},
  {"name":"O1","amplitude":0.23,"phase_GMT":208.4}
]}''';

const _datumsBody =
    '{"datums":[{"name":"MSL","value":2.773},{"name":"MLLW","value":1.822}]}';

/// FES stand-in returning a fixed calculator for any location.
class _FakeFesService extends TideDataService {
  final TideCalculator? calculator;
  _FakeFesService(this.calculator);

  @override
  Future<TideCalculator?> getCalculatorForLocation(
    double latitude,
    double longitude,
  ) async => calculator;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final index = NoaaStationIndex.fromJsonString(
    '[["9414290","San Francisco",37.8063,-122.4659]]',
  );
  final fesCalculator = TideCalculator(
    constituents: {
      'M2': const TideConstituent(name: 'M2', amplitude: 0.5, phase: 100.0),
    },
  );

  late LocalCacheDatabase db;
  late NoaaStationCacheRepository cache;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    cache = NoaaStationCacheRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  TideConstituentResolver resolver({
    NoaaStationIndex? idx,
    required http.Client client,
    TideCalculator? fes,
    DateTime Function()? now,
  }) {
    return TideConstituentResolver(
      stationIndex: idx,
      stationService: NoaaStationService(client: client),
      cache: cache,
      fesService: _FakeFesService(fes),
      now: now,
    );
  }

  test(
    'station in range: fetches, caches, returns station provenance',
    () async {
      var harconCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('harcon.json')) {
          harconCalls++;
          return http.Response(_harconBody, 200);
        }
        return http.Response(_datumsBody, 200);
      });
      final r = resolver(idx: index, client: client, fes: fesCalculator);

      // Point ~5 km from the SF station.
      final resolved = await r.resolve(37.83, -122.42);
      expect(resolved, isNotNull);
      expect(resolved!.source.kind, TideDataSourceKind.noaaStation);
      expect(resolved.source.stationId, '9414290');
      expect(resolved.source.mllwDatum, true);
      expect(resolved.calculator.z0, closeTo(0.951, 1e-9));
      expect(resolved.calculator.constituents.containsKey('M2'), true);

      // Second resolve hits the cache, not the network.
      await r.resolve(37.83, -122.42);
      expect(harconCalls, 1);
    },
  );

  test('no station in range falls back to FES with model provenance', () async {
    final client = MockClient((request) async => http.Response('x', 500));
    final r = resolver(idx: index, client: client, fes: fesCalculator);

    final resolved = await r.resolve(-17.5, 177.5); // Fiji: no NOAA station
    expect(resolved, isNotNull);
    expect(resolved!.source.kind, TideDataSourceKind.fesModel);
    expect(resolved.calculator.z0, 0.0);
  });

  test(
    'transient fetch failure falls back to FES and caches nothing',
    () async {
      final client = MockClient(
        (request) async => throw http.ClientException('offline'),
      );
      final r = resolver(idx: index, client: client, fes: fesCalculator);

      final resolved = await r.resolve(37.83, -122.42);
      expect(resolved!.source.kind, TideDataSourceKind.fesModel);
      expect(await cache.read('9414290'), isNull);
    },
  );

  test('unavailable station is cached and skipped thereafter', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('nope', 404);
    });
    final r = resolver(idx: index, client: client, fes: fesCalculator);

    final first = await r.resolve(37.83, -122.42);
    expect(first!.source.kind, TideDataSourceKind.fesModel);
    expect(
      (await cache.read('9414290'))!.status,
      NoaaStationCacheStatus.unavailable,
    );

    await r.resolve(37.83, -122.42);
    expect(calls, 1);
  });

  test('stale ok row triggers refetch but survives fetch failure', () async {
    // Seed a 2-year-old ok row.
    await cache.write(
      stationId: '9414290',
      name: 'San Francisco',
      latitude: 37.8063,
      longitude: -122.4659,
      constituents: {
        'M2': const TideConstituent(name: 'M2', amplitude: 0.5, phase: 208.2),
      },
      datumOffsetMllw: 0.9,
      status: NoaaStationCacheStatus.ok,
    );
    final client = MockClient(
      (request) async => throw http.ClientException('offline'),
    );
    final r = resolver(
      idx: index,
      client: client,
      fes: fesCalculator,
      now: () => DateTime.now().toUtc().add(const Duration(days: 800)),
    );

    final resolved = await r.resolve(37.83, -122.42);
    // Stale data beats no data: still station-tier.
    expect(resolved!.source.kind, TideDataSourceKind.noaaStation);
  });

  test('returns null when neither station nor FES has data', () async {
    final client = MockClient((request) async => http.Response('x', 500));
    final r = resolver(idx: index, client: client, fes: null);
    expect(await r.resolve(-17.5, 177.5), isNull);
  });
}
