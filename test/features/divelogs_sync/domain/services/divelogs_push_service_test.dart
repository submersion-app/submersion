import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divelogs_sync/domain/services/divelogs_push_service.dart';

void main() {
  Dive dive(int n, {Duration? runtime = const Duration(minutes: 45)}) => Dive(
    id: 'd$n',
    dateTime: DateTime.utc(2022, 9, n + 1, 10),
    entryTime: DateTime.utc(2022, 9, n + 1, 10),
    runtime: runtime,
    maxDepth: 10.0 + n,
  );

  DivelogsApiClient api(Future<http.Response> Function(http.Request) handler) =>
      DivelogsApiClient(
        getBearerToken: () async => 't',
        onTokenRejected: () {},
        httpClient: MockClient(handler),
      );

  DivelogsPushService service(DivelogsApiClient client, {int chunkSize = 2}) =>
      DivelogsPushService(
        api: client,
        chunkSize: chunkSize,
        delay: (_) async {},
      );

  test('chunks dives and reports progress', () async {
    final batches = <int>[];
    final progress = <(int, int)>[];
    final result =
        await service(
          api((req) async {
            batches.add((jsonDecode(req.body) as List).length);
            return http.Response('{}', 200);
          }),
        ).push([
          dive(1),
          dive(2),
          dive(3),
        ], onProgress: (done, total) => progress.add((done, total)));
    expect(batches, [2, 1]);
    expect(progress, [(2, 3), (3, 3)]);
    expect(result.pushed, 3);
    expect(result.skippedUnmappable, 0);
    expect(result.failed, isFalse);
  });

  test('unmappable dives are counted and not sent', () async {
    var sent = 0;
    final result = await service(
      api((req) async {
        sent += (jsonDecode(req.body) as List).length;
        return http.Response('{}', 200);
      }),
    ).push([dive(1), dive(2, runtime: null)]);
    expect(sent, 1);
    expect(result.pushed, 1);
    expect(result.skippedUnmappable, 1);
  });

  test('a failed chunk stops the push and reports partial progress', () async {
    var call = 0;
    final result = await service(
      api((req) async {
        call++;
        return call == 1 ? http.Response('{}', 200) : http.Response('', 500);
      }),
    ).push([dive(1), dive(2), dive(3)]);
    expect(result.pushed, 2);
    expect(result.failed, isTrue);
    expect(result.error, contains('500'));
  });

  test('empty mapped list makes no network calls', () async {
    final result = await service(
      api((req) async => fail('no call expected')),
    ).push([dive(1, runtime: null)]);
    expect(result.pushed, 0);
    expect(result.skippedUnmappable, 1);
  });
}
