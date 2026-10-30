import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';

void main() {
  test('round-trips through JSON, omitting defaults', () {
    const a = ColorAdjustment(
      autoOverride: true,
      warmth: 0.3,
      whitePoint: WhitePoint(0.4, 0.6, 0.7),
    );
    final s = a.toJsonString();
    expect(jsonDecode(s), {
      'v': 1,
      'auto': true,
      'warmth': 0.3,
      'white': [0.4, 0.6, 0.7],
    });
    expect(ColorAdjustment.fromJsonString(s), a);
  });

  test('every field round-trips', () {
    const a = ColorAdjustment(
      autoOverride: false,
      strength: 0.4,
      warmth: -0.2,
      tint: 0.1,
      brightness: 0.25,
      contrast: -0.5,
      saturation: 0.6,
    );
    expect(ColorAdjustment.fromJsonString(a.toJsonString()), a);
  });

  test('null, empty, malformed and non-object JSON give null', () {
    for (final raw in [null, '', '{', '[1]', '"x"', 'null']) {
      expect(ColorAdjustment.fromJsonString(raw), isNull, reason: '$raw');
    }
  });

  test('unknown keys and a newer version are tolerated', () {
    expect(
      ColorAdjustment.fromJsonString('{"v":9,"tint":0.2,"future":1}'),
      const ColorAdjustment(tint: 0.2),
    );
  });

  test('wrongly typed values fall back to their defaults', () {
    expect(
      ColorAdjustment.fromJsonString(
        '{"v":1,"warmth":"hot","tint":0.1,"auto":"yes","white":[1,"x"]}',
      ),
      const ColorAdjustment(tint: 0.1),
    );
  });

  test('the stored neutral value (a cleared adjustment) reads as none', () {
    expect(
      ColorAdjustment.fromJsonString(const ColorAdjustment().toJsonString()),
      isNull,
    );
    expect(ColorAdjustment.fromJsonString('{"v":1,"warmth":"hot"}'), isNull);
  });

  test('out-of-range values clamp', () {
    expect(
      ColorAdjustment.fromJsonString(
        '{"v":1,"warmth":5,"strength":-1,"white":[2,-1,0.5]}',
      ),
      const ColorAdjustment(
        warmth: 1,
        strength: 0,
        whitePoint: WhitePoint(1, 0, 0.5),
      ),
    );
  });

  test(
    'withSlidersFrom copies sliders and auto, keeps its own white point',
    () {
      const target = ColorAdjustment(
        warmth: -0.5,
        whitePoint: WhitePoint(0.5, 0.5, 0.6),
      );
      const source = ColorAdjustment(
        autoOverride: false,
        warmth: 0.4,
        contrast: 0.2,
        whitePoint: WhitePoint(0.1, 0.2, 0.3),
      );
      expect(
        target.withSlidersFrom(source),
        const ColorAdjustment(
          autoOverride: false,
          warmth: 0.4,
          contrast: 0.2,
          whitePoint: WhitePoint(0.5, 0.5, 0.6),
        ),
      );
    },
  );

  test('isNeutral only for all defaults', () {
    expect(const ColorAdjustment().isNeutral, isTrue);
    expect(const ColorAdjustment(autoOverride: false).isNeutral, isFalse);
    expect(const ColorAdjustment(tint: 0.01).isNeutral, isFalse);
    expect(
      const ColorAdjustment(whitePoint: WhitePoint(0.5, 0.5, 0.5)).isNeutral,
      isFalse,
    );
  });

  test('copyWith can clear the override and the white point', () {
    const a = ColorAdjustment(
      autoOverride: true,
      whitePoint: WhitePoint(0.5, 0.5, 0.5),
    );
    expect(
      a.copyWith(autoOverride: null, whitePoint: null),
      const ColorAdjustment(),
    );
    expect(a.copyWith(warmth: 0.2).autoOverride, isTrue);
  });
}
