import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/storage/storage_category.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/features/settings/presentation/providers/storage_usage_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Reports how many bytes the app holds on this device, by category.
///
/// Read-only by design. Nothing on this page deletes anything: the categories
/// that can be reclaimed today are reclaimed from the pages that already own
/// that action, and the ones that cannot be reclaimed safely at all (exports
/// live beside the database and are user-visible in the Files app; every backup
/// is a full copy of the database) are shown here precisely so the user can
/// decide for themselves.
class StorageUsagePage extends ConsumerWidget {
  const StorageUsagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(storageCategoriesProvider);
    final grouped = <StorageGroup, List<StorageCategory>>{};
    for (final category in categories) {
      grouped.putIfAbsent(category.group, () => []).add(category);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_storageUsage_appBar_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.settings_storageUsage_refresh_tooltip,
            onPressed: () {
              for (final category in categories) {
                ref.invalidate(storageCategorySizeProvider(category.id));
              }
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          _TotalHeader(categories: categories),
          for (final group in StorageGroup.values)
            if (grouped[group] != null) ...[
              _GroupHeader(group: group),
              for (final category in grouped[group]!)
                StorageUsageRow(category: category),
            ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// The running total across every category that contributed a number.
///
/// Labelled as partial whenever any category did not contribute, which covers
/// three different reasons and deliberately does not distinguish them here: a
/// category still measuring, one that failed, and one that is structurally
/// unmeasurable all leave the sum short of the truth. The row itself says
/// which, so the header only has to avoid claiming a short sum is the total.
/// Presenting an incomplete figure as final is the failure mode that matters,
/// because a user acts on the number.
class _TotalHeader extends ConsumerWidget {
  const _TotalHeader({required this.categories});

  final List<StorageCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    var total = 0;
    var incomplete = false;
    for (final category in categories) {
      final size = ref.watch(storageCategorySizeProvider(category.id));
      switch (size) {
        case AsyncData(:final value?):
          total += value;
        case AsyncData():
          // Structurally unmeasurable, so the sum is short by an unknown amount.
          incomplete = true;
        case AsyncError():
          incomplete = true;
        default:
          incomplete = true;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            incomplete
                ? context.l10n.settings_storageUsage_totalPartial
                : context.l10n.settings_storageUsage_total,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(formatBytes(total), style: theme.textTheme.headlineMedium),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final StorageGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        _labelFor(context, group),
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static String _labelFor(BuildContext context, StorageGroup group) {
    final l10n = context.l10n;
    return switch (group) {
      StorageGroup.appData => l10n.settings_storageUsage_group_appData,
      StorageGroup.mediaCache => l10n.settings_storageUsage_group_mediaCache,
      StorageGroup.caches => l10n.settings_storageUsage_group_caches,
      StorageGroup.backups => l10n.settings_storageUsage_group_backups,
      StorageGroup.temporary => l10n.settings_storageUsage_group_temporary,
      StorageGroup.exports => l10n.settings_storageUsage_group_exports,
    };
  }
}

/// One category's row.
///
/// The label is Flexible on purpose: the test font renders one em per glyph, so
/// a fixed label beside a size overflows a 360px surface.
class StorageUsageRow extends ConsumerWidget {
  const StorageUsageRow({required this.category, super.key});

  final StorageCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final size = ref.watch(storageCategorySizeProvider(category.id));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Flexible(
            child: Text(
              _labelFor(context, category.id),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          _SizeLabel(size: size),
        ],
      ),
    );
  }

  static String _labelFor(BuildContext context, String id) {
    final l10n = context.l10n;
    return switch (id) {
      StorageCategoryId.database =>
        l10n.settings_storageUsage_category_database,
      StorageCategoryId.localCache =>
        l10n.settings_storageUsage_category_localCache,
      StorageCategoryId.mediaCacheOriginals =>
        l10n.settings_storageUsage_category_mediaCacheOriginals,
      StorageCategoryId.mediaCacheThumbs =>
        l10n.settings_storageUsage_category_mediaCacheThumbs,
      StorageCategoryId.mediaCacheRenditions =>
        l10n.settings_storageUsage_category_mediaCacheRenditions,
      StorageCategoryId.mediaCacheStaging =>
        l10n.settings_storageUsage_category_mediaCacheStaging,
      StorageCategoryId.mediaCacheTranscode =>
        l10n.settings_storageUsage_category_mediaCacheTranscode,
      StorageCategoryId.mapTiles =>
        l10n.settings_storageUsage_category_mapTiles,
      StorageCategoryId.networkImages =>
        l10n.settings_storageUsage_category_networkImages,
      StorageCategoryId.videoThumbnails =>
        l10n.settings_storageUsage_category_videoThumbnails,
      StorageCategoryId.pdfThumbnails =>
        l10n.settings_storageUsage_category_pdfThumbnails,
      StorageCategoryId.backups => l10n.settings_storageUsage_category_backups,
      StorageCategoryId.temporary =>
        l10n.settings_storageUsage_category_temporary,
      StorageCategoryId.exports => l10n.settings_storageUsage_category_exports,
      _ => id,
    };
  }
}

class _SizeLabel extends StatelessWidget {
  const _SizeLabel({required this.size});

  final AsyncValue<int?> size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return switch (size) {
      AsyncData(:final value?) => Text(
        formatBytes(value),
        style: theme.textTheme.bodyMedium,
      ),
      AsyncData() => Text(
        context.l10n.settings_storageUsage_unavailable,
        style: muted,
      ),
      AsyncError() => Text(
        context.l10n.settings_storageUsage_measureFailed,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
      _ => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    };
  }
}
