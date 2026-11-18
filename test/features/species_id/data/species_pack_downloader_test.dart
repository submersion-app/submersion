import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/species_id/data/pack/species_pack_downloader.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';

import '../../../helpers/temp_dir.dart';
import '../domain/manifest_fixture.dart';

final _bytes = Uint8List.fromList(List.generate(1000, (i) => i % 251));
final _sha = sha256.convert(_bytes).toString();
final _url = Uri.parse('https://example.test/pack/candidates.json');

PackFile _file({int size = 1000, String? sha}) => PackFile(
  name: 'candidates.json',
  engine: 'all',
  size: size,
  sha256: sha ?? _sha,
);

/// A server that sends [body] in 100-byte chunks with [status].
MockClient _server({
  int status = 200,
  List<int>? body,
  void Function(http.BaseRequest request)? inspect,
  Object? failAfterFirstChunk,
}) => MockClient.streaming((request, _) async {
  inspect?.call(request);
  final data = body ?? _bytes;
  final controller = StreamController<List<int>>();
  () async {
    for (var i = 0; i < data.length; i += 100) {
      controller.add(
        data.sublist(i, i + 100 > data.length ? data.length : i + 100),
      );
      await Future<void>.delayed(Duration.zero);
      if (failAfterFirstChunk != null) {
        controller.addError(failAfterFirstChunk);
        break;
      }
    }
    await controller.close();
  }();
  return http.StreamedResponse(controller.stream, status);
});

void main() {
  late Directory dir;
  late File dest;
  File part() => File('${dest.path}.part');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pack_download_test');
    dest = File(p.join(dir.path, 'candidates.json'));
  });
  tearDown(() => deleteTempDir(dir));

  Matcher failsWith(PackDownloadFailure reason) => throwsA(
    isA<PackDownloadException>().having((e) => e.reason, 'reason', reason),
  );

  test('a finished file that checks out is not downloaded again', () async {
    await dest.writeAsBytes(_bytes);
    var requests = 0;
    await SpeciesPackDownloader(
      client: _server(inspect: (_) => requests++),
    ).downloadFile(url: _url, file: _file(), dest: dest);
    expect(requests, 0);
    expect(await dest.readAsBytes(), _bytes);
  });

  test('a finished file of the right size but other content is downloaded '
      'again', () async {
    await dest.writeAsBytes(Uint8List(1000));
    await SpeciesPackDownloader(
      client: _server(),
    ).downloadFile(url: _url, file: _file(), dest: dest);
    expect(await dest.readAsBytes(), _bytes);
  });

  test('a clean download is verified and renamed into place', () async {
    final progress = <int>[];
    await SpeciesPackDownloader(client: _server()).downloadFile(
      url: _url,
      file: _file(),
      dest: dest,
      onProgress: progress.add,
    );
    expect(await dest.readAsBytes(), _bytes);
    expect(await part().exists(), isFalse);
    expect(progress.last, 1000);
  });

  test('a partial file resumes with a Range request', () async {
    await part().writeAsBytes(_bytes.sublist(0, 100));
    String? range;
    await SpeciesPackDownloader(
      client: _server(
        status: 206,
        body: _bytes.sublist(100),
        inspect: (r) => range = r.headers['Range'],
      ),
    ).downloadFile(url: _url, file: _file(), dest: dest);
    expect(range, 'bytes=100-');
    expect(await dest.readAsBytes(), _bytes);
  });

  test('a server that ignores Range sends the whole file again', () async {
    await part().writeAsBytes(List.filled(100, 9));
    await SpeciesPackDownloader(
      client: _server(),
    ).downloadFile(url: _url, file: _file(), dest: dest);
    expect(await dest.readAsBytes(), _bytes);
  });

  test('a complete part that verifies is used without a request', () async {
    await part().writeAsBytes(_bytes);
    var requested = false;
    await SpeciesPackDownloader(
      client: MockClient((_) async {
        requested = true;
        return http.Response('', 500);
      }),
    ).downloadFile(url: _url, file: _file(), dest: dest);
    expect(requested, isFalse);
    expect(await dest.readAsBytes(), _bytes);
  });

  test('a wrong hash fails and discards the part', () async {
    await expectLater(
      SpeciesPackDownloader(client: _server()).downloadFile(
        url: _url,
        file: _file(sha: 'b' * 64),
        dest: dest,
      ),
      failsWith(PackDownloadFailure.checksumMismatch),
    );
    expect(await part().exists(), isFalse);
    expect(await dest.exists(), isFalse);
  });

  test(
    'more bytes than the manifest says fails and discards the part',
    () async {
      await expectLater(
        SpeciesPackDownloader(
          client: _server(body: [..._bytes, ...List.filled(200, 1)]),
        ).downloadFile(url: _url, file: _file(), dest: dest),
        failsWith(PackDownloadFailure.sizeMismatch),
      );
      expect(await part().exists(), isFalse);
    },
  );

  test('a body that ends short keeps the part to resume', () async {
    await expectLater(
      SpeciesPackDownloader(
        client: _server(body: _bytes.sublist(0, 900)),
      ).downloadFile(url: _url, file: _file(), dest: dest),
      failsWith(PackDownloadFailure.network),
    );
    expect(await part().length(), 900);
  });

  test('cancelling keeps the part', () async {
    var chunks = 0;
    await expectLater(
      SpeciesPackDownloader(client: _server()).downloadFile(
        url: _url,
        file: _file(),
        dest: dest,
        onProgress: (_) => chunks++,
        isCancelled: () => chunks >= 2,
      ),
      failsWith(PackDownloadFailure.cancelled),
    );
    expect(await part().exists(), isTrue);
  });

  test('a broken connection keeps the part', () async {
    await expectLater(
      SpeciesPackDownloader(
        client: _server(failAfterFirstChunk: const SocketException('reset')),
      ).downloadFile(url: _url, file: _file(), dest: dest),
      failsWith(PackDownloadFailure.network),
    );
    expect(await part().length(), 100);
  });

  test('a server error is an http failure', () async {
    await expectLater(
      SpeciesPackDownloader(
        client: MockClient((_) async => http.Response('nope', 500)),
      ).downloadFile(url: _url, file: _file(), dest: dest),
      failsWith(PackDownloadFailure.httpStatus),
    );
  });

  test('a destination that cannot be written is a storage failure', () async {
    final notADir = File(p.join(dir.path, 'plain-file'));
    await notADir.writeAsString('x');
    await expectLater(
      SpeciesPackDownloader(client: _server()).downloadFile(
        url: _url,
        file: _file(),
        dest: File(p.join(notADir.path, 'candidates.json')),
      ),
      failsWith(PackDownloadFailure.storage),
    );
  });

  group('downloadModel', () {
    final zip = Uint8List.fromList(
      ZipEncoder().encodeBytes(
        Archive()
          ..addFile(
            ArchiveFile.bytes('detector.mlpackage/Manifest.json', [1, 2, 3]),
          )
          ..addFile(
            ArchiveFile.bytes(
              'detector.mlpackage/Data/weights.bin',
              List.generate(3000, (i) => i % 7),
            ),
          ),
      ),
    );
    final zipSha = sha256.convert(zip).toString();
    final modelUrl = Uri.parse('https://example.test/pack/detector.coreml.zip');
    late Directory folder;
    Directory partFolder() => Directory('${folder.path}.part');
    File weights() =>
        File(p.join(folder.path, 'detector.mlpackage', 'Data', 'weights.bin'));

    PackFile model({String? sha, int? size}) => PackFile(
      name: 'detector.coreml.zip',
      engine: 'coreml',
      size: size ?? zip.length,
      sha256: sha ?? zipSha,
    );

    setUp(() => folder = Directory(p.join(dir.path, 'detector')));

    Future<void> download(
      http.Client client, {
      PackFile? file,
      void Function(int)? onProgress,
      bool Function()? isCancelled,
    }) => SpeciesPackDownloader(client: client).downloadModel(
      url: modelUrl,
      file: file ?? model(),
      dest: folder,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );

    test('unpacks as it downloads: no zip is written', () async {
      final progress = <int>[];
      String? range;
      await download(
        _server(body: zip, inspect: (r) => range = r.headers['Range']),
        onProgress: progress.add,
      );
      expect(await weights().readAsBytes(), List.generate(3000, (i) => i % 7));
      expect(range, isNull);
      expect(progress.last, zip.length);
      expect(await partFolder().exists(), isFalse);
      final written = dir.listSync(recursive: true).whereType<File>();
      expect(written.where((f) => f.path.endsWith('.zip')), isEmpty);
    });

    test(
      'a model unpacked from the same zip is not downloaded again',
      () async {
        await download(_server(body: zip));
        var requests = 0;
        final progress = <int>[];
        await download(
          _server(body: zip, inspect: (_) => requests++),
          onProgress: progress.add,
        );
        expect(requests, 0);
        expect(progress, [zip.length]);
        expect(await weights().exists(), isTrue);
      },
    );

    test('a model unpacked from another zip is downloaded again', () async {
      await folder.create(recursive: true);
      await File(p.join(folder.path, 'stale.bin')).writeAsString('old');
      await download(_server(body: zip));
      expect(await weights().exists(), isTrue);
      expect(await File(p.join(folder.path, 'stale.bin')).exists(), isFalse);
    });

    test('a zip an earlier build left whole or in part is removed', () async {
      final whole = File(p.join(dir.path, 'detector.coreml.zip'));
      final part = File('${whole.path}.part');
      await whole.writeAsBytes(zip);
      await part.writeAsBytes(zip.sublist(0, 10));
      await download(_server(body: zip));
      expect(await whole.exists(), isFalse);
      expect(await part.exists(), isFalse);
      expect(await weights().exists(), isTrue);
    });

    test('a wrong hash fails and leaves nothing unpacked', () async {
      await expectLater(
        download(
          _server(body: zip),
          file: model(sha: 'b' * 64),
        ),
        failsWith(PackDownloadFailure.checksumMismatch),
      );
      expect(await folder.exists(), isFalse);
      expect(await partFolder().exists(), isFalse);
    });

    test('a body that ends short fails and leaves nothing to resume', () async {
      await expectLater(
        download(_server(body: zip.sublist(0, zip.length - 50))),
        failsWith(PackDownloadFailure.network),
      );
      expect(await folder.exists(), isFalse);
      expect(await partFolder().exists(), isFalse);
    });

    test('more bytes than the manifest says fails', () async {
      await expectLater(
        download(_server(body: [...zip, 1, 2, 3])),
        failsWith(PackDownloadFailure.sizeMismatch),
      );
      expect(await partFolder().exists(), isFalse);
    });

    test('cancelling leaves nothing unpacked', () async {
      var chunks = 0;
      await expectLater(
        download(
          _server(body: zip),
          onProgress: (_) => chunks++,
          isCancelled: () => chunks >= 2,
        ),
        failsWith(PackDownloadFailure.cancelled),
      );
      expect(await partFolder().exists(), isFalse);
    });

    test('a broken connection leaves nothing unpacked', () async {
      await expectLater(
        download(
          _server(body: zip, failAfterFirstChunk: const SocketException('x')),
        ),
        failsWith(PackDownloadFailure.network),
      );
      expect(await partFolder().exists(), isFalse);
    });

    test('a file that is not a zip is malformed', () async {
      final html = utf8.encode('<html>${'x' * 200}</html>');
      await expectLater(
        download(
          _server(body: html),
          file: model(sha: sha256.convert(html).toString(), size: html.length),
        ),
        failsWith(PackDownloadFailure.malformed),
      );
      expect(await folder.exists(), isFalse);
      expect(await partFolder().exists(), isFalse);
    });

    test('a server error is an http failure', () async {
      await expectLater(
        download(MockClient((_) async => http.Response('nope', 500))),
        failsWith(PackDownloadFailure.httpStatus),
      );
    });

    test('a folder that cannot be written is a storage failure', () async {
      final notADir = File(p.join(dir.path, 'plain-file'));
      await notADir.writeAsString('x');
      folder = Directory(p.join(notADir.path, 'detector'));
      await expectLater(
        download(_server(body: zip)),
        failsWith(PackDownloadFailure.storage),
      );
    });
  });

  group('SpeciesPackManifestClient', () {
    final manifestUrl = Uri.parse('https://example.test/pack/manifest.json');

    test('a manifest served with no charset is read as UTF-8', () async {
      final body = utf8.encode(
        manifestJson(
          (m) => m['credits'] = [
            {'name': 'Détecteur', 'licence': 'MIT', 'text': 'Ré'},
          ],
        ),
      );
      final client = SpeciesPackManifestClient(
        client: MockClient(
          (_) async => http.Response.bytes(
            body,
            200,
            headers: {'content-type': 'application/octet-stream'},
          ),
        ),
        url: manifestUrl,
      );
      expect((await client.fetch())!.credits.single.name, 'Détecteur');
    });

    test('nothing published reads as null', () async {
      final client = SpeciesPackManifestClient(
        client: MockClient((_) async => http.Response('', 404)),
        url: manifestUrl,
      );
      expect(await client.fetch(), isNull);
    });

    test('a server error throws', () async {
      final client = SpeciesPackManifestClient(
        client: MockClient((_) async => http.Response('', 503)),
        url: manifestUrl,
      );
      await expectLater(
        client.fetch(),
        failsWith(PackDownloadFailure.httpStatus),
      );
    });

    test('a newer format asks for an app update', () async {
      final client = SpeciesPackManifestClient(
        client: MockClient(
          (_) async =>
              http.Response(manifestJson((m) => m['formatVersion'] = 9), 200),
        ),
        url: manifestUrl,
      );
      await expectLater(
        client.fetch(),
        failsWith(PackDownloadFailure.unsupportedFormat),
      );
    });

    test('a broken manifest is malformed', () async {
      final client = SpeciesPackManifestClient(
        client: MockClient((_) async => http.Response('{', 200)),
        url: manifestUrl,
      );
      await expectLater(
        client.fetch(),
        failsWith(PackDownloadFailure.malformed),
      );
    });

    test(
      'a manifest parses, keeps its text, and files sit beside it',
      () async {
        final source = manifestJson();
        final client = SpeciesPackManifestClient(
          client: MockClient((_) async => http.Response(source, 200)),
          url: manifestUrl,
        );
        final manifest = (await client.fetch())!;
        expect(manifest.packVersion, '2026.11.1');
        expect(jsonDecode(manifest.source), jsonDecode(source));
        expect(
          client.fileUrl(manifest.files.first).toString(),
          'https://example.test/pack/detector.coreml.zip',
        );
      },
    );
  });
}
