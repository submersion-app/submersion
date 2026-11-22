import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/species_id/domain/entities/naming_level.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';

import 'manifest_fixture.dart';

void main() {
  group('SpeciesPackManifest.parse', () {
    test('parses the spec manifest', () {
      final m = SpeciesPackManifest.parse(manifestJson());

      expect(m.formatVersion, 1);
      expect(m.packVersion, '2026.11.1');
      // A format 1 pack is one fish detector, as every earlier app ran it.
      final detector = m.detectors.single;
      expect(detector.id, 'cfd-rfdetr-nano-640-20260706');
      expect(detector.format, DetectorFormat.rfdetr);
      expect(detector.file, 'detector');
      expect(detector.inputSize, 640);
      expect(detector.mean, [0.485, 0.456, 0.406]);
      expect(detector.scoreThreshold, 0.3);
      expect(detector.maxBoxes, 8);
      expect(m.boxes.cropPadding, 0.10);
      expect(m.boxes.maxBoxes, 8);
      expect(m.boxes.mergeIoU, 0.5);
      expect(m.detectorSetId, 'cfd-rfdetr-nano-640-20260706');
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
          manifestJson((m) => m['formatVersion'] = 3),
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

    test('without a no-location confident bar, the confident bar serves '
        'both', () {
      final m = SpeciesPackManifest.parse(manifestJson());

      expect(m.naming.confidentScoreNoLocation, m.naming.confidentScore);
    });

    test('an unset no-location confident bar follows the confident bar '
        'through copyWith', () {
      final naming = SpeciesPackManifest.parse(manifestJson()).naming;

      final changed = naming.copyWith(confidentScore: 0.9);

      expect(changed.confidentScoreNoLocation, 0.9);
      expect(
        changed
            .copyWith(confidentScoreNoLocation: 1.01)
            .confidentScoreNoLocation,
        1.01,
      );
    });

    test('a no-location confident bar is read, including never', () {
      final m = SpeciesPackManifest.parse(
        manifestJson((m) {
          (m['naming']! as Map<String, Object?>)['confidentScoreNoLocation'] =
              1.01;
        }),
      );

      expect(m.naming.confidentScoreNoLocation, 1.01);
      expect(m.naming.confidentScore, 0.70);
    });

    test('a no-location confident bar that is not a number is malformed', () {
      expect(
        () => SpeciesPackManifest.parse(
          manifestJson((m) {
            (m['naming']! as Map<String, Object?>)['confidentScoreNoLocation'] =
                'x';
          }),
        ),
        throwsA(isA<PackManifestException>()),
      );
    });

    test('a pack that names no crop fitting is padded to square', () {
      final m = SpeciesPackManifest.parse(manifestJson());

      expect(m.classifier.cropFit, CropFit.padSquare);
    });

    test('a pack can ask for centre crop', () {
      final m = SpeciesPackManifest.parse(
        manifestJson((m) {
          (m['classifier']! as Map<String, Object?>)['cropFit'] = 'centreCrop';
        }),
      );

      expect(m.classifier.cropFit, CropFit.centreCrop);
      expect(
        VisionModels.fromManifest(
          m,
          detectorPaths: const ['/d'],
          classifierPath: '/c',
        ).cropFit,
        CropFit.centreCrop,
      );
    });

    test('embeddings are identified by the classifier and its fitting', () {
      final m = SpeciesPackManifest.parse(manifestJson());

      expect(m.classifier.embeddingId, 'bioclip-2-vitl14-2957b32');
      expect(
        m.classifier.copyWith(cropFit: CropFit.centreCrop).embeddingId,
        'bioclip-2-vitl14-2957b32/centreCrop',
      );
    });

    test('a crop fitting this app does not know is padded to square', () {
      final m = SpeciesPackManifest.parse(
        manifestJson((m) {
          (m['classifier']! as Map<String, Object?>)['cropFit'] = 'stretch';
        }),
      );

      expect(m.classifier.cropFit, CropFit.padSquare);
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
      expect(
        SpeciesPackManifest.modelFile('detector', 'coreml'),
        'detector.coreml.zip',
      );
      expect(
        SpeciesPackManifest.modelFile('detector-megalodon', 'coreml'),
        'detector-megalodon.coreml.zip',
      );
      expect(
        SpeciesPackManifest.classifierFile('coreml'),
        'classifier.coreml.zip',
      );
    });
  });

  group('format 2, one or two detectors', () {
    Matcher malformed() => throwsA(
      isA<PackManifestException>().having(
        (e) => e.reason,
        'reason',
        PackManifestFailure.malformed,
      ),
    );

    test('parses both detectors and how their boxes are merged', () {
      final m = SpeciesPackManifest.parse(manifestV2Json());

      expect(m.formatVersion, 2);
      expect(m.detectors, hasLength(2));
      expect(m.detectors[0].id, 'cfd-rfdetr-nano-640-20260706');
      expect(m.detectors[0].format, DetectorFormat.rfdetr);
      expect(m.detectors[0].file, 'detector');
      expect(m.detectors[1].id, 'megalodon-yolo11x-403704d');
      expect(m.detectors[1].format, DetectorFormat.yolo);
      expect(m.detectors[1].file, 'detector-megalodon');
      expect(m.detectors[1].mean, [0.0, 0.0, 0.0]);
      expect(m.detectors[1].std, [1.0, 1.0, 1.0]);
      expect(m.detectors[1].scoreThreshold, 0.25);
      expect(m.detectors[1].maxBoxes, 8);
      expect(m.boxes.mergeIoU, 0.5);
      expect(m.boxes.maxBoxes, 8);
      expect(m.boxes.cropPadding, 0.10);
    });

    test('a pair is stored as both ids, in the pack order', () {
      final m = SpeciesPackManifest.parse(manifestV2Json());

      expect(
        m.detectorSetId,
        'cfd-rfdetr-nano-640-20260706+megalodon-yolo11x-403704d',
      );
    });

    test('one detector is stored as its own id', () {
      final m = SpeciesPackManifest.parse(
        manifestV2Json((m) => detectorsOf(m).removeAt(0)),
      );

      expect(m.detectors.single.format, DetectorFormat.yolo);
      expect(m.detectorSetId, 'megalodon-yolo11x-403704d');
    });

    test('no detector is malformed', () {
      expect(
        () => SpeciesPackManifest.parse(
          manifestV2Json((m) => m['detectors'] = <Object?>[]),
        ),
        malformed(),
      );
    });

    test('three detectors are malformed', () {
      expect(
        () => SpeciesPackManifest.parse(
          manifestV2Json((m) {
            final third = Map<String, Object?>.of(detectorsOf(m).last)
              ..['file'] = 'detector-third';
            (m['detectors']! as List).add(third);
          }),
        ),
        malformed(),
      );
    });

    test('a detector format this app does not know is malformed', () {
      expect(
        () => SpeciesPackManifest.parse(
          manifestV2Json((m) => detectorsOf(m).last['format'] = 'ssd'),
        ),
        malformed(),
      );
    });

    test('a detector with no format is malformed', () {
      expect(
        () => SpeciesPackManifest.parse(
          manifestV2Json((m) => detectorsOf(m).last.remove('format')),
        ),
        malformed(),
      );
    });

    test('a detector file that is not a safe name is malformed', () {
      expect(
        () => SpeciesPackManifest.parse(
          manifestV2Json((m) => detectorsOf(m).last['file'] = '../escape'),
        ),
        malformed(),
      );
    });

    test('two detectors sharing a file are malformed', () {
      expect(
        () => SpeciesPackManifest.parse(
          manifestV2Json((m) => detectorsOf(m).last['file'] = 'detector'),
        ),
        malformed(),
      );
    });

    test('a format 1 pack cannot gain a detector after parsing', () {
      final m = SpeciesPackManifest.parse(manifestJson());
      final more = m.detectors.single.copyWith(id: 'other', file: 'other');

      expect(() => m.detectors.add(more), throwsUnsupportedError);
    });

    test('a detector file must be a plain name, not a data file', () {
      for (final file in [
        'candidates.json',
        'manifest.json',
        'regions.bin',
        'detector.coreml.zip',
      ]) {
        expect(
          () => SpeciesPackManifest.parse(
            manifestV2Json((m) => detectorsOf(m).last['file'] = file),
          ),
          malformed(),
          reason: file,
        );
      }
    });

    test('detector files differing only in case are malformed', () {
      expect(
        () => SpeciesPackManifest.parse(
          manifestV2Json((m) => detectorsOf(m).last['file'] = 'Detector'),
        ),
        malformed(),
      );
      expect(
        () => SpeciesPackManifest.parse(
          manifestV2Json((m) => detectorsOf(m).last['file'] = 'Classifier'),
        ),
        malformed(),
      );
    });

    test('a detector id with a plus sign is malformed', () {
      // A pair is stored as both ids joined with a plus sign, so a single id
      // holding one could read as a pair.
      expect(
        () => SpeciesPackManifest.parse(
          manifestV2Json((m) => detectorsOf(m).last['id'] = 'a+b'),
        ),
        malformed(),
      );
      expect(
        () => SpeciesPackManifest.parse(
          manifestJson((m) => (m['detector']! as Map)['id'] = 'a+b'),
        ),
        malformed(),
      );
    });

    test('a detector named like the classifier is malformed', () {
      expect(
        () => SpeciesPackManifest.parse(
          manifestV2Json((m) => detectorsOf(m).last['file'] = 'classifier'),
        ),
        malformed(),
      );
    });

    test('no boxes block is malformed', () {
      expect(
        () =>
            SpeciesPackManifest.parse(manifestV2Json((m) => m.remove('boxes'))),
        malformed(),
      );
    });

    test('a merge overlap outside 0 to 1 is malformed', () {
      for (final value in [0, 1.5]) {
        expect(
          () => SpeciesPackManifest.parse(
            manifestV2Json((m) => (m['boxes']! as Map)['mergeIoU'] = value),
          ),
          malformed(),
        );
      }
    });

    test('every detector model is needed for an engine', () {
      final whole = SpeciesPackManifest.parse(manifestV2Json());
      expect(whole.supportsEngine('coreml'), isTrue);
      expect(
        whole.downloadBytesFor('coreml'),
        55000000 + 110000000 + 600000000 + 1000000 + 12000000 + 2000000,
      );

      final missing = SpeciesPackManifest.parse(
        manifestV2Json(
          (m) => (m['files']! as List).removeWhere(
            (f) => (f as Map)['name'] == 'detector-megalodon.coreml.zip',
          ),
        ),
      );
      expect(missing.supportsEngine('coreml'), isFalse);
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

    test('a catalogue id that is not text is malformed', () {
      expect(
        () => parseCandidates(
          '[{"gbifKey": 1, "scientificName": "Scarus vetula", "catalogId": 5}]',
        ),
        throwsA(isA<PackManifestException>()),
      );
    });

    test('a credit whose licence is not text is malformed', () {
      expect(
        () => SpeciesPackManifest.parse(
          manifestJson(
            (m) => m['credits'] = [
              {'name': 'BioCLIP 2', 'licence': 1},
            ],
          ),
        ),
        throwsA(isA<PackManifestException>()),
      );
    });

    test('a candidate list that is not a list is malformed', () {
      expect(
        () => parseCandidates('{}'),
        throwsA(isA<PackManifestException>()),
      );
    });
  });

  group('naming levels (issue #4721)', () {
    Map<String, Object?> balanced([Map<String, Object?> edit = const {}]) => {
      'id': 'balanced',
      'target': 0.75,
      'suggestScore': 0.4,
      'suggestScoreNoLocation': 0.6,
      'precision': 0.81,
      ...edit,
    };
    Map<String, Object?> eager([Map<String, Object?> edit = const {}]) => {
      'id': 'eager',
      'target': 0.65,
      'suggestScore': 0.3,
      'suggestScoreNoLocation': 0.5,
      'precision': 0.72,
      ...edit,
    };
    NamingConfig naming(
      Object? levels, {
      Object? precision,
      bool provisional = false,
    }) => SpeciesPackManifest.parse(
      manifestJson((m) {
        final n = m['naming']! as Map<String, Object?>;
        n['provisional'] = provisional;
        if (levels != null) n['levels'] = levels;
        if (precision != null) n['precision'] = precision;
      }),
    ).naming;
    List<NamingLevel> ids(NamingConfig n) => [
      for (final l in n.levels) l.level,
    ];

    test('are read in order, surest first, with the precision', () {
      final n = naming([eager(), balanced()], precision: 0.897);
      expect(ids(n), [NamingLevel.balanced, NamingLevel.eager]);
      expect(n.precision, 0.897);
      expect(
        n.levels.first,
        const MeasuredNamingLevel(
          level: NamingLevel.balanced,
          target: 0.75,
          suggestScore: 0.4,
          suggestScoreNoLocation: 0.6,
          precision: 0.81,
        ),
      );
    });

    test('a pack without them has none and no precision', () {
      final n = naming(null);
      expect(n.levels, isEmpty);
      expect(n.precision, isNull);
    });

    test('a bad entry is dropped and the pack still reads', () {
      expect(
        ids(
          naming([
            balanced({'id': 'surer'}),
          ]),
        ),
        isEmpty,
      );
      expect(
        ids(
          naming([
            balanced({'id': 'reckless'}),
          ]),
        ),
        isEmpty,
      );
      expect(ids(naming([balanced(), balanced()])), [NamingLevel.balanced]);
      expect(
        ids(
          naming([
            balanced({'suggestScore': 'low'}),
          ]),
        ),
        isEmpty,
      );
      expect(
        ids(
          naming([
            balanced({'suggestScore': 0.55}),
          ]),
        ),
        isEmpty,
      );
      expect(
        ids(
          naming([
            balanced({'suggestScoreNoLocation': 0.75}),
          ]),
        ),
        isEmpty,
      );
      for (final target in [0, -0.5, 1.5]) {
        expect(
          ids(
            naming([
              balanced({'target': target}),
            ]),
          ),
          isEmpty,
          reason: 'target $target',
        );
      }
      expect(
        ids(
          naming([
            balanced({'precision': 0}),
          ]),
        ),
        isEmpty,
      );
      expect(
        ids(
          naming([
            balanced({'precision': 1.2}),
          ]),
        ),
        isEmpty,
      );
      expect(ids(naming(['balanced'])), isEmpty);
      expect(ids(naming('levels')), isEmpty);
    });

    test('a provisional pack carries no levels and no precision', () {
      final n = naming([balanced()], precision: 0.9, provisional: true);
      expect(n.levels, isEmpty);
      expect(n.precision, isNull);
    });

    test('a level that names nothing more than the one above is dropped', () {
      expect(
        ids(
          naming([
            balanced({'suggestScore': 0.5, 'suggestScoreNoLocation': 0.7}),
          ]),
        ),
        isEmpty,
      );
      expect(
        ids(
          naming([
            balanced(),
            eager({'suggestScore': 0.4, 'suggestScoreNoLocation': 0.6}),
          ]),
        ),
        [NamingLevel.balanced],
      );
    });

    test('a level lower in one bar only, and as often right, is kept', () {
      // A level sharing one bar with the level above, as the published
      // pair's Eager shares Balanced's with a location, and as often right
      // (a tie the app allows).
      expect(
        ids(
          naming([
            balanced(),
            eager({
              'suggestScore': 0.4,
              'suggestScoreNoLocation': 0.5,
              'precision': 0.81,
            }),
          ]),
        ),
        [NamingLevel.balanced, NamingLevel.eager],
      );
      // The mirror case: lower with a location, Balanced's bar without.
      expect(
        ids(
          naming([
            balanced(),
            eager({
              'suggestScore': 0.3,
              'suggestScoreNoLocation': 0.6,
              'precision': 0.81,
            }),
          ]),
        ),
        [NamingLevel.balanced, NamingLevel.eager],
      );
    });

    test('a level more often right than the one above is dropped', () {
      expect(
        ids(
          naming([
            balanced({'precision': 0.95}),
          ], precision: 0.897),
        ),
        isEmpty,
      );
      expect(
        ids(
          naming([
            balanced(),
            eager({'precision': 0.85}),
          ]),
        ),
        [NamingLevel.balanced],
      );
      // With no measured precision for Surer, Balanced has nothing above it
      // to be compared with.
      expect(
        ids(
          naming([
            balanced({'precision': 0.95}),
          ]),
        ),
        [NamingLevel.balanced],
      );
    });

    test('eager above balanced is dropped', () {
      expect(
        ids(
          naming([
            balanced(),
            eager({'suggestScore': 0.45}),
          ]),
        ),
        [NamingLevel.balanced],
      );
    });

    group('a republished manifest is adoptable', () {
      // Levels are read only from measured bars.
      void measured(Map<String, Object?> m) =>
          (m['naming']! as Map<String, Object?>)['provisional'] = false;
      final installed = SpeciesPackManifest.parse(manifestJson(measured));
      SpeciesPackManifest published(void Function(Map<String, Object?>) edit) =>
          SpeciesPackManifest.parse(
            manifestJson((m) {
              measured(m);
              edit(m);
            }),
          );
      void addLevels(Map<String, Object?> m) =>
          (m['naming']! as Map<String, Object?>)['levels'] = [balanced()];

      test('when it withdraws its levels and precision', () {
        final withLevels = published((m) {
          addLevels(m);
          (m['naming']! as Map<String, Object?>)['precision'] = 0.9;
        });
        expect(
          withLevels.adoptableFrom(published((_) {}), engine: 'coreml'),
          isTrue,
        );
      });

      test('when it adds levels, a precision or credits', () {
        expect(
          installed.adoptableFrom(published(addLevels), engine: 'coreml'),
          isTrue,
        );
        expect(
          installed.adoptableFrom(
            published(
              (m) => (m['naming']! as Map<String, Object?>)['precision'] = 0.9,
            ),
            engine: 'coreml',
          ),
          isTrue,
        );
        expect(
          installed.adoptableFrom(
            published((m) => m['credits'] = []),
            engine: 'coreml',
          ),
          isTrue,
        );
      });

      test('only when nothing else changes', () {
        expect(
          installed.adoptableFrom(published((_) {}), engine: 'coreml'),
          isFalse,
        );
        expect(
          installed.adoptableFrom(
            published((m) {
              addLevels(m);
              (m['naming']! as Map<String, Object?>)['suggestScore'] = 0.6;
            }),
            engine: 'coreml',
          ),
          isFalse,
        );
        expect(
          installed.adoptableFrom(
            published((m) {
              addLevels(m);
              ((m['files']! as List)[2] as Map)['sha256'] = 'b' * 64;
            }),
            engine: 'coreml',
          ),
          isFalse,
        );
        expect(
          installed.adoptableFrom(
            published((m) {
              addLevels(m);
              m['packVersion'] = '2026.11.2';
            }),
            engine: 'coreml',
          ),
          isFalse,
        );
        expect(
          installed.adoptableFrom(
            published((m) {
              addLevels(m);
              (m['detector']! as Map)['scoreThreshold'] = 0.4;
            }),
            engine: 'coreml',
          ),
          isFalse,
        );
      });

      test('when it only adds another engine\'s files', () {
        expect(
          installed.adoptableFrom(
            published(
              (m) => (m['files']! as List).add({
                'name': 'classifier.onnx.zip',
                'engine': 'onnx',
                'size': 1,
                'sha256': 'c' * 64,
              }),
            ),
            engine: 'coreml',
          ),
          isTrue,
        );
      });

      test('not when it changes a file of this engine', () {
        expect(
          installed.adoptableFrom(
            published((m) {
              addLevels(m);
              ((m['files']! as List)[0] as Map)['sha256'] = 'b' * 64;
            }),
            engine: 'coreml',
          ),
          isFalse,
        );
      });
    });

    test('a precision outside (0, 1] reads as none', () {
      expect(naming(null, precision: 0).precision, isNull);
      expect(naming(null, precision: 1.5).precision, isNull);
      expect(naming(null, precision: 'high').precision, isNull);
    });
  });
}
