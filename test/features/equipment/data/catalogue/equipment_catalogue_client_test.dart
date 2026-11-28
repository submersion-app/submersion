import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/equipment/data/catalogue/equipment_catalogue_client.dart';

void main() {
  test('the release asset URL', () {
    expect(
      kEquipmentCatalogueUrl,
      'https://github.com/submersion-app/equipment-catalogue/releases/latest/'
      'download/equipment-catalogue.json',
    );
  });

  test('returns the body on 200, read as UTF-8', () async {
    final client = EquipmentCatalogueClient(
      client: MockClient(
        (_) async => http.Response.bytes(utf8.encode('{"m":"Ü"}'), 200),
      ),
    );
    expect(await client.fetch(), '{"m":"Ü"}');
  });

  test('returns null on 404: nothing is published yet', () async {
    final client = EquipmentCatalogueClient(
      client: MockClient((_) async => http.Response('', 404)),
    );
    expect(await client.fetch(), isNull);
  });

  test('throws on 500', () {
    final client = EquipmentCatalogueClient(
      client: MockClient((_) async => http.Response('', 500)),
    );
    expect(client.fetch(), throwsA(isA<EquipmentCatalogueFetchException>()));
  });

  test('throws on a network failure', () {
    final client = EquipmentCatalogueClient(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(client.fetch(), throwsA(isA<EquipmentCatalogueFetchException>()));
  });

  test('throws on timeout', () {
    final client = EquipmentCatalogueClient(
      client: MockClient((_) => Completer<http.Response>().future),
      timeout: const Duration(milliseconds: 10),
    );
    expect(client.fetch(), throwsA(isA<EquipmentCatalogueFetchException>()));
  });

  test('sends a plain GET with no query parameters', () async {
    late http.Request seen;
    final client = EquipmentCatalogueClient(
      client: MockClient((request) async {
        seen = request;
        return http.Response('{}', 200);
      }),
    );
    await client.fetch();
    expect(seen.method, 'GET');
    expect(seen.url.query, isEmpty);
    expect(seen.url.toString(), kEquipmentCatalogueUrl);
  });
}
