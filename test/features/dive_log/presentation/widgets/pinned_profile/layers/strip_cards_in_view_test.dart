import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_cards_in_view.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

const _env = DiveDetailSectionId.environment;

/// [card] in content coordinates, the page scrolled to [pixels], in an
/// 800 px viewport.
Set<DiveDetailSectionId> _inView(Rect card, {double pixels = 0}) => cardsInView(
  cardsInContent: {_env: card},
  pixels: pixels,
  viewportHeight: 800,
);

void main() {
  test('the grown strip is 72 px', () {
    expect(kPinnedStripGrownHeight, 72);
    expect(kCardInViewMinPx, 96);
  });

  test('card fully below the strip edge is in view', () {
    expect(_inView(const Rect.fromLTWH(0, 1100, 400, 300), pixels: 1000), {
      _env,
    });
  });

  test('card with 95 px below the 72 px edge is not in view', () {
    // On screen from -133 to 167: 95 px below the edge at 72.
    expect(
      _inView(const Rect.fromLTWH(0, 867, 400, 300), pixels: 1000),
      isEmpty,
    );
  });

  test('card with 96 px below the 72 px edge is in view', () {
    expect(_inView(const Rect.fromLTWH(0, 868, 400, 300), pixels: 1000), {
      _env,
    });
  });

  test('short card counts once all of it shows', () {
    expect(_inView(const Rect.fromLTWH(0, 1072, 400, 60), pixels: 1000), {
      _env,
    });
    // Its top 1 px is under the edge.
    expect(
      _inView(const Rect.fromLTWH(0, 1071, 400, 60), pixels: 1000),
      isEmpty,
    );
  });

  test('card past the viewport bottom is not in view', () {
    // On screen from 710: 90 px above the 800 px bottom.
    expect(_inView(const Rect.fromLTWH(0, 710, 400, 300)), isEmpty);
    expect(_inView(const Rect.fromLTWH(0, 704, 400, 300)), {_env});
  });

  test('card entirely above the edge is not in view', () {
    expect(
      _inView(const Rect.fromLTWH(0, 500, 400, 300), pixels: 1000),
      isEmpty,
    );
  });

  test('several cards are judged one by one', () {
    expect(
      cardsInView(
        cardsInContent: {
          _env: const Rect.fromLTWH(0, 100, 400, 300),
          DiveDetailSectionId.tanks: const Rect.fromLTWH(0, 500, 400, 300),
          DiveDetailSectionId.media: const Rect.fromLTWH(0, 2000, 400, 300),
        },
        pixels: 0,
        viewportHeight: 800,
      ),
      {_env, DiveDetailSectionId.tanks},
    );
  });

  // A card resting on the threshold must not flicker in and out with a
  // pixel of trackpad jitter (review): once in view it stays in until it
  // falls a little further below the threshold.
  group('hysteresis', () {
    Set<DiveDetailSectionId> judged(double top, {required bool wasIn}) =>
        cardsInView(
          cardsInContent: {_env: Rect.fromLTWH(0, top, 400, 300)},
          pixels: 1000,
          viewportHeight: 800,
          previously: wasIn ? {_env} : const {},
        );

    test('a card in view stays in a little below the threshold', () {
      // 90 px below the edge: under 96, inside the hysteresis.
      expect(judged(862, wasIn: true), {_env});
      expect(judged(862, wasIn: false), isEmpty);
    });

    test('it leaves once past the hysteresis', () {
      expect(
        judged(1072 - 300 + 96 - kCardInViewHysteresisPx - 1, wasIn: true),
        isEmpty,
      );
    });

    test('a card out of view still needs the full threshold to come in', () {
      expect(judged(867, wasIn: false), isEmpty);
      expect(judged(868, wasIn: false), {_env});
    });
  });
}
