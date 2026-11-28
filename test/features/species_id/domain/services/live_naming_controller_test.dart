import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';
import 'package:submersion/features/species_id/domain/services/live_naming_controller.dart';

VisionDetection _fish(double x, double y) => VisionDetection(
  x: x,
  y: y,
  width: 0.2,
  height: 0.2,
  score: 0.9,
  pixelWidth: 200,
  pixelHeight: 200,
  cropJpeg: Uint8List(0),
  embedding: Float32List(4),
);

const _plenty = VisionMemory(
  footprintBytes: 0,
  availableBytes: 2 * 1024 * 1024 * 1024,
);

/// Live suggestions over the Identify camera (issue #5122).
void main() {
  late DateTime clock;
  late List<VisionDetection> seen;
  late VisionMemory memory;
  late int analysed;
  Completer<void>? holdAnalysis;
  late LiveNamingController controller;
  late List<LiveLabels> emitted;
  final frame = LiveFrame(Uint8List.fromList([0xff, 0xd8]));

  setUp(() {
    clock = DateTime.utc(2026, 11, 28, 12);
    seen = [_fish(0.1, 0.1)];
    memory = _plenty;
    analysed = 0;
    holdAnalysis = null;
    controller = LiveNamingController(
      analyze: (_) async {
        analysed++;
        await holdAnalysis?.future;
        return VisionAnalysis(imageWidth: 1, imageHeight: 1, detections: seen);
      },
      name: (found) async => [for (final _ in found) 'Clownfish'],
      memory: () async => memory,
      now: () => clock,
    );
    emitted = [];
    controller.labels.listen(emitted.add);
    addTearDown(controller.dispose);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('names a frame, then drops frames inside 250 ms', () async {
    await controller.offer(frame);
    clock = clock.add(const Duration(milliseconds: 100));
    await controller.offer(frame);
    await settle();

    expect(analysed, 1);
    expect(emitted.single.boxes.single.name, 'Clownfish');

    clock = clock.add(const Duration(milliseconds: 200));
    await controller.offer(frame);
    expect(analysed, 2);
  });

  test(
    'a frame offered while one is being named is dropped, not queued',
    () async {
      holdAnalysis = Completer<void>();
      final first = controller.offer(frame);
      clock = clock.add(const Duration(seconds: 1));
      expect(controller.wantsFrame, isFalse);
      await controller.offer(frame);
      holdAnalysis!.complete();
      await first;

      expect(analysed, 1);
    },
  );

  test('low free memory pauses naming, which resumes with room', () async {
    memory = const VisionMemory(footprintBytes: 0, availableBytes: 100);
    await controller.offer(frame);
    await settle();
    expect(emitted.single.pause, LivePause.memory);
    expect(analysed, 0);

    memory = _plenty;
    clock = clock.add(const Duration(seconds: 1));
    await controller.offer(frame);
    await settle();
    expect(emitted.last.pause, isNull);
    expect(analysed, 1);
  });

  test('the system saying memory is low pauses from the first frame', () async {
    memory = const VisionMemory(footprintBytes: 0, lowMemory: true);
    await controller.offer(frame);
    await settle();

    expect(emitted.single.pause, LivePause.memory);
  });

  test('an animal that moves a little keeps its track', () async {
    await controller.offer(frame);
    await settle();
    final track = emitted.single.boxes.single.track;
    seen = [_fish(0.12, 0.11), _fish(0.7, 0.7)];
    clock = clock.add(const Duration(seconds: 1));
    await controller.offer(frame);
    await settle();

    final boxes = emitted.last.boxes;
    expect(boxes.first.track, track);
    expect(boxes.last.track, isNot(track));
  });

  test('after dispose nothing is wanted or named', () async {
    await controller.dispose();

    expect(controller.wantsFrame, isFalse);
    await controller.offer(frame);
    expect(analysed, 0);
  });
}
