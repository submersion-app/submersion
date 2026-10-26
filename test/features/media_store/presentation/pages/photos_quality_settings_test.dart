import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/media_upload_quality_policy.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion/features/media_store/presentation/pages/photos_videos_page.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../support/fake_app_settings_repository.dart';

import 'photos_page_harness.dart';

void main() {
  late PhotosPageHarness h;

  setUp(() async => h = await PhotosPageHarness.create());

  testWidgets('the quality section renders the synced levels', (tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final policy = MediaUploadQualityPolicy(
      settings: FakeAppSettingsRepository(),
    );
    await policy.setPhotoUploadQuality(MediaUploadQuality.small);
    await policy.setVideoUploadQuality(MediaUploadQuality.high);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        h.app(
          statusHint: 'dive-media @ minio',
          extraOverrides: [
            mediaUploadQualityPolicyProvider.overrideWithValue(policy),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(find.byKey(const Key('media-quality-photos')), findsOneWidget);
    expect(find.byKey(const Key('media-quality-video')), findsOneWidget);

    final photo = tester.widget<DropdownButton<MediaUploadQuality>>(
      find.byKey(const Key('media-quality-photos')),
    );
    final video = tester.widget<DropdownButton<MediaUploadQuality>>(
      find.byKey(const Key('media-quality-video')),
    );
    expect(photo.value, MediaUploadQuality.small);
    expect(video.value, MediaUploadQuality.high);
  });

  testWidgets('changing the photo quality writes to the synced setting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final settings = FakeAppSettingsRepository();
    final policy = MediaUploadQualityPolicy(settings: settings);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        h.app(
          statusHint: 'dive-media @ minio',
          extraOverrides: [
            mediaUploadQualityPolicyProvider.overrideWithValue(policy),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    final dropdown = find.byKey(const Key('media-quality-photos'));
    await tester.ensureVisible(dropdown);
    await tester.runAsync(() async {
      await tester.tap(dropdown);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });
    await tester.runAsync(() async {
      await tester.tap(find.text('Small').last);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(settings.values[MediaUploadQualityPolicy.photoQualityKey], 'small');
  });

  // Popping the page mid-save must not crash: `ref` throws once the
  // ConsumerState is disposed, so _saveQuality captures the app-level
  // container before the first await. The write and the invalidate both still
  // have to land, otherwise the next visit shows a stale level.
  testWidgets('a save that outlives the page neither throws nor is lost', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final settings = FakeAppSettingsRepository();
    final policy = MediaUploadQualityPolicy(settings: settings);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        h.app(
          statusHint: 'dive-media @ minio',
          extraOverrides: [
            mediaUploadQualityPolicyProvider.overrideWithValue(policy),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    // Hold the write open so the page can be disposed while it is in flight.
    final gate = Completer<void>();
    settings.gateWrite = gate;

    final dropdown = find.byKey(const Key('media-quality-photos'));
    await tester.ensureVisible(dropdown);
    await tester.runAsync(() async {
      await tester.tap(dropdown);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });
    await tester.runAsync(() async {
      await tester.tap(find.text('Small').last);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    // Navigate away: the page is disposed while the write is still
    // awaiting the gate.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    expect(find.byType(PhotosVideosPage), findsNothing);

    await tester.runAsync(() async {
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      settings.values[MediaUploadQualityPolicy.photoQualityKey],
      'small',
      reason: 'the write must still land after the page is gone',
    );
  });

  // Writes rethrow by design so a failed save is visible; the previous
  // handlers awaited the write and swallowed the error entirely.
  testWidgets('a failed quality write surfaces a snackbar', (tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final settings = FakeAppSettingsRepository();
    final policy = MediaUploadQualityPolicy(settings: settings);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        h.app(
          statusHint: 'dive-media @ minio',
          extraOverrides: [
            mediaUploadQualityPolicyProvider.overrideWithValue(policy),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    settings.throwOnWrite = StateError('disk full');

    final dropdown = find.byKey(const Key('media-quality-photos'));
    await tester.ensureVisible(dropdown);
    await tester.runAsync(() async {
      await tester.tap(dropdown);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });
    await tester.runAsync(() async {
      await tester.tap(find.text('Small').last);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.pump();

    expect(
      find.text('Could not save the upload quality. Try again.'),
      findsOneWidget,
    );
    expect(
      settings.values[MediaUploadQualityPolicy.photoQualityKey],
      isNull,
      reason: 'the failed write must not appear to have landed',
    );
  });

  testWidgets('Linux hint shows when video level set and ffmpeg missing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final policy = MediaUploadQualityPolicy(
      settings: FakeAppSettingsRepository(),
    );
    await policy.setVideoUploadQuality(MediaUploadQuality.small);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        h.app(
          apple: false,
          statusHint: 'dive-media @ minio',
          extraOverrides: [
            mediaUploadQualityPolicyProvider.overrideWithValue(policy),
            isLinuxPlatformProvider.overrideWithValue(true),
            videoTranscodeAvailableProvider.overrideWith((ref) async => false),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump(); // policy load applies; video level becomes 'small'
      // The availability provider is only watched once _videoQuality is set
      // (the if-condition short-circuits before it), so a second cycle lets
      // that provider resolve and the hint render.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.ensureVisible(
      find.byKey(const Key('media-quality-transcoder-hint')),
    );
    expect(
      find.byKey(const Key('media-quality-transcoder-hint')),
      findsOneWidget,
    );
  });

  // The Linux gate was only correct while quality was per-device: a user could
  // then only pick a level their own machine could not honour. A library-wide
  // setting lets a Mac choose a level for a Windows box with no engine.
  testWidgets('a non-Linux device without an engine shows the generic hint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final policy = MediaUploadQualityPolicy(
      settings: FakeAppSettingsRepository(),
    );
    await policy.setVideoUploadQuality(MediaUploadQuality.small);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        h.app(
          statusHint: 'dive-media @ minio',
          extraOverrides: [
            mediaUploadQualityPolicyProvider.overrideWithValue(policy),
            isLinuxPlatformProvider.overrideWithValue(false),
            videoTranscodeAvailableProvider.overrideWith((ref) async => false),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.ensureVisible(
      find.byKey(const Key('media-quality-transcoder-hint')),
    );
    expect(
      find.byKey(const Key('media-quality-transcoder-hint')),
      findsOneWidget,
    );
    expect(
      find.text(
        'This device cannot compress video. Originals are uploaded '
        'from it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a device with a working engine shows no hint', (tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final policy = MediaUploadQualityPolicy(
      settings: FakeAppSettingsRepository(),
    );
    await policy.setVideoUploadQuality(MediaUploadQuality.small);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        h.app(
          statusHint: 'dive-media @ minio',
          extraOverrides: [
            mediaUploadQualityPolicyProvider.overrideWithValue(policy),
            isLinuxPlatformProvider.overrideWithValue(false),
            videoTranscodeAvailableProvider.overrideWith((ref) async => true),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(
      find.byKey(const Key('media-quality-transcoder-hint')),
      findsNothing,
    );
  });
}
