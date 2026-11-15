import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_lift.dart';

void main() {
  group('pinnedStripShadows', () {
    test('light shadows at full strength', () {
      final s = pinnedStripShadows(Brightness.light, strength: 1);
      expect(s, hasLength(2));
      expect(s[0].color.a, closeTo(0.18, 1e-6));
      expect(s[0].offset, const Offset(0, 2));
      expect(s[0].blurRadius, 4);
      expect(s[1].color.a, closeTo(0.24, 1e-6));
      expect(s[1].offset, const Offset(0, 10));
      expect(s[1].blurRadius, 22);
      for (final shadow in s) {
        expect(shadow.color.r, 0);
        expect(shadow.color.g, 0);
        expect(shadow.color.b, 0);
        expect(shadow.spreadRadius, 0);
      }
    });

    // Black barely darkens a near-black page, so dark mode needs far more
    // of it to read as a shadow at all.
    test('dark shadows at full strength', () {
      final s = pinnedStripShadows(Brightness.dark, strength: 1);
      expect(s, hasLength(2));
      expect(s[0].color.a, closeTo(0.65, 1e-6));
      expect(s[0].offset, const Offset(0, 2));
      expect(s[0].blurRadius, 6);
      expect(s[1].color.a, closeTo(0.70, 1e-6));
      expect(s[1].offset, const Offset(0, 12));
      expect(s[1].blurRadius, 28);
    });

    // Scaling only the size would leave a hard, fully dark line just as the
    // strip starts to condense; opacity shrinks with it.
    test('strength scales opacity, offset and blur', () {
      final half = pinnedStripShadows(Brightness.dark, strength: 0.5);
      expect(half[1].color.a, closeTo(0.35, 1e-6));
      expect(half[1].offset, const Offset(0, 6));
      expect(half[1].blurRadius, 14);
    });

    test('strength is clamped to 0..1', () {
      final over = pinnedStripShadows(Brightness.light, strength: 2);
      expect(over[1].color.a, closeTo(0.24, 1e-6));
      expect(over[1].blurRadius, 22);
      expect(pinnedStripShadows(Brightness.light, strength: -1), isEmpty);
    });

    test('no shadows at strength 0', () {
      expect(pinnedStripShadows(Brightness.light, strength: 0), isEmpty);
      expect(pinnedStripShadows(Brightness.dark, strength: 0), isEmpty);
    });
  });

  group('pinnedStripEdge', () {
    test('dark rim when the theme has no outline', () {
      final rim = pinnedStripEdge(
        brightness: Brightness.dark,
        themeSide: BorderSide.none,
        surfaceOpacity: 1,
        strength: 1,
      );
      expect(rim.width, 1);
      expect(rim.style, BorderStyle.solid);
      expect(rim.color.a, closeTo(kPinnedStripRimAlpha, 1e-6));
      expect(rim.color.r, 1);
      expect(rim.color.g, 1);
      expect(rim.color.b, 1);
    });

    test('rim follows strength and is off at 0', () {
      final half = pinnedStripEdge(
        brightness: Brightness.dark,
        themeSide: BorderSide.none,
        surfaceOpacity: 1,
        strength: 0.5,
      );
      expect(half.color.a, closeTo(0.06, 1e-6));
      expect(
        pinnedStripEdge(
          brightness: Brightness.dark,
          themeSide: BorderSide.none,
          surfaceOpacity: 0.5,
          strength: 0,
        ),
        BorderSide.none,
      );
    });

    test('no rim in light mode', () {
      expect(
        pinnedStripEdge(
          brightness: Brightness.light,
          themeSide: BorderSide.none,
          surfaceOpacity: 1,
          strength: 1,
        ),
        BorderSide.none,
      );
    });

    // A theme whose cards have an outline already marks the edge; the rim
    // on top of it would draw a second line.
    test('theme outline wins over the rim', () {
      const side = BorderSide(color: Color(0xFF336699), width: 1.5);
      final edge = pinnedStripEdge(
        brightness: Brightness.dark,
        themeSide: side,
        surfaceOpacity: 0.5,
        strength: 0,
      );
      expect(edge.width, 1.5);
      expect(edge.color.a, closeTo(0.5, 1e-6));
      expect(edge.color.b, closeTo(side.color.b, 1e-6));
      final settled = pinnedStripEdge(
        brightness: Brightness.dark,
        themeSide: side,
        surfaceOpacity: 1,
        strength: 1,
      );
      expect(settled, side);
    });

    test('a zero-width theme outline does not count as one', () {
      final edge = pinnedStripEdge(
        brightness: Brightness.dark,
        themeSide: const BorderSide(color: Color(0xFF336699), width: 0),
        surfaceOpacity: 1,
        strength: 1,
      );
      expect(edge.width, 1);
      expect(edge.color.a, closeTo(kPinnedStripRimAlpha, 1e-6));
    });
  });
}
