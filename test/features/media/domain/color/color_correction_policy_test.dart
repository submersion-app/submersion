import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/channel_stats.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/color/color_correction_policy.dart';
import 'package:submersion/features/media/domain/color/color_matrix.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

MediaEnrichment enrichment({
  double? depth = 18,
  MatchConfidence confidence = MatchConfidence.interpolated,
  int? offset,
}) => MediaEnrichment(
  id: 'e',
  mediaId: 'm',
  diveId: 'd',
  depthMeters: depth,
  elapsedSeconds: 600,
  matchConfidence: confidence,
  timestampOffsetSeconds: offset,
  createdAt: DateTime.utc(2026),
);

MediaItem item({
  String? diveId = 'd',
  MediaType type = MediaType.photo,
  MediaEnrichment? enrichment,
}) => MediaItem(
  id: 'm',
  diveId: diveId,
  mediaType: type,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  enrichment: enrichment,
);

const blue = ChannelStats(meanR: 0.08, meanG: 0.40, meanB: 0.55);
const warm = ChannelStats(meanR: 0.70, meanG: 0.60, meanB: 0.45);

void main() {
  group('isSurfaceShot', () {
    test('a shot outside the recorded profile is a surface shot', () {
      expect(
        isSurfaceShot(
          enrichment(confidence: MatchConfidence.estimated, offset: -90),
        ),
        isTrue,
      );
    });
    test('a mid-dive shot across a sparse profile gap is not', () {
      // The matcher marks interpolation across a long gap `estimated` too,
      // but only edge clamps carry an offset.
      expect(
        isSurfaceShot(
          enrichment(depth: 20, confidence: MatchConfidence.estimated),
        ),
        isFalse,
      );
    });
    test('a shot shallower than 1 m is a surface shot', () {
      expect(isSurfaceShot(enrichment(depth: 0.6)), isTrue);
    });
    test('an 18 m interpolated shot is not', () {
      expect(isSurfaceShot(enrichment()), isFalse);
    });
    test('no enrichment is not known to be a surface shot', () {
      expect(isSurfaceShot(null), isFalse);
    });
  });

  group('autoEnabledFor', () {
    test('follows the diver setting by default', () {
      expect(autoEnabledFor(item(), diverAutoEnabled: true), isTrue);
      expect(autoEnabledFor(item(), diverAutoEnabled: false), isFalse);
    });
    test('the per-item override wins in both directions', () {
      expect(
        autoEnabledFor(
          item(),
          adjustment: const ColorAdjustment(autoOverride: false),
          diverAutoEnabled: true,
        ),
        isFalse,
      );
      expect(
        autoEnabledFor(
          item(),
          adjustment: const ColorAdjustment(autoOverride: true),
          diverAutoEnabled: false,
        ),
        isTrue,
      );
    });
    test('never for media that is not on a dive, even when forced on', () {
      expect(
        autoEnabledFor(
          item(diveId: null),
          adjustment: const ColorAdjustment(autoOverride: true),
          diverAutoEnabled: true,
        ),
        isFalse,
      );
    });
    test('never for signatures', () {
      expect(
        autoEnabledFor(
          item(type: MediaType.instructorSignature),
          diverAutoEnabled: true,
        ),
        isFalse,
      );
    });
    test('never for documents', () {
      expect(
        autoEnabledFor(item(type: MediaType.document), diverAutoEnabled: true),
        isFalse,
      );
    });
  });

  group('needsAutoStats', () {
    test('needs stats for an underwater dive photo with auto on', () {
      expect(
        needsAutoStats(item(enrichment: enrichment()), diverAutoEnabled: true),
        isTrue,
      );
    });
    test('none with auto off', () {
      expect(
        needsAutoStats(item(enrichment: enrichment()), diverAutoEnabled: false),
        isFalse,
      );
    });
    test('none when a white point replaces the automatic fix', () {
      expect(
        needsAutoStats(
          item(enrichment: enrichment()),
          adjustment: const ColorAdjustment(
            whitePoint: WhitePoint(0.5, 0.6, 0.7),
          ),
          diverAutoEnabled: true,
        ),
        isFalse,
      );
    });
    test('none for a surface photo', () {
      expect(
        needsAutoStats(
          item(enrichment: enrichment(depth: 0.3)),
          diverAutoEnabled: true,
        ),
        isFalse,
      );
    });
    test('a surface-starting video still needs stats (per moment)', () {
      expect(
        needsAutoStats(
          item(
            type: MediaType.video,
            enrichment: enrichment(confidence: MatchConfidence.estimated),
          ),
          diverAutoEnabled: true,
        ),
        isTrue,
      );
    });
  });

  group('autoParamsForPhoto', () {
    test('null without stats', () {
      expect(autoParamsForPhoto(item(enrichment: enrichment()), null), isNull);
    });
    test('no depth needs the photo to look underwater', () {
      expect(autoParamsForPhoto(item(), warm), isNull);
      expect(autoParamsForPhoto(item(), blue), computeAutoCorrection(blue));
    });
    test('with depth uses it', () {
      expect(
        autoParamsForPhoto(item(enrichment: enrichment()), blue),
        computeAutoCorrection(blue, depthMeters: 18),
      );
    });
    test('a surface clip drawn from its poster is not warmed', () {
      // A boat video with no per-moment track: the matcher clamped it to
      // the profile's first sample (1.5 m) and recorded the offset.
      final boat = item(
        type: MediaType.video,
        enrichment: enrichment(
          depth: 1.5,
          confidence: MatchConfidence.estimated,
          offset: -310,
        ),
      );
      expect(autoParamsForPhoto(boat, blue), isNull);
    });
  });

  group('composeCorrection', () {
    final auto = computeAutoCorrection(blue, depthMeters: 18);

    test('nothing is identity', () {
      expect(
        composeCorrection(adjustment: null, auto: null).isIdentity,
        isTrue,
      );
    });
    test('auto alone is the auto matrix', () {
      expect(composeCorrection(adjustment: null, auto: auto), auto.toMatrix());
    });
    test('strength 0 removes the automatic part', () {
      expect(
        composeCorrection(
          adjustment: const ColorAdjustment(strength: 0),
          auto: auto,
        ).isIdentity,
        isTrue,
      );
    });
    test('strength 0.5 is halfway to the automatic fix', () {
      expect(
        composeCorrection(
          adjustment: const ColorAdjustment(strength: 0.5),
          auto: auto,
        ),
        ColorMatrix.lerp(ColorMatrix.identity, auto.toMatrix(), 0.5),
      );
    });
    test('a white point replaces the automatic fix', () {
      const w = WhitePoint(0.3, 0.5, 0.6);
      expect(
        composeCorrection(
          adjustment: const ColorAdjustment(whitePoint: w),
          auto: auto,
        ),
        whitePointGains(w),
      );
    });
    test('sliders apply on top in a fixed order', () {
      const a = ColorAdjustment(
        warmth: 0.4,
        tint: -0.2,
        saturation: 0.3,
        contrast: 0.1,
        brightness: -0.2,
      );
      expect(
        composeCorrection(adjustment: a, auto: null),
        ColorMatrix.identity
            .then(ColorMatrix.warmth(0.4))
            .then(ColorMatrix.tint(-0.2))
            .then(ColorMatrix.saturation(0.3))
            .then(ColorMatrix.contrast(0.1))
            .then(ColorMatrix.brightness(-0.2)),
      );
    });
  });

  group('whitePointGains', () {
    test('a neutral sample is identity', () {
      expect(
        whitePointGains(const WhitePoint(0.5, 0.5, 0.5)).isIdentity,
        isTrue,
      );
    });
    test('a blue sample is warmed and clamped', () {
      final m = whitePointGains(const WhitePoint(0.05, 0.4, 0.6));
      expect(m.values[0], 3.0); // 0.35 / 0.05 = 7, clamped
      expect(m.values[6], closeTo(0.35 / 0.4, 1e-9));
      expect(m.values[12], closeTo(0.35 / 0.6, 1e-9));
    });
    test('a black channel does not divide by zero', () {
      expect(whitePointGains(const WhitePoint(0, 0.4, 0.6)).values[0], 3.0);
    });
  });
}
