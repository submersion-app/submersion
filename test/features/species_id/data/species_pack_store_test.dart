import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/float16.dart';

import '../../../helpers/temp_dir.dart';
import '../domain/manifest_fixture.dart';

/// A pack with two candidates and three-wide embeddings.
SpeciesPackManifest _manifest(String version) => SpeciesPackManifest.parse(
  manifestJson((m) {
    m['packVersion'] = version;
    (m['classifier']! as Map)['embeddingSize'] = 3;
  }),
);

/// The same pack carrying both detectors (format 2).
SpeciesPackManifest _pairManifest(String version) => SpeciesPackManifest.parse(
  manifestV2Json((m) {
    m['packVersion'] = version;
    (m['classifier']! as Map)['embeddingSize'] = 3;
  }),
);

Uint8List _zipOf(String folder) {
  final archive = Archive()
    ..addFile(
      ArchiveFile.bytes('$folder/Manifest.json', utf8.encode('{"model": 1}')),
    )
    ..addFile(ArchiveFile.bytes('$folder/Data/weights.bin', Uint8List(16)));
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

/// A zip of one stored (uncompressed) file whose headers claim [claimed]
/// bytes while it holds [actual]: what a model looks like when it did not
/// unpack in full.
Uint8List _zipClaiming(
  String name, {
  required int actual,
  required int claimed,
}) {
  final archive = Archive()
    ..addFile(ArchiveFile.noCompress(name, actual, Uint8List(actual)));
  final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(archive));
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i + 4 <= bytes.length; i++) {
    final signature = data.getUint32(i, Endian.little);
    if (signature == 0x04034b50) data.setUint32(i + 22, claimed, Endian.little);
    if (signature == 0x02014b50) data.setUint32(i + 24, claimed, Endian.little);
  }
  return bytes;
}

void main() {
  late Directory support;
  late List<String> excluded;
  late SpeciesPackStore store;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('pack_store_test');
    excluded = [];
    store = SpeciesPackStore(
      supportPath: () async => support.path,
      engine: 'coreml',
      excludeFromBackup: (dir) async => excluded.add(dir),
    );
  });
  tearDown(() => deleteTempDir(support));

  /// Writes every file of [manifest] into staging, as the downloader would.
  Future<void> stage(
    SpeciesPackManifest manifest, {
    int embeddingValues = 6,
  }) async {
    final dir = await store.staging(manifest.packVersion);
    for (final detector in manifest.detectors) {
      File(
        p.join(
          dir.path,
          SpeciesPackManifest.modelFile(detector.file, 'coreml'),
        ),
      ).writeAsBytesSync(_zipOf('${detector.file}.mlpackage'));
    }
    File(
      p.join(dir.path, 'classifier.coreml.zip'),
    ).writeAsBytesSync(_zipOf('classifier.mlpackage'));
    File(p.join(dir.path, 'candidates.json')).writeAsStringSync(
      jsonEncode([
        {
          'gbifKey': 1,
          'scientificName': 'Scarus vetula',
          'commonName': 'Queen Parrotfish',
          'category': 'fish',
          'catalogId': 'sp_queen_parrotfish',
        },
        {
          'gbifKey': 2,
          'scientificName': 'Chromis multilineata',
          'commonName': 'Brown Chromis',
          'category': 'fish',
        },
      ]),
    );
    File(p.join(dir.path, 'text_embeddings.f16')).writeAsBytesSync(
      encodeFloat16(
        Float32List.fromList(List.generate(embeddingValues, (i) => i / 10)),
      ),
    );
    // 5 degree cells: 2592 of them, 324 bytes a row. Candidate 0 is
    // recorded in cell 0 only.
    final regions = Uint8List(2 * 324)..[0] = 1;
    File(p.join(dir.path, 'regions.bin')).writeAsBytesSync(regions);
  }

  test('nothing is installed at first', () async {
    expect(await store.installed(), isNull);
    expect(await store.sizeBytes(), 0);
  });

  test('an installed pack has its models unpacked where it says', () async {
    final manifest = _manifest('2026.11.1');
    await stage(manifest);
    final pack = await store.install(manifest);

    expect(pack.manifest.packVersion, '2026.11.1');
    expect(p.basename(pack.detectorPaths.single), 'detector.mlpackage');
    expect(p.basename(pack.classifierPath), 'classifier.mlpackage');
    expect(
      await File(p.join(pack.detectorPaths.single, 'Manifest.json')).exists(),
      isTrue,
    );
    expect(await store.installed(), pack);
    expect(excluded, [(await store.root()).path]);
    expect(
      await Directory(
        p.join((await store.root()).path, '2026.11.1.staging'),
      ).exists(),
      isFalse,
    );
    expect(await store.sizeBytes(), greaterThan(0));
  });

  test('a compiled model beside the package is preferred', () async {
    final manifest = _manifest('2026.11.1');
    await stage(manifest);
    final pack = await store.install(manifest);
    final compiled = Directory(
      p.join(p.dirname(pack.detectorPaths.single), 'detector.mlmodelc'),
    );
    await compiled.create();
    expect(
      p.basename((await store.installed())!.detectorPaths.single),
      'detector.mlmodelc',
    );
  });

  test('installing a newer pack removes the older one', () async {
    final first = _manifest('2026.11.1');
    await stage(first);
    await store.install(first);
    final second = _manifest('2026.12.1');
    await stage(second);
    await store.install(second);

    final versions = (await store.root())
        .listSync()
        .map((e) => p.basename(e.path))
        .toList();
    expect(versions, ['2026.12.1']);
    expect((await store.installed())!.manifest.packVersion, '2026.12.1');
  });

  test('removing clears the pack', () async {
    final manifest = _manifest('2026.11.1');
    await stage(manifest);
    await store.install(manifest);
    await store.remove();
    expect(await store.installed(), isNull);
  });

  test('loading reads candidates, embeddings and regions', () async {
    final manifest = _manifest('2026.11.1');
    await stage(manifest);
    final loaded = await store.load(await store.install(manifest));

    expect(loaded.candidates.map((c) => c.gbifKey), [1, 2]);
    expect(loaded.textEmbeddings, hasLength(6));
    expect(loaded.textEmbeddings[1], closeTo(0.1, 1e-3));
    expect(loaded.regions.recorded(0, 0), isTrue);
    expect(loaded.regions.recorded(1, 0), isFalse);
  });

  test(
    'an embedding table that does not fit the candidates is refused',
    () async {
      final manifest = _manifest('2026.11.1');
      await stage(manifest, embeddingValues: 5);
      final pack = await store.install(manifest);
      await expectLater(
        store.load(pack),
        throwsA(isA<PackManifestException>()),
      );
    },
  );

  test('a model that does not unpack to the size its zip records is not '
      'installed', () async {
    final manifest = _manifest('2026.11.1');
    await stage(manifest);
    final dir = await store.staging(manifest.packVersion);
    File(p.join(dir.path, 'detector.coreml.zip')).writeAsBytesSync(
      _zipClaiming(
        'detector.mlpackage/Data/weights.bin',
        actual: 16,
        claimed: 32,
      ),
    );
    await expectLater(
      store.install(manifest),
      throwsA(isA<PackManifestException>()),
    );
    expect(await store.installed(), isNull);
  });

  test('a zip entry that would land outside the model folder is '
      'refused', () async {
    final manifest = _manifest('2026.11.1');
    await stage(manifest);
    final dir = await store.staging(manifest.packVersion);
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('../escaped.bin', Uint8List(4)));
    File(
      p.join(dir.path, 'detector.coreml.zip'),
    ).writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    await expectLater(
      store.install(manifest),
      throwsA(isA<PackManifestException>()),
    );
    expect(await File(p.join(dir.path, 'escaped.bin')).exists(), isFalse);
    expect(await store.installed(), isNull);
  });

  test(
    'a download is kept out of device backups from its first file',
    () async {
      await store.staging('2026.11.1');
      expect(excluded, [(await store.root()).path]);
    },
  );

  test('a pack whose model is missing is not installed', () async {
    final manifest = _manifest('2026.11.1');
    await stage(manifest);
    final pack = await store.install(manifest);
    await Directory(pack.classifierPath).delete(recursive: true);
    expect(await store.installed(), isNull);
  });

  test('a pair pack unpacks each detector into its own folder', () async {
    final manifest = _pairManifest('2026.11.2');
    await stage(manifest);
    final pack = await store.install(manifest);

    expect(pack.detectorPaths, hasLength(2));
    expect(p.basename(p.dirname(pack.detectorPaths[0])), 'detector');
    expect(p.basename(pack.detectorPaths[0]), 'detector.mlpackage');
    expect(p.basename(p.dirname(pack.detectorPaths[1])), 'detector-megalodon');
    expect(p.basename(pack.detectorPaths[1]), 'detector-megalodon.mlpackage');
    expect(await store.installed(), pack);
  });

  test('a pair pack missing its second model is not installed', () async {
    final manifest = _pairManifest('2026.11.2');
    await stage(manifest);
    final pack = await store.install(manifest);
    await Directory(pack.detectorPaths[1]).delete(recursive: true);
    expect(await store.installed(), isNull);
  });
}
