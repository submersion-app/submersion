import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_computer/presentation/utils/last_download_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';

/// Page displaying a list of saved dive computers.
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
    final computersAsync = ref.watch(allDiveComputersProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final visibleIds =
        computersAsync.value?.map((c) => c.id).toList() ?? const <String>[];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(visibleIds);
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
                  // Delete only: favourite reads as singular, and a multi-device
                  // download would be a new flow rather than a lifted action.
                  actions: const [],
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
          body: computersAsync.when(
            data: (computers) {
              if (computers.isEmpty) {
                return _buildEmptyState(context, colorScheme);
              }
              return _buildComputerList(context, ref, computers);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: colorScheme.error),
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
                    onPressed: () => ref.invalidate(allDiveComputersProvider),
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.diveComputer_list_retry),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: selection.isActive
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => context.push('/dive-computers/discover'),
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.diveComputer_list_addComputer),
                ),
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.common_bulkDelete_title(ids.length)),
        content: Text(ctx.l10n.common_bulkDelete_body),
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
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(diveComputerNotifierProvider.notifier);
    _selection.exit();
    for (final id in ids) {
      await notifier.delete(id);
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.common_bulkDelete_snackbar(ids.length)),
      ),
    );
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
    List<DiveComputer> computers,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88), // FAB clearance
      itemCount: computers.length,
      itemBuilder: (context, index) {
        final computer = computers[index];
        return _ComputerCard(
          computer: computer,
          onTap: () {
            if (SelectableListScope.isModifierPressed()) {
              _selection.enterImplicit(computer.id);
              return;
            }
            if (_isSelectionMode) {
              _selection.toggle(computer.id);
              return;
            }
            context.push('/dive-computers/${computer.id}');
          },
          onDownload: () => _startQuickDownload(context, ref, computer),
          isSelectionMode: _isSelectionMode,
          isChecked: _selectedIds.contains(computer.id),
          onCheckChanged: (_) => _selection.toggle(computer.id),
        );
      },
    );
  }

  void _startQuickDownload(
    BuildContext context,
    WidgetRef ref,
    DiveComputer computer,
  ) {
    // Navigate to download page for this computer
    context.push('/dive-computers/${computer.id}/download');
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

/// Card widget displaying a single dive computer.
class _ComputerCard extends StatelessWidget {
  final DiveComputer computer;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final bool isSelectionMode;
  final bool isChecked;
  final ValueChanged<bool>? onCheckChanged;

  const _ComputerCard({
    required this.computer,
    required this.onTap,
    required this.onDownload,
    this.isSelectionMode = false,
    this.isChecked = false,
    this.onCheckChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Semantics(
        button: true,
        label: context.l10n.diveComputer_list_cardSemanticLabel(
          computer.displayName,
        ),
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
                      color: computer.isFavorite
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getConnectionIcon(computer.connectionType),
                      color: computer.isFavorite
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
                              computer.displayName,
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (computer.isFavorite)
                            ExcludeSemantics(
                              child: Icon(
                                Icons.star,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        computer.fullName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.scuba_diving,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.diveComputer_list_diveCount(
                              computer.diveCount,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatLastDownload(context, computer.lastDownload),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Download button
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

  IconData _getConnectionIcon(String? connectionType) {
    switch (connectionType?.toLowerCase()) {
      case 'bluetooth':
        return Icons.bluetooth;
      case 'usb':
        return Icons.usb;
      case 'wifi':
        return Icons.wifi;
      default:
        return Icons.watch;
    }
  }
}
