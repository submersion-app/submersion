import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/chart/plan_stop_tags.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

PlanCanvasSeries _series(
  List<(double depth, int seconds)> stops, {
  Set<int> switchOnly = const {},
}) {
  var t = 1800.0;
  var i = 0;
  return PlanCanvasSeries(
    profile: const [],
    ceiling: const [],
    gasSwitches: const [],
    stopLabels: [
      for (final (depth, seconds) in stops)
        CanvasMarker(
          t += 120,
          depth,
          '',
          durationSeconds: seconds,
          isGasSwitchOnly: switchOnly.contains(i++),
        ),
    ],
    maxTimeSeconds: 3000,
    maxDepth: 45,
  );
}

String _metres(double m) => '${m.round()}m';

void main() {
  final base = _series([(9, 120), (6, 60), (3, 180)]);

  test('without a preview the base stops are tagged as they are', () {
    final tags = planStopTags(series: base, formatDepth: _metres);

    expect(tags.map((t) => t.label), ['9m 2′', '6m 1′', '3m 3′']);
    expect(tags.every((t) => t.change == null && !t.isNew), isTrue);
    expect(tags.first.marker, same(base.stopLabels.first));
  });

  test('a preview tags its own stops with the change against the base', () {
    final preview = _series([(12, 120), (9, 120), (6, 240), (3, 300)]);

    final tags = planStopTags(
      series: base,
      preview: preview,
      formatDepth: _metres,
    );

    expect(tags.map((t) => t.label), ['12m 2′', '9m 2′', '6m 4′', '3m 5′']);
    expect(tags.map((t) => t.change), [null, null, '+3', '+2']);
    expect(tags.map((t) => t.isNew), [true, false, false, false]);
    expect(tags.first.marker, same(preview.stopLabels.first));
  });

  test('a stop the preview no longer has gets no tag', () {
    final preview = _series([(6, 60), (3, 180)]);

    final tags = planStopTags(
      series: base,
      preview: preview,
      formatDepth: _metres,
    );

    expect(tags.map((t) => t.label), ['6m 1′', '3m 3′']);
  });

  test('the change is taken from the whole minutes the tags show', () {
    // 1:59 shows as 1′, 4:01 as 4′: the tags read +3, not the +2 that the
    // seconds would round to.
    final before = _series([(6, 119)]);
    final after = _series([(6, 241)]);

    final tags = planStopTags(
      series: before,
      preview: after,
      formatDepth: _metres,
    );

    expect(tags.single.label, '6m 4′');
    expect(tags.single.change, '+3');
  });

  test('a shorter stop shows a negative change', () {
    final tags = planStopTags(
      series: _series([(3, 300)]),
      preview: _series([(3, 180)]),
      formatDepth: _metres,
    );

    expect(tags.single.change, '−2');
  });

  test('stops sharing a depth are compared in order', () {
    // A gas-switch-only stop and the stop after it can share a depth.
    final tags = planStopTags(
      series: _series([(21, 60), (21, 120)]),
      preview: _series([(21, 60), (21, 300), (21, 60)]),
      formatDepth: _metres,
    );

    expect(tags.map((t) => t.change), [null, '+3', null]);
    expect(tags.map((t) => t.isNew), [false, false, true]);
  });

  test('a switch stop is compared with the switch stop, not the deco stop', () {
    // The base holds 21 m for a 30 s switch, then 2' of deco; with that gas
    // lost the preview holds 21 m once, 3' of deco. Matched in order it would
    // read +2 against the switch stop; against the deco stop it is +1.
    final tags = planStopTags(
      series: _series([(21, 30), (21, 120)], switchOnly: {0}),
      preview: _series([(21, 180)]),
      formatDepth: _metres,
    );

    expect(tags.single.change, '+1');
    expect(tags.single.isNew, isFalse);
  });

  test('a switch stop only the preview holds is new', () {
    final tags = planStopTags(
      series: _series([(21, 120)]),
      preview: _series([(21, 30), (21, 120)], switchOnly: {0}),
      formatDepth: _metres,
    );

    expect(tags.map((t) => t.isNew), [true, false]);
    expect(tags.map((t) => t.change), [null, null]);
  });

  test('a stop shorter than a minute shows as one, never as zero', () {
    final tags = planStopTags(
      series: _series([(21, 30), (6, 60)]),
      formatDepth: _metres,
    );

    expect(tags.map((t) => t.label), ['21m 1′', '6m 1′']);
    expect(planStopDurationText(59), '1′');
    expect(planStopDurationText(119), '1′');
  });

  test('depths are formatted with the given unit', () {
    final tags = planStopTags(
      series: base,
      formatDepth: (m) => '${(m * 3.28084).round()}ft',
    );

    expect(tags.first.label, '30ft 2′');
  });
}
