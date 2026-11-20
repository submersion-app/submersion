import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_vision/onnx_runtime.dart';

import 'package:submersion/features/species_id/data/engines/onnx/device_crash_guard.dart';
import 'package:submersion/features/species_id/data/engines/onnx/hardware_engines.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_vision_engine.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/onnx_pipeline.dart';
import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

import '../../../../helpers/temp_dir.dart';

/// Engines a test sets up, recording what the engine asks of them.
class FakeHardware implements HardwareEngines {
  FakeHardware({
    this.offers = false,
    this.libraries = const [],
    this.fetched = const [],
  });

  final bool offers;
  List<ProviderLibrary> libraries;

  /// What a fetch adds to [libraries].
  final List<ProviderLibrary> fetched;
  final asked = <String>[];

  @override
  Future<bool> offersEngineToFetch() async {
    asked.add('offers');
    return offers;
  }

  @override
  Future<bool> fetchEngine() async {
    asked.add('fetch');
    libraries = [...libraries, ...fetched];
    return true;
  }

  @override
  Future<List<ProviderLibrary>> readyProviderLibraries() async {
    asked.add('libraries');
    return libraries;
  }
}

/// A worker that loads anything and reports the processor.
class QuietWorker implements OnnxWorkerHandle {
  @override
  Future<String?> load(VisionModels models) async => 'cpu';

  @override
  Future<PipelineResult> analyze(RgbaImage image) => throw UnimplementedError();

  @override
  Future<List<PipelineBox>> detect(RgbaImage frame) =>
      throw UnimplementedError();

  @override
  Future<VisionMomentCrop?> cropAndEmbed(
    RgbaImage frame,
    IdentificationBox box,
  ) => throw UnimplementedError();

  @override
  Future<void> unload() async {}

  @override
  Future<void> close() async {}
}

const _models = VisionModels(
  detectors: [],
  classifierPath: 'classifier/model.onnx',
  mergeIoU: 0.5,
  maxBoxes: 8,
  cropPadding: 0.1,
  classifierInputSize: 224,
  classifierMean: [0.5, 0.5, 0.5],
  classifierStd: [0.5, 0.5, 0.5],
  embeddingSize: 768,
  cropThumbnailSize: 320,
);

const _nv = (name: 'NvTensorRTRTXExecutionProvider', path: 'C:\\nv.dll');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<OrtDevice> seenDevices;
  late List<ProviderLibrary> seenLibraries;
  late int spawns;
  String? seenNote;

  late Directory guardDir;

  OnnxVisionEngine engine(TargetPlatform platform, HardwareEngines hardware) {
    final e = OnnxVisionEngine(
      platform: platform,
      onnxPlatforms: true,
      hardware: hardware,
      crashGuard: DeviceCrashGuard(guardDir),
      spawnWorker:
          ({
            required List<OrtDevice> devices,
            required List<ProviderLibrary> providerLibraries,
            required int intraOpThreads,
            String? openingNote,
          }) async {
            seenNote = openingNote;
            seenDevices = devices;
            seenLibraries = providerLibraries;
            spawns++;
            return QuietWorker();
          },
    );
    addTearDown(() => WidgetsBinding.instance.removeObserver(e));
    return e;
  }

  setUp(() async {
    seenDevices = const [];
    seenLibraries = const [];
    spawns = 0;
    guardDir = await Directory.systemTemp.createTemp('device_guard');
    addTearDown(() => deleteTempDir(guardDir));
  });

  test('on Windows the models try a hardware engine, then DirectML, then '
      'the processor, with the ready engines registered', () async {
    final hardware = FakeHardware(libraries: const [_nv]);

    await engine(TargetPlatform.windows, hardware).load(_models);

    expect(seenDevices, [
      OrtDevice.hardware,
      OrtDevice.directMl,
      OrtDevice.cpu,
    ]);
    expect(seenLibraries, const [_nv]);
  });

  test('elsewhere the models run on the processor and no engine is asked '
      'for', () async {
    final hardware = FakeHardware(libraries: const [_nv]);

    await engine(TargetPlatform.android, hardware).load(_models);

    expect(seenDevices, [OrtDevice.cpu]);
    expect(seenLibraries, isEmpty);
    expect(hardware.asked, isEmpty);
  });

  test('the engine is a hardware engine source: on Windows it passes the '
      "catalogue's offer and fetch through", () async {
    final hardware = FakeHardware(offers: true);
    final HardwareEngineSource source = engine(
      TargetPlatform.windows,
      hardware,
    );

    expect(await source.offersEngineToFetch(), isTrue);
    expect(await source.fetchEngine(), isTrue);
    expect(hardware.asked, ['offers', 'fetch']);
  });

  test('a fetched engine restarts the worker, so the next load registers '
      'it', () async {
    final hardware = FakeHardware(fetched: const [_nv]);
    final e = engine(TargetPlatform.windows, hardware);
    await e.load(_models);
    expect(seenLibraries, isEmpty);

    expect(await e.fetchEngine(), isTrue);
    await e.load(_models);

    expect(spawns, 2);
    expect(seenLibraries, const [_nv]);
  });

  test('off Windows it offers nothing to fetch and fetches nothing', () async {
    final hardware = FakeHardware(offers: true);
    final HardwareEngineSource source = engine(TargetPlatform.linux, hardware);

    expect(await source.offersEngineToFetch(), isFalse);
    expect(await source.fetchEngine(), isFalse);
    expect(hardware.asked, isEmpty);
  });

  group('a device the app ended on while opening models', () {
    const all = [OrtDevice.hardware, OrtDevice.directMl, OrtDevice.cpu];

    test('is skipped the next time', () async {
      // The worker's note, left behind because the app ended mid-open.
      OpeningNote(
        DeviceCrashGuard(guardDir).openingNotePath,
      ).opening(OrtDevice.hardware);

      await engine(TargetPlatform.windows, FakeHardware()).load(_models);

      expect(seenDevices, [OrtDevice.directMl, OrtDevice.cpu]);
    });

    test(
      'the device named is the one skipped, and never the processor',
      () async {
        final guard = DeviceCrashGuard(guardDir);
        final note = OpeningNote(guard.openingNotePath);

        note.opening(OrtDevice.directMl);
        expect(await guard.devicesFor(all), [
          OrtDevice.hardware,
          OrtDevice.cpu,
        ]);
        note.opening(OrtDevice.hardware);
        expect(await guard.devicesFor(all), [OrtDevice.cpu]);
        note.opening(OrtDevice.cpu);
        expect(await guard.devicesFor(all), [OrtDevice.cpu]);
      },
    );

    test('the worker is told where to note each open', () async {
      await engine(TargetPlatform.windows, FakeHardware()).load(_models);

      expect(seenNote, DeviceCrashGuard(guardDir).openingNotePath);
    });

    test('notes that cannot be written never fail anything', () async {
      // A file where the guard's folder should be: every note fails.
      final blocked = File('${guardDir.path}${Platform.pathSeparator}blocked')
        ..writeAsStringSync('in the way');
      final guard = DeviceCrashGuard(Directory(blocked.path));
      final note = OpeningNote(guard.openingNotePath);

      note.opening(OrtDevice.hardware);
      note.opened();
      expect(await guard.devicesFor(all), all);
      await guard.reset();
    });

    test('a newly fetched engine gets another chance', () async {
      OpeningNote(
        DeviceCrashGuard(guardDir).openingNotePath,
      ).opening(OrtDevice.hardware);
      final e = engine(
        TargetPlatform.windows,
        FakeHardware(fetched: const [_nv]),
      );
      await e.load(_models);
      expect(seenDevices, isNot(contains(OrtDevice.hardware)));

      await e.fetchEngine();
      await e.load(_models);

      expect(seenDevices, all);
    });
  });
}
