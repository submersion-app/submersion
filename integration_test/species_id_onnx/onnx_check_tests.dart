import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_vision_engine.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';
import 'package:submersion/features/species_id/presentation/providers/species_pack_controller.dart';

import 'onnx_check_engine.dart';
import 'onnx_check_inputs.dart';
import 'onnx_check_pack.dart';
import 'onnx_check_photos.dart';
import 'onnx_check_video.dart';

/// Registers one test of the check: `testWidgets` in the app.
typedef DefineTest =
    void Function(
      String description,
      Future<void> Function() body, {
      Timeout? timeout,
    });

/// The checks of species_id_onnx_test.dart, in order, sharing one engine
/// and one installed pack. [platform] is the one the engine runs as
/// (Windows or Linux in the app), [runsHere] whether the engine can run at
/// all, and [makeEngine] builds the app's engine with [WorkerLog.spawner]
/// as its way of starting workers.
void onnxCheckTests({
  required bool runsHere,
  required TargetPlatform platform,
  required DefineTest define,
  required OnnxVisionEngine Function(WorkerLog workers) makeEngine,
}) {
  final onWindows = platform == TargetPlatform.windows;
  final onLinux = platform == TargetPlatform.linux;
  final videoRuns = visionVideoRuns(platform);
  const skipReason = 'the ONNX engine runs on Windows and Linux';
  const long = Timeout(Duration(minutes: 45));
  const medium = Timeout(Duration(minutes: 20));

  late Directory support;
  late WorkerLog workers;
  late ObservedEngine engine;
  VisionModels? loaded;
  final uprights = <String, VisionAnalysis>{};
  final summary = <String>[];

  /// [line] now, and again in the summary at the end.
  void note(String line) {
    summary.add(line);
    report(line);
  }

  VisionModels models() => loaded ?? (throw StateError('no pack installed'));

  /// Skips the test where the engine does not run (a Mac).
  bool skipped() {
    if (runsHere) return false;
    markTestSkipped(skipReason);
    return true;
  }

  setUpAll(() async {
    if (!runsHere) return;
    // The engine's own log lines (where the models opened, a move to
    // another device, the Windows ML engines) go to the workflow log too.
    final logs = LoggerService.logStream.listen((entry) {
      if (entry.level.index >= LogLevel.info.index) {
        report('log ${entry.level.tag}: ${entry.message}');
      }
    });
    addTearDown(logs.cancel);
    support = await Directory.systemTemp.createTemp('species_id_onnx_pack');
    addTearDown(() async {
      try {
        await support.delete(recursive: true);
      } on FileSystemException catch (e) {
        report('Could not remove ${support.path}: ${e.message}');
      }
    });
    workers = WorkerLog();
    final onnx = makeEngine(workers);
    engine = ObservedEngine(onnx);
    addTearDown(() async {
      await engine.unload();
      // The engine watches the app's memory warnings once loaded.
      WidgetsBinding.instance.removeObserver(onnx);
      report('Summary:');
      summary.forEach(report);
    });
  });

  define('the ONNX engine is available here', () async {
    if (skipped()) return;
    note(
      'Platform: ${Platform.operatingSystem} '
      '${Platform.operatingSystemVersion}, '
      '${Platform.numberOfProcessors} processors',
    );
    note('Before loading: ${describeMemory(await engine.memory())}');
    expect(engine.engineName, VisionEngine.onnxEngine);
    expect(await engine.availability(), VisionAvailability.available);
    for (final name in onnxCheckPhotos) {
      expect(
        await onnxCheckInput(name).exists(),
        isTrue,
        reason: 'run tool/species_id_onnx_it/prepare_test.dart first',
      );
    }
  });

  define('the Download installs the live pack', () async {
    if (skipped()) return;
    final run = await installLivePack(
      engine: engine,
      supportPath: support.path,
    );
    expect(run.before, isA<PackNotInstalled>());
    expect(run.after, isA<PackInstalled>());
    final pack = run.installed!;
    final files = [...pack.detectorPaths, pack.classifierPath];
    note(
      'Pack ${pack.manifest.packVersion} downloaded and installed in '
      '${run.downloadMs} ms over ${run.attempts} attempt(s): '
      '${files.map(p.basename).join(', ')}',
    );
    for (final file in files) {
      expect(file, endsWith('.onnx'));
    }
    // The models the installed pack loads, built as the app builds them.
    loaded = VisionModels.fromManifest(
      pack.manifest,
      detectorPaths: pack.detectorPaths,
      classifierPath: pack.classifierPath,
    );
    // The Download loads the models once, then frees them.
    expect(engine.loadMs, hasLength(1));
    note(
      'First load, in the Download: ${engine.loadMs.single} ms, on '
      '${workers.lastDevice}',
    );
    // The Download asks for a vendor engine whatever the platform; on a PC
    // with no GPU none is offered, which is no failure.
    final asked = engine.hardware.where((a) => a.call == 'offersEngineToFetch');
    expect(asked, isNotEmpty);
    for (final answer in engine.hardware) {
      note(
        'Download asked ${answer.call}: '
        '${answer.error ?? answer.answer} (${answer.ms} ms)',
      );
      expect(answer.error, isNull);
    }
    if (!onWindows) expect(asked.first.answer, isFalse);
  }, timeout: long);

  define('Windows ML is asked for vendor engines', () async {
    if (skipped()) return;
    if (onWindows) {
      for (final line in await describeWindowsMlCatalogue()) {
        note(line);
      }
    }
    final offers = await engine.offersEngineToFetch();
    final fetched = await engine.fetchEngine();
    note('offersEngineToFetch: $offers; fetchEngine: $fetched');
    if (!onWindows) {
      expect(offers, isFalse);
      expect(fetched, isFalse);
    }
  }, timeout: medium);

  define('the models load, and say where they run', () async {
    if (skipped()) return;
    final (_, ms) = await timed(() => engine.load(models()));
    final device = workers.lastDevice;
    note(
      'Load: $ms ms, on $device (devices offered: '
      '${workers.starts.last.map((d) => d.name).join(', ')})',
    );
    expect(device, isNotNull);
    if (onLinux) expect(device, 'cpu');
    final (_, again) = await timed(() => engine.load(models()));
    note('The same models again: $again ms (nothing to do)');
    note('Loaded: ${describeMemory(await engine.memory())}');
  }, timeout: medium);

  define('the photos give fish, each with an embedding', () async {
    if (skipped()) return;
    final size = models().embeddingSize;
    for (final name in onnxCheckPhotos) {
      final path = onnxCheckInput(name).path;
      final (analysis, ms) = await timed(() => engine.analyze(path: path));
      note('Photo $name: $ms ms');
      describeAnalysis(analysis).forEach(report);
      for (final d in analysis.detections) {
        expect(d.embedding, hasLength(size));
        expect(d.cropJpeg, isNotEmpty);
      }
      uprights[name] = analysis;
      if (name == anemonefishPhoto) {
        expect(analysis.detections, isNotEmpty);
        expect(analysis.imageWidth, greaterThan(analysis.imageHeight));
        final (_, warm) = await timed(() => engine.analyze(path: path));
        note('Photo $name again: $warm ms');
      }
    }
  }, timeout: medium);

  define('a photo stored turned, with its EXIF orientation, gives the '
      'upright boxes', () async {
    if (skipped()) return;
    // The same picture as the viewer shows it, stored as a phone held
    // upright stores it: only EXIF orientation 6 turns it back. Every sure
    // box must come back where it was, in the image the viewer shows.
    for (final name in onnxCheckPhotos) {
      final straight = uprights[name] ?? (throw StateError('no $name'));
      final source = await onnxCheckInput(name).readAsBytes();
      final copy = File(p.join(support.path, 'stored_turned_$name'));
      await copy.writeAsBytes(storedTurnedJpeg(source));
      final (back, ms) = await timed(() => engine.analyze(path: copy.path));
      note('$name stored turned, EXIF orientation 6: $ms ms');
      describeAnalysis(back).forEach(report);
      expect(back.imageWidth, straight.imageWidth);
      expect(back.imageHeight, straight.imageHeight);
      final boxes = back.detections.map(boxOf).toList();
      final sure = straight.detections.where((d) => d.score >= confidentScore);
      for (final d in sure) {
        final match = closestMatch(boxOf(d), boxes);
        note(
          '  upright ${describeBox(boxOf(d))} came back overlapping '
          '${match.iou.toStringAsFixed(3)}, edges within '
          '${match.edge.toStringAsFixed(3)}',
        );
        expect(match.iou, greaterThanOrEqualTo(sameBoxMinIou));
        expect(match.edge, lessThanOrEqualTo(sameBoxMaxEdge));
      }
      expect(
        sure,
        isNotEmpty,
        reason: 'no box of $name scored $confidentScore',
      );
    }
  }, timeout: medium);

  define('a photo EXIF orientation 6 turns is analysed turned', () async {
    if (skipped()) return;
    final straight =
        uprights[anemonefishPhoto] ?? (throw StateError('no upright'));
    final source = await onnxCheckInput(anemonefishPhoto).readAsBytes();
    final copy = File(p.join(support.path, 'anemonefish_orientation_6.jpg'));
    await copy.writeAsBytes(withExifOrientation(source, exifRotatedClockwise));
    final (turned, ms) = await timed(() => engine.analyze(path: copy.path));
    note('$anemonefishPhoto with EXIF orientation 6 added: $ms ms');
    describeAnalysis(turned).forEach(report);
    // Turned as the viewer shows it: taller than wide.
    expect(turned.imageWidth, straight.imageHeight);
    expect(turned.imageHeight, straight.imageWidth);
    expect(turned.detections, isNotEmpty);
    // For the write-up only: the detectors see the fish on its side here,
    // so their boxes and scores differ from the upright ones by more than
    // the orientation (measured on a Mac: the fish at 0.39 upright, 0.82
    // turned, overlapping about 0.6). The test above checks the boxes.
    final boxes = turned.detections.map(boxOf).toList();
    for (final d in straight.detections) {
      final want = turnedClockwise(boxOf(d));
      final match = closestMatch(want, boxes);
      note(
        '  upright ${describeBox(boxOf(d))} turned is ${describeBox(want)}; '
        'closest turned box overlaps it ${match.iou.toStringAsFixed(3)}',
      );
    }
  }, timeout: medium);

  define('videos scan on Windows, and are refused on Linux', () async {
    if (skipped()) return;
    if (!videoRuns) {
      await expectUnsupportedVideo(engine);
      note('No video on ${platform.name}: refused as unsupported');
      return;
    }
    for (final clip in [landscapeClip, portraitClip]) {
      for (final line in await scanClip(
        engine,
        clip,
        portrait: clip == portraitClip,
        embeddingSize: models().embeddingSize,
      )) {
        note(line);
      }
    }
  }, timeout: medium);

  define('after unload a call is not_loaded, and a reload serves', () async {
    if (skipped()) return;
    final path = onnxCheckInput(anemonefishPhoto).path;
    await engine.unload();
    note('Unloaded: ${describeMemory(await engine.memory())}');
    await expectLater(
      engine.analyze(path: path),
      throwsA(
        isA<VisionEngineException>().having(
          (e) => e.code,
          'code',
          VisionEngineException.notLoaded,
        ),
      ),
    );
    if (videoRuns) await expectVideoNotLoaded(engine);
    // What the analysis queue does on not_loaded: load again, then retry.
    final (_, ms) = await timed(() => engine.load(models()));
    note('Reload after unload: $ms ms, on ${workers.lastDevice}');
    final again = await engine.analyze(path: path);
    expect(
      again.detections,
      hasLength(uprights[anemonefishPhoto]!.detections.length),
    );
    await engine.unload();
  }, timeout: medium);
}
