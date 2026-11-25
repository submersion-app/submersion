import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/media/data/services/network_video_cache.dart';

void main() {
  late Directory dir;
  late List<http.BaseRequest> requests;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('network_video_cache_test');
    requests = [];
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  NetworkVideoCache cache(
    Future<http.Response> Function(http.Request) handler, {
    Map<String, String>? headers,
    int maxBytes = 1 << 30,
  }) => NetworkVideoCache(
    client: MockClient((request) {
      requests.add(request);
      return handler(request);
    }),
    directory: () async => Directory(p.join(dir.path, 'videos')),
    headersFor: (_) async => headers,
    maxBytes: maxBytes,
  );

  http.Response video(int size) => http.Response.bytes(
    List.filled(size, 7),
    200,
    headers: {'content-type': 'video/mp4'},
  );

  final url = Uri.parse('https://nas.example.com:5001/v.mp4?id=1');

  test('downloads with the source headers and plays from disk', () async {
    final c = cache((_) async => video(10), headers: {'Cookie': 'sid=1'});
    final path = await c.fileFor(url);
    expect(path, isNotNull);
    expect(await File(path!).length(), 10);
    expect(requests.single.headers['Cookie'], 'sid=1');
  });

  test('a second open reuses the file', () async {
    final c = cache((_) async => video(10));
    final first = await c.fileFor(url);
    final second = await c.fileFor(url);
    expect(second, first);
    expect(requests, hasLength(1));
  });

  test('concurrent opens share one download', () async {
    final gate = Completer<void>();
    final c = cache((_) async {
      await gate.future;
      return video(10);
    });
    final a = c.fileFor(url);
    final b = c.fileFor(url);
    gate.complete();
    expect(await a, await b);
    expect(requests, hasLength(1));
  });

  test('an error answered as JSON is no video', () async {
    final c = cache(
      (_) async => http.Response(
        '{"success":false,"error":{"code":119}}',
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    expect(await c.fileFor(url), isNull);
    final videos = Directory(p.join(dir.path, 'videos'));
    expect(await videos.list().toList(), isEmpty);
  });

  test('an unavailable cache directory answers null, never throws', () async {
    final c = NetworkVideoCache(
      client: MockClient((_) async => video(10)),
      directory: () async => throw const FileSystemException('no cache'),
      headersFor: (_) async => null,
    );
    expect(await c.fileFor(url), isNull);
    expect(await c.motionClipFor(url), isNull);
  });

  test('a failed transfer leaves nothing behind', () async {
    final c = cache((_) async => throw http.ClientException('down'));
    expect(await c.fileFor(url), isNull);
  });

  test('the oldest videos go once the cache is full', () async {
    final c = cache((_) async => video(10), maxBytes: 25);
    final first = await c.fileFor(Uri.parse('https://h/1.mp4'));
    await File(first!).setLastModified(DateTime(2020));
    await c.fileFor(Uri.parse('https://h/2.mp4'));
    final third = await c.fileFor(Uri.parse('https://h/3.mp4'));
    expect(File(first).existsSync(), isFalse);
    expect(File(third!).existsSync(), isTrue);
  });

  test('downloads finishing together keep both new videos', () async {
    final gate = Completer<void>();
    final c = cache((_) async {
      await gate.future;
      return video(10);
    }, maxBytes: 25);
    // Two old videos already fill most of the cache.
    final videos = Directory(p.join(dir.path, 'videos'));
    await videos.create(recursive: true);
    for (final name in ['old1.mp4', 'old2.mp4']) {
      final f = File(p.join(videos.path, name));
      await f.writeAsBytes(List.filled(10, 1));
      await f.setLastModified(DateTime(2020));
    }

    final a = c.fileFor(Uri.parse('https://h/a.mp4'));
    final b = c.fileFor(Uri.parse('https://h/b.mp4'));
    gate.complete();
    final paths = [await a, await b];

    for (final path in paths) {
      expect(File(path!).existsSync(), isTrue);
    }
    expect(File(p.join(videos.path, 'old1.mp4')).existsSync(), isFalse);
    expect(File(p.join(videos.path, 'old2.mp4')).existsSync(), isFalse);
  });

  test('a video larger than the cache plays, and goes on the next', () async {
    final c = cache(
      (r) async => video(r.url.path.contains('big') ? 40 : 10),
      maxBytes: 25,
    );
    final big = await c.fileFor(Uri.parse('https://h/big.mp4'));
    // Kept although it alone is over the bound: it is about to play.
    expect(File(big!).existsSync(), isTrue);

    final next = await c.fileFor(Uri.parse('https://h/small.mp4'));
    expect(File(big).existsSync(), isFalse);
    expect(File(next!).existsSync(), isTrue);
  });

  group('motion photos', () {
    final photo = Uri.parse('https://nas.example.com:5001/p.jpg?id=2');
    final clip = [0, 0, 0, 16, ...'ftypmp42'.codeUnits, 0, 0, 0, 0, 5, 5];
    final file = [
      0xFF, 0xD8, 0xFF, 0xE1, //
      ...'Item:Semantic="MotionPhoto" Item:Length="${clip.length}"'.codeUnits,
      0xFF, 0xD9,
      ...clip,
    ];
    http.Response jpeg(List<int> bytes) => http.Response.bytes(
      bytes,
      200,
      headers: {'content-type': 'image/jpeg'},
    );

    test('the probe reads only the start of the file', () async {
      final c = cache((_) async => jpeg(file));
      expect(await c.isMotionPhoto(photo), isTrue);
      expect(requests.single.headers['Range'], startsWith('bytes=0-'));
      // Remembered for the session.
      expect(await c.isMotionPhoto(photo), isTrue);
      expect(requests, hasLength(1));
    });

    test('a plain photo is none, an error is unknown', () async {
      expect(
        await cache((_) async => jpeg([0xFF, 0xD8, 1, 2])).isMotionPhoto(photo),
        isFalse,
      );
      expect(
        await cache(
          (_) async => http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          ),
        ).isMotionPhoto(photo),
        isNull,
      );
    });

    test('the clip is cut out and kept', () async {
      final c = cache((_) async => jpeg(file));
      final path = await c.motionClipFor(photo);
      expect(await File(path!).readAsBytes(), clip);
      expect(await c.motionClipFor(photo), path);
      expect(requests, hasLength(1));
    });

    test('a clip that cannot be put in place leaves nothing behind', () async {
      // Something already sits at the clip's name (here a folder), so the
      // write cannot finish: no half-written clip may stay to be served.
      final videos = Directory(p.join(dir.path, 'videos'));
      final key = 'motion-${sha1.convert(utf8.encode(photo.toString()))}';
      await Directory(p.join(videos.path, '$key.mp4')).create(recursive: true);
      final c = cache((_) async => jpeg(file));
      expect(await c.motionClipFor(photo), isNull);
      final left = [
        for (final e in videos.listSync())
          if (e is File) p.basename(e.path),
      ];
      expect(left, isEmpty);
    });

    test('a photo without a clip gives no file', () async {
      final c = cache((_) async => jpeg([0xFF, 0xD8, 0xFF, 0xD9]));
      expect(await c.motionClipFor(photo), isNull);
    });
  });
}
