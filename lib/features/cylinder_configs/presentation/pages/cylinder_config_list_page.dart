import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_checkbox_slot.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';

/// Lists every configuration, grouped by owning rebreather with generic gas
/// plans last.
class CylinderConfigListPage extends ConsumerStatefulWidget {
  const CylinderConfigListPage({super.key});

  @override
  ConsumerState<CylinderConfigListPage> createState() =>
      _CylinderConfigListPageState();
}

class _CylinderConfigListPageState
    extends ConsumerState<CylinderConfigListPage> {
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
    final l10n = context.l10n;
    final configsAsync = ref.watch(cylinderConfigsProvider);
    final equipmentAsync = ref.watch(allEquipmentProvider);

    // Everything is deletable: configs are applied by copying into dive_tanks,
    // so no dive references a config id and there is no in-use predicate.
    final selectableIds =
        configsAsync.value?.map((c) => c.id).toList() ?? const <String>[];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(selectableIds);
    });

    return SelectableListScope(
      controller: _selection,
      selectableIds: selectableIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) => Scaffold(
          appBar: selection.isActive
              ? SelectionAppBar(
                  controller: _selection,
                  selectableIds: selectableIds,
                  actions: const [],
                  shell: SelectionBarShell.appBar,
                  onDelete: _confirmAndDelete,
                )
              : AppBar(
                  title: Text(l10n.cylinderConfigs_title),
                  actions: [
                    IconButton(
                      key: const ValueKey('enter_selection'),
                      icon: const Icon(Icons.checklist),
                      tooltip: l10n.common_selection_enterTooltip,
                      onPressed: _selection.enterExplicit,
                    ),
                  ],
                ),
          body: configsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('$error')),
            data: (configs) {
              if (configs.isEmpty) {
                return _EmptyState(l10n: l10n);
              }

              final unitNames = <String, String>{
                for (final item in equipmentAsync.valueOrNull ?? const [])
                  item.id: item.name,
              };

              final owned = <String, List<CylinderConfig>>{};
              final generic = <CylinderConfig>[];
              for (final config in configs) {
                final unitId = config.equipmentId;
                if (unitId == null) {
                  generic.add(config);
                } else {
                  owned.putIfAbsent(unitId, () => []).add(config);
                }
              }

              return ListView(
                children: [
                  for (final entry in owned.entries) ...[
                    _GroupHeader(
                      label:
                          unitNames[entry.key] ?? l10n.cylinderConfigs_forUnit,
                    ),
                    for (final config in entry.value) _selectable(config),
                  ],
                  if (generic.isNotEmpty) ...[
                    _GroupHeader(label: l10n.cylinderConfigs_gasPlans),
                    for (final config in generic) _selectable(config),
                  ],
                ],
              );
            },
          ),
          floatingActionButton: selection.isActive
              ? null
              : FloatingActionButton.extended(
                  onPressed: () =>
                      context.push('/equipment/cylinder-configs/new'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.cylinderConfigs_new),
                ),
        ),
      ),
    );
  }

  /// A config row that can carry a checkbox while selecting.
  Widget _selectable(CylinderConfig config) {
    return _ConfigTile(
      config: config,
      isSelectionMode: _isSelectionMode,
      isChecked: _selectedIds.contains(config.id),
      onSelectToggle: () => _selection.toggle(config.id),
      onCheckChanged: (_) => _selection.toggle(config.id),
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
    final repo = ref.read(cylinderConfigRepositoryProvider);
    _selection.exit();
    for (final id in ids) {
      await repo.deleteConfig(id);
    }
    if (!mounted) return;
    ref.invalidate(cylinderConfigsProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.common_bulkDelete_snackbar(ids.length)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.propane_tank_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.cylinderConfigs_empty,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.cylinderConfigs_emptyBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ConfigTile extends StatelessWidget {
  const _ConfigTile({
    required this.config,
    this.isSelectionMode = false,
    this.isChecked = false,
    this.onSelectToggle,
    this.onCheckChanged,
  });

  final CylinderConfig config;

  /// While selecting, a tap toggles the row rather than opening the editor.
  final bool isSelectionMode;
  final bool isChecked;
  final VoidCallback? onSelectToggle;
  final ValueChanged<bool>? onCheckChanged;

  @override
  Widget build(BuildContext context) {
    final roles = config.items.map((i) => i.tankRole.displayName).join(', ');
    return ListTile(
      // ListTile reserves leading width for any non-null child, however wide
      // that child actually draws, so a zero-width slot would still indent the
      // title. Hand it null outside selection mode instead.
      leading: isSelectionMode
          ? SelectionCheckboxSlot(
              isSelectionMode: isSelectionMode,
              isChecked: isChecked,
              onChanged: onCheckChanged,
              gap: 0,
            )
          : null,
      title: Text(config.name),
      subtitle: roles.isEmpty ? null : Text(roles),
      trailing: Text('${config.cylinderCount}'),
      onTap: isSelectionMode
          ? onSelectToggle
          : () => context.push('/equipment/cylinder-configs/${config.id}'),
    );
  }
}
