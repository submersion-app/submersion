import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_downloader.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_pack_controller.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings for marine life identification (issue #4668): the optional
/// model download, whether photos are analysed as they are opened, and the
/// suggestions kept on this device.
class MarineLifeIdentificationPage extends ConsumerStatefulWidget {
  const MarineLifeIdentificationPage({super.key});

  @override
  ConsumerState<MarineLifeIdentificationPage> createState() =>
      _MarineLifeIdentificationPageState();
}

class _MarineLifeIdentificationPageState
    extends ConsumerState<MarineLifeIdentificationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(speciesPackControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(speciesPackControllerProvider);
    final controller = ref.read(speciesPackControllerProvider.notifier);
    final count = ref.watch(identificationCountProvider).value;
    final cropBytes = ref.watch(identificationCropBytesProvider).value;
    final credits = controller.credits;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_speciesId_title)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l10n.settings_speciesId_intro),
          ),
          ListTile(
            leading: const Icon(Icons.memory_outlined),
            title: Text(l10n.settings_speciesId_model),
            subtitle: Text(_status(l10n, state)),
          ),
          if (state case PackDownloading(:final received, :final total))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(
                value: total == 0 ? null : received / total,
              ),
            ),
          if (state is PackInstalling)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _actions(context, l10n, state, controller),
            ),
          ),
          const Divider(),
          SwitchListTile(
            key: const ValueKey('species_id_toggle'),
            title: Text(l10n.settings_speciesId_toggle),
            value: ref.watch(identifyFishOnOpenProvider),
            onChanged: (value) =>
                ref.read(identifyFishOnOpenProvider.notifier).setEnabled(value),
          ),
          ListTile(
            title: Text(l10n.settings_speciesId_kept),
            subtitle: Text(
              l10n.settings_speciesId_keptValue(
                count ?? 0,
                formatBytes(cropBytes ?? 0),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton(
                key: const ValueKey('species_id_clear'),
                onPressed: (count ?? 0) == 0 && (cropBytes ?? 0) == 0
                    ? null
                    : () => _confirmClear(context),
                child: Text(l10n.settings_speciesId_clear),
              ),
            ),
          ),
          if (credits.isNotEmpty) ...[
            const SizedBox(height: 8),
            ListTile(
              key: const ValueKey('species_id_credits'),
              title: Text(l10n.settings_speciesId_credits),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showCredits(context),
            ),
          ],
        ],
      ),
    );
  }

  String _status(AppLocalizations l10n, SpeciesPackState state) =>
      switch (state) {
        PackChecking() => '',
        PackUnsupported(reason: VisionAvailability.deviceNotEligible) =>
          l10n.settings_speciesId_notEligible,
        PackUnsupported() => l10n.settings_speciesId_unsupported,
        PackNotPublished() => l10n.settings_speciesId_modelNotAvailable,
        PackNotForThisDevice() => l10n.settings_speciesId_modelNotForDevice,
        PackNeedsAppUpdate() => l10n.settings_speciesId_needsAppUpdate,
        PackNotInstalled() => l10n.settings_speciesId_modelNotDownloaded,
        PackDownloading(:final received, :final total) =>
          l10n.settings_speciesId_downloading(
            total == 0 ? 0 : (received * 100 / total).floor(),
          ),
        PackInstalling() => l10n.settings_speciesId_installing,
        PackInstalled(:final version) => l10n.settings_speciesId_modelInstalled(
          version,
        ),
        PackFailed(reason: PackDownloadFailure.storage) =>
          l10n.settings_speciesId_downloadNoSpace,
        PackFailed(reason: PackDownloadFailure.unsupportedFormat) =>
          l10n.settings_speciesId_needsAppUpdate,
        PackFailed() => l10n.settings_speciesId_downloadFailed,
      };

  List<Widget> _actions(
    BuildContext context,
    AppLocalizations l10n,
    SpeciesPackState state,
    SpeciesPackController controller,
  ) => switch (state) {
    PackNotInstalled(:final bytes, :final resumable) => [
      FilledButton(
        key: const ValueKey('species_id_download'),
        onPressed: () => _confirmDownload(context, bytes),
        child: Text(
          resumable
              ? l10n.settings_speciesId_resume(formatBytes(bytes))
              : l10n.settings_speciesId_download(formatBytes(bytes)),
        ),
      ),
    ],
    // The check itself failed: nothing is known to download yet.
    PackFailed(bytes: 0, :final reason)
        when reason != PackDownloadFailure.unsupportedFormat =>
      [
        FilledButton(
          key: const ValueKey('species_id_retry'),
          onPressed: controller.refresh,
          child: Text(l10n.common_action_tryAgain),
        ),
      ],
    PackFailed(:final bytes, :final reason)
        when reason != PackDownloadFailure.unsupportedFormat =>
      [
        FilledButton(
          key: const ValueKey('species_id_download'),
          onPressed: () => controller.download(),
          child: Text(l10n.settings_speciesId_resume(formatBytes(bytes))),
        ),
      ],
    PackDownloading() => [
      OutlinedButton(
        key: const ValueKey('species_id_cancel'),
        onPressed: controller.cancel,
        child: Text(l10n.common_action_cancel),
      ),
    ],
    PackInstalled(:final updateBytes, :final bytes) => [
      if (updateBytes != null)
        FilledButton(
          key: const ValueKey('species_id_update'),
          onPressed: () => _confirmDownload(context, updateBytes),
          child: Text(l10n.settings_speciesId_update(formatBytes(updateBytes))),
        ),
      OutlinedButton(
        key: const ValueKey('species_id_remove'),
        onPressed: () => _confirmRemove(context, bytes),
        child: Text(l10n.settings_speciesId_remove),
      ),
    ],
    _ => const [],
  };

  Future<void> _confirmDownload(BuildContext context, int bytes) async {
    final l10n = context.l10n;
    final size = formatBytes(bytes);
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_speciesId_downloadConfirmTitle),
        content: Text(l10n.settings_speciesId_downloadConfirmBody(size)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            key: const ValueKey('species_id_download_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settings_speciesId_download(size)),
          ),
        ],
      ),
    );
    if (go ?? false) {
      await ref.read(speciesPackControllerProvider.notifier).download();
    }
  }

  Future<void> _confirmRemove(BuildContext context, int bytes) async {
    final l10n = context.l10n;
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_speciesId_removeConfirmTitle),
        content: Text(
          l10n.settings_speciesId_removeConfirmBody(formatBytes(bytes)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            key: const ValueKey('species_id_remove_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settings_speciesId_remove),
          ),
        ],
      ),
    );
    if (go ?? false) {
      await ref.read(speciesPackControllerProvider.notifier).remove();
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final l10n = context.l10n;
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_speciesId_clearConfirmTitle),
        content: Text(l10n.settings_speciesId_clearConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            key: const ValueKey('species_id_clear_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settings_speciesId_clear),
          ),
        ],
      ),
    );
    if (!(go ?? false) || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = l10n.common_error_tryAgain;
    final cleanup = ref.read(identificationCleanupProvider);
    final service = ref.read(mediaIdentificationServiceProvider);
    try {
      // A scan still running would write back what is cleared.
      await service.settleAll();
      await cleanup.clearAll();
    } catch (_) {
      messenger?.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  Future<void> _showCredits(BuildContext context) {
    final l10n = context.l10n;
    final credits = ref.read(speciesPackControllerProvider.notifier).credits;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_speciesId_credits),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final credit in credits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildSettingsSectionHeader(context, credit.name),
                      if (credit.licence.isNotEmpty) Text(credit.licence),
                      if (credit.text.isNotEmpty) Text(credit.text),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.common_action_close),
          ),
        ],
      ),
    );
  }
}
