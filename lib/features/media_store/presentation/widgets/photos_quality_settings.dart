import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/media_store/media_upload_quality_policy.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/label_with_control.dart';

/// Upload quality for photos and videos, with the compression hints (spec
/// section 8.3, Advanced). Synced, library-wide levels.
class PhotosQualitySettings extends ConsumerWidget {
  const PhotosQualitySettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // AsyncValue.value, not .when: an in-flight refresh after a write keeps
    // the previous level on screen instead of blanking the whole section.
    final photoQuality = ref.watch(photoUploadQualityProvider).value;
    final videoQuality = ref.watch(videoUploadQualityProvider).value;
    if (photoQuality == null || videoQuality == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            l10n.settings_photos_quality,
            style: theme.textTheme.titleSmall,
          ),
        ),
        ListTile(
          title: LabelWithControl(
            label: Text(l10n.settings_mediaStorage_quality_photos),
            control: DropdownButton<MediaUploadQuality>(
              key: const Key('media-quality-photos'),
              value: photoQuality,
              underline: const SizedBox(),
              onChanged: (value) async {
                if (value == null) return;
                await _saveQuality(
                  context,
                  (policy) => policy.setPhotoUploadQuality(value),
                  photoUploadQualityProvider,
                );
              },
              items: _qualityItems(l10n),
            ),
          ),
        ),
        ListTile(
          title: LabelWithControl(
            label: Text(l10n.settings_mediaStorage_quality_video),
            control: DropdownButton<MediaUploadQuality>(
              key: const Key('media-quality-video'),
              value: videoQuality,
              underline: const SizedBox(),
              onChanged: (value) async {
                if (value == null) return;
                await _saveQuality(
                  context,
                  (policy) => policy.setVideoUploadQuality(value),
                  videoUploadQualityProvider,
                );
              },
              items: _qualityItems(l10n),
            ),
          ),
        ),
        // A library-wide level can be set from a device that cannot honour
        // it, so this note is not Linux-specific: any device without a
        // working engine uploads originals. Only the remedy differs, which
        // is why the copy branches but the condition does not. The `?? true`
        // keeps the note hidden while availability is still resolving,
        // rather than flashing a warning that then disappears.
        if (videoQuality != MediaUploadQuality.original &&
            !(ref.watch(videoTranscodeAvailableProvider).value ?? true))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              ref.watch(isLinuxPlatformProvider)
                  ? l10n.settings_mediaStorage_quality_linuxFfmpegHint
                  : l10n.settings_mediaStorage_quality_noTranscoderHint,
              key: const Key('media-quality-transcoder-hint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.settings_mediaStorage_quality_caveat,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  /// Persists a quality level, surfacing a failed write rather than letting
  /// it pass silently. The invalidate runs either way: on success it re-reads
  /// the new truth, on failure it discards the optimistic value for free.
  Future<void> _saveQuality(
    BuildContext context,
    Future<void> Function(MediaUploadQualityPolicy policy) write,
    FutureProvider<MediaUploadQuality> provider,
  ) async {
    // Captured before the first await: the app-level container outlives
    // this page, so the write and invalidate still run (and never throw) if
    // the page is popped during the async gap. Guarding the invalidate with
    // `mounted` instead would leave a stale cached level for the next visit,
    // since these providers are not autoDispose.
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await write(container.read(mediaUploadQualityPolicyProvider));
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.settings_mediaStorage_quality_saveFailed),
          ),
        );
      }
    }
    container.invalidate(provider);
  }

  List<DropdownMenuItem<MediaUploadQuality>> _qualityItems(
    AppLocalizations l10n,
  ) {
    String label(MediaUploadQuality q) => switch (q) {
      MediaUploadQuality.original =>
        l10n.settings_mediaStorage_quality_original,
      MediaUploadQuality.high => l10n.settings_mediaStorage_quality_high,
      MediaUploadQuality.balanced =>
        l10n.settings_mediaStorage_quality_balanced,
      MediaUploadQuality.small => l10n.settings_mediaStorage_quality_small,
    };
    return [
      for (final q in MediaUploadQuality.values)
        DropdownMenuItem(value: q, child: Text(label(q))),
    ];
  }
}
