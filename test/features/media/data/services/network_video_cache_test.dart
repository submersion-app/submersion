import 'dart:async';
import 'dart:io';

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
}
