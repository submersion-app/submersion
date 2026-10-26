import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/storage/gc/cloud_usage_measure.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/features/media/presentation/providers/media_health_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_sweep_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/media_store/presentation/widgets/photos_quality_settings.dart';
import 'package:submersion/features/settings/presentation/providers/media_badge_settings_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/media_cache_settings_card.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Photos & videos' Advanced section (spec section 8.3): upload quality,
/// upload everything already attached, verify the copies, network
/// sources, the two display preferences, the cache, the media report and
/// Stop keeping copies on this device. The copy-keeping controls show only
/// on a device that keeps copies; the report always shows, since a device
/// with no copies is the one most likely to be asking why.
class PhotosAdvancedSection extends ConsumerStatefulWidget {
  const PhotosAdvancedSection({super.key, required this.attached});

  final bool attached;

  @override
  ConsumerState<PhotosAdvancedSection> createState() =>
      _PhotosAdvancedSectionState();
}

class _PhotosAdvancedSectionState extends ConsumerState<PhotosAdvancedSection> {
  bool _busy = false;
  bool _verifying = false;
  bool _exporting = false;

  /// A sweep holds store and database state a concurrent detach or
  /// backfill would race with; every copy action gates on all three.
  bool get _actionInFlight => _busy || _verifying || _exporting;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final attached = widget.attached;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: buildSettingsSectionHeader(
            context,
            l10n.settings_data_header_advanced,
          ),
        ),
        if (attached) ...[
          const PhotosQualitySettings(),
          ListTile(
            key: const Key('media-s3-backfill'),
            leading: const Icon(Icons.upload_outlined),
            title: Text(l10n.settings_photos_uploadAll),
            enabled: !_actionInFlight,
            onTap: _backfill,
          ),
          ListTile(
            key: const Key('media-verify-library'),
            leading: const Icon(Icons.fact_check_outlined),
            title: Text(
              _verifying
                  ? l10n.settings_mediaStorage_verify_running
                  : l10n.settings_photos_verify,
            ),
            subtitle: _verifying ? const LinearProgressIndicator() : null,
            enabled: !_actionInFlight,
            onTap: _verify,
          ),
        ],
        ListTile(
          leading: const Icon(Icons.lan_outlined),
          title: Text(l10n.settings_photosMedia_networkSources_title),
          subtitle: Text(l10n.settings_photosMedia_networkSources_subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushSettingsPage(
            '/settings/media-sources/network-sources',
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.sell_outlined),
          title: Text(l10n.settings_media_provenanceBadges),
          subtitle: Text(l10n.settings_media_provenanceBadgesSubtitle),
          value: ref.watch(mediaProvenanceBadgesProvider),
          onChanged: (value) => ref
              .read(mediaProvenanceBadgesProvider.notifier)
              .setEnabled(value),
        ),
        // Display-only, per diver and synced (issue #3520).
        SwitchListTile(
          secondary: const Icon(Icons.palette_outlined),
          title: Text(l10n.settings_media_autoColorCorrection),
          subtitle: Text(l10n.settings_media_autoColorCorrectionSubtitle),
          value: ref.watch(
            settingsProvider.select((s) => s.autoColorCorrection),
          ),
          onChanged: (value) =>
              ref.read(settingsProvider.notifier).setAutoColorCorrection(value),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            l10n.settings_photosMedia_cacheHeader,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: MediaCacheSettingsCard(),
        ),
        Builder(
          builder: (tileContext) => ListTile(
            key: const Key('media-export-report'),
            leading: const Icon(Icons.description_outlined),
            title: Text(
              _exporting
                  ? l10n.settings_mediaStorage_report_running
                  : l10n.settings_mediaStorage_report_action,
            ),
            subtitle: Text(l10n.settings_mediaStorage_report_note),
            enabled: !_actionInFlight,
            onTap: () => _exportReport(tileContext),
          ),
        ),
        if (attached)
          ListTile(
            key: const Key('media-s3-disconnect'),
            leading: Icon(
              Icons.cloud_off_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.settings_photos_stopKeeping,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            enabled: !_actionInFlight,
            onTap: _stopKeeping,
          ),
      ],
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: isError
            ? const Duration(seconds: 10)
            : const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _backfill() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final count = await ref.read(mediaBackfillServiceProvider).enqueueAll();
      if (!mounted) return;
      _showSnack(l10n.settings_mediaStorage_backfill_enqueued(count));
      final runtime = await ref.read(mediaStoreRuntimeProvider.future);
      unawaited(runtime?.worker?.drain());
    } catch (e) {
      _showSnack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Builds the whole-library health report and hands it to the exporter
  /// (share sheet, or a save dialog where sharing is unsupported). Reads
  /// the store through the side-effect-free adapter provider, so exporting
  /// never starts a drain. [tileContext] anchors the iPad share popover.
  Future<void> _exportReport(BuildContext tileContext) async {
    final l10n = context.l10n;
    final anchor = shareAnchorFrom(tileContext);
    setState(() => _exporting = true);
    try {
      final report = await ref.read(mediaHealthReporterProvider).forLibrary();
      await ref.read(textFileExporterProvider)(
        report.toText(),
        'submersion-media-report.txt',
        'text/plain',
        sharePositionOrigin: anchor,
      );
      if (mounted) _showSnack(l10n.settings_mediaStorage_report_done);
    } catch (e) {
      if (mounted) _showSnack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// The Verify sweep (orphan-prevention spec 6.3): reconciles the attached
  /// store against the media table and reports what changed.
  Future<void> _verify() async {
    final l10n = context.l10n;
    setState(() => _verifying = true);
    try {
      final report = await ref.read(mediaVerifyRunnerProvider)();
      if (!mounted) return;
      final summary = l10n.settings_mediaStorage_verify_summary(
        report.objectsChecked,
        report.originalsChecked,
        report.thumbsChecked,
        report.renditionsChecked,
        report.orphansRemoved,
        report.repairsQueued,
        report.sessionsAborted,
      );
      // "Removed 0" alone would read as nothing to remove; say what the
      // deferred deletes wait on.
      final held = !report.deferred
          ? null
          : switch (report.hold) {
              null || CloudDeleteHold.sync =>
                l10n.settings_mediaStorage_verify_deferred,
              CloudDeleteHold.unregistered =>
                l10n.settings_mediaStorage_verify_unregistered,
              CloudDeleteHold.uploads =>
                l10n.settings_mediaStorage_verify_uploads,
            };
      _showSnack(held == null ? summary : '$summary\n$held');
    } on MediaStoreException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } catch (e) {
      if (mounted) _showSnack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Today's Disconnect: this device only; nothing in the account goes.
  Future<void> _stopKeeping() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_photos_stopKeeping),
        content: Text(l10n.settings_photos_stopKeepingBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.common_action_cancel),
          ),
          TextButton(
            key: const Key('media-s3-disconnect-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.settings_photos_stopKeeping),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(mediaStoreServiceProvider).disconnect();
      invalidateMediaStoreAttachment(ref);
      ref.invalidate(photosCopiesProvider);
    } catch (e) {
      _showSnack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
