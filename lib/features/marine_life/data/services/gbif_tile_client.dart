import 'package:flutter_map/flutter_map.dart' show TileProvider;
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

/// The HTTP client behind the species map's GBIF occurrence tiles
/// (issue #4358).
///
/// GBIF answers a tile with no records with 204 and an empty body, and
/// flutter_map reads any empty non-200 answer as a failed tile. Most of the
/// world is empty for any one species, so passed on as it is, nearly every
/// view would say the records did not load. This client hands such a tile on
/// as a 200 carrying flutter_map's own transparent tile, keeping GBIF's
/// caching headers, so it is drawn (as nothing) and cached like any other.
///
/// It also retries a busy answer (503), as the client flutter_map builds for
/// itself does, so a momentary GBIF hiccup is not reported as a failure.
class GbifTileClient extends http.BaseClient {
  /// GBIF's "no records in this tile". A literal rather than dart:io's
  /// HttpStatus, which the web build cannot import.
  static const int _noContent = 204;

  final http.Client _inner;

  GbifTileClient(http.Client inner) : _inner = RetryClient(inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (response.statusCode != _noContent) return response;
    await response.stream.drain<void>();
    final empty = TileProvider.transparentImage;
    return http.StreamedResponse(
      Stream.value(empty),
      200,
      contentLength: empty.length,
      request: response.request,
      headers: {
        for (final header in response.headers.entries)
          if (header.key.toLowerCase() != 'content-length')
            header.key: header.value,
      },
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: 'OK',
    );
  }

  /// Closes the client it wraps.
  @override
  void close() => _inner.close();
}
