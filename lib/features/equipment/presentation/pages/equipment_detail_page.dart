import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/detail_scroll_retainer.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:collection/collection.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/unit_configurations_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_clocks_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_history_section.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';

class EquipmentDetailPage extends ConsumerStatefulWidget {
  final String equipmentId;
  final bool embedded;
  final VoidCallback? onDeleted;

  const EquipmentDetailPage({
    super.key,
    required this.equipmentId,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  ConsumerState<EquipmentDetailPage> createState() =>
      _EquipmentDetailPageState();
}

class _EquipmentDetailPageState extends ConsumerState<EquipmentDetailPage> {
  bool _hasRedirected = false;

  @override
  Widget build(BuildContext context) {
    // Desktop redirect: if viewing detail page directly on desktop, redirect to master-detail.
    // Skip in table mode -- table view has no master-detail split to redirect into.
    if (!widget.embedded &&
        !_hasRedirected &&
        ResponsiveBreakpoints.isMasterDetail(context)) {
      final viewMode = ref.read(equipmentListViewModeProvider);
      if (viewMode != ListViewMode.table) {
        _hasRedirected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/equipment?selected=${widget.equipmentId}');
          }
        });
      }
    }

    final equipmentAsync = ref.watch(equipmentItemProvider(widget.equipmentId));

    return equipmentAsync.when(
      data: (equipment) {
        if (equipment == null) {
          if (widget.embedded) {
            return Center(
              child: Text(context.l10n.equipment_detail_notFoundMessage),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.equipment_detail_notFoundTitle),
            ),
            body: Center(
              child: Text(context.l10n.equipment_detail_notFoundMessage),
            ),
          );
        }
        return _EquipmentDetailContent(
          equipment: equipment,
          equipmentId: widget.equipmentId,
          embedded: widget.embedded,
          onDeleted: widget.onDeleted,
        );
      },
      loading: () {
        if (widget.embedded) {
          return const Center(child: CircularProgressIndicator());
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.equipment_detail_loadingTitle),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, _) {
        if (widget.embedded) {
          return Center(
            child: Text(context.l10n.equipment_detail_errorMessage('$error')),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.equipment_detail_errorTitle)),
          body: Center(
            child: Text(context.l10n.equipment_detail_errorMessage('$error')),
          ),
        );
      },
    );
  }
}

class _EquipmentDetailContent extends ConsumerWidget {
  final EquipmentItem equipment;
  final String equipmentId;
  final bool embedded;
  final VoidCallback? onDeleted;

  const _EquipmentDetailContent({
    required this.equipment,
    required this.equipmentId,
    required this.embedded,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    // Service state now derives from the clock engine, not the legacy
    // isServiceDue getter: any overdue clock lights the header.
    final isServiceOverdue =
        ref
            .watch(serviceClockStatusesProvider(equipmentId))
            .value
            ?.any((s) => s.severity == ServiceClockSeverity.overdue) ??
        false;

    final body = SingleChildScrollView(
      controller: DetailScrollController.maybeOf(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(context, equipment, isServiceOverdue),
          const SizedBox(height: 24),
          _buildDetailsSection(context, ref, equipment, units),
          const SizedBox(height: 24),
          ServiceClocksCard(
            equipmentId: equipmentId,
            equipmentType: equipment.type,
            onLogService: (status) => _showAddServiceDialogForKind(
              context,
              ref,
              serviceKindId: status.kind.id,
            ),
          ),
          // Only rebreathers own configurations; every other type would show
          // a card that can never be anything but empty.
          if (equipment.type == EquipmentType.rebreather) ...[
            const SizedBox(height: 24),
            UnitConfigurationsCard(equipmentId: equipmentId),
          ],
          const SizedBox(height: 24),
          ServiceHistorySection(equipmentId: equipmentId),
          if (equipment.notes.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildNotesSection(context, equipment),
          ],
        ],
      ),
    );

    if (embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, ref, equipment, isServiceOverdue),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(equipment.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: context.l10n.equipment_detail_editTooltip,
            onPressed: () => context.push('/equipment/$equipmentId/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) =>
                _handleMenuAction(context, ref, value, equipment),
            itemBuilder: (context) => _buildMenuItems(context, equipment),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildEmbeddedHeader(
    BuildContext context,
    WidgetRef ref,
    EquipmentItem equipment,
    bool isServiceOverdue,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isServiceOverdue
                ? colorScheme.errorContainer
                : colorScheme.tertiaryContainer,
            child: Icon(
              equipmentTypeIcon(equipment.type),
              size: 20,
              color: isServiceOverdue
                  ? colorScheme.onErrorContainer
                  : colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  equipment.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  equipment.type.displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            tooltip: context.l10n.equipment_detail_editTooltipShort,
            onPressed: () {
              final state = GoRouterState.of(context);
              final currentPath = state.uri.path;
              context.go('$currentPath?selected=$equipmentId&mode=edit');
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) =>
                _handleMenuAction(context, ref, value, equipment),
            itemBuilder: (context) => _buildMenuItems(context, equipment),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(
    BuildContext context,
    EquipmentItem equipment,
  ) {
    return [
      PopupMenuItem(
        value: equipment.isActive ? 'retire' : 'reactivate',
        child: ListTile(
          leading: Icon(equipment.isActive ? Icons.archive : Icons.unarchive),
          title: Text(
            equipment.isActive
                ? context.l10n.equipment_menu_retireEquipment
                : context.l10n.equipment_menu_reactivate,
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        child: ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: Text(
            context.l10n.equipment_menu_delete,
            style: const TextStyle(color: Colors.red),
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ];
  }

  Widget _buildHeaderSection(
    BuildContext context,
    EquipmentItem equipment,
    bool isServiceOverdue,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: isServiceOverdue
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.tertiaryContainer,
                  child: Icon(
                    equipmentTypeIcon(equipment.type),
                    size: 32,
                    color: isServiceOverdue
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipment.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        equipment.type.displayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (!equipment.isActive)
                        Chip(
                          label: Text(
                            context.l10n.equipment_detail_retiredChip,
                          ),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (isServiceOverdue) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.equipment_detail_serviceOverdue,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection(
    BuildContext context,
    WidgetRef ref,
    EquipmentItem equipment,
    UnitFormatter units,
  ) {
    final diveCountAsync = ref.watch(equipmentDiveCountProvider(equipmentId));
    final tripCountAsync = ref.watch(equipmentTripCountProvider(equipmentId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.equipment_detail_detailsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            _buildDetailRow(
              context,
              context.l10n.equipment_detail_statusLabel,
              equipment.status.displayName,
            ),
            diveCountAsync.when(
              data: (count) => Semantics(
                button: count > 0,
                label: context.l10n.equipment_detail_divesSemanticLabel,
                child: InkWell(
                  onTap: count > 0
                      ? () {
                          ref.read(diveFilterProvider.notifier).state =
                              DiveFilterState(equipmentIds: [equipmentId]);
                          context.go('/dives');
                        }
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.equipment_detail_divesLabel,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              count == 1
                                  ? context.l10n
                                        .equipment_detail_divesCountSingular(
                                          count,
                                        )
                                  : context.l10n
                                        .equipment_detail_divesCountPlural(
                                          count,
                                        ),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: count > 0
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                            ),
                            if (count > 0) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              loading: () => _buildDetailRow(
                context,
                context.l10n.equipment_detail_divesLabel,
                '...',
              ),
              error: (e, s) => const SizedBox.shrink(),
            ),
            tripCountAsync.when(
              data: (count) => Semantics(
                button: count > 0,
                label: context.l10n.equipment_detail_tripsSemanticLabel,
                child: InkWell(
                  onTap: count > 0
                      ? () {
                          ref.read(tripFilterProvider.notifier).state =
                              TripFilterState(equipmentId: equipmentId);
                          context.go('/trips');
                        }
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.equipment_detail_tripsLabel,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              count == 1
                                  ? context.l10n
                                        .equipment_detail_tripsCountSingular(
                                          count,
                                        )
                                  : context.l10n
                                        .equipment_detail_tripsCountPlural(
                                          count,
                                        ),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: count > 0
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                            ),
                            if (count > 0) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              loading: () => _buildDetailRow(
                context,
                context.l10n.equipment_detail_tripsLabel,
                '...',
              ),
              error: (e, s) => const SizedBox.shrink(),
            ),
            if (equipment.brand != null)
              _buildDetailRow(
                context,
                context.l10n.equipment_detail_brandLabel,
                equipment.brand!,
              ),
            if (equipment.model != null)
              _buildDetailRow(
                context,
                context.l10n.equipment_detail_modelLabel,
                equipment.model!,
              ),
            if (equipment.serialNumber != null)
              _buildDetailRow(
                context,
                context.l10n.equipment_detail_serialNumberLabel,
                equipment.serialNumber!,
              ),
            // Curated attributes in catalog order, then custom fields.
            for (final def in EquipmentAttributeCatalog.attributesFor(
              equipment.type,
            ))
              if (equipment.attributes.firstWhereOrNull(
                    (a) => !a.isCustom && a.key == def.key,
                  )
                  case final attr? when attr.hasValue)
                _buildDetailRow(
                  context,
                  attributeLabel(context.l10n, def.key),
                  formatAttributeValue(attr, def, units, context.l10n),
                ),
            for (final attr
                in equipment.attributes.where((a) => a.isCustom).toList()
                  ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
              if (attr.hasValue)
                _buildDetailRow(context, attr.key, attr.valueText ?? ''),
            if (equipment.purchaseDate != null)
              _buildDetailRow(
                context,
                context.l10n.equipment_detail_purchaseDateLabel,
                units.formatDate(equipment.purchaseDate),
              ),
            if (equipment.purchasePrice != null)
              _buildDetailRow(
                context,
                context.l10n.equipment_detail_purchasePriceLabel,
                formatMoney(
                  equipment.purchasePrice!,
                  equipment.purchaseCurrency,
                ),
              ),
            if (equipment.ownershipDuration != null)
              _buildDetailRow(
                context,
                context.l10n.equipment_detail_ownedForLabel,
                _formatDuration(context, equipment.ownershipDuration!),
              ),
          ],
        ),
      ),
    );
  }

  /// Opens the add-service dialog pre-tagged with a clock's kind so the
  /// saved record resets that clock.
  void _showAddServiceDialogForKind(
    BuildContext context,
    WidgetRef ref, {
    required String serviceKindId,
  }) {
    showDialog(
      context: context,
      builder: (context) => ServiceRecordDialog(
        equipmentId: equipmentId,
        serviceKindId: serviceKindId,
        onSave: (record) async {
          await ref
              .read(serviceRecordNotifierProvider(equipmentId).notifier)
              .addRecord(record);
        },
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context, EquipmentItem equipment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notes,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.equipment_detail_notesTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              equipment.notes,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          // Flexible so long values (e.g. free-text custom fields) wrap
          // instead of overflowing the row.
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(BuildContext context, Duration duration) {
    final days = duration.inDays;
    if (days < 30) return context.l10n.equipment_detail_durationDays(days);
    if (days < 365) {
      final months = (days / 30).floor();
      return context.l10n.equipment_detail_durationMonths(months);
    }
    final years = (days / 365).floor();
    final months = ((days % 365) / 30).floor();
    if (months == 0) {
      return years == 1
          ? context.l10n.equipment_detail_durationYearsSingular(years)
          : context.l10n.equipment_detail_durationYearsPlural(years);
    }
    if (years == 1 && months == 1) {
      return context.l10n.equipment_detail_durationYearsMonthsSingularSingular(
        years,
        months,
      );
    }
    if (years == 1) {
      return context.l10n.equipment_detail_durationYearsMonthsSingularPlural(
        years,
        months,
      );
    }
    if (months == 1) {
      return context.l10n.equipment_detail_durationYearsMonthsPluralSingular(
        years,
        months,
      );
    }
    return context.l10n.equipment_detail_durationYearsMonthsPluralPlural(
      years,
      months,
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    EquipmentItem equipment,
  ) async {
    final notifier = ref.read(equipmentListNotifierProvider.notifier);

    switch (action) {
      case 'retire':
        await notifier.retireEquipment(equipmentId);
        ref.invalidate(equipmentItemProvider(equipmentId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.equipment_snackbar_retired)),
          );
        }
        break;

      case 'reactivate':
        await notifier.reactivateEquipment(equipmentId);
        ref.invalidate(equipmentItemProvider(equipmentId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.equipment_snackbar_reactivated),
            ),
          );
        }
        break;

      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.equipment_deleteDialog_title),
            content: Text(context.l10n.equipment_deleteDialog_content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.equipment_deleteDialog_cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(context.l10n.equipment_deleteDialog_confirm),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await notifier.deleteEquipment(equipmentId);
          if (context.mounted) {
            if (embedded) {
              onDeleted?.call();
            } else {
              context.go('/equipment');
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.equipment_snackbar_deleted)),
            );
          }
        }
        break;
    }
  }
}
