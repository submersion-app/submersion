import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/features/divelogs_sync/domain/services/divelogs_photo_sync_service.dart';
import 'package:submersion/features/divelogs_sync/domain/services/divelogs_sync_planner.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

void main() {
  final t0 = DateTime.utc(2022, 9, 3, 10);

  DivelogsMatchedDive pair(String remote, String local) =>
      DivelogsMatchedDive(remoteId: remote, localDiveId: local, localTime: t0);

  MediaItem photo(String id, {String? filename}) => MediaItem(
    id: id,
    diveId: 'l1',
    mediaType: MediaType.photo,
    originalFilename: filename,
    takenAt: t0,
    createdAt: t0,
    updatedAt: t0,
  );

  DivelogsApiClient api(Future<http.Response> Function(http.Request) handler) =>
      DivelogsApiClient(
        getBearerToken: () async => 't',
        onTokenRejected: () {},
        httpClient: MockClient(handler),
      );

  /// Records the calls the page-level wiring would make.
  ({
    List<({Uint8List bytes, String filename, String diveId, DateTime takenAt})>
    attached,
    DivelogsPhotoSyncService service,
  })
  build(
    DivelogsApiClient client, {
    Map<String, List<MediaItem>> localByDive = const {},
    Map<String, Uint8List> localBytes = const {},
  }) {
    final attached =
        <
          ({Uint8List bytes, String filename, String diveId, DateTime takenAt})
        >[];
    final service = DivelogsPhotoSyncService(
      api: client,
      getLocalMedia: (diveId) async => localByDive[diveId] ?? const [],
      resolveLocalBytes: (item) async => localBytes[item.id],
      attachToDive:
          ({
            required bytes,
            required filename,
            required diveId,
            required takenAt,
          }) async {
            attached.add((
              bytes: bytes,
              filename: filename,
              diveId: diveId,
              takenAt: takenAt,
            ));
          },
    );
    return (attached: attached, service: service);
  }

  test(
    'pulls a new remote picture and attaches it (filename from url)',
    () async {
      final client = api((req) async {
        if (req.url.path == '/api/pictures/r1') {
          return http.Response(
            jsonEncode([
              {'id': 1, 'url': 'https://cdn.divelogs.de/p/1.jpg'},
            ]),
            200,
          );
        }
        if (req.url.host == 'cdn.divelogs.de') {
          return http.Response.bytes([1, 2, 3], 200);
        }
        fail('unexpected ${req.method} ${req.url}');
      });
      final h = build(client);
      final result = await h.service.sync([pair('r1', 'l1')]);

      expect(result.pulled, 1);
      expect(result.pulledDuplicates, 0);
      expect(h.attached.single.filename, '1.jpg');
      expect(h.attached.single.bytes, [1, 2, 3]);
      expect(h.attached.single.diveId, 'l1');
      expect(h.attached.single.takenAt, t0);
    },
  );

  test(
    'a remote picture matching a local hash is a duplicate, not attached',
    () async {
      final client = api((req) async {
        if (req.url.path == '/api/pictures/r1') {
          return http.Response(
            jsonEncode([
              {'id': 1, 'url': 'https://cdn.divelogs.de/p/1.jpg'},
            ]),
            200,
          );
        }
        return http.Response.bytes([7, 7, 7], 200);
      });
      final h = build(
        client,
        localByDive: {
          'l1': [photo('m1')],
        },
        localBytes: {
          'm1': Uint8List.fromList([7, 7, 7]),
        },
      );
      final result = await h.service.sync([pair('r1', 'l1')]);

      expect(result.pulled, 0);
      expect(result.pulledDuplicates, 1);
      expect(h.attached, isEmpty);
    },
  );

  test('remote rows without a usable url are counted as skipped', () async {
    final client = api((req) async {
      if (req.url.path == '/api/pictures/r1') {
        return http.Response(
          jsonEncode([
            {'id': 1, 'url': '1.jpg'},
          ]),
          200,
        );
      }
      fail('no download expected for a bare filename');
    });
    final h = build(client);
    final result = await h.service.sync([pair('r1', 'l1')]);

    expect(result.skippedNoUrl, 1);
    expect(result.pulled, 0);
    expect(h.attached, isEmpty);
  });

  test('pushes local photos only when the remote list is empty', () async {
    var posted = 0;
    late http.MultipartRequest capturedPush;
    final client = DivelogsApiClient(
      getBearerToken: () async => 't',
      onTokenRejected: () {},
      httpClient: _CapturingClient(
        (req) {
          if (req.method == 'POST') {
            posted++;
            capturedPush = req as http.MultipartRequest;
          }
        },
        bodyForGet: (req) {
          // r1 has a remote picture, r2 has none.
          return req.url.path == '/api/pictures/r1'
              ? jsonEncode([
                  {'id': 9, 'url': 'https://cdn.divelogs.de/p/9.jpg'},
                ])
              : jsonEncode([]);
        },
      ),
    );
    final h = build(
      client,
      localByDive: {
        'l1': [photo('m1', filename: 'a.jpg')],
        'l2': [photo('m2', filename: 'b.jpg')],
      },
      localBytes: {
        'm1': Uint8List.fromList([1]),
        'm2': Uint8List.fromList([2]),
      },
    );
    // r1 (has remote pics, so pull downloads them) and r2 (empty, so push).
    final result = await h.service.sync([pair('r1', 'l1'), pair('r2', 'l2')]);

    expect(posted, 1, reason: 'only l2 pushes (r2 has no remote pictures)');
    expect(capturedPush.files.single.field, 'imagefile');
    expect(capturedPush.files.single.filename, 'b.jpg');
    expect(result.pushed, 1);
  });

  test('a 500 mid-run stops and reports partial counts', () async {
    final client = api((req) async {
      if (req.url.path == '/api/pictures/r1') {
        return http.Response(
          jsonEncode([
            {'id': 1, 'url': 'https://cdn.divelogs.de/p/1.jpg'},
          ]),
          200,
        );
      }
      if (req.url.host == 'cdn.divelogs.de') {
        return http.Response('', 500);
      }
      fail('unexpected ${req.url}');
    });
    final h = build(client);
    final result = await h.service.sync([pair('r1', 'l1')]);

    expect(result.failed, isTrue);
    expect(result.error, contains('500'));
    expect(result.pulled, 0);
  });
}

/// Captures POSTs and serves a JSON body for GETs (MockClient materializes
/// multipart bodies, so we need a BaseClient to inspect the file part).
class _CapturingClient extends http.BaseClient {
  _CapturingClient(this.onRequest, {required this.bodyForGet});

  final void Function(http.BaseRequest) onRequest;
  final String Function(http.BaseRequest) bodyForGet;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onRequest(request);
    final body = request.method == 'GET' ? bodyForGet(request) : '{}';
    return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
  }
}
