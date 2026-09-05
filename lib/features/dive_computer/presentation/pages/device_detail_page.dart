import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_computer/presentation/utils/last_download_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import 'package:submersion/features/dive_computer/domain/services/dive_computer_merge_rules.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_merge_sheet.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Page displaying details about a specific dive computer.
class DeviceDetailPage extends ConsumerWidget {
  final String computerId;

  const DeviceDetailPage({super.key, required this.computerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final computerAsync = ref.watch(diveComputerByIdProvider(computerId));
    final theme = Theme.of(context);

    return computerAsync.when(
      data: (computer) {
        if (computer == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.diveComputer_title)),
            body: Center(child: Text(context.l10n.diveComputer_error_notFound)),
          );
        }
        return _buildContent(context, ref, computer, theme);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: Text(context.l10n.diveComputer_title)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.diveComputer_title)),
        body: Center(
          child: Text(
            context.l10n.diveComputer_error_generic(error.toString()),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    DiveComputer computer,
    ThemeData theme,
  ) {
    final colorScheme = theme.colorScheme;
    final units = UnitFormatter(ref.watch(settingsProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(computer.displayName),
        actions: [
          if (!computer.isFavorite)
            IconButton(
              icon: const Icon(Icons.star_outline),
              onPressed: () => _setFavorite(ref, computer),
              tooltip: context.l10n.diveComputer_action_setFavorite,
            ),
          if (computer.isFavorite)
            IconButton(
              icon: Icon(Icons.star, color: colorScheme.primary),
              onPressed: () {},
              tooltip: context.l10n.diveComputer_status_favorite,
            ),
          PopupMenuButton<String>(
            onSelected: (action) =>
                _handleMenuAction(context, ref, action, computer),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(context.l10n.common_action_edit),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'merge',
                child: ListTile(
                  leading: const Icon(Icons.merge_type),
                  title: Text(context.l10n.diveComputer_detail_mergeMenu),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: const Icon(Icons.delete),
                  title: Text(context.l10n.common_action_delete),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDuplicateBanner(context, ref, computer),
            _buildInfoCard(context, computer, colorScheme),
            const SizedBox(height: 16),
            _buildStatsCard(context, computer, colorScheme, units),
            const SizedBox(height: 16),
            _buildActionsCard(context, ref, computer, colorScheme),
            if (computer.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildNotesCard(context, computer, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  /// Points at another saved record that reports this computer's serial
  /// number (#645). Shrinks to nothing while loading or when there is none,
  /// so the page never reserves space for a banner it may not show.
  Widget _buildDuplicateBanner(
    BuildContext context,
    WidgetRef ref,
    DiveComputer computer,
  ) {
    final duplicates =
        ref.watch(possibleDuplicateComputersProvider(computer.id)).value ??
        const <DiveComputer>[];
    if (duplicates.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    // One duplicate is named; several are counted. Joining names into the
    // singular message reads as "A, B reports the same serial number".
    final message = duplicates.length == 1
        ? context.l10n.diveComputer_detail_duplicateBanner(
            duplicates.first.displayName,
          )
        : context.l10n.diveComputer_detail_duplicateBannerMultiple(
            duplicates.length,
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        key: const ValueKey('duplicate_banner'),
        color: colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.copy_all, color: colorScheme.onTertiaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: colorScheme.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  key: const ValueKey('duplicate_banner_merge'),
                  onPressed: () =>
                      _mergeWith(context, ref, computer, duplicates),
                  icon: const Icon(Icons.merge_type),
                  label: Text(
                    context.l10n.diveComputer_detail_duplicateBannerAction,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    DiveComputer computer,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getConnectionIcon(computer.connectionType),
                    size: 32,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    computer.fullName,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              context.l10n.diveComputer_detail_labelName,
              computer.name,
            ),
            _buildInfoRow(
              context,
              context.l10n.diveComputer_detail_labelManufacturer,
              computer.manufacturer ?? context.l10n.diveComputer_detail_unknown,
            ),
            _buildInfoRow(
              context,
              context.l10n.diveComputer_detail_labelModel,
              computer.model ?? context.l10n.diveComputer_detail_unknown,
            ),
            if (computer.serialNumber != null)
              _buildInfoRow(
                context,
                context.l10n.diveLog_detail_label_serialNumber,
                computer.serialNumber!,
              ),
            _buildInfoRow(
              context,
              context.l10n.diveComputer_detail_labelConnection,
              _getConnectionName(context, computer.connectionType),
            ),
            if (computer.equipmentId != null)
              _LinkedGearRow(equipmentId: computer.equipmentId!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildStatsCard(
    BuildContext context,
    DiveComputer computer,
    ColorScheme colorScheme,
    UnitFormatter units,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveComputer_detail_statisticsTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    Icons.scuba_diving,
                    '${computer.diveCount}',
                    context.l10n.diveComputer_detail_divesImported,
                    colorScheme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    Icons.download,
                    formatLastDownload(
                      context,
                      computer.lastDownload,
                      units: units,
                    ),
                    context.l10n.diveComputer_detail_lastDownload,
                    colorScheme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCard(
    BuildContext context,
    WidgetRef ref,
    DiveComputer computer,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () =>
                  context.push('/dive-computers/${computer.id}/download'),
              icon: const Icon(Icons.download),
              label: Text(context.l10n.diveComputer_detail_downloadDivesButton),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _viewDivesFromComputer(context, ref, computer),
              icon: const Icon(Icons.list),
              label: Text(context.l10n.diveComputer_detail_viewDivesButton),
            ),
            if (computer.lastDiveFingerprint != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmReimportAll(context, computer),
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.diveComputer_detail_reimportAllButton),
              ),
            ],
            Consumer(
              builder: (context, ref, _) {
                final counts = ref.watch(rawDataCountProvider(computer.id));
                return counts.when(
                  data: (c) {
                    if (c.withRawData == 0) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _confirmReparseAll(context, ref, computer, c),
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            context.l10n.diveComputer_detail_reparseAllButton,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            c.withoutRawData > 0
                                ? context.l10n
                                      .diveComputer_detail_reparseRawDataCountWithout(
                                        c.withRawData,
                                        c.withoutRawData,
                                      )
                                : context.l10n
                                      .diveComputer_detail_reparseRawDataCount(
                                        c.withRawData,
                                      ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (err, stack) => const SizedBox.shrink(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(
    BuildContext context,
    DiveComputer computer,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveComputer_detail_notesTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(computer.notes, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  void _setFavorite(WidgetRef ref, DiveComputer computer) {
    ref.read(diveComputerNotifierProvider.notifier).setFavorite(computer.id);
  }

  /// Shows the dive list restricted to this computer.
  ///
  /// Filters on the computer id, not its serial number. Keying this on the
  /// serial used to dead-end with a "no serial number" snackbar on every
  /// computer whose firmware never reported one (issue #1064), even though the
  /// dives were downloaded and attributed correctly.
  void _viewDivesFromComputer(
    BuildContext context,
    WidgetRef ref,
    DiveComputer computer,
  ) {
    ref.read(diveFilterProvider.notifier).state = DiveFilterState(
      computerId: computer.id,
    );
    context.go('/dives');
  }

  Future<void> _confirmReimportAll(
    BuildContext context,
    DiveComputer computer,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.diveComputer_detail_reimportDialogTitle),
        content: Text(
          l10n.diveComputer_detail_reimportDialogBody(computer.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.common_action_continue),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.push('/dive-computers/${computer.id}/download?forceFull=true');
    }
  }

  Future<void> _confirmReparseAll(
    BuildContext context,
    WidgetRef ref,
    DiveComputer computer,
    ({int withRawData, int withoutRawData}) counts,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.diveComputer_detail_reparseAllTitle),
        content: Text(
          l10n.diveComputer_detail_reparseAllMessage(counts.withRawData),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.common_action_reparse),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _executeReparseAll(context, ref, computer.id);
    }
  }

  Future<void> _executeReparseAll(
    BuildContext context,
    WidgetRef ref,
    String computerId,
  ) async {
    final service = ref.read(reparseServiceProvider);
    final l10n = context.l10n;

    final counts = await service.getRawDataCounts(computerId);
    if (counts.withRawData == 0) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.diveComputer_detail_reparseAllProgress(counts.withRawData),
          ),
        ),
      );
    }

    final result = await service.reparseAllForComputer(
      computerId,
      parseFn: pigeon.DiveComputerHostApi().parseRawDiveData,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failed == 0
                ? l10n.diveComputer_detail_reparseAllSuccess(result.succeeded)
                : l10n.diveComputer_detail_reparseAllPartial(
                    result.succeeded,
                    result.succeeded + result.failed,
                    result.failed,
                  ),
          ),
        ),
      );
    }

    ref.invalidate(rawDataCountProvider(computerId));
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    DiveComputer computer,
  ) {
    switch (action) {
      case 'edit':
        _showEditDialog(context, ref, computer);
        break;
      case 'merge':
        logFailure(
          _showMergePicker(context, ref, computer),
          DeviceDetailPage,
          'open merge picker',
        );
        break;
      case 'delete':
        _showDeleteConfirmation(context, ref, computer);
        break;
    }
  }

  /// Lists the diver's other computers so one can be merged with this one.
  /// Records that share this computer's serial number are listed first.
  Future<void> _showMergePicker(
    BuildContext context,
    WidgetRef ref,
    DiveComputer computer,
  ) async {
    final all = await ref.read(allDiveComputersProvider.future);
    if (!context.mounted) return;

    final duplicates = duplicateCandidatesFor(computer, all);
    final duplicateIds = duplicates.map((d) => d.id).toSet();
    final others = [
      ...duplicates,
      for (final other in all)
        if (other.id != computer.id && !duplicateIds.contains(other.id)) other,
    ];

    final chosen = await showModalBottomSheet<DiveComputer>(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  sheetContext.l10n.diveComputer_detail_mergePickerTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (others.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Text(
                    sheetContext.l10n.diveComputer_detail_mergePickerEmpty,
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final other in others)
                        ListTile(
                          key: ValueKey('merge_pick_${other.id}'),
                          leading: const Icon(Icons.watch),
                          title: Text(other.displayName),
                          subtitle: Text(
                            duplicateIds.contains(other.id)
                                ? sheetContext
                                      .l10n
                                      .diveComputer_detail_mergePickerSameSerial
                                : other.fullName,
                          ),
                          trailing: duplicateIds.contains(other.id)
                              ? Icon(
                                  Icons.copy_all,
                                  color: theme.colorScheme.tertiary,
                                )
                              : null,
                          onTap: () => Navigator.of(sheetContext).pop(other),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
    if (chosen == null || !context.mounted) return;
    await _mergeWith(context, ref, computer, [chosen]);
  }

  /// Opens the merge sheet for this computer and [others]. When another
  /// record survives, the page moves to it: this one no longer exists.
  Future<void> _mergeWith(
    BuildContext context,
    WidgetRef ref,
    DiveComputer computer,
    List<DiveComputer> others,
  ) async {
    final computers = [computer, ...others];
    final messenger = ScaffoldMessenger.of(context);
    final result = await DiveComputerMergeSheet.show(context, computers);
    if (result == null || !context.mounted) return;

    final survivor = computers.firstWhere((c) => c.id == result.survivorId);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.diveComputer_merge_snackbar(
            result.mergedComputerIds.length,
            survivor.displayName,
          ),
        ),
      ),
    );
    if (survivor.id != computer.id) {
      context.pushReplacement('/dive-computers/${survivor.id}');
    }
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    DiveComputer computer,
  ) {
    final nameController = TextEditingController(text: computer.name);
    final notesController = TextEditingController(text: computer.notes);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.diveComputer_detail_editDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: context.l10n.diveComputer_detail_labelName,
                hintText: context.l10n.diveComputer_detail_editNameHint,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: context.l10n.diveComputer_detail_notesTitle,
                hintText: context.l10n.diveComputer_detail_editNotesHint,
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () {
              final updated = computer.copyWith(
                name: nameController.text.trim(),
                notes: notesController.text.trim(),
              );
              ref.read(diveComputerNotifierProvider.notifier).update(updated);
              Navigator.of(context).pop();
            },
            child: Text(context.l10n.common_action_save),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    DiveComputer computer,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.diveComputer_detail_deleteDialogTitle),
        content: Text(
          dialogContext.l10n.diveComputer_detail_deleteDialogContent(
            computer.displayName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.common_action_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () {
              ref
                  .read(diveComputerNotifierProvider.notifier)
                  .delete(computer.id);
              Navigator.of(dialogContext).pop();
              context.pop(); // Go back to list
            },
            child: Text(dialogContext.l10n.common_action_delete),
          ),
        ],
      ),
    );
  }

  IconData _getConnectionIcon(String? connectionType) {
    switch (connectionType?.toLowerCase()) {
      case 'ble':
      case 'bluetooth':
      case 'bluetoothclassic':
        return Icons.bluetooth;
      case 'usb':
        return Icons.usb;
      case 'wifi':
        return Icons.wifi;
      case 'infrared':
        return Icons.sensors;
      default:
        return Icons.watch;
    }
  }

  String _getConnectionName(BuildContext context, String? connectionType) {
    final l10n = context.l10n;
    switch (connectionType?.toLowerCase()) {
      case 'ble':
        return l10n.diveComputer_connectionType_ble;
      case 'bluetooth':
      case 'bluetoothclassic':
        return l10n.diveComputer_connectionType_bluetooth;
      case 'usb':
        return l10n.diveComputer_connectionType_usb;
      case 'wifi':
        return l10n.diveComputer_connectionType_wifi;
      case 'infrared':
        return l10n.diveComputer_connectionType_infrared;
      default:
        return l10n.diveComputer_connectionType_unknown;
    }
  }
}

/// The equipment row representing this device as gear, its gear twin (v175).
///
/// Absent when the computer has no `equipmentId`, which is what deleting the
/// gear item leaves behind and is permanent by design: only a genuine
/// registration mints a twin.
class _LinkedGearRow extends ConsumerWidget {
  const _LinkedGearRow({required this.equipmentId});

  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final item = ref.watch(equipmentItemProvider(equipmentId)).valueOrNull;
    if (item == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () => context.push('/equipment/$equipmentId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.diveComputer_detail_linkedGear,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.name, style: theme.textTheme.bodyMedium),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
