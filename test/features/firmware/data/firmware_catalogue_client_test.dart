import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/firmware/data/firmware_catalogue_client.dart';

/// Fetching the published firmware catalogue (issue #5104). A plain GET of a
/// public file; anything but a good format 1 file is a quiet failure.
void main() {
  late String sample;
  final url = Uri.parse('https://example.com/firmware-catalogue.json');

  setUpAll(() {
    sample = File(
      p.join('test', 'fixtures', 'firmware_catalogue', 'sample.json'),
    ).readAsStringSync();
  });

  FirmwareCatalogueClient client(
    Future<http.Response> Function(http.Request) handler, {
    Duration timeout = const Duration(seconds: 20),
  }) => FirmwareCatalogueClient(
    client: MockClient(handler),
    url: url,
    timeout: timeout,
  );

  test('the default address is the latest release asset', () {
    expect(
      kFirmwareCatalogueUrl,
      'https://github.com/submersion-app/firmware-catalogue/releases/latest/download/firmware-catalogue.json',
    );
  });

  test('a good file is fetched, with nothing added to the request', () async {
    http.Request? seen;
    final result = await client((request) async {
      seen = request;
      return http.Response(sample, 200);
    }).fetch();

    expect(result, isA<FirmwareFetched>());
    result as FirmwareFetched;
    expect(result.catalogue.models, hasLength(2));
    expect(result.raw, sample);
    expect(seen!.method, 'GET');
    expect(seen!.url, url);
    expect(seen!.url.query, isEmpty);
  });

  test('a missing release is not published yet', () async {
    final result = await client(
      (_) async => http.Response('Not Found', 404),
    ).fetch();
    expect(result, isA<FirmwareNotPublished>());
  });

  test('server errors, bad files and timeouts fail quietly', () async {
    for (final response in [
      http.Response('oops', 500),
      http.Response('not json', 200),
      http.Response('{"format":2,"models":[]}', 200),
    ]) {
      expect(
        await client((_) async => response).fetch(),
        isA<FirmwareFetchFailed>(),
      );
    }

    expect(
      await client(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 10),
      ).fetch(),
      isA<FirmwareFetchFailed>(),
    );

    expect(
      await client((_) async => throw const SocketException('offline')).fetch(),
      isA<FirmwareFetchFailed>(),
    );
  });
}
