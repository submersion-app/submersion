import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/media_store/media_upload_quality_policy.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

import '../../../support/fake_app_settings_repository.dart';

void main() {
  late FakeAppSettingsRepository settings;
  late MediaUploadQualityPolicy policy;

  setUp(() {
    settings = FakeAppSettingsRepository();
    policy = MediaUploadQualityPolicy(settings: settings);
  });

  test('defaults to original for both media types', () async {
    expect(await policy.photoUploadQuality(), MediaUploadQuality.original);
    expect(await policy.videoUploadQuality(), MediaUploadQuality.original);
    expect(
      await policy.qualityFor(MediaType.photo),
      MediaUploadQuality.original,
    );
    expect(
      await policy.qualityFor(MediaType.video),
      MediaUploadQuality.original,
    );
  });

  test('round-trips every photo level', () async {
    for (final level in MediaUploadQuality.values) {
      await policy.setPhotoUploadQuality(level);
      expect(await policy.photoUploadQuality(), level);
      expect(await policy.qualityFor(MediaType.photo), level);
    }
  });

  test('round-trips every video level', () async {
    for (final level in MediaUploadQuality.values) {
      await policy.setVideoUploadQuality(level);
      expect(await policy.videoUploadQuality(), level);
      expect(await policy.qualityFor(MediaType.video), level);
    }
  });

  test('video level is independent of photo level', () async {
    await policy.setPhotoUploadQuality(MediaUploadQuality.high);
    await policy.setVideoUploadQuality(MediaUploadQuality.small);
    expect(await policy.qualityFor(MediaType.photo), MediaUploadQuality.high);
    expect(await policy.qualityFor(MediaType.video), MediaUploadQuality.small);
  });

  test('writes land under the documented synced keys', () async {
    await policy.setPhotoUploadQuality(MediaUploadQuality.balanced);
    await policy.setVideoUploadQuality(MediaUploadQuality.small);
    expect(
      settings.values[MediaUploadQualityPolicy.photoQualityKey],
      'balanced',
    );
    expect(settings.values[MediaUploadQualityPolicy.videoQualityKey], 'small');
  });

  test('an unknown stored value falls back to original', () async {
    settings.values[MediaUploadQualityPolicy.photoQualityKey] = 'bogus';
    expect(await policy.photoUploadQuality(), MediaUploadQuality.original);
  });

  // The pipeline reads this on a background upload path, and the database can
  // be absent mid-restore. Falling back to original fails toward full
  // fidelity: never make a degraded rendition the only copy of a photo.
  test('a throwing read falls back to original', () async {
    settings.values[MediaUploadQualityPolicy.photoQualityKey] = 'small';
    settings.throwOnRead = StateError('db gone');
    expect(await policy.photoUploadQuality(), MediaUploadQuality.original);
  });

  test('a throwing write is rethrown', () async {
    settings.throwOnWrite = StateError('disk full');
    expect(
      () => policy.setPhotoUploadQuality(MediaUploadQuality.small),
      throwsStateError,
    );
  });
}
