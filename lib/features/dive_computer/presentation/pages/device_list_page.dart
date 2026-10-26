import 'package:flutter/material.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_computer/presentation/providers/dive_computer_connection_providers.dart';
import 'package:submersion/features/dive_computer/presentation/utils/connection_presentation.dart';
import 'package:submersion/features/dive_computer/presentation/utils/last_download_formatter.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/clock_sync_global_switch.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/raw_dive_data_discard.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_merge_sheet.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_delete_dialog.dart';
import 'package:submersion/features/equipment/presentation/providers/device_item_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';
import 'package:submersion/shared/widgets/card_icon_label.dart';

/// The Dive Computers list (issue #3676): every Dive Computer Equipment
/// item, discovered or added by hand. Each row opens the item's Equipment
/// page, which carries every control for the device.
class DeviceListPage extends ConsumerStatefulWidget {
  const DeviceListPage({super.key});

  @override
  ConsumerState<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends ConsumerState<DeviceListPage> {
  /// Owns the bulk-selection state machine for this page.
  final SelectionController _selection = SelectionController();

  /// Convenience mirrors of the controller, so the widget tree reads clearly.
  bool get _isSelectionMode => _selection.value.isActive;
  Set<String> get _selectedIds => _selection.value.checkedIds;

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final computersAsync = ref.watch(computerItemsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final visibleIds =
        computersAsync.value?.map((r) => r.item.id).toList() ??
        const <String>[];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _selection.pruneToSettled(
          computersAsync,
          (rows) => rows.map((r) => r.item.id),
        );
      }
    });

    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) => Scaffold(
          appBar: selection.isActive
              ? SelectionAppBar(
                  controller: _selection,
                  selectableIds: visibleIds,
                  // Merge and delete: favourite reads as singular, and a
                  // multi-device download would be a new flow rather than a
                  // lifted action.
                  actions: [
                    BulkAction(
                      id: 'merge',
                      icon: Icons.merge_type,
                      label:
                          context.l10n.diveComputer_list_selection_mergeTooltip,
                      minCount: 2,
                      onInvoke: _startMerge,
                    ),
                  ],
                  shell: SelectionBarShell.appBar,
                  onDelete: _confirmAndDelete,
                )
              : AppBar(
                  title: Text(context.l10n.diveComputer_list_title),
                  actions: [
                    IconButton(
                      key: const ValueKey('enter_selection'),
                      icon: const Icon(Icons.checklist),
                      tooltip: context.l10n.common_selection_enterTooltip,
                      onPressed: _selection.enterExplicit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline),
                      onPressed: () => _showHelpDialog(context),
                      tooltip: context.l10n.diveComputer_list_helpTooltip,
                    ),
                  ],
                ),
          body: Column(
            children: [
              const ClockSyncGlobalSwitch(),
              const Divider(height: 1),
              const RawDiveDataTile(),
              Expanded(
                child: computersAsync.when(
                  data: (computers) {
                    if (computers.isEmpty) {
                      return _buildEmptyState(context, colorScheme);
                    }
                    return _buildComputerList(context, ref, computers);
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.diveComputer_list_loadFailed,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () =>
                              ref.invalidate(computerItemsProvider),
                          icon: const Icon(Icons.refresh),
                          label: Text(context.l10n.diveComputer_list_retry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: selection.isActive
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _showAddChoices(context),
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.diveComputer_list_addComputer),
                ),
        ),
      ),
    );
  }

  /// Find a computer over Bluetooth or USB, or add one by hand as an
  /// Equipment item to connect later (issue #3676).
  Future<void> _showAddChoices(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bluetooth_searching),
              title: Text(sheetContext.l10n.diveComputer_list_findComputers),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/dive-computers/discover');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: Text(sheetContext.l10n.diveComputer_list_addByHand),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(
                  '/equipment/new?type=${EquipmentType.computer.name}',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Folds the registrations behind the checked items into one (#645). The
  /// sheet owns the confirmation; this only reports the outcome and leaves
  /// selection mode.
  Future<BulkActionOutcome> _startMerge() async {
    final ids = _selectedIds;
    final computers = [
      for (final row
          in ref.read(computerItemsProvider).value ?? const <ComputerItem>[])
        // Every registration behind a checked item: one left out would keep
        // its item linked, and the item would not be folded in.
        if (ids.contains(row.item.id)) ...row.computers,
    ];
    if (computers.length < 2) return BulkActionOutcome.cancelled;

    final messenger = ScaffoldMessenger.of(context);
    final result = await DiveComputerMergeSheet.show(context, computers);
    if (result == null) return BulkActionOutcome.cancelled;
    if (!mounted) return BulkActionOutcome.completed;

    _selection.exit();
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
    return BulkActionOutcome.completed;
  }

  Future<BulkActionOutcome> _confirmAndDelete() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return BulkActionOutcome.cancelled;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.common_bulkDelete_title(ids.length)),
        // Every row is a computer's item, which takes the computer with it.
        content: Text(bulkDeleteBody(ctx.l10n, [EquipmentType.computer])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(ctx.l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return BulkActionOutcome.cancelled;

    final messenger = ScaffoldMessenger.of(context);
    // Deleting the item deletes the computer behind it (issue #3676).
    final deleteItem = ref.read(deviceItemDeleterProvider);
    _selection.exit();
    // Delete is owner-only (issue #2046): a shared item is kept, and the
    // snackbar says how many.
    var deleted = 0;
    for (final id in ids) {
      if (await deleteItem(id)) deleted++;
    }
    final skipped = ids.length - deleted;
    if (!mounted) return BulkActionOutcome.completed;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          skipped == 0
              ? context.l10n.common_bulkDelete_snackbar(deleted)
              : context.l10n.equipment_bulkDelete_partial(deleted, skipped),
        ),
      ),
    );
    return BulkActionOutcome.completed;
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.watch_outlined,
                size: 80,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.diveComputer_list_emptyTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.diveComputer_list_emptyMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/dive-computers/discover'),
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(context.l10n.diveComputer_list_findComputers),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComputerList(
    BuildContext context,
    WidgetRef ref,
    List<ComputerItem> rows,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88), // FAB clearance
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final id = row.item.id;
        final computer = row.computers.firstOrNull;
        return _ComputerCard(
          row: row,
          onTap: () {
            if (SelectableListScope.isModifierPressed()) {
              _selection.enterImplicit(id);
              return;
            }
            if (_isSelectionMode) {
              _selection.toggle(id);
              return;
            }
            context.push('/equipment/$id');
          },
          onDownload: computer == null
              ? null
              : () => context.push('/dive-computers/${computer.id}/download'),
          isSelectionMode: _isSelectionMode,
          isChecked: _selectedIds.contains(id),
          onCheckChanged: (_) => _selection.toggle(id),
        );
      },
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.diveComputer_list_helpDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.diveComputer_list_helpConnectionsTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(context.l10n.diveComputer_list_helpBluetooth),
              Text(context.l10n.diveComputer_list_helpBluetoothClassic),
              Text(context.l10n.diveComputer_list_helpUsb),
              const SizedBox(height: 16),
              Text(
                context.l10n.diveComputer_list_helpTipsTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(context.l10n.diveComputer_list_helpTip1),
              Text(context.l10n.diveComputer_list_helpTip2),
              Text(context.l10n.diveComputer_list_helpTip3),
              const SizedBox(height: 16),
              Text(
                context.l10n.diveComputer_list_helpBrandsTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(context.l10n.diveComputer_list_helpBrandsList),
              const SizedBox(height: 8),
              // Garmin has no libdivecomputer backend: its dives arrive as
              // FIT files or from Garmin Connect, so point there by the same
              // labels the Transfer screen shows.
              Text(
                context.l10n.diveComputer_list_helpGarminNote(
                  '${context.l10n.nav_transfer} > '
                      '${context.l10n.transfer_section_importTitle}',
                  '${context.l10n.nav_transfer} > '
                      '${context.l10n.transfer_section_cloudTitle}',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.diveComputer_list_helpDismiss),
          ),
        ],
      ),
    );
  }
}

/// One Dive Computer item: its name, and for a connected one the device's
/// model, dive count, last download and a download shortcut.
class _ComputerCard extends ConsumerWidget {
  final ComputerItem row;
  final VoidCallback onTap;
  final VoidCallback? onDownload;
  final bool isSelectionMode;
  final bool isChecked;
  final ValueChanged<bool>? onCheckChanged;

  const _ComputerCard({
    required this.row,
    required this.onTap,
    required this.onDownload,
    this.isSelectionMode = false,
    this.isChecked = false,
    this.onCheckChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final computer = row.computers.firstOrNull;
    final isFavorite = computer?.isFavorite ?? false;
    // The newest connection's icon (issue #3106); the legacy type while the
    // connections load or for a computer with none yet.
    final connections =
        ref
            .watch(allDiveComputerConnectionsProvider)
            .valueOrNull?[computer?.id] ??
        const <DiveComputerConnection>[];
    final subtitle =
        computer?.fullName ??
        [?row.item.brand, ?row.item.model].join(' ').trim();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Semantics(
        button: true,
        label: context.l10n.diveComputer_list_cardSemanticLabel(row.item.name),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon, which becomes the checkbox in selection mode.
                SelectionLeading(
                  isSelectionMode: isSelectionMode,
                  isChecked: isChecked,
                  onChanged: onCheckChanged,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isFavorite
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      computer == null
                          ? Icons.watch_outlined
                          : computerConnectionIcon(computer, connections),
                      color: isFavorite
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.item.name,
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isFavorite)
                            ExcludeSemantics(
                              child: Icon(
                                Icons.star,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                      // Retired, loaned or spare reads differently from the
                      // computer in use.
                      if (row.item.status != EquipmentStatus.active)
                        Text(
                          row.item.status.localizedName(context.l10n),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.tertiary,
                          ),
                        ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // A Wrap, not a Row: the two stats drop onto their own
                      // lines when a narrow card, or the checkbox column in
                      // selection mode, leaves too little width for both.
                      if (computer == null)
                        CardIconLabel(
                          icon: Icons.link_off,
                          text: context.l10n.diveComputer_list_notConnected,
                        )
                      else
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            CardIconLabel(
                              icon: Icons.scuba_diving,
                              text: context.l10n.diveComputer_list_diveCount(
                                computer.diveCount,
                              ),
                            ),
                            CardIconLabel(
                              icon: Icons.access_time,
                              text: formatLastDownload(
                                context,
                                computer.lastDownload,
                                units: units,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (onDownload != null)
                  IconButton(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download),
                    tooltip: context.l10n.diveComputer_list_downloadTooltip,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
