import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/marine_life/data/services/gbif_tile_client.dart';

/// GBIF's answer for a tile with no records: 204 and no body.
MockClient _noRecords() => MockClient(
  (request) async => http.Response.bytes(const [], 204, request: request),
);

/// Loads one tile through flutter_map's own network provider, as the public
/// layer does, and returns the error it reported, or null when it drew.
Future<Object?> _loadTile(http.Client client, String path) async {
  final provider = NetworkTileProvider(
    httpClient: client,
    silenceExceptions: false,
    cachingProvider: const DisabledMapCachingProvider(),
  );
  final image = provider.getImageWithCancelLoadingSupport(
    const TileCoordinates(1, 1, 1),
    TileLayer(
      urlTemplate: 'https://tiles.test/$path/{z}/{x}/{y}.png',
      userAgentPackageName: 'app.submersion',
    ),
    Completer<void>().future,
  );
  final done = Completer<Object?>();
  final stream = image.resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener(
    (info, _) {
      info.dispose();
      if (!done.isCompleted) done.complete(null);
    },
    onError: (error, _) {
      if (!done.isCompleted) done.complete(error);
    },
  );
  stream.addListener(listener);
  final error = await done.future;
  stream.removeListener(listener);
  return error;
}

class _ClosingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnimplementedError();

  @override
  void close() => closed = true;
}

void main() {
  group('a tile with no records', () {
    testWidgets('fails the tile layer when the client passes the 204 on', (
      tester,
    ) async {
      // Why the wrapper exists: flutter_map reads an empty non-200 answer as
      // a failed tile.
      final error = await tester.runAsync(
        () => _loadTile(_noRecords(), 'plain'),
      );

      expect(error, isNotNull);
    });

    testWidgets('reaches the tile layer as an empty tile, not a failure', (
      tester,
    ) async {
      final error = await tester.runAsync(
        () => _loadTile(GbifTileClient(_noRecords()), 'wrapped'),
      );

      expect(error, isNull);
    });

    test('comes back as a 200 holding the transparent tile', () async {
      final response = await GbifTileClient(
        _noRecords(),
      ).get(Uri.parse('https://tiles.test/1/1/1.png'));

      expect(response.statusCode, 200);
      expect(response.bodyBytes, TileProvider.transparentImage);
    });
  });

  test('every other answer passes through untouched', () async {
    final client = GbifTileClient(
      MockClient((request) async {
        final failing = request.url.path.contains('fail');
        return http.Response.bytes(
          failing ? const [] : const [1, 2, 3],
          failing ? 500 : 200,
          request: request,
        );
      }),
    );

    final drawn = await client.get(Uri.parse('https://tiles.test/1/0/0.png'));
    final failed = await client.get(Uri.parse('https://tiles.test/fail.png'));

    expect(drawn.statusCode, 200);
    expect(drawn.bodyBytes, const [1, 2, 3]);
    expect(failed.statusCode, 500);
  });

  test('a busy answer (503) is asked again, as flutter_map does', () async {
    var calls = 0;
    final client = GbifTileClient(
      MockClient((request) async {
        calls++;
        return http.Response.bytes(
          calls == 1 ? const [] : const [1],
          calls == 1 ? 503 : 200,
          request: request,
        );
      }),
    );

    final response = await client.get(Uri.parse('https://tiles.test/1.png'));

    expect(response.statusCode, 200);
    expect(calls, 2);
  });

  test('closing it closes the client it wraps', () {
    final inner = _ClosingClient();

    GbifTileClient(inner).close();

    expect(inner.closed, isTrue);
  });
}
