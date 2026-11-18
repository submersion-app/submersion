import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/track_sample.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';

import 'manifest_fixture.dart';

const _parrotfish = PackCandidate(
  gbifKey: 1,
  scientificName: 'Scarus vetula',
  commonName: 'Queen Parrotfish',
  category: SpeciesCategory.fish,
  catalogId: 'sp_queen_parrotfish',
);
const _chromis = PackCandidate(
  gbifKey: 2,
  scientificName: 'Chromis multilineata',
  commonName: 'Brown Chromis',
  category: SpeciesCategory.other,
);

void main() {
  group('copyWith with nothing given is an equal copy, and changes what is '
      'given', () {
    test('candidates', () {
      expect(_parrotfish.copyWith(), _parrotfish);
      expect(
        _parrotfish.copyWith(
          gbifKey: 2,
          scientificName: 'Chromis multilineata',
          commonName: 'Brown Chromis',
          category: SpeciesCategory.other,
          catalogId: () => null,
        ),
        _chromis,
      );
      expect(_chromis.copyWith(catalogId: () => 'sp_x').catalogId, 'sp_x');

      const named = NamedCandidate(candidate: _parrotfish, score: 0.9);
      expect(named.copyWith(), named);
      expect(
        named.copyWith(candidate: _chromis, score: 0.1),
        const NamedCandidate(candidate: _chromis, score: 0.1),
      );
    });

    test('boxes, tags and suggestions', () {
      const box = IdentificationBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4);
      expect(box.copyWith(), box);
      expect(
        box.copyWith(x: 0.5, y: 0.6, width: 0.1, height: 0.2),
        const IdentificationBox(x: 0.5, y: 0.6, width: 0.1, height: 0.2),
      );

      const tag = TaggedSpecies(speciesId: 'a', scientificName: 'Scarus');
      expect(tag.copyWith(), tag);
      expect(
        tag.copyWith(speciesId: 'b', scientificName: () => null),
        const TaggedSpecies(speciesId: 'b'),
      );

      const top = NamedCandidate(candidate: _parrotfish, score: 0.9);
      const other = NamedCandidate(candidate: _chromis, score: 0.1);
      const suggestion = SpeciesSuggestion(
        top: top,
        score: 0.9,
        count: 1,
        cropIdentificationId: 'i1',
        identificationIds: ['i1'],
        alternatives: [top],
      );
      expect(suggestion.copyWith(), suggestion);
      expect(
        suggestion.copyWith(
          top: other,
          score: 0.1,
          count: 2,
          cropIdentificationId: 'i2',
          identificationIds: ['i2', 'i3'],
          alternatives: [other],
        ),
        const SpeciesSuggestion(
          top: other,
          score: 0.1,
          count: 2,
          cropIdentificationId: 'i2',
          identificationIds: ['i2', 'i3'],
          alternatives: [other],
        ),
      );
    });

    test('tracks on a video', () {
      const box = IdentificationBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4);
      const other = IdentificationBox(x: 0.5, y: 0.5, width: 0.1, height: 0.1);
      const sample = TrackSample(ms: 250, box: box);
      expect(sample.copyWith(), sample);
      expect(
        sample.copyWith(ms: 500, box: other),
        const TrackSample(ms: 500, box: other),
      );

      final track = MediaIdentification(
        id: 'i1',
        mediaId: 'v1',
        box: box,
        boxPixelWidth: 80,
        boxPixelHeight: 60,
        detectorScore: 0.9,
        openScore: 0.5,
        candidates: const [],
        locationLimited: false,
        suggestable: true,
        decision: IdentificationDecision.undecided,
        createdAt: DateTime.utc(2026),
        startMs: 0,
        endMs: 1500,
        bestMs: 750,
        path: const [sample],
        claimedSpeciesId: 'sp_a',
        confident: true,
        specific: true,
      );
      expect(track.copyWith(), track);
      expect(track.isTrack, isTrue);
      expect(track.durationMs, 1500);
      final changed = track.copyWith(
        startMs: () => 100,
        endMs: () => 200,
        bestMs: () => 150,
        path: const [],
        claimedSpeciesId: () => null,
        confident: false,
        specific: false,
      );
      expect(changed.startMs, 100);
      expect(changed.endMs, 200);
      expect(changed.bestMs, 150);
      expect(changed.path, isEmpty);
      expect(changed.claimedSpeciesId, isNull);
      expect(changed.confident, isFalse);
      expect(changed.specific, isFalse);
      expect(track.copyWith(startMs: () => null).isTrack, isFalse);

      final run = MediaIdentificationRun(
        mediaId: 'v1',
        packVersion: 'p',
        detectorId: 'd',
        classifierId: 'c',
        analysedAt: DateTime.utc(2026),
        imageWidth: 1920,
        imageHeight: 1080,
        detectionCount: 0,
        scannedMs: 10000,
        videoDurationMs: 25000,
      );
      expect(run.copyWith(), run);
      expect(run.scanComplete, isFalse);
      final done = run.copyWith(scannedMs: () => 25000);
      expect(done.scanComplete, isTrue);
      expect(run.copyWith(videoDurationMs: () => null).scanComplete, isFalse);
    });

    test('video detections and moments', () {
      const box = IdentificationBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4);
      const other = IdentificationBox(x: 0.5, y: 0.5, width: 0.1, height: 0.1);
      const detected = DetectedBox(box: box, score: 0.8);
      expect(detected.copyWith(), detected);
      expect(
        detected.copyWith(box: other, score: 0.5),
        const DetectedBox(box: other, score: 0.5),
      );
      const frame = FrameDetections(ms: 250, boxes: [detected]);
      expect(frame.copyWith(), frame);
      expect(
        frame.copyWith(ms: 500, boxes: const []),
        const FrameDetections(ms: 500, boxes: []),
      );
      const video = VideoDetections(
        width: 1920,
        height: 1080,
        durationMs: 25000,
        frames: [frame],
      );
      expect(video.copyWith(), video);
      expect(
        video.copyWith(width: 1080, height: 1920, durationMs: 1, frames: []),
        const VideoDetections(
          width: 1080,
          height: 1920,
          durationMs: 1,
          frames: [],
        ),
      );
      const moment = VisionMoment(ms: 250, box: box);
      expect(moment.copyWith(), moment);
      expect(
        moment.copyWith(ms: 500, box: other),
        const VisionMoment(ms: 500, box: other),
      );
      final crop = VisionMomentCrop(
        pixelWidth: 80,
        pixelHeight: 60,
        cropJpeg: Uint8List.fromList([1]),
        embedding: Float32List.fromList([1, 0]),
      );
      expect(crop.copyWith(), crop);
      expect(crop.copyWith(pixelWidth: 10, pixelHeight: 20).pixelWidth, 10);
    });

    test('the manifest and its parts', () {
      final manifest = SpeciesPackManifest.parse(manifestJson());
      expect(manifest.copyWith(), manifest);

      const detector = DetectorConfig(
        id: 'd2',
        format: DetectorFormat.yolo,
        file: 'detector-2',
        inputSize: 320,
        mean: [0.1, 0.1, 0.1],
        std: [0.2, 0.2, 0.2],
        scoreThreshold: 0.5,
        maxBoxes: 4,
      );
      expect(
        manifest.detectors.single.copyWith(
          id: 'd2',
          format: DetectorFormat.yolo,
          file: 'detector-2',
          inputSize: 320,
          mean: [0.1, 0.1, 0.1],
          std: [0.2, 0.2, 0.2],
          scoreThreshold: 0.5,
          maxBoxes: 4,
        ),
        detector,
      );
      const boxes = BoxesConfig(mergeIoU: 0.4, maxBoxes: 6, cropPadding: 0.2);
      expect(
        manifest.boxes.copyWith(mergeIoU: 0.4, maxBoxes: 6, cropPadding: 0.2),
        boxes,
      );
      const classifier = ClassifierConfig(
        id: 'c2',
        inputSize: 336,
        mean: [0.3, 0.3, 0.3],
        std: [0.4, 0.4, 0.4],
        embeddingSize: 512,
        logitScale: 50,
        cropFit: CropFit.centreCrop,
      );
      expect(
        manifest.classifier.copyWith(
          id: 'c2',
          inputSize: 336,
          mean: [0.3, 0.3, 0.3],
          std: [0.4, 0.4, 0.4],
          embeddingSize: 512,
          logitScale: 50,
          cropFit: CropFit.centreCrop,
        ),
        classifier,
      );
      const naming = NamingConfig(
        provisional: false,
        minCropSide: 32,
        minOpenScore: 0.2,
        suggestScore: 0.6,
        confidentScore: 0.8,
        suggestScoreNoLocation: 0.75,
        confidentScoreNoLocation: 0.85,
        minAllowedCandidates: 100,
        topK: 3,
      );
      expect(
        manifest.naming.copyWith(
          provisional: false,
          minCropSide: 32,
          minOpenScore: 0.2,
          suggestScore: 0.6,
          confidentScore: 0.8,
          suggestScoreNoLocation: 0.75,
          confidentScoreNoLocation: 0.85,
          minAllowedCandidates: 100,
          topK: 3,
        ),
        naming,
      );
      const region = RegionConfig(cellDegrees: 10, neighbourCells: 2);
      expect(
        manifest.region.copyWith(cellDegrees: 10, neighbourCells: 2),
        region,
      );
      const file = PackFile(name: 'a', engine: 'all', size: 1, sha256: 'b');
      expect(
        manifest.files.first.copyWith(
          name: 'a',
          engine: 'all',
          size: 1,
          sha256: 'b',
        ),
        file,
      );
      const credit = PackCredit(name: 'n', licence: 'l', text: 't');
      expect(
        manifest.credits.first.copyWith(name: 'n', licence: 'l', text: 't'),
        credit,
      );

      final changed = manifest.copyWith(
        formatVersion: 2,
        packVersion: '2027.1.1',
        detectors: const [detector],
        boxes: boxes,
        classifier: classifier,
        naming: naming,
        region: region,
        cropThumbnailSize: 128,
        files: [file],
        credits: [credit],
        source: '{}',
      );
      expect(changed.formatVersion, 2);
      expect(changed.packVersion, '2027.1.1');
      expect(changed.detectors, [detector]);
      expect(changed.boxes, boxes);
      expect(changed.classifier, classifier);
      expect(changed.naming, naming);
      expect(changed.region, region);
      expect(changed.cropThumbnailSize, 128);
      expect(changed.files, [file]);
      expect(changed.credits, [credit]);
      expect(changed.source, '{}');
    });

    test('vision models and analyses', () {
      final manifest = SpeciesPackManifest.parse(manifestJson());
      final models = VisionModels.fromManifest(
        manifest,
        detectorPaths: const ['/d'],
        classifierPath: '/c',
      );
      expect(models.copyWith(), models);
      const detector = VisionDetector(
        path: '/d2',
        format: DetectorFormat.yolo,
        inputSize: 1,
        mean: [1, 1, 1],
        std: [2, 2, 2],
        scoreThreshold: 0.9,
        maxBoxes: 1,
      );
      expect(models.detectors.single.copyWith(), models.detectors.single);
      expect(
        models.detectors.single.copyWith(
          path: '/d2',
          format: DetectorFormat.yolo,
          inputSize: 1,
          mean: [1, 1, 1],
          std: [2, 2, 2],
          scoreThreshold: 0.9,
          maxBoxes: 1,
        ),
        detector,
      );
      const changedModels = VisionModels(
        detectors: [detector],
        classifierPath: '/c2',
        mergeIoU: 0.3,
        maxBoxes: 1,
        cropPadding: 0.5,
        classifierInputSize: 2,
        classifierMean: [3, 3, 3],
        classifierStd: [4, 4, 4],
        embeddingSize: 3,
        cropThumbnailSize: 64,
        cropFit: CropFit.centreCrop,
      );
      expect(
        models.copyWith(
          detectors: const [detector],
          classifierPath: '/c2',
          mergeIoU: 0.3,
          maxBoxes: 1,
          cropPadding: 0.5,
          classifierInputSize: 2,
          classifierMean: [3, 3, 3],
          classifierStd: [4, 4, 4],
          embeddingSize: 3,
          cropThumbnailSize: 64,
          cropFit: CropFit.centreCrop,
        ),
        changedModels,
      );

      final crop = Uint8List.fromList([1]);
      final embedding = Float32List.fromList([1, 0]);
      final detection = VisionDetection(
        x: 0,
        y: 0,
        width: 1,
        height: 1,
        score: 0.5,
        pixelWidth: 10,
        pixelHeight: 10,
        cropJpeg: crop,
        embedding: embedding,
      );
      expect(detection.copyWith(), detection);
      final moved = detection.copyWith(
        x: 0.1,
        y: 0.2,
        width: 0.3,
        height: 0.4,
        score: 0.9,
        pixelWidth: 20,
        pixelHeight: 30,
        cropJpeg: Uint8List.fromList([2]),
        embedding: Float32List.fromList([0, 1]),
      );
      expect(
        [moved.x, moved.y, moved.width, moved.height],
        [0.1, 0.2, 0.3, 0.4],
      );
      expect([moved.score, moved.pixelWidth, moved.pixelHeight], [0.9, 20, 30]);
      expect(moved.cropJpeg, [2]);
      expect(moved.embedding, [0, 1]);

      final analysis = VisionAnalysis(
        imageWidth: 100,
        imageHeight: 50,
        detections: [detection],
      );
      expect(analysis.copyWith(), analysis);
      final other = analysis.copyWith(
        imageWidth: 200,
        imageHeight: 100,
        detections: const [],
      );
      expect([other.imageWidth, other.imageHeight], [200, 100]);
      expect(other.detections, isEmpty);
    });
  });
}
