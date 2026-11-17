import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';

import 'manifest_fixture.dart';

void main() {
  group('SpeciesPackManifest.parse', () {
    test('parses the spec manifest', () {
      final m = SpeciesPackManifest.parse(manifestJson());

      expect(m.formatVersion, 1);
      expect(m.packVersion, '2026.11.1');
      expect(m.detector.id, 'cfd-rfdetr-nano-640-20260706');
      expect(m.detector.inputSize, 640);
      expect(m.detector.mean, [0.485, 0.456, 0.406]);
      expect(m.detector.scoreThreshold, 0.3);
      expect(m.detector.maxBoxes, 8);
      expect(m.detector.cropPadding, 0.10);
      expect(m.classifier.id, 'bioclip-2-vitl14-2957b32');
      expect(m.classifier.embeddingSize, 768);
      expect(m.classifier.logitScale, 100.0);
      expect(m.naming.provisional, isTrue);
      expect(m.naming.minCropSide, 64);
      expect(m.naming.minOpenScore, 0.15);
      expect(m.naming.suggestScore, 0.50);
      expect(m.naming.confidentScore, 0.70);
      expect(m.naming.suggestScoreNoLocation, 0.70);
      expect(m.naming.minAllowedCandidates, 200);
      expect(m.naming.topK, 5);
      expect(m.region.cellDegrees, 5);
      expect(m.region.neighbourCells, 1);
      expect(m.cropThumbnailSize, 320);
      expect(m.files, hasLength(5));
      expect(m.credits.single.name, 'BioCLIP 2');
      expect(m.credits.single.licence, 'MIT');
    });

    test('an unknown format version is refused', () {
      expect(
        () => SpeciesPackManifest.parse(
          manifestJson((m) => m['formatVersion'] = 2),
        ),
        throwsA(
          isA<PackManifestException>().having(
            (e) => e.reason,
            'reason',
            PackManifestFailure.unsupportedFormat,
          ),
        ),
      );
    });

    test('text that is not JSON is malformed', () {
      expect(
        () => SpeciesPackManifest.parse('not json'),
        throwsA(
          isA<PackManifestException>().having(
            (e) => e.reason,
            'reason',
            PackManifestFailure.malformed,
          ),
        ),
      );
    });

    test('a bad hash is malformed', () {
      expect(
        () => SpeciesPackManifest.parse(
          manifestJson((m) {
            final files = (m['files']! as List).cast<Map<String, Object?>>();
            files.first['sha256'] = 'XYZ';
          }),
        ),
        throwsA(isA<PackManifestException>()),
      );
    });

    test('a zero size is malformed', () {
      expect(
        () => SpeciesPackManifest.parse(
          manifestJson((m) {
            final files = (m['files']! as List).cast<Map<String, Object?>>();
            files.first['size'] = 0;
          }),
        ),
        throwsA(isA<PackManifestException>()),
      );
    });

    test('a missing naming block is malformed', () {
      expect(
        () =>
            SpeciesPackManifest.parse(manifestJson((m) => m.remove('naming'))),
        throwsA(isA<PackManifestException>()),
      );
    });

    test('a file name with a path separator is malformed', () {
      expect(
        () => SpeciesPackManifest.parse(
          manifestJson((m) {
            final files = (m['files']! as List).cast<Map<String, Object?>>();
            files.first['name'] = '../detector.coreml.zip';
          }),
        ),
        throwsA(isA<PackManifestException>()),
      );
    });
  });

  group('files for an engine', () {
    final m = SpeciesPackManifest.parse(manifestJson());

    test('are its own and the shared ones', () {
      expect(
        m.filesFor('coreml').map((f) => f.name),
        unorderedEquals([
          'detector.coreml.zip',
          'classifier.coreml.zip',
          'candidates.json',
          'text_embeddings.f16',
          'regions.bin',
        ]),
      );
      expect(
        m.downloadBytesFor('coreml'),
        55000000 + 600000000 + 1000000 + 12000000 + 2000000,
      );
    });

    test('an engine the pack has no models for is not supported', () {
      expect(m.supportsEngine('coreml'), isTrue);
      expect(m.supportsEngine('onnx'), isFalse);
      expect(
        m.filesFor('onnx').map((f) => f.name),
        unorderedEquals([
          'candidates.json',
          'text_embeddings.f16',
          'regions.bin',
        ]),
      );
    });

    test('the model file names follow the engine', () {
      expect(SpeciesPackManifest.detectorFile('coreml'), 'detector.coreml.zip');
      expect(
        SpeciesPackManifest.classifierFile('coreml'),
        'classifier.coreml.zip',
      );
    });
  });

  group('candidates', () {
    test('parse in order, with and without a catalogue id', () {
      final list = parseCandidates(
        jsonEncode([
          {
            'gbifKey': 2398623,
            'scientificName': 'Abudefduf saxatilis',
            'commonName': 'Sergeant Major',
            'category': 'fish',
            'catalogId': 'sp_sergeant_major',
          },
          {
            'gbifKey': 2394345,
            'scientificName': 'Chromis multilineata',
            'commonName': 'Brown Chromis',
            'category': 'fish',
          },
        ]),
      );

      expect(list, hasLength(2));
      expect(list[0].gbifKey, 2398623);
      expect(list[0].catalogId, 'sp_sergeant_major');
      expect(list[0].category, SpeciesCategory.fish);
      expect(list[1].catalogId, isNull);
      expect(list[1].commonName, 'Brown Chromis');
    });

    test('an unknown category is other', () {
      final c = PackCandidate.fromJson({
        'gbifKey': 1,
        'scientificName': 'X y',
        'commonName': 'X',
        'category': 'sponge-like',
      });
      expect(c.category, SpeciesCategory.other);
    });

    test('a named candidate round trips through JSON', () {
      const named = NamedCandidate(
        candidate: PackCandidate(
          gbifKey: 7,
          scientificName: 'Scarus vetula',
          commonName: 'Queen Parrotfish',
          category: SpeciesCategory.fish,
          catalogId: 'sp_queen_parrotfish',
        ),
        score: 0.92,
      );
      expect(NamedCandidate.fromJson(named.toJson()), named);
    });

    test('a candidate list that is not a list is malformed', () {
      expect(
        () => parseCandidates('{}'),
        throwsA(isA<PackManifestException>()),
      );
    });
  });
}
