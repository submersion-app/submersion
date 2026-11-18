import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/pinned_strip_layer_animator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_data.dart';

const _temperatureOnly = PinnedStripLayerData(
  lines: [
    StripLine(
      layer: StripLayer.temperature,
      key: 'temperature',
      color: Colors.red,
      runs: [
        [StripPoint(0, 20), StripPoint(60, 18)],
      ],
      min: 18,
      max: 20,
    ),
  ],
  dots: [StripDot(seconds: 30, depthMeters: 10)],
);

late StripLayerState _last;

Future<void> _pump(
  WidgetTester tester, {
  Set<DiveDetailSectionId> cards = const {},
  bool settled = true,
  PinnedStripLayerData data = _temperatureOnly,
  bool reduceMotion = false,
}) => tester.pumpWidget(
  MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: PinnedStripLayerAnimator(
      data: data,
      cardsInView: cards,
      settled: settled,
      builder: (context, state) {
        _last = state;
        return const SizedBox.shrink();
      },
    ),
  ),
);

const _env = {DiveDetailSectionId.environment};

void main() {
  testWidgets('no cards in view: every strength 0 and grow 0', (tester) async {
    await _pump(tester);
    for (final layer in StripLayer.values) {
      expect(_last.strengthOf(layer), 0);
    }
    expect(_last.grow, 0);
    expect(_last.active, isEmpty);
  });

  testWidgets('environment in view while settled fades temperature in over '
      '250 ms', (tester) async {
    await _pump(tester);
    await _pump(tester, cards: _env);
    expect(_last.active, {StripLayer.temperature});
    await tester.pump(const Duration(milliseconds: 125));
    final halfway = _last.strengthOf(StripLayer.temperature);
    expect(halfway, greaterThan(0));
    expect(halfway, lessThan(1));
    expect(_last.grow, closeTo(halfway, 1e-9));
    await tester.pump(const Duration(milliseconds: 125));
    expect(_last.strengthOf(StripLayer.temperature), 1);
    expect(_last.grow, 1);
  });

  // Issue #4579: the strip condensed to its normal height, then grew once it
  // settled. It grows while it condenses, so it reaches its final height in
  // one motion; only the layers wait for it to settle.
  testWidgets('not settled: no layer shows, but the strip grows for the card', (
    tester,
  ) async {
    await _pump(tester, cards: _env, settled: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_last.strengthOf(StripLayer.temperature), 0);
    expect(_last.active, isEmpty);
    expect(_last.grow, 1);
  });

  // A fast scroll can settle the strip before its 250 ms growth is done;
  // it then kept growing after settling, the bounce of #4579 (review). The
  // hand-over finishes the growth ([StripLayerState.condensedBy]), so it is
  // complete at once when the strip settles.
  testWidgets('settling completes the growth at once', (tester) async {
    await _pump(tester, cards: _env, settled: false);
    expect(_last.grow, 0);
    expect(_last.growTarget, 1);
    await _pump(tester, cards: _env);
    expect(_last.grow, 1);
  });

  test('the hand-over carries the growth to its target', () {
    const growing = StripLayerState(
      data: PinnedStripLayerData.empty,
      strengths: {},
      grow: 0.2,
      active: {},
      growTarget: 1,
    );
    expect(growing.condensedBy(0).grow, 0.2);
    expect(growing.condensedBy(0.5).grow, 0.5);
    expect(growing.condensedBy(0.9).grow, 0.9);
    // Settled, the animator's own growth stands.
    expect(identical(growing.condensedBy(1), growing), isTrue);
    const shrinking = StripLayerState(
      data: PinnedStripLayerData.empty,
      strengths: {},
      grow: 0.8,
      active: {},
    );
    expect(shrinking.condensedBy(0).grow, 0.8);
    expect(shrinking.condensedBy(0.5).grow, 0.5);
    expect(shrinking.condensedBy(0.9).grow, closeTo(0.1, 1e-9));
    expect(identical(shrinking.condensedBy(1), shrinking), isTrue);
  });

  testWidgets('settling with the card in view keeps the strip grown', (
    tester,
  ) async {
    await _pump(tester, cards: _env, settled: false);
    await tester.pump(const Duration(milliseconds: 300));
    await _pump(tester, cards: _env);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_last.grow, 1);
    expect(_last.strengthOf(StripLayer.temperature), greaterThan(0));
  });

  testWidgets('card leaves mid-fade: strength reverses from where it was', (
    tester,
  ) async {
    await _pump(tester);
    await _pump(tester, cards: _env);
    await tester.pump(const Duration(milliseconds: 100));
    final reached = _last.strengthOf(StripLayer.temperature);
    expect(reached, greaterThan(0));
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 16));
    final after = _last.strengthOf(StripLayer.temperature);
    expect(after, lessThan(reached));
    expect(after, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_last.strengthOf(StripLayer.temperature), 0);
    expect(_last.grow, 0);
  });

  // A layer turned on and off again before its fade had ticked once kept
  // fading in, and stayed on with nothing to show it for (#4579).
  testWidgets('a layer turned off before its fade starts stays hidden', (
    tester,
  ) async {
    await _pump(tester);
    await _pump(tester, cards: _env);
    await _pump(tester, cards: _env, settled: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_last.strengthOf(StripLayer.temperature), 0);
    expect(_last.active, isEmpty);
    // And it can still come back.
    await _pump(tester, cards: _env);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_last.strengthOf(StripLayer.temperature), 1);
  });

  // The mirror case: turned back on before its fade-out had ticked, it kept
  // fading out with its card in view.
  testWidgets('a layer turned back on before its fade-out starts stays on', (
    tester,
  ) async {
    await _pump(tester);
    await _pump(tester, cards: _env);
    await tester.pump(const Duration(milliseconds: 300));
    await _pump(tester);
    await _pump(tester, cards: _env);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_last.strengthOf(StripLayer.temperature), 1);
    expect(_last.grow, 1);
  });

  testWidgets('media in view with photos fades media in, grow stays 0', (
    tester,
  ) async {
    await _pump(tester);
    await _pump(tester, cards: {DiveDetailSectionId.media});
    await tester.pump(const Duration(milliseconds: 300));
    expect(_last.strengthOf(StripLayer.media), 1);
    expect(_last.grow, 0);
  });

  testWidgets('a card whose layer has no data shows and grows nothing', (
    tester,
  ) async {
    await _pump(tester);
    await _pump(tester, cards: {DiveDetailSectionId.tanks});
    await tester.pump(const Duration(milliseconds: 300));
    expect(_last.strengthOf(StripLayer.tankPressure), 0);
    expect(_last.active, isEmpty);
    expect(_last.grow, 0);
  });

  testWidgets('reduce motion applies targets at once', (tester) async {
    await _pump(tester, reduceMotion: true);
    await _pump(tester, cards: _env, reduceMotion: true);
    await tester.pump();
    expect(_last.strengthOf(StripLayer.temperature), 1);
    expect(_last.grow, 1);
  });
}
