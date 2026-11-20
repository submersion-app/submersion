import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as p;
import 'package:submersion_vision/src/ort/ort_release.dart';

import '../hook/build.dart' as hook;

/// The build hook's library step: the pinned archive is downloaded and read
/// only when a library is missing or changed, and every file is checked
/// against its pin.
void main() {
  late Directory shared;
  final library = [1, 2, 3, 4];
  final zip = ZipEncoder().encode(
    Archive()..addFile(ArchiveFile('lib/libort.so', library.length, library)),
  );

  OrtArchive archive({List<int>? zipBytes}) => OrtArchive(
    url: 'https://example.org/ort.zip',
    sha256: sha256.convert(zipBytes ?? zip).toString(),
    libraries: [
      OrtLibrary(
        assetName: 'src/ort/ort_native.dart',
        entry: 'lib/libort.so',
        sha256: sha256.convert(library).toString(),
      ),
    ],
  );

  setUp(() => shared = Directory.systemTemp.createTempSync('ort_hook_'));
  tearDown(() => shared.deleteSync(recursive: true));

  test('a library already in place needs no download', () async {
    Directory(p.join(shared.path, 'linux-x64')).createSync();
    File(
      p.join(shared.path, 'linux-x64', 'libort.so'),
    ).writeAsBytesSync(library);

    final files = await hook.ensureLibraries(
      archive(),
      shared,
      'linux-x64',
      fetch: (url, to) async => fail('nothing should be downloaded'),
    );

    expect(files.single.$2.readAsBytesSync(), library);
  });

  test('a missing library is taken out of the downloaded archive', () async {
    final fetched = <String>[];

    final files = await hook.ensureLibraries(
      archive(),
      shared,
      'linux-x64',
      fetch: (url, to) async {
        fetched.add(url);
        await to.writeAsBytes(zip);
      },
    );

    expect(fetched, ['https://example.org/ort.zip']);
    expect(files.single.$2.readAsBytesSync(), library);
    expect(
      shared.listSync(recursive: true).where((f) => f.path.endsWith('.part')),
      isEmpty,
    );
  });

  test(
    'a download that does not match its pin fails and is not kept',
    () async {
      await expectLater(
        hook.ensureLibraries(
          archive(),
          shared,
          'linux-x64',
          fetch: (url, to) async => to.writeAsBytes([9, 9, 9]),
        ),
        throwsA(isA<BuildError>()),
      );
      expect(File(p.join(shared.path, 'ort.zip')).existsSync(), isFalse);
    },
  );

  test('temporary files are named for the process, so two builds at once '
      'never share one', () {
    final target = File(p.join(shared.path, 'ort.zip'));
    expect(hook.partFile(target).path, '${target.path}.$pid.part');
  });
}
