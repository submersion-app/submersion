import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:submersion/core/platform/zlib/platform_zlib.dart';
import 'package:submersion/features/demo_mode/data/bundled_demo.dart';
import 'package:submersion/features/demo_mode/data/demo_downloader.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';

final _index = Uri.parse('https://dive.example/log/demo/demo.json');

String _indexJson({int schema = 327, int compressedSize = 9}) => jsonEncode({
  'formatVersion': 1,
  'schemaVersion': schema,
  'generatedAt': '2026-10-30T17:31:51.882927Z',
  'database': {
    'path': 'submersion_demo.db.gz',
    'size': 24,
    'sha256': 'c' * 64,
    'compressedSize': compressedSize,
  },
  'photos': ['photos/reef.jpg'],
});

/// A browser's sample logbook ships inside the site (issue #4121): the
/// client reads the index beside it, and the installer fetches the gzipped
/// database, checks it and installs it as a browser database.
void main() {
  group('BundledDemoManifestClient', () {
    BundledDemoManifestClient clientServing(
      Future<http.Response> Function(http.Request) handler,
    ) => BundledDemoManifestClient(client: MockClient(handler), index: _index);

    test('offers the database the site ships', () async {
      Uri? asked;
      final package = await clientServing((request) async {
        asked = request.url;
        return http.Response(_indexJson(), 200);
      }).fetchBest(337);

      expect(asked, _index);
      expect(
        package,
        DemoPackage(
          schemaVersion: 327,
          url: Uri.parse('https://dive.example/log/demo/submersion_demo.db.gz'),
          sha256: 'c' * 64,
          size: 9,
          generatedAt: DateTime.utc(2026, 10, 30, 17, 31, 51, 882, 927),
        ),
      );
    });

    test('offers nothing a newer app built', () async {
      expect(
        await clientServing(
          (_) async => http.Response(_indexJson(schema: 400), 200),
        ).fetchBest(337),
        isNull,
      );
    });

    test('offers nothing when the site ships no sample logbook', () async {
      expect(
        await clientServing(
          (_) async => http.Response('not found', 404),
        ).fetchBest(337),
        isNull,
      );
      expect(
        await clientServing(
          (_) async => http.Response('{"formatVersion": 1}', 200),
        ).fetchBest(337),
        isNull,
      );
    });
  });

  group('BundledDemoPackageInstaller', () {
    final database = Uint8List.fromList(utf8.encode('SQLite format 3 sample'));
    final packed = PlatformZlib.gzip(database);
    const paths = DemoPaths('/opfs/support');

    DemoPackage packageFor({String? sha, int? size}) => DemoPackage(
      schemaVersion: 327,
      url: Uri.parse('https://dive.example/log/demo/submersion_demo.db.gz'),
      sha256: sha ?? sha256.convert(database).toString(),
      size: size ?? packed.length,
      generatedAt: DateTime.utc(2026, 10, 30),
    );

    test('fetches, inflates, checks and installs the database', () async {
      final installed = <(String, Uint8List)>[];
      final downloads = <(int, int)>[];
      final unpacks = <(int, int)>[];
      final installer = BundledDemoPackageInstaller(
        client: MockClient((_) async => http.Response.bytes(packed, 200)),
        photosUrl: Uri.parse('https://dive.example/log/demo/photos/'),
        installImage: (path, image) async => installed.add((path, image)),
      );

      await installer.install(
        packageFor(),
        paths,
        onDownload: (done, total) => downloads.add((done, total)),
        onUnpack: (done, total) => unpacks.add((done, total)),
      );

      expect(installed.single.$1, paths.databaseFile);
      expect(installed.single.$2, database);
      expect(downloads.last, (packed.length, packed.length));
      expect(unpacks.first, (0, 0));
      expect(
        installer.photosUrl,
        Uri.parse('https://dive.example/log/demo/photos/'),
      );
    });

    Future<DemoDownloadFailure> failureOf(
      BundledDemoPackageInstaller installer,
      DemoPackage package, {
      bool Function()? isCancelled,
    }) async {
      try {
        await installer.install(package, paths, isCancelled: isCancelled);
      } on DemoDownloadException catch (e) {
        return e.reason;
      }
      fail('the install went through');
    }

    BundledDemoPackageInstaller serving(
      http.Response response, {
      List<Uint8List>? installed,
    }) => BundledDemoPackageInstaller(
      client: MockClient((_) async => response),
      photosUrl: Uri.parse('https://dive.example/log/demo/photos/'),
      installImage: (_, image) async => installed?.add(image),
    );

    test('a database that does not match is never installed', () async {
      final installed = <Uint8List>[];
      expect(
        await failureOf(
          serving(http.Response.bytes(packed, 200), installed: installed),
          packageFor(sha: 'd' * 64),
        ),
        DemoDownloadFailure.checksumMismatch,
      );
      expect(installed, isEmpty);
    });

    test('a download of the wrong size is refused', () async {
      expect(
        await failureOf(
          serving(http.Response.bytes(packed, 200)),
          packageFor(size: packed.length + 1),
        ),
        DemoDownloadFailure.sizeMismatch,
      );
    });

    test('an error status is refused', () async {
      expect(
        await failureOf(serving(http.Response('gone', 404)), packageFor()),
        DemoDownloadFailure.httpStatus,
      );
    });

    test('Cancel stops it before anything is installed', () async {
      final installed = <Uint8List>[];
      expect(
        await failureOf(
          serving(http.Response.bytes(packed, 200), installed: installed),
          packageFor(),
          isCancelled: () => true,
        ),
        DemoDownloadFailure.cancelled,
      );
      expect(installed, isEmpty);
    });
  });
}
