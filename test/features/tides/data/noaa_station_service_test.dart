import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/tides/data/services/noaa_station_service.dart';

const _harconBody = '''
{"HarmonicConstituents":[
  {"name":"M2","amplitude":0.576,"phase_GMT":208.2,"speed":28.984104},
  {"name":"K1","amplitude":0.37,"phase_GMT":225.4,"speed":15.041069},
  {"name":"LAM2","amplitude":0.007,"phase_GMT":214.3,"speed":29.455625},
  {"name":"RHO","amplitude":0.009,"phase_GMT":200.0,"speed":13.471515},
  {"name":"MK3","amplitude":0.018,"phase_GMT":100.0,"speed":44.025173},
  {"name":"ZERO","amplitude":0.0,"phase_GMT":10.0,"speed":1.0}
]}''';

const _datumsBody = '''
{"datums":[
  {"name":"MHHW","value":2.949},
  {"name":"MSL","value":2.773},
  {"name":"MLLW","value":1.822}
]}''';

void main() {
  test('parses constituents, maps NOAA names, computes MLLW offset', () async {
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add(request.url.path);
      if (request.url.path.endsWith('harcon.json')) {
        expect(request.url.queryParameters['units'], 'metric');
        return http.Response(_harconBody, 200);
      }
      if (request.url.path.endsWith('datums.json')) {
        return http.Response(_datumsBody, 200);
      }
      return http.Response('not found', 404);
    });

    final result = await NoaaStationService(
      client: client,
    ).fetchStation('9414290');

    expect(result.status, NoaaFetchStatus.ok);
    final data = result.data!;
    // Identity names kept, NOAA aliases mapped, unknown (MK3) and
    // zero-amplitude entries skipped.
    expect(data.constituents.keys.toSet(), {'M2', 'K1', 'La2', 'Rho1'});
    expect(data.constituents['La2']!.amplitude, 0.007);
    expect(data.constituents['Rho1']!.phase, 200.0);
    expect(data.datumOffsetMllw, closeTo(0.951, 1e-9));
    expect(requested.first, contains('/stations/9414290/'));
  });

  test('missing datums yields null offset but still ok', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('harcon.json')) {
        return http.Response(_harconBody, 200);
      }
      return http.Response('{}', 200);
    });
    final result = await NoaaStationService(
      client: client,
    ).fetchStation('9414290');
    expect(result.status, NoaaFetchStatus.ok);
    expect(result.data!.datumOffsetMllw, isNull);
  });

  test('empty constituent list is deterministic unavailable', () async {
    final client = MockClient(
      (request) async => http.Response('{"HarmonicConstituents":[]}', 200),
    );
    final result = await NoaaStationService(
      client: client,
    ).fetchStation('1111111');
    expect(result.status, NoaaFetchStatus.unavailable);
  });

  test('404 is deterministic unavailable', () async {
    final client = MockClient((request) async => http.Response('nope', 404));
    final result = await NoaaStationService(
      client: client,
    ).fetchStation('1111111');
    expect(result.status, NoaaFetchStatus.unavailable);
  });

  test('network error is transient failure, not unavailable', () async {
    final client = MockClient(
      (request) async => throw http.ClientException('boom'),
    );
    final result = await NoaaStationService(
      client: client,
    ).fetchStation('9414290');
    expect(result.status, NoaaFetchStatus.failed);
    expect(result.data, isNull);
  });

  test('malformed payload is deterministic unavailable', () async {
    final client = MockClient(
      (request) async =>
          http.Response('{"HarmonicConstituents":"garbage"}', 200),
    );
    final result = await NoaaStationService(
      client: client,
    ).fetchStation('9414290');
    expect(result.status, NoaaFetchStatus.unavailable);
  });
}
