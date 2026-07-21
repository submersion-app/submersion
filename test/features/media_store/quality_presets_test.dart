import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media_store/data/quality_presets.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

void main() {
  test('original has no preset', () {
    expect(photoPresetFor(MediaUploadQuality.original), isNull);
    expect(videoPresetFor(MediaUploadQuality.original), isNull);
  });

  test('photo presets shrink with level', () {
    expect(photoPresetFor(MediaUploadQuality.high)!.maxDimension, 3072);
    expect(photoPresetFor(MediaUploadQuality.balanced)!.maxDimension, 2048);
    expect(photoPresetFor(MediaUploadQuality.small)!.maxDimension, 1280);
    expect(photoPresetFor(MediaUploadQuality.small)!.jpegQuality, 75);
  });

  test('video presets are bitrate-based', () {
    final high = videoPresetFor(MediaUploadQuality.high)!;
    expect(high.maxHeight, 1080);
    expect(high.videoBitrateKbps, 8000);
    expect(high.audioBitrateKbps, 128);
    expect(videoPresetFor(MediaUploadQuality.balanced)!.videoBitrateKbps, 4000);
    final small = videoPresetFor(MediaUploadQuality.small)!;
    expect(small.videoBitrateKbps, 1800);
    expect(small.audioBitrateKbps, 96);
  });

  test('ceiling: small-and-cheap source is within ceiling', () {
    final preset = videoPresetFor(MediaUploadQuality.balanced)!;
    const probe = VideoProbe(
      width: 1280,
      height: 720,
      durationMs: 10000,
      overallBitrateKbps: 3000,
    );
    expect(videoWithinCeiling(probe, preset), isTrue);
  });

  test(
    'ceiling: high-bitrate source at target resolution still compresses',
    () {
      final preset = videoPresetFor(MediaUploadQuality.balanced)!;
      const probe = VideoProbe(
        width: 1280,
        height: 720,
        durationMs: 10000,
        overallBitrateKbps: 20000,
      );
      expect(videoWithinCeiling(probe, preset), isFalse);
    },
  );

  test('ceiling: larger resolution always compresses', () {
    final preset = videoPresetFor(MediaUploadQuality.balanced)!;
    const probe = VideoProbe(
      width: 3840,
      height: 2160,
      durationMs: 10000,
      overallBitrateKbps: 3000,
    );
    expect(videoWithinCeiling(probe, preset), isFalse);
  });

  test('enum round-trips through name', () {
    expect(
      MediaUploadQuality.values.byName('balanced'),
      MediaUploadQuality.balanced,
    );
  });
}
