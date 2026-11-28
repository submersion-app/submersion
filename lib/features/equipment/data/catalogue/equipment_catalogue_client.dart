import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// The latest equipment catalogue release's asset (issue #5118). GitHub's
/// release download sends no CORS header, which is one reason the web build
/// never fetches it.
const String kEquipmentCatalogueUrl =
    'https://github.com/submersion-app/equipment-catalogue/releases/latest/'
    'download/equipment-catalogue.json';

/// A download that did not give a catalogue body: a network failure, a
/// timeout or an HTTP status other than 200 and 404.
class EquipmentCatalogueFetchException implements Exception {
  const EquipmentCatalogueFetchException(this.detail);

  final String detail;

  @override
  String toString() => 'EquipmentCatalogueFetchException: $detail';
}

/// Downloads the latest catalogue release: a plain GET with no query
/// parameters and nothing about the diver, their gear or their device.
class EquipmentCatalogueClient {
  EquipmentCatalogueClient({
    http.Client? client,
    Uri? url,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _url = url ?? Uri.parse(kEquipmentCatalogueUrl);

  final http.Client _client;
  final Uri _url;
  final Duration timeout;

  /// The body, or null when nothing is published (HTTP 404).
  Future<String?> fetch() async {
    final http.Response response;
    try {
      response = await _client.get(_url).timeout(timeout);
    } on TimeoutException {
      throw const EquipmentCatalogueFetchException('timeout');
    } on Exception catch (e) {
      throw EquipmentCatalogueFetchException('$e');
    }
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw EquipmentCatalogueFetchException('HTTP ${response.statusCode}');
    }
    // Always UTF-8: release assets come with no charset, and
    // `response.body` would then read them as Latin-1.
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }
}
