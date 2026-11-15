import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_cards_in_view.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

const _env = DiveDetailSectionId.environment;

/// [card] in content coordinates, the page scrolled to [pixels], in an
/// 800 px viewport: 728 px of room below the grown strip.
Set<DiveDetailSectionId> _inView(
  Rect card, {
  double pixels = 0,
  bool wasIn = false,
}) => cardsInView(
  cardsInContent: {_env: card},
  pixels: pixels,
  viewportHeight: 800,
  previously: wasIn ? {_env} : const {},
);

/// A 300 px card whose top is [screenTop] px from the viewport's top.
Rect _card(double screenTop, {double height = 300}) =>
    Rect.fromLTWH(0, 1000 + screenTop, 400, height);

void main() {
  test('the grown strip is 72 px and a card needs three quarters', () {
    expect(kPinnedStripGrownHeight, 72);
    expect(kCardInViewShare, 0.75);
  });

  // The diver: layers show only once the whole of a card, or most of it, is
  // in the window.
  group('a card that fits below the strip', () {
    test('wholly in view, it counts', () {
      expect(_inView(_card(100), pixels: 1000), {_env});
    });

    test('with a quarter under the strip, it counts', () {
      // 225 of its 300 px show below the edge at 72.
      expect(_inView(_card(-3), pixels: 1000), {_env});
    });

    test('with more than a quarter under the strip, it does not', () {
      // 224 px show.
      expect(_inView(_card(-4), pixels: 1000), isEmpty);
    });

    test('half in view below, it does not count', () {
      // Its top half shows above the viewport's bottom.
      expect(_inView(_card(650), pixels: 1000), isEmpty);
    });

    test('with three quarters above the viewport bottom, it counts', () {
      expect(_inView(_card(575), pixels: 1000), {_env});
      expect(_inView(_card(576), pixels: 1000), isEmpty);
    });

    test('a short card needs most of itself too', () {
      expect(_inView(_card(100, height: 60), pixels: 1000), {_env});
      // 45 of its 60 px show below the edge.
      expect(_inView(_card(57, height: 60), pixels: 1000), {_env});
      // 44 px show.
      expect(_inView(_card(56, height: 60), pixels: 1000), isEmpty);
    });

    test('above the edge altogether, it does not count', () {
      expect(_inView(_card(-400), pixels: 1000), isEmpty);
    });
  });

  group('a card taller than the room below the strip', () {
    test('filling most of the room, it counts', () {
      // 2000 px tall, its middle filling the whole 728 px room.
      expect(_inView(_card(-500, height: 2000), pixels: 1000), {_env});
      // Its top 546 px, three quarters of the room, from 254 down.
      expect(_inView(_card(254, height: 2000), pixels: 1000), {_env});
    });

    test('filling less than most of the room, it does not', () {
      expect(_inView(_card(300, height: 2000), pixels: 1000), isEmpty);
    });
  });

  test('several cards are judged one by one', () {
    expect(
      cardsInView(
        cardsInContent: {
          _env: const Rect.fromLTWH(0, 100, 400, 300),
          DiveDetailSectionId.tanks: const Rect.fromLTWH(0, 420, 400, 300),
          DiveDetailSectionId.media: const Rect.fromLTWH(0, 760, 400, 300),
        },
        pixels: 0,
        viewportHeight: 800,
      ),
      {_env, DiveDetailSectionId.tanks},
    );
  });

  // A card resting on the threshold must not flicker in and out with a
  // pixel of trackpad jitter: once in view it stays in until it falls a
  // little further below the threshold.
  group('hysteresis', () {
    test('a card in view stays in a little below the threshold', () {
      // 215 px show: under 225, inside the hysteresis.
      expect(_inView(_card(-13), pixels: 1000, wasIn: true), {_env});
      expect(_inView(_card(-13), pixels: 1000), isEmpty);
    });

    test('it leaves once past the hysteresis', () {
      // 225 - 16 - 1 = 208 px show.
      expect(
        _inView(_card(-20), pixels: 1000, wasIn: true),
        isEmpty,
        reason: '${kCardInViewHysteresisPx}px of hysteresis',
      );
    });
  });
}
