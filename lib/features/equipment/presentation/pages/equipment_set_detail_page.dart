import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/equipment/presentation/utils/equipment_row_label.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_chips.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_inputs.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';

class EquipmentSetDetailPage extends ConsumerStatefulWidget {
  final String setId;

  const EquipmentSetDetailPage({super.key, required this.setId});

  @override
  ConsumerState<EquipmentSetDetailPage> createState() =>
      _EquipmentSetDetailPageState();
}

class _EquipmentSetDetailPageState
    extends ConsumerState<EquipmentSetDetailPage> {
  /// The item whose disc and legend row are highlighted, cleared after a
  /// moment so the highlight reads as a flash rather than a selection mode.
  String? _selectedId;
  Timer? _flashTimer;
  final Map<String, GlobalKey> _rowKeys = {};

  String get setId => widget.setId;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  /// Highlights [id] on the figure and in the list, and brings its row into
  /// view. Tapping either a disc or a row badge lands here.
  void _select(String id) {
    _flashTimer?.cancel();
    setState(() => _selectedId = id);
    _flashTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _selectedId = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rowContext = _rowKeys[id]?.currentContext;
      if (rowContext != null && rowContext.mounted) {
        Scrollable.ensureVisible(
          rowContext,
          alignment: 0.3,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final setAsync = ref.watch(equipmentSetProvider(setId));

    return setAsync.when(
      data: (set) {
        if (set == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.equipment_setDetail_notFoundTitle),
            ),
            body: Center(
              child: Text(context.l10n.equipment_setDetail_notFoundMessage),
            ),
          );
        }
        return _buildContent(context, ref, set);
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.equipment_setDetail_loadingTitle),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.equipment_setDetail_errorTitle),
        ),
        body: Center(
          child: Text(context.l10n.equipment_setDetail_errorMessage('$error')),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, EquipmentSet set) {
    // Labelled as one list, so identical items in the set read differently
    // from each other (#1549).
    final labels = equipmentRowLabelsOf(
      context,
      ref,
      set.items ?? const <EquipmentItem>[],
    );
    // Arranged the same way as the gear lists on a dive, so a set reads the
    // way the diver reads their rig (#1486, #1576). The figure numbers items
    // in this same order, so its discs and the list's badges agree.
    final groups = arrangeEquipment(
      set.items ?? const <EquipmentItem>[],
      ref.watch(equipmentArrangementProvider),
      typeLabel: (type) => type.localizedName(context.l10n),
    );
    final ordered = [for (final group in groups) ...group.items];
    final components =
        ref.watch(equipmentComponentsIndexProvider).value ??
        ComponentsIndex.empty;
    final model = composeFigure(
      figureInputsFromItems(ordered, components: components),
    );
    // The figure is opt-in per set; without it the list's numbers would
    // point at nothing, so they go too.
    final numberById = set.showFigure
        ? {for (final p in model.numbered) p.item.id: p.number}
        : const <String, int>{};
    return Scaffold(
      appBar: AppBar(
        title: Text(set.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: context.l10n.equipment_setDetail_editTooltip,
            onPressed: () => context.push('/equipment/sets/$setId/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, ref, value, set),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggleFigure',
                child: ListTile(
                  leading: Icon(
                    set.showFigure
                        ? Icons.visibility_off_outlined
                        : Icons.accessibility_new,
                  ),
                  title: Text(
                    set.showFigure
                        ? context.l10n.equipment_setDetail_hideFigure
                        : context.l10n.equipment_setDetail_showFigure,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (!set.isDefault)
                PopupMenuItem(
                  value: 'setAsDefault',
                  child: ListTile(
                    leading: const Icon(Icons.star_outline),
                    title: Text(context.l10n.equipment_setDetail_setAsDefault),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    context.l10n.equipment_setDetail_deleteMenuItem,
                    style: const TextStyle(color: Colors.red),
                  ),
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
            // Header card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.folder,
                        size: 32,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  set.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              if (set.isDefault) ...[
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(
                                    context.l10n.equipment_sets_defaultBadge,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ],
                          ),
                          if (set.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              set.description,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            set.itemCount == 1
                                ? context.l10n.equipment_sets_itemCountSingular(
                                    set.itemCount,
                                  )
                                : context.l10n.equipment_sets_itemCountPlural(
                                    set.itemCount,
                                  ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (set.showFigure && ordered.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DiverFigure(
                    model: model,
                    semanticsLabel: context.l10n.equipment_figure_summary(
                      set.name,
                      model.itemCount,
                    ),
                    labelText: (placed) => placed.item.name,
                    sideLabel: (view, count) => view == FigureView.front
                        ? context.l10n.equipment_figure_frontCount(count)
                        : context.l10n.equipment_figure_backCount(count),
                    selectedItemId: _selectedId,
                    onItemTap: (placed) => _select(placed.item.id),
                    itemSemantics: (placed) =>
                        context.l10n.equipment_figure_discLabel(
                          placed.number,
                          placed.item.type.localizedName(context.l10n),
                          placed.item.name,
                        ),
                    trayTitle: context.l10n.equipment_figure_trayTitle,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Equipment items
            Text(
              context.l10n.equipment_setDetail_equipmentInSetTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (set.items == null || set.items!.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.backpack_outlined,
                          size: 48,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.equipment_setDetail_emptySet,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/equipment/sets/$setId/edit'),
                          icon: const Icon(Icons.add),
                          label: Text(
                            context.l10n.equipment_setDetail_addEquipmentButton,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              for (final group in groups) ...[
                if (group.type != null) EquipmentGroupHeader(type: group.type!),
                ...group.items.map(
                  (item) => _buildEquipmentTile(
                    context,
                    item,
                    labels,
                    numberById[item.id],
                  ),
                ),
              ],
            const SizedBox(height: 24),
            Text(
              context.l10n.equipment_setDetail_geofencesTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                final fencesAsync = ref.watch(
                  equipmentSetGeofencesProvider(setId),
                );
                return fencesAsync.maybeWhen(
                  data: (fences) => fences.isEmpty
                      ? Text(context.l10n.equipment_setDetail_noGeofences)
                      : Column(
                          children: [
                            for (final g in fences)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.place_outlined),
                                title: Text(
                                  g.label ??
                                      context
                                          .l10n
                                          .equipment_geofenceEditor_title,
                                ),
                              ),
                          ],
                        ),
                  orElse: () => const SizedBox.shrink(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// One member of the set. [number] is its figure number, shown as the
  /// legend badge; child items and assembly parts have none.
  Widget _buildEquipmentTile(
    BuildContext context,
    EquipmentItem item,
    Map<String, EquipmentRowLabel> labels,
    int? number,
  ) {
    final selected = item.id == _selectedId;
    final scheme = Theme.of(context).colorScheme;
    final highlight = selected ? figureHighlightFor(scheme) : null;
    return Card(
      key: _rowKeys.putIfAbsent(item.id, GlobalKey.new),
      margin: const EdgeInsets.only(bottom: 8),
      color: highlight?.fill,
      child: ListTile(
        textColor: highlight?.onFill,
        iconColor: highlight?.onFill,
        onTap: () => context.push('/equipment/${item.id}'),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (number != null) ...[
              FigureNumberBadge(
                number: number,
                selected: selected,
                onTap: () => _select(item.id),
              ),
              const SizedBox(width: 8),
            ],
            CircleAvatar(
              backgroundColor: scheme.tertiaryContainer,
              child: Icon(
                equipmentTypeIcon(item.type),
                color: scheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
        title: Text(item.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The type stands in for a missing brand and model, as it always
            // has here; an identifier or a tie-break detail follows it
            // rather than replacing it, or "ID P2" alone would not say what
            // the item is.
            Text(
              [
                if (item.fullName == item.name)
                  item.type.localizedName(context.l10n),
                ...?labels[item.id]?.subtitleParts,
              ].join(' · '),
            ),
            AssemblyChips(itemId: item.id),
            ServiceStatusIndicatorFor(
              equipmentId: item.id,
              density: ServiceIndicatorDensity.compact,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    EquipmentSet set,
  ) async {
    if (action == 'toggleFigure') {
      await ref
          .read(equipmentSetListNotifierProvider.notifier)
          .updateSet(set.copyWith(showFigure: !set.showFigure));
      return;
    }
    if (action == 'setAsDefault') {
      await ref
          .read(equipmentSetListNotifierProvider.notifier)
          .setAsDefault(setId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.equipment_setDetail_setAsDefaultSnackbar(set.name),
            ),
          ),
        );
      }
      return;
    }
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.equipment_setDetail_deleteDialog_title),
          content: Text(context.l10n.equipment_setDetail_deleteDialog_content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.equipment_setDetail_deleteDialog_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(
                context.l10n.equipment_setDetail_deleteDialog_confirm,
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref
            .read(equipmentSetListNotifierProvider.notifier)
            .deleteSet(setId);
        if (context.mounted) {
          context.go('/equipment');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.equipment_setDetail_snackbar_deleted),
            ),
          );
        }
      }
    }
  }
}
