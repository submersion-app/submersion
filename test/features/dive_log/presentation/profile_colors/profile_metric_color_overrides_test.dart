import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_swatches.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

int _argb(Color c) => c.toARGB32();
const _purpleA200 = Color(0xFFE040FB);

void main() {
  const none = ProfileMetricColorOverrides.none;

  group('withColor', () {
    test('a free colour is stored for the metric alone', () {
      final next = none.withColor(ProfileMetric.ppO2, _purpleA200);
      expect(next.argbOf(ProfileMetric.ppO2), _argb(_purpleA200));
      expect(next.count, 1);
    });

    test('a colour another metric shows swaps the two', () {
      // TTS shows Pink 800 by default; ppO2 takes it.
      final next = none.withColor(ProfileMetric.ppO2, ProfileMetricColors.tts);
      expect(
        next.effectiveArgb(ProfileMetric.ppO2),
        _argb(ProfileMetricColors.tts),
      );
      expect(
        next.effectiveArgb(ProfileMetric.tts),
        _argb(ProfileMetricColors.ppO2),
      );
      expect(next.count, 2);
    });

    test('a metric handed its own default stores no override', () {
      final swapped = none.withColor(
        ProfileMetric.ppO2,
        ProfileMetricColors.tts,
      );
      // TTS takes Pink 800 back; ppO2 receives Cyan 600, its own default.
      final back = swapped.withColor(
        ProfileMetric.tts,
        ProfileMetricColors.tts,
      );
      expect(back, none);
    });

    test('null on a fixed-default metric is choosing that default', () {
      final swapped = none.withColor(
        ProfileMetric.ppO2,
        ProfileMetricColors.tts,
      );
      expect(swapped.withColor(ProfileMetric.ppO2, null), none);
    });

    test('an Auto metric taking a held colour hands the holder the first '
        'free swatch, never a theme colour', () {
      final next = none.withColor(
        ProfileMetric.temperature,
        ProfileMetricColors.depth,
      );
      expect(
        next.effectiveArgb(ProfileMetric.temperature),
        _argb(ProfileMetricColors.depth),
      );
      // Swatches 0-17 are held by the 18 fixed defaults (depth's now by
      // temperature); 18 (Cyan 800) is the first free one.
      expect(
        next.effectiveArgb(ProfileMetric.depth),
        _argb(profileMetricSwatches[18]),
      );
    });

    test('null on an Auto metric returns it to Auto and swaps nothing', () {
      final custom = none.withColor(ProfileMetric.pressure, _purpleA200);
      final back = custom.withColor(ProfileMetric.pressure, null);
      expect(back.argbOf(ProfileMetric.pressure), isNull);
      expect(back.effectiveArgb(ProfileMetric.pressure), isNull);
      expect(back, none);
    });

    test('picking the colour a metric already shows changes nothing', () {
      expect(none.withColor(ProfileMetric.ndl, ProfileMetricColors.ndl), none);
    });

    test('Auto metrics on Auto never receive a swap', () {
      final next = none.withColor(ProfileMetric.ppO2, ProfileMetricColors.ndl);
      expect(next.effectiveArgb(ProfileMetric.temperature), isNull);
      expect(next.effectiveArgb(ProfileMetric.pressure), isNull);
    });
  });

  group('deduped', () {
    test('keeps the first metric in enum order and moves later holders to '
        'the first free swatch', () {
      // Two devices resolved per field: ppO2 and ppN2 both hold Purple A200.
      final clash = ProfileMetricColorOverrides.fromArgb({
        ProfileMetric.ppO2: _argb(_purpleA200),
        ProfileMetric.ppN2: _argb(_purpleA200),
      });
      final fixed = clash.deduped();
      expect(fixed.effectiveArgb(ProfileMetric.ppO2), _argb(_purpleA200));
      // Free under the clash: Cyan 600 (ppO2's default, now unused) is
      // swatch 10, the first one nobody shows.
      expect(
        fixed.effectiveArgb(ProfileMetric.ppN2),
        _argb(ProfileMetricColors.ppO2),
      );
    });

    test('an override equal to an earlier metric default moves the later '
        'metric', () {
      final clash = ProfileMetricColorOverrides.fromArgb({
        ProfileMetric.meanDepth: _argb(ProfileMetricColors.depth),
      });
      final fixed = clash.deduped();
      expect(
        fixed.effectiveArgb(ProfileMetric.depth),
        _argb(ProfileMetricColors.depth),
      );
      expect(
        fixed.effectiveArgb(ProfileMetric.meanDepth),
        isNot(_argb(ProfileMetricColors.depth)),
      );
    });

    test('returns itself when nothing clashes', () {
      final ok = none.withColor(ProfileMetric.ppO2, _purpleA200);
      expect(identical(ok.deduped(), ok), isTrue);
    });

    test('withColor starts from the deduped state', () {
      final clash = ProfileMetricColorOverrides.fromArgb({
        ProfileMetric.ppO2: _argb(_purpleA200),
        ProfileMetric.ppN2: _argb(_purpleA200),
      });
      final next = clash.withColor(ProfileMetric.gf, const Color(0xFF00E676));
      final shown = [
        for (final m in ProfileMetric.values) ?next.effectiveArgb(m),
      ];
      expect(shown.toSet(), hasLength(shown.length));
    });
  });

  group('fromArgb', () {
    test('drops nulls, fully transparent values and stored defaults', () {
      final o = ProfileMetricColorOverrides.fromArgb({
        ProfileMetric.depth: null,
        ProfileMetric.ppO2: 0x0000ACC1,
        ProfileMetric.ndl: _argb(ProfileMetricColors.ndl),
        ProfileMetric.gf: _argb(_purpleA200),
      });
      expect(o.count, 1);
      expect(o.argbOf(ProfileMetric.gf), _argb(_purpleA200));
    });

    test('keeps a colour outside the palette (a newer build may add some)', () {
      final o = ProfileMetricColorOverrides.fromArgb({
        ProfileMetric.gf: 0xFF123456,
      });
      expect(o.argbOf(ProfileMetric.gf), 0xFF123456);
    });
  });

  test('cacheKey is exact: equal sets share it, different sets never do', () {
    final a = none.withColor(ProfileMetric.ppO2, _purpleA200);
    final b = none.withColor(ProfileMetric.ppN2, _purpleA200);
    expect(
      a.cacheKey,
      none.withColor(ProfileMetric.ppO2, _purpleA200).cacheKey,
    );
    expect(a.cacheKey, isNot(b.cacheKey));
    expect(a.cacheKey, isNot(none.cacheKey));
  });

  test('equality is by value', () {
    expect(
      none.withColor(ProfileMetric.ppO2, _purpleA200),
      none.withColor(ProfileMetric.ppO2, _purpleA200),
    );
    expect(
      none.withColor(ProfileMetric.ppO2, _purpleA200).hashCode,
      none.withColor(ProfileMetric.ppO2, _purpleA200).hashCode,
    );
  });
}
