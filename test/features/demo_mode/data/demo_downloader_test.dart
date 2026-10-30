import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/demo_mode/data/demo_downloader.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';

void main() {
  late Directory dir;
  late File dest;
  final body = Uint8List.fromList(List.generate(50000, (i) => i % 251));

  setUp(() {
    dir = Directory.systemTemp.createTempSync('demo_download');
    dest = File(p.join(dir.path, 'package.zip'));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  DemoPackage pkg({String? sha, int? size}) => DemoPackage(
    schemaVersion: 318,
    url: Uri.parse('https://example.com/demo.zip'),
    sha256: sha ?? sha256.convert(body).toString(),
    size: size ?? body.length,
    generatedAt: DateTime.utc(2026, 10, 20),
  );

  /// Streams [body] in 10 chunks.
  MockClient streaming({int status = 200}) =>
      MockClient.streaming((request, _) async {
        final chunks = [
          for (var i = 0; i < body.length; i += 5000)
            body.sublist(i, (i + 5000).clamp(0, body.length)),
        ];
        return http.StreamedResponse(
          Stream.fromIterable(chunks),
          status,
          contentLength: body.length,
        );
      });

  test(
    'download writes the file and reports progress that ends at total',
    () async {
      final progress = <(int, int)>[];

      final file = await DemoDownloader(
        client: streaming(),
      ).download(pkg(), dest, onProgress: (r, t) => progress.add((r, t)));

      expect(file.readAsBytesSync(), body);
      expect(progress.last, (body.length, body.length));
      expect(progress.length, greaterThan(1));
    },
  );

  test(
    'download throws checksumMismatch and leaves neither dest nor dest.tmp',
    () async {
      await expectLater(
        DemoDownloader(client: streaming()).download(pkg(sha: 'c' * 64), dest),
        throwsA(
          isA<DemoDownloadException>().having(
            (e) => e.reason,
            'reason',
            DemoDownloadFailure.checksumMismatch,
          ),
        ),
      );
      expect(dest.existsSync(), isFalse);
      expect(File('${dest.path}.tmp').existsSync(), isFalse);
    },
  );

  test(
    'download throws sizeMismatch when the body is not the listed size',
    () async {
      await expectLater(
        DemoDownloader(client: streaming()).download(pkg(size: 10), dest),
        throwsA(
          isA<DemoDownloadException>().having(
            (e) => e.reason,
            'reason',
            DemoDownloadFailure.sizeMismatch,
          ),
        ),
      );
      expect(File('${dest.path}.tmp').existsSync(), isFalse);
    },
  );

  test(
    'a stalled download ends as a network failure and leaves no file',
    () async {
      // The first chunk arrives, then the connection goes quiet for good.
      final stalled = MockClient.streaming((request, _) async {
        final controller = StreamController<List<int>>()
          ..add(body.sublist(0, 5000));
        return http.StreamedResponse(
          controller.stream,
          200,
          contentLength: body.length,
        );
      });

      await expectLater(
        DemoDownloader(
          client: stalled,
          idleTimeout: const Duration(milliseconds: 50),
        ).download(pkg(), dest),
        throwsA(
          isA<DemoDownloadException>().having(
            (e) => e.reason,
            'reason',
            DemoDownloadFailure.network,
          ),
        ),
      );
      expect(dest.existsSync(), isFalse);
      expect(File('${dest.path}.tmp').existsSync(), isFalse);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  test('a request that never answers ends as a network failure', () async {
    final silent = MockClient.streaming(
      (request, _) => Completer<http.StreamedResponse>().future,
    );

    await expectLater(
      DemoDownloader(
        client: silent,
        connectTimeout: const Duration(milliseconds: 50),
      ).download(pkg(), dest),
      throwsA(
        isA<DemoDownloadException>().having(
          (e) => e.reason,
          'reason',
          DemoDownloadFailure.network,
        ),
      ),
    );
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('download throws httpStatus on a non-200 response', () async {
    await expectLater(
      DemoDownloader(client: streaming(status: 404)).download(pkg(), dest),
      throwsA(
        isA<DemoDownloadException>().having(
          (e) => e.reason,
          'reason',
          DemoDownloadFailure.httpStatus,
        ),
      ),
    );
  });

  test('download throws network when the request fails', () async {
    final client = MockClient.streaming(
      (_, _) async => throw http.ClientException('offline'),
    );

    await expectLater(
      DemoDownloader(client: client).download(pkg(), dest),
      throwsA(
        isA<DemoDownloadException>().having(
          (e) => e.reason,
          'reason',
          DemoDownloadFailure.network,
        ),
      ),
    );
  });

  test(
    'download throws cancelled when isCancelled returns true mid-stream',
    () async {
      var chunks = 0;

      await expectLater(
        DemoDownloader(client: streaming()).download(
          pkg(),
          dest,
          onProgress: (_, _) => chunks++,
          isCancelled: () => chunks >= 3,
        ),
        throwsA(
          isA<DemoDownloadException>().having(
            (e) => e.reason,
            'reason',
            DemoDownloadFailure.cancelled,
          ),
        ),
      );
      expect(dest.existsSync(), isFalse);
      expect(File('${dest.path}.tmp').existsSync(), isFalse);
    },
  );
}
