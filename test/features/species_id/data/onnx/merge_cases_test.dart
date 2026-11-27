import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/engines/onnx/pipeline/detector_reading.dart';

/// The cases of `vision_cli/merge_check.swift` in submersion-app/species-pack,
/// one test per `check(...)`, with the same names and values: the Swift
/// pipeline and this one must merge two detectors' boxes exactly as the
/// accuracy scorer's `boxes.py` does.
void main() {
  List<PipelineBox> merge(List<List<PipelineBox>> runs, {int limit = 8}) =>
      mergeRuns(runs, iou: 0.5, limit: limit);

  const lowA = PipelineBox(0.1, 0.1, 0.3, 0.3, 0.6);
  const highB = PipelineBox(0.11, 0.1, 0.3, 0.3, 0.9);
  const farA = PipelineBox(0.0, 0.0, 0.2, 0.2, 0.6);
  const farB = PipelineBox(0.5, 0.5, 0.2, 0.2, 0.9);
  const thirdB = PipelineBox(0.1, 0.0, 0.2, 0.2, 0.9);
  final run = [
    for (var i = 0; i < 10; i++)
      PipelineBox(i / 10, 0.0, 0.05, 0.05, 1 - i / 100),
  ];
  const tieA = PipelineBox(0.2, 0.2, 0.3, 0.3, 0.5);
  const tieB = PipelineBox(0.21, 0.2, 0.3, 0.3, 0.5);
  const tieP = PipelineBox(0.0, 0.0, 0.1, 0.1, 0.7);
  const tieQ = PipelineBox(0.6, 0.6, 0.1, 0.1, 0.7);
  const only = [
    PipelineBox(0.0, 0.0, 0.1, 0.1, 0.9),
    PipelineBox(0.5, 0.5, 0.1, 0.1, 0.8),
  ];
  const overlapA = PipelineBox(0.1, 0.1, 0.3, 0.3, 0.9);
  const overlapB = PipelineBox(0.12, 0.1, 0.3, 0.3, 0.8);
  const whole = PipelineBox(0.0, 0.0, 1.0, 1.0, 0.9);
  const half = PipelineBox(0.0, 0.0, 0.5, 1.0, 0.4);
  const under = PipelineBox(0.0, 0.0, 0.49, 1.0, 0.4);

  test('keeps the higher of two overlapping boxes', () {
    expect(
      merge([
        [lowA],
        [highB],
      ]),
      [highB],
    );
  });

  test('keeps both when they do not overlap, best first', () {
    expect(
      merge([
        [farA],
        [farB],
      ]),
      [farB, farA],
    );
  });

  test('overlap below the threshold keeps both', () {
    expect(
      merge([
        [farA],
        [thirdB],
      ]),
      [thirdB, farA],
    );
  });

  test('stops at the limit', () {
    expect(merge([run]), run.take(8).toList());
  });

  test("equal scores keep the first detector's box", () {
    expect(
      merge([
        [tieA],
        [tieB],
      ]),
      [tieA],
    );
  });

  test('equal scores keep pool order within a run', () {
    expect(
      merge([
        [tieP, tieQ],
        [],
      ]),
      [tieP, tieQ],
    );
  });

  test('equal scores keep pool order, reversed', () {
    expect(
      merge([
        [tieQ, tieP],
        [],
      ]),
      [tieQ, tieP],
    );
  });

  test('equal scores across runs keep run order', () {
    expect(
      merge([
        [tieQ],
        [tieP],
      ]),
      [tieQ, tieP],
    );
  });

  test("one empty run returns the other's boxes", () {
    expect(merge([[], only]), only);
  });

  test('one empty run is still capped', () {
    expect(merge([[], run], limit: 3), run.take(3).toList());
  });

  test('one empty run still merges its own overlapping boxes', () {
    expect(
      merge([
        [overlapA, overlapB],
        [],
      ]),
      [overlapA],
    );
  });

  test('an overlap of exactly the threshold is dropped', () {
    expect(
      merge([
        [whole],
        [half],
      ]),
      [whole],
    );
  });

  test('an overlap just under the threshold is kept', () {
    expect(
      merge([
        [whole],
        [under],
      ]),
      [whole, under],
    );
  });

  test('nothing from either detector is nothing', () {
    expect(merge([[], []]), isEmpty);
  });
}
