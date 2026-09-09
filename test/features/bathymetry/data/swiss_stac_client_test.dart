import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_stac_client.dart';

void main() {
  const bbox = [8.54, 47.24, 8.55, 47.25];
  const overlappingBbox = [8.535, 47.235, 8.555, 47.255];
  const decoyBbox = [9.5, 46.0, 9.51, 46.01];

  group('SwissStacClient.findAsset', () {
    test('picks an ESRI ASCII grid asset over an XYZ one', () async {
      late Uri requested;
      final client = SwissStacClient(
        client: MockClient((req) async {
          requested = req.url;
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': overlappingBbox,
                  'assets': {
                    'xyz': {
                      'href': 'https://example.org/tile_2685_1240.xyz.zip',
                    },
                    'grid': {
                      'href': 'https://example.org/tile_2685_1240_grid.zip',
                    },
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      final asset = await client.findAsset(
        collectionId: 'ch.swisstopo.swissbathy3d',
        bbox: bbox,
      );
      expect(asset, isNotNull);
      expect(asset!.format, 'esri-ascii');
      expect(asset.href, contains('_grid.zip'));
      expect(requested.path, contains('ch.swisstopo.swissbathy3d/items'));
      expect(requested.queryParameters['bbox'], bbox.join(','));
    });

    test('carries the item datetime as the asset version token', () async {
      final client = SwissStacClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': overlappingBbox,
                  'properties': {'datetime': '2023-05-01T00:00:00Z'},
                  'assets': {
                    'grid': {
                      'href': 'https://example.org/tile_2685_1240_grid.zip',
                    },
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      final asset = await client.findAsset(
        collectionId: 'ch.swisstopo.swissbathy3d',
        bbox: bbox,
      );
      expect(asset!.datetime, '2023-05-01T00:00:00Z');
    });

    test(
      'falls back to "updated" then "created" when datetime is absent',
      () async {
        final client = SwissStacClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'features': [
                  {
                    'bbox': overlappingBbox,
                    'properties': {'created': '2021-01-01T00:00:00Z'},
                    'assets': {
                      'grid': {'href': 'https://example.org/tile_grid.zip'},
                    },
                  },
                ],
              }),
              200,
            ),
          ),
        );
        final asset = await client.findAsset(
          collectionId: 'ch.swisstopo.swissbathy3d',
          bbox: bbox,
        );
        expect(asset!.datetime, '2021-01-01T00:00:00Z');
      },
    );

    test('datetime is null when the item has no properties', () async {
      final client = SwissStacClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': overlappingBbox,
                  'assets': {
                    'grid': {'href': 'https://example.org/tile_grid.zip'},
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      final asset = await client.findAsset(
        collectionId: 'ch.swisstopo.swissbathy3d',
        bbox: bbox,
      );
      expect(asset!.datetime, isNull);
    });

    test('falls back to any zip asset when none looks like a grid', () async {
      final client = SwissStacClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': overlappingBbox,
                  'assets': {
                    'data': {'href': 'https://example.org/tile.zip'},
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      final asset = await client.findAsset(
        collectionId: 'ch.swisstopo.swissbathy3d',
        bbox: bbox,
      );
      expect(asset, isNotNull);
      expect(asset!.format, 'unknown');
    });

    test('skips a feature whose own bbox does not overlap the request, even '
        'when the server returned it as the first result (a non-spatially- '
        'filtering or mis-paginating server must not splice an unrelated '
        'tile into the stitched mosaic)', () async {
      final client = SwissStacClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'features': [
                {
                  // Decoy: far from the requested tile. A server that
                  // ignores bbox (or paginates without filtering) could
                  // put this first regardless of what was asked for.
                  'bbox': decoyBbox,
                  'assets': {
                    'grid': {'href': 'https://example.org/decoy_grid.zip'},
                  },
                },
                {
                  'bbox': overlappingBbox,
                  'assets': {
                    'grid': {'href': 'https://example.org/correct_grid.zip'},
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      final asset = await client.findAsset(
        collectionId: 'ch.swisstopo.swissbathy3d',
        bbox: bbox,
      );
      expect(asset, isNotNull);
      expect(asset!.href, 'https://example.org/correct_grid.zip');
    });

    test('returns null when every candidate feature is a spatial decoy (no '
        'real match, rather than trusting an unrelated tile)', () async {
      final client = SwissStacClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': decoyBbox,
                  'assets': {
                    'grid': {'href': 'https://example.org/decoy_grid.zip'},
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      final asset = await client.findAsset(
        collectionId: 'ch.swisstopo.swissbathy3d',
        bbox: bbox,
      );
      expect(asset, isNull);
    });

    test('skips a feature with no bbox field at all (cannot be trusted, even '
        'though the STAC spec requires one for items with geometry)', () async {
      final client = SwissStacClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'assets': {
                    'grid': {'href': 'https://example.org/no_bbox.zip'},
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      final asset = await client.findAsset(
        collectionId: 'ch.swisstopo.swissbathy3d',
        bbox: bbox,
      );
      expect(asset, isNull);
    });

    test('skips a feature whose bbox contains non-numeric coordinates instead '
        'of throwing a raw TypeError, and still returns the valid candidates '
        'around it', () async {
      final client = SwissStacClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': ['not', 'a', 'number', 'here'],
                  'assets': {
                    'grid': {'href': 'https://example.org/malformed.zip'},
                  },
                },
                {
                  'bbox': overlappingBbox,
                  'assets': {
                    'grid': {'href': 'https://example.org/valid.zip'},
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      final candidates = await client.findAssetCandidates(
        collectionId: 'ch.swisstopo.swissbathy3d',
        bbox: bbox,
      );
      expect(candidates.map((a) => a.href), ['https://example.org/valid.zip']);
    });

    test('returns null when the collection has no matching item', () async {
      final client = SwissStacClient(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'features': []}), 200),
        ),
      );
      final asset = await client.findAsset(
        collectionId: 'ch.swisstopo.swissbathy3d',
        bbox: bbox,
      );
      expect(asset, isNull);
    });

    test('throws SwissStacCollectionNotFoundException on 404', () async {
      final client = SwissStacClient(
        client: MockClient((_) async => http.Response('not found', 404)),
      );
      expect(
        () => client.findAsset(
          collectionId: 'ch.swisstopo.swissbathy3d_wrong',
          bbox: bbox,
        ),
        throwsA(isA<SwissStacCollectionNotFoundException>()),
      );
    });

    test('throws SwissStacException on a server error', () async {
      final client = SwissStacClient(
        client: MockClient((_) async => http.Response('oops', 500)),
      );
      expect(
        () => client.findAsset(
          collectionId: 'ch.swisstopo.swissbathy3d',
          bbox: bbox,
        ),
        throwsA(isA<SwissStacException>()),
      );
    });

    test('throws SwissStacException on an unparseable body', () async {
      final client = SwissStacClient(
        client: MockClient((_) async => http.Response('<html></html>', 200)),
      );
      expect(
        () => client.findAsset(
          collectionId: 'ch.swisstopo.swissbathy3d',
          bbox: bbox,
        ),
        throwsA(isA<SwissStacException>()),
      );
    });
  });

  group('SwissStacClient.findAssetCandidates', () {
    test(
      'returns every bbox-overlapping feature, not just the first',
      () async {
        final client = SwissStacClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'features': [
                  {
                    'bbox': overlappingBbox,
                    'assets': {
                      'grid': {'href': 'https://example.org/first.zip'},
                    },
                  },
                  {
                    'bbox': overlappingBbox,
                    'assets': {
                      'grid': {'href': 'https://example.org/second.zip'},
                    },
                  },
                  {
                    // Decoy: does not overlap, must be excluded.
                    'bbox': decoyBbox,
                    'assets': {
                      'grid': {'href': 'https://example.org/decoy.zip'},
                    },
                  },
                ],
              }),
              200,
            ),
          ),
        );
        final candidates = await client.findAssetCandidates(
          collectionId: 'ch.swisstopo.swissbathy3d',
          bbox: bbox,
        );
        expect(candidates.map((a) => a.href), [
          'https://example.org/first.zip',
          'https://example.org/second.zip',
        ]);
      },
    );

    test(
      'returns an empty list rather than null when nothing overlaps',
      () async {
        final client = SwissStacClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'features': [
                  {
                    'bbox': decoyBbox,
                    'assets': {
                      'grid': {'href': 'https://example.org/decoy.zip'},
                    },
                  },
                ],
              }),
              200,
            ),
          ),
        );
        final candidates = await client.findAssetCandidates(
          collectionId: 'ch.swisstopo.swissbathy3d',
          bbox: bbox,
        );
        expect(candidates, isEmpty);
      },
    );

    test(
      'follows the STAC next link to collect candidates past the first page',
      () async {
        final requestedUrls = <Uri>[];
        final client = SwissStacClient(
          client: MockClient((req) async {
            requestedUrls.add(req.url);
            if (req.url.queryParameters['page'] == '2') {
              return http.Response(
                jsonEncode({
                  'features': [
                    {
                      'bbox': overlappingBbox,
                      'assets': {
                        'grid': {'href': 'https://example.org/second.zip'},
                      },
                    },
                  ],
                  'links': [],
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'features': [
                  {
                    'bbox': overlappingBbox,
                    'assets': {
                      'grid': {'href': 'https://example.org/first.zip'},
                    },
                  },
                ],
                'links': [
                  {
                    'rel': 'next',
                    'href':
                        'https://data.geo.admin.ch/api/stac/v1/collections/'
                        'ch.swisstopo.swissbathy3d/items?page=2',
                  },
                ],
              }),
              200,
            );
          }),
        );
        final candidates = await client.findAssetCandidates(
          collectionId: 'ch.swisstopo.swissbathy3d',
          bbox: bbox,
        );
        expect(candidates.map((a) => a.href), [
          'https://example.org/first.zip',
          'https://example.org/second.zip',
        ]);
        expect(requestedUrls, hasLength(2));
      },
    );

    test(
      'throws instead of silently returning a partial candidate list when '
      'a next link still exists past the page cap (an incomplete list here '
      'must never be cached by a caller as a definitive "no tile here")',
      () async {
        final client = SwissStacClient(
          client: MockClient((req) async {
            final page = int.tryParse(req.url.queryParameters['page'] ?? '1');
            return http.Response(
              jsonEncode({
                'features': [
                  {
                    'bbox': overlappingBbox,
                    'assets': {
                      'grid': {'href': 'https://example.org/p$page.zip'},
                    },
                  },
                ],
                // Always declares a next page, regardless of how many pages
                // have already been fetched -- simulates a server (or a
                // misconfigured/pathological one) that never terminates.
                'links': [
                  {
                    'rel': 'next',
                    'href':
                        'https://data.geo.admin.ch/api/stac/v1/collections/'
                        'ch.swisstopo.swissbathy3d/items?page=${(page ?? 1) + 1}',
                  },
                ],
              }),
              200,
            );
          }),
        );
        expect(
          () => client.findAssetCandidates(
            collectionId: 'ch.swisstopo.swissbathy3d',
            bbox: bbox,
          ),
          throwsA(isA<SwissStacException>()),
        );
      },
    );

    test('throws SwissStacException instead of a raw TypeError when the '
        "response's top-level JSON is not an object", () async {
      final client = SwissStacClient(
        client: MockClient((_) async => http.Response(jsonEncode([]), 200)),
      );
      expect(
        () => client.findAssetCandidates(
          collectionId: 'ch.swisstopo.swissbathy3d',
          bbox: bbox,
        ),
        throwsA(isA<SwissStacException>()),
      );
    });

    test('throws SwissStacException instead of a raw TypeError when '
        "'features' is present but not a list", () async {
      final client = SwissStacClient(
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode({'features': 'not-a-list'}), 200),
        ),
      );
      expect(
        () => client.findAssetCandidates(
          collectionId: 'ch.swisstopo.swissbathy3d',
          bbox: bbox,
        ),
        throwsA(isA<SwissStacException>()),
      );
    });

    test(
      'skips a feature entry that is not a JSON object instead of throwing '
      'a raw TypeError, and still returns the valid candidates around it',
      () async {
        final client = SwissStacClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'features': [
                  'not-a-feature-object',
                  {
                    'bbox': overlappingBbox,
                    'assets': {
                      'grid': {'href': 'https://example.org/valid.zip'},
                    },
                  },
                ],
              }),
              200,
            ),
          ),
        );
        final candidates = await client.findAssetCandidates(
          collectionId: 'ch.swisstopo.swissbathy3d',
          bbox: bbox,
        );
        expect(candidates.map((a) => a.href), [
          'https://example.org/valid.zip',
        ]);
      },
    );

    test('skips an asset entry that is not a JSON object instead of throwing a '
        'raw TypeError when picking the best asset', () async {
      final client = SwissStacClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': overlappingBbox,
                  'assets': {
                    'malformed': 'not-an-object',
                    'grid': {'href': 'https://example.org/valid.zip'},
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      final candidates = await client.findAssetCandidates(
        collectionId: 'ch.swisstopo.swissbathy3d',
        bbox: bbox,
      );
      expect(candidates.map((a) => a.href), ['https://example.org/valid.zip']);
    });

    test('treats a malformed links array (non-object entries) as "no next '
        'page" instead of throwing, and still returns the current page\'s '
        'candidates', () async {
      final client = SwissStacClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': overlappingBbox,
                  'assets': {
                    'grid': {'href': 'https://example.org/only.zip'},
                  },
                },
              ],
              'links': [
                'not-a-link-object',
                {'rel': 'next'}, // no href
                {'href': 'https://example.org/no-rel'}, // no rel
              ],
            }),
            200,
          ),
        ),
      );
      final candidates = await client.findAssetCandidates(
        collectionId: 'ch.swisstopo.swissbathy3d',
        bbox: bbox,
      );
      expect(candidates.map((a) => a.href), ['https://example.org/only.zip']);
    });

    test('treats a top-level "links" field that is not a list as "no next '
        'page" instead of throwing', () async {
      final client = SwissStacClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': overlappingBbox,
                  'assets': {
                    'grid': {'href': 'https://example.org/only.zip'},
                  },
                },
              ],
              'links': 'not-a-list',
            }),
            200,
          ),
        ),
      );
      final candidates = await client.findAssetCandidates(
        collectionId: 'ch.swisstopo.swissbathy3d',
        bbox: bbox,
      );
      expect(candidates.map((a) => a.href), ['https://example.org/only.zip']);
    });

    test('findAsset still returns just the first candidate', () async {
      final client = SwissStacClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'features': [
                {
                  'bbox': overlappingBbox,
                  'assets': {
                    'grid': {'href': 'https://example.org/first.zip'},
                  },
                },
                {
                  'bbox': overlappingBbox,
                  'assets': {
                    'grid': {'href': 'https://example.org/second.zip'},
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      final asset = await client.findAsset(
        collectionId: 'ch.swisstopo.swissbathy3d',
        bbox: bbox,
      );
      expect(asset!.href, 'https://example.org/first.zip');
    });
  });

  group('SwissStacClient.downloadBytes', () {
    test('returns the response bytes on 200', () async {
      final client = SwissStacClient(
        client: MockClient((_) async => http.Response.bytes([1, 2, 3], 200)),
      );
      final bytes = await client.downloadBytes('https://example.org/a.zip');
      expect(bytes, [1, 2, 3]);
    });

    test('throws SwissStacException on a non-200 status', () async {
      final client = SwissStacClient(
        client: MockClient((_) async => http.Response('nope', 404)),
      );
      expect(
        () => client.downloadBytes('https://example.org/a.zip'),
        throwsA(isA<SwissStacException>()),
      );
    });

    // Regression: a real swissBATHY3D asset ZIP is lake-wide (potentially
    // tens of megabytes) and was observed timing out at the old 15-second
    // limit on ordinary connections. This proves a download that takes
    // longer than that old limit, but stays under the new one, now succeeds
    // instead of throwing.
    test('does not time out on a download slower than the old 15s limit', () {
      fakeAsync((async) {
        final client = SwissStacClient(
          client: MockClient((_) async {
            await Future<void>.delayed(const Duration(seconds: 20));
            return http.Response.bytes([1, 2, 3], 200);
          }),
        );

        Uint8List? bytes;
        Object? error;
        unawaited(
          client
              .downloadBytes('https://example.org/a.zip')
              .then((v) => bytes = v, onError: (e) => error = e),
        );

        async.elapse(const Duration(seconds: 20));

        expect(error, isNull);
        expect(bytes, [1, 2, 3]);
      });
    });

    test('still times out on a download slower than the new 120s limit', () {
      fakeAsync((async) {
        final client = SwissStacClient(
          client: MockClient((_) async {
            await Future<void>.delayed(const Duration(seconds: 121));
            return http.Response.bytes([1, 2, 3], 200);
          }),
        );

        Object? error;
        unawaited(
          client
              .downloadBytes('https://example.org/a.zip')
              .then((_) {}, onError: (e) => error = e),
        );

        async.elapse(const Duration(seconds: 121));

        expect(error, isA<SwissStacException>());
      });
    });
  });
}
