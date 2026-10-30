import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/storage/gc/storage_gc_coordinator.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_gc_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The "In the Cloud" group of the Storage usage page (issue #3396): what
/// Submersion's own files take up in the media store, the database sync
/// folder and the shared site libraries, as of the last scan.
///
/// Listing a whole store is slow and, on a metered connection, costs data,
/// so the figures come from the cleanup's last scan rather than from opening
/// the page; Rescan measures again on request. A row appears only for an
/// area this device has set up. The group itself always shows, with its
/// Rescan, so an area connected since the last scan can be measured at once
/// instead of waiting for the weekly measurement.
class CloudStorageGroup extends ConsumerWidget {
  const CloudStorageGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final view = ref.watch(storageGcStateProvider).value;
    final usage = view?.cloudUsage;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final running = view?.running ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            l10n.settings_storageUsage_group_cloud,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (usage?.mediaBytes case final bytes?)
          _CloudRow(
            label: l10n.settings_storageUsage_cloud_media,
            bytes: bytes,
            detail: (usage?.mediaReclaimableBytes ?? 0) > 0
                ? l10n.settings_storageUsage_reclaimable(
                    formatBytes(usage!.mediaReclaimableBytes!),
                  )
                : null,
          ),
        if (usage?.syncBytes case final bytes?)
          _CloudRow(label: l10n.settings_storageUsage_cloud_sync, bytes: bytes),
        if (usage?.librariesBytes case final bytes?)
          _CloudRow(
            label: l10n.settings_storageUsage_cloud_libraries,
            bytes: bytes,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                usage == null
                    ? l10n.settings_storageUsage_cloud_notScanned
                    : l10n.settings_storageUsage_cloud_scanned(
                        UnitFormatter(
                          ref.watch(settingsProvider),
                        ).formatDateTime(usage.scannedAt, l10n: l10n),
                      ),
                style: muted,
              ),
              TextButton(
                onPressed: running
                    ? null
                    : () => unawaited(
                        ref
                            .read(storageGcCoordinatorProvider)
                            .run(StorageGcTrigger.rescan),
                      ),
                child: Text(l10n.settings_storageUsage_cloud_rescan),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One cloud area: label, bytes used, and an optional second line.
///
/// The label is Flexible for the same reason as the device rows: a fixed
/// label beside a size overflows a narrow surface in the test font.
class _CloudRow extends StatelessWidget {
  const _CloudRow({required this.label, required this.bytes, this.detail});

  final String label;
  final int bytes;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Text(label, style: theme.textTheme.bodyMedium)),
              const SizedBox(width: 12),
              Text(formatBytes(bytes), style: theme.textTheme.bodyMedium),
            ],
          ),
          if (detail case final text?)
            Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
