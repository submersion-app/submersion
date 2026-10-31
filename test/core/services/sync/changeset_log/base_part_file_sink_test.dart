import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_file_sink.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_hasher.dart';
import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/utils/off_isolate.dart';

import '../../../../helpers/recording_base_part_hasher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late BasePartFileSink sink;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('base_sink_test');
    sink = BasePartFileSink(tempDirProvider: () async => dir);
  });
  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  Uint8List bytes(String s) => Uint8List.fromList(s.codeUnits);

  test('assembles parts into one file and returns its path', () async {
    final p0 = bytes('hello ');
    final p1 = bytes('world');
    final whole = BaseChunker.checksum(bytes('hello world'));
    final path = await sink.assemble(
      name: 'base',
      partCount: 2,
      wholeChecksum: whole,
      partChecksums: [BaseChunker.checksum(p0), BaseChunker.checksum(p1)],
      downloadPart: (i) async => [p0, p1][i],
    );
    expect(path, isNotNull);
    expect(await File(path!).readAsString(), 'hello world');
  });

  test(
    'returns null and deletes the file on a per-part checksum mismatch',
    () async {
      final p0 = bytes('hello ');
      final p1 = bytes('world');
      final path = await sink.assemble(
        name: 'base',
        partCount: 2,
        wholeChecksum: null,
        partChecksums: [BaseChunker.checksum(p0), 'sha256:deadbeef'],
        downloadPart: (i) async => [p0, p1][i],
      );
      expect(path, isNull);
      expect(dir.listSync().whereType<File>(), isEmpty);
    },
  );

  test('returns null when a part is missing', () async {
    final p0 = bytes('hello ');
    final path = await sink.assemble(
      name: 'base',
      partCount: 2,
      wholeChecksum: null,
      partChecksums: [BaseChunker.checksum(p0), 'sha256:whatever'],
      downloadPart: (i) async => i == 0 ? p0 : null,
    );
    expect(path, isNull);
    expect(dir.listSync().whereType<File>(), isEmpty);
  });

  test('returns null on a whole-file checksum mismatch', () async {
    final p0 = bytes('hello ');
    final p1 = bytes('world');
    final path = await sink.assemble(
      name: 'base',
      partCount: 2,
      wholeChecksum: 'sha256:notreal',
      partChecksums: [BaseChunker.checksum(p0), BaseChunker.checksum(p1)],
      downloadPart: (i) async => [p0, p1][i],
    );
    expect(path, isNull);
    expect(dir.listSync().whereType<File>(), isEmpty);
  });

  test('verifies whole-file checksum across many parts', () async {
    final parts = List.generate(10, (i) => bytes('chunk$i-'));
    final joined = bytes(parts.map((p) => String.fromCharCodes(p)).join());
    final path = await sink.assemble(
      name: 'multi',
      partCount: parts.length,
      wholeChecksum: BaseChunker.checksum(joined),
      partChecksums: parts.map(BaseChunker.checksum).toList(),
      downloadPart: (i) async => parts[i],
    );
    expect(path, isNotNull);
    expect(await File(path!).readAsBytes(), joined);
  });

  test('deleteQuietly removes a file and never throws', () async {
    final f = File('${dir.path}/x');
    await f.writeAsString('y');
    await sink.deleteQuietly(f.path);
    expect(f.existsSync(), isFalse);
    await sink.deleteQuietly('${dir.path}/does-not-exist'); // no throw
  });

  // Issue #1327: the temp path was built by interpolating a literal '/' into
  // a directory that is backslashed on Windows, producing the exact
  // mixed-separator shape that killed every Windows base publish in #1304 once
  // something split it on Platform.pathSeparator. Nothing splits these paths
  // today, so the bug was latent -- these tests keep it that way by pinning the
  // Windows style, which is the only way a POSIX CI host can see the
  // difference at all.
  group('temp path construction (#1327)', () {
    final windows = p.Context(style: p.Style.windows);

    test('joins with the platform separator, never a literal /', () {
      final path = basePartTempPath(
        r'C:\Users\diver\AppData\Local\Temp',
        'ssv1_base_devA_7',
        'a1b2c3',
        context: windows,
      );
      expect(
        path,
        r'C:\Users\diver\AppData\Local\Temp\ssv1_base_devA_7.a1b2c3.base',
      );
      expect(path, isNot(contains('/')));
    });

    test('survives the #1304 basename split on Windows', () {
      final path = basePartTempPath(
        r'C:\Users\diver\AppData\Local\Temp',
        'ssv1_base_devA_7',
        'a1b2c3',
        context: windows,
      );
      // The #1304 consumer pattern: split on the Windows separator only. With
      // a mixed path this yielded 'Temp/ssv1_base_devA_7.a1b2c3.base'.
      expect(path.split(r'\').last, 'ssv1_base_devA_7.a1b2c3.base');
      expect(windows.basename(path), 'ssv1_base_devA_7.a1b2c3.base');
    });

    test('defaults to the host context', () {
      final path = basePartTempPath('/tmp/sync', 'base', 'u');
      expect(path, p.join('/tmp/sync', 'base.u.base'));
    });

    test(
      'assemble returns a path the host context accepts as joined',
      () async {
        final part = bytes('payload');
        final path = await sink.assemble(
          name: 'ssv1_base_devA_7',
          partCount: 1,
          wholeChecksum: BaseChunker.checksum(part),
          partChecksums: [BaseChunker.checksum(part)],
          downloadPart: (_) async => part,
        );
        expect(path, isNotNull);
        expect(p.dirname(path!), dir.path);
        expect(p.basename(path), startsWith('ssv1_base_devA_7.'));
        expect(p.basename(path), endsWith('.base'));
      },
    );
  });

  // Issue #509: with no injected temp dir, the sink must default to the
  // app-container temp dir (path_provider's getTemporaryDirectory), NOT
  // Directory.systemTemp (/tmp on macOS, where a hardened-runtime app is
  // denied -> PathAccessException errno 1).
  group('default temp dir', () {
    late Directory fakeAppTemp;

    setUpAll(() async {
      fakeAppTemp = await Directory.systemTemp.createTemp('app_temp_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => call.method == 'getTemporaryDirectory'
                ? fakeAppTemp.path
                : null,
          );
    });

    tearDownAll(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      if (fakeAppTemp.existsSync()) await fakeAppTemp.delete(recursive: true);
    });

    test(
      'assemble writes into the app-container temp dir by default',
      () async {
        final defaultSink = BasePartFileSink(); // no injected dir
        final path = await defaultSink.assemble(
          name: 'ssv1_base_dev_0',
          partCount: 1,
          wholeChecksum: null,
          partChecksums: const [],
          downloadPart: (_) async => Uint8List.fromList([1, 2, 3]),
        );
        expect(path, isNotNull);
        expect(
          path!.startsWith(fakeAppTemp.path),
          isTrue,
          reason: 'must not fall back to /tmp (systemTemp)',
        );
        await defaultSink.deleteQuietly(path);
      },
    );
  });

  test('reports each part as it lands, as (downloaded, total)', () async {
    final parts = [bytes('a'), bytes('b'), bytes('c')];
    final seen = <(int, int)>[];
    final path = await sink.assemble(
      name: 'base',
      partCount: 3,
      wholeChecksum: null,
      partChecksums: [for (final p in parts) BaseChunker.checksum(p)],
      downloadPart: (i) async => parts[i],
      onPartDownloaded: (downloaded, total) => seen.add((downloaded, total)),
    );
    expect(path, isNotNull);
    expect(seen, [(1, 3), (2, 3), (3, 3)]);
  });
  group('what a failed assemble means', () {
    final part = bytes('payload');

    Future<String?> assembling(
      Future<Uint8List?> Function(int index) downloadPart, {
      BasePartFileSink? using,
      int partCount = 1,
      String? wholeChecksum,
    }) => (using ?? sink).assemble(
      name: 'ssv1_x',
      partCount: partCount,
      wholeChecksum: wholeChecksum,
      partChecksums: const [],
      downloadPart: downloadPart,
    );

    test('a part the cloud lacks returns null', () async {
      expect(await assembling((_) async => null), isNull);
      expect(dir.listSync(), isEmpty);
    });

    test('a part that fails its digest returns null', () async {
      final path = await sink.assemble(
        name: 'ssv1_x',
        partCount: 1,
        wholeChecksum: null,
        partChecksums: const ['sha256:not-it'],
        downloadPart: (_) async => part,
      );
      expect(path, isNull);
      expect(dir.listSync(), isEmpty);
    });

    test('a whole file that fails its digest returns null', () async {
      expect(
        await assembling((_) async => part, wholeChecksum: 'sha256:not-it'),
        isNull,
      );
      expect(dir.listSync(), isEmpty);
    });

    test('a corrupt envelope returns null', () async {
      expect(
        await assembling(
          (_) async => throw const EnvelopeCorruptException('bad'),
        ),
        isNull,
      );
      expect(dir.listSync(), isEmpty);
    });

    test('a key this device lacks returns null', () async {
      expect(
        await assembling(
          (_) async => throw const SyncEncryptionRequired(message: 'locked'),
        ),
        isNull,
      );
      expect(dir.listSync(), isEmpty);
    });

    test('a download error is an interruption, not a null', () async {
      const dropped = CloudStorageException('connection lost');
      await expectLater(
        assembling((_) async => throw dropped),
        throwsA(
          isA<BaseFetchInterrupted>().having(
            (e) => e.cause,
            'cause',
            same(dropped),
          ),
        ),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('a refused download comes out as itself', () async {
      const refused = CloudAccessRefusedException('refused');
      await expectLater(
        assembling((_) async => throw refused),
        throwsA(same(refused)),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('a hasher failure is an interruption', () async {
      final failing = BasePartFileSink(
        tempDirProvider: () async => dir,
        openHasher: (_) async => RecordingBasePartHasher(failOnPart: 0),
      );
      await expectLater(
        assembling((_) async => part, using: failing),
        throwsA(
          isA<BaseFetchInterrupted>().having(
            (e) => e.cause,
            'cause',
            isA<BasePartHasherException>(),
          ),
        ),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('a hasher that fails on finish is an interruption', () async {
      final failing = BasePartFileSink(
        tempDirProvider: () async => dir,
        openHasher: (_) async => RecordingBasePartHasher(failOnFinish: true),
      );
      await expectLater(
        assembling(
          (_) async => part,
          using: failing,
          wholeChecksum: 'sha256:whole',
        ),
        throwsA(isA<BaseFetchInterrupted>()),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('a temp dir that cannot be resolved is an interruption', () async {
      final noDir = BasePartFileSink(
        tempDirProvider: () async => throw const FileSystemException('no dir'),
      );
      await expectLater(
        assembling((_) async => part, using: noDir),
        throwsA(isA<BaseFetchInterrupted>()),
      );
    });

    test('a temp file that cannot be written is an interruption', () async {
      final unwritable = BasePartFileSink(
        tempDirProvider: () async => Directory(p.join(dir.path, 'gone')),
      );
      await expectLater(
        assembling((_) async => part, using: unwritable),
        throwsA(
          isA<BaseFetchInterrupted>().having(
            (e) => e.cause,
            'cause',
            isA<FileSystemException>(),
          ),
        ),
      );
    });

    test('a missing part stays a null if the temp file fails too', () async {
      final unwritable = BasePartFileSink(
        tempDirProvider: () async => Directory(p.join(dir.path, 'gone')),
      );
      expect(
        await assembling(
          (i) async => i == 0 ? part : null,
          using: unwritable,
          partCount: 2,
        ),
        isNull,
      );
    });

    test('no whole-file digest was promised, so none is computed', () async {
      final finishFails = BasePartFileSink(
        tempDirProvider: () async => dir,
        openHasher: (_) async => RecordingBasePartHasher(failOnFinish: true),
      );
      expect(
        await assembling((_) async => part, using: finishFails),
        isNotNull,
      );
    });
  });

  group('through a hasher', () {
    test('a real worker verifies parts and the whole file', () async {
      final p0 = Uint8List.fromList(
        List.generate(kOffIsolateMinBytes, (i) => i % 251),
      );
      final p1 = bytes('short last part');
      final path = await sink.assemble(
        name: 'ssv1_big',
        partCount: 2,
        wholeChecksum: BaseChunker.checksum(Uint8List.fromList([...p0, ...p1])),
        partChecksums: [BaseChunker.checksum(p0), BaseChunker.checksum(p1)],
        downloadPart: (i) async => i == 0 ? p0 : p1,
      );
      expect(path, isNotNull);
      expect(File(path!).lengthSync(), p0.length + p1.length);
    });

    test('a real worker still rejects a corrupt part', () async {
      final p0 = Uint8List.fromList(
        List.generate(kOffIsolateMinBytes, (i) => i % 251),
      );
      final path = await sink.assemble(
        name: 'ssv1_big',
        partCount: 1,
        wholeChecksum: null,
        partChecksums: ['sha256:not-it'],
        downloadPart: (_) async => p0,
      );
      expect(path, isNull);
      expect(dir.listSync(), isEmpty);
    });

    test('the hasher is sized from the first part', () async {
      final opened = <int>[];
      final sized = BasePartFileSink(
        tempDirProvider: () async => dir,
        openHasher: (firstPartBytes) async {
          opened.add(firstPartBytes);
          return RecordingBasePartHasher();
        },
      );
      await sized.assemble(
        name: 'ssv1_x',
        partCount: 2,
        wholeChecksum: null,
        partChecksums: const [],
        downloadPart: (i) async => bytes(i == 0 ? 'longer' : 'short'),
      );
      expect(opened, [6]);
    });

    for (final (name, download) in <(String, Future<Uint8List?> Function(int))>[
      ('a finished transfer', (_) async => Uint8List(1)),
      ('a missing second part', (i) async => i == 0 ? Uint8List(1) : null),
      (
        'an interrupted transfer',
        (i) async =>
            i == 0 ? Uint8List(1) : throw const CloudStorageException('x'),
      ),
    ]) {
      test('$name releases the hasher', () async {
        final hasher = RecordingBasePartHasher();
        final recording = BasePartFileSink(
          tempDirProvider: () async => dir,
          openHasher: (_) async => hasher,
        );
        await recording
            .assemble(
              name: 'ssv1_x',
              partCount: 2,
              wholeChecksum: null,
              partChecksums: const [],
              downloadPart: download,
            )
            .catchError((Object _) => null);
        expect(hasher.disposals, 1);
      });
    }

    test('no hasher opens when the first part is missing', () async {
      var opens = 0;
      final recording = BasePartFileSink(
        tempDirProvider: () async => dir,
        openHasher: (_) async {
          opens++;
          return RecordingBasePartHasher();
        },
      );
      await recording.assemble(
        name: 'ssv1_x',
        partCount: 2,
        wholeChecksum: null,
        partChecksums: const [],
        downloadPart: (_) async => null,
      );
      expect(opens, 0);
    });

    test('no parts cannot satisfy a promised whole-file digest', () async {
      final path = await sink.assemble(
        name: 'ssv1_x',
        partCount: 0,
        wholeChecksum: 'sha256:not-it',
        partChecksums: const [],
        downloadPart: (_) async => null,
      );
      expect(path, isNull);
    });
  });
}
