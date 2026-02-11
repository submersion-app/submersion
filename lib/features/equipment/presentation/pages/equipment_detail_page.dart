import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

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
    // Desktop redirect: if viewing detail page directly on desktop, redirect to master-detail
    if (!widget.embedded &&
        !_hasRedirected &&
        ResponsiveBreakpoints.isMasterDetail(context)) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/equipment?selected=${widget.equipmentId}');
        }
      });
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

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(context, equipment),
          const SizedBox(height: 24),
          _buildDetailsSection(context, ref, equipment, units),
          if (equipment.serviceIntervalDays != null) ...[
            const SizedBox(height: 24),
            _buildServiceSection(context, equipment, units),
          ],
          const SizedBox(height: 24),
          _ServiceHistorySection(equipmentId: equipmentId),
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
          _buildEmbeddedHeader(context, ref, equipment),
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
            backgroundColor: equipment.isServiceDue
                ? colorScheme.errorContainer
                : colorScheme.tertiaryContainer,
            child: Icon(
              _getIconForType(equipment.type),
              size: 20,
              color: equipment.isServiceDue
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
      if (equipment.isActive)
        PopupMenuItem(
          value: 'service',
          child: ListTile(
            leading: const Icon(Icons.build),
            title: Text(context.l10n.equipment_menu_markAsServiced),
            contentPadding: EdgeInsets.zero,
          ),
        ),
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

  Widget _buildHeaderSection(BuildContext context, EquipmentItem equipment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: equipment.isServiceDue
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.tertiaryContainer,
                  child: Icon(
                    _getIconForType(equipment.type),
                    size: 32,
                    color: equipment.isServiceDue
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
            if (equipment.isServiceDue) ...[
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
            if (equipment.size != null)
              _buildDetailRow(
                context,
                context.l10n.equipment_detail_sizeLabel,
                equipment.size!,
              ),
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
                '${equipment.purchasePrice!.toStringAsFixed(2)} ${equipment.purchaseCurrency}',
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

  Widget _buildServiceSection(
    BuildContext context,
    EquipmentItem equipment,
    UnitFormatter units,
  ) {
    final daysUntil = equipment.daysUntilService;
    final isOverdue = daysUntil != null && daysUntil < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.equipment_detail_serviceInfoTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            _buildDetailRow(
              context,
              context.l10n.equipment_detail_serviceIntervalLabel,
              context.l10n.equipment_detail_serviceIntervalValue(
                equipment.serviceIntervalDays!,
              ),
            ),
            if (equipment.lastServiceDate != null)
              _buildDetailRow(
                context,
                context.l10n.equipment_detail_lastServiceLabel,
                units.formatDate(equipment.lastServiceDate),
              ),
            if (equipment.nextServiceDue != null)
              _buildDetailRow(
                context,
                context.l10n.equipment_detail_nextServiceDueLabel,
                units.formatDate(equipment.nextServiceDue),
              ),
            if (daysUntil != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? Theme.of(context).colorScheme.errorContainer
                        : daysUntil < 30
                        ? Theme.of(context).colorScheme.tertiaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOverdue ? Icons.warning : Icons.schedule,
                        size: 16,
                        color: isOverdue
                            ? Theme.of(context).colorScheme.onErrorContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOverdue
                            ? context.l10n.equipment_detail_daysOverdue(
                                daysUntil.abs(),
                              )
                            : context.l10n.equipment_detail_daysUntilService(
                                daysUntil,
                              ),
                        style: TextStyle(
                          color: isOverdue
                              ? Theme.of(context).colorScheme.onErrorContainer
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: isOverdue ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
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
      case 'service':
        await notifier.markAsServiced(equipmentId);
        ref.invalidate(equipmentItemProvider(equipmentId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.equipment_snackbar_markedAsServiced),
            ),
          );
        }
        break;

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

  IconData _getIconForType(EquipmentType type) {
    switch (type) {
      case EquipmentType.regulator:
        return Icons.air;
      case EquipmentType.bcd:
        return Icons.accessibility_new;
      case EquipmentType.wetsuit:
      case EquipmentType.drysuit:
        return Icons.checkroom;
      case EquipmentType.fins:
        return Icons.directions_walk;
      case EquipmentType.mask:
        return Icons.visibility;
      case EquipmentType.computer:
        return Icons.watch;
      case EquipmentType.tank:
        return Icons.propane_tank;
      case EquipmentType.weights:
        return Icons.fitness_center;
      case EquipmentType.light:
        return Icons.flashlight_on;
      case EquipmentType.camera:
        return Icons.camera_alt;
      default:
        return Icons.backpack;
    }
  }
}

/// Service History Section Widget
class _ServiceHistorySection extends ConsumerWidget {
  final String equipmentId;

  const _ServiceHistorySection({required this.equipmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(serviceRecordNotifierProvider(equipmentId));
    final totalCostAsync = ref.watch(
      serviceRecordTotalCostProvider(equipmentId),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.equipment_service_historyTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showAddServiceDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.equipment_service_addButton),
                ),
              ],
            ),
            const Divider(),
            recordsAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.build_outlined,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.equipment_service_emptyState,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    // Total cost summary
                    totalCostAsync.when(
                      data: (totalCost) {
                        if (totalCost > 0) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.l10n.equipment_service_totalCostLabel,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Text(
                                  '\$${totalCost.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    // Service records list
                    ...records.map(
                      (record) => _ServiceRecordTile(
                        record: record,
                        onTap: () =>
                            _showEditServiceDialog(context, ref, record),
                        onDelete: () =>
                            _confirmDeleteRecord(context, ref, record),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Center(
                child: Text(
                  context.l10n.equipment_detail_errorMessage('$error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddServiceDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => ServiceRecordDialog(
        equipmentId: equipmentId,
        onSave: (record) async {
          await ref
              .read(serviceRecordNotifierProvider(equipmentId).notifier)
              .addRecord(record);
        },
      ),
    );
  }

  void _showEditServiceDialog(
    BuildContext context,
    WidgetRef ref,
    ServiceRecord record,
  ) {
    showDialog(
      context: context,
      builder: (context) => ServiceRecordDialog(
        equipmentId: equipmentId,
        existingRecord: record,
        onSave: (updatedRecord) async {
          await ref
              .read(serviceRecordNotifierProvider(equipmentId).notifier)
              .updateRecord(updatedRecord);
        },
      ),
    );
  }

  Future<void> _confirmDeleteRecord(
    BuildContext context,
    WidgetRef ref,
    ServiceRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.equipment_service_deleteDialog_title),
        content: Text(
          context.l10n.equipment_service_deleteDialog_content(
            record.serviceType.displayName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.equipment_service_deleteDialog_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.equipment_service_deleteDialog_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(serviceRecordNotifierProvider(equipmentId).notifier)
          .deleteRecord(record.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.equipment_service_snackbar_deleted),
          ),
        );
      }
    }
  }
}

/// Service Record Tile Widget
class _ServiceRecordTile extends ConsumerWidget {
  final ServiceRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ServiceRecordTile({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          _getServiceTypeIcon(record.serviceType),
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          size: 20,
        ),
      ),
      title: Text(record.serviceType.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(units.formatDate(record.serviceDate)),
          if (record.provider != null)
            Text(
              record.provider!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (record.cost != null)
            Text(
              '\$${record.cost!.toStringAsFixed(2)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                onTap();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(context.l10n.equipment_service_editMenuItem),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  context.l10n.equipment_service_deleteMenuItem,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  IconData _getServiceTypeIcon(ServiceType type) {
    switch (type) {
      case ServiceType.annual:
        return Icons.event_repeat;
      case ServiceType.repair:
        return Icons.build;
      case ServiceType.inspection:
        return Icons.search;
      case ServiceType.overhaul:
        return Icons.settings_suggest;
      case ServiceType.replacement:
        return Icons.swap_horiz;
      case ServiceType.cleaning:
        return Icons.cleaning_services;
      case ServiceType.calibration:
        return Icons.tune;
      case ServiceType.warranty:
        return Icons.verified_user;
      case ServiceType.recall:
        return Icons.warning;
      case ServiceType.other:
        return Icons.handyman;
    }
  }
}

/// Service Record Dialog for Add/Edit
class ServiceRecordDialog extends ConsumerStatefulWidget {
  final String equipmentId;
  final ServiceRecord? existingRecord;
  final Future<void> Function(ServiceRecord) onSave;

  const ServiceRecordDialog({
    super.key,
    required this.equipmentId,
    this.existingRecord,
    required this.onSave,
  });

  @override
  ConsumerState<ServiceRecordDialog> createState() =>
      _ServiceRecordDialogState();
}

class _ServiceRecordDialogState extends ConsumerState<ServiceRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late ServiceType _serviceType;
  late DateTime _serviceDate;
  final _providerController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _nextServiceDue;
  bool _isSaving = false;

  bool get isEditing => widget.existingRecord != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final record = widget.existingRecord!;
      _serviceType = record.serviceType;
      _serviceDate = record.serviceDate;
      _providerController.text = record.provider ?? '';
      _costController.text = record.cost?.toString() ?? '';
      _notesController.text = record.notes;
      _nextServiceDue = record.nextServiceDue;
    } else {
      _serviceType = ServiceType.annual;
      _serviceDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _providerController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return AlertDialog(
      title: Text(
        isEditing
            ? context.l10n.equipment_serviceDialog_editTitle
            : context.l10n.equipment_serviceDialog_addTitle,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Service type dropdown
                DropdownButtonFormField<ServiceType>(
                  initialValue: _serviceType,
                  decoration: InputDecoration(
                    labelText:
                        context.l10n.equipment_serviceDialog_serviceTypeLabel,
                    prefixIcon: const Icon(Icons.build),
                  ),
                  items: ServiceType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _serviceType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Service date picker
                Semantics(
                  button: true,
                  label: context
                      .l10n
                      .equipment_serviceDialog_serviceDateSemanticLabel,
                  child: InkWell(
                    onTap: () => _pickServiceDate(),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: context
                            .l10n
                            .equipment_serviceDialog_serviceDateLabel,
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(units.formatDate(_serviceDate)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Provider field
                TextFormField(
                  controller: _providerController,
                  decoration: InputDecoration(
                    labelText:
                        context.l10n.equipment_serviceDialog_providerLabel,
                    prefixIcon: const Icon(Icons.store),
                    hintText: context.l10n.equipment_serviceDialog_providerHint,
                  ),
                ),
                const SizedBox(height: 16),

                // Cost field
                TextFormField(
                  controller: _costController,
                  decoration: InputDecoration(
                    labelText: context.l10n.equipment_serviceDialog_costLabel,
                    prefixIcon: const Icon(Icons.attach_money),
                    hintText: context.l10n.equipment_serviceDialog_costHint,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final parsed = double.tryParse(value);
                      if (parsed == null || parsed < 0) {
                        return context
                            .l10n
                            .equipment_serviceDialog_costValidation;
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Next service due date picker
                Semantics(
                  button: true,
                  label: context
                      .l10n
                      .equipment_serviceDialog_nextServiceDueSemanticLabel,
                  child: InkWell(
                    onTap: () => _pickNextServiceDate(),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: context
                            .l10n
                            .equipment_serviceDialog_nextServiceDueLabel,
                        prefixIcon: const Icon(Icons.event),
                        suffixIcon: _nextServiceDue != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                tooltip: context
                                    .l10n
                                    .equipment_serviceDialog_clearNextServiceDateTooltip,
                                onPressed: () =>
                                    setState(() => _nextServiceDue = null),
                              )
                            : null,
                      ),
                      child: Text(
                        _nextServiceDue != null
                            ? units.formatDate(_nextServiceDue)
                            : context
                                  .l10n
                                  .equipment_serviceDialog_nextServiceNotSet,
                        style: TextStyle(
                          color: _nextServiceDue == null
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes field
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: context.l10n.equipment_serviceDialog_notesLabel,
                    prefixIcon: const Icon(Icons.notes),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.equipment_serviceDialog_cancelButton),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  isEditing
                      ? context.l10n.equipment_serviceDialog_updateButton
                      : context.l10n.equipment_serviceDialog_addButton,
                ),
        ),
      ],
    );
  }

  Future<void> _pickServiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _serviceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _serviceDate = picked);
    }
  }

  Future<void> _pickNextServiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _nextServiceDue ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _nextServiceDue = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final record = ServiceRecord(
        id: widget.existingRecord?.id ?? '',
        equipmentId: widget.equipmentId,
        serviceType: _serviceType,
        serviceDate: _serviceDate,
        provider: _providerController.text.trim().isEmpty
            ? null
            : _providerController.text.trim(),
        cost: _costController.text.isEmpty
            ? null
            : double.tryParse(_costController.text),
        currency: 'USD',
        nextServiceDue: _nextServiceDue,
        notes: _notesController.text.trim(),
        createdAt: widget.existingRecord?.createdAt ?? now,
        updatedAt: now,
      );

      await widget.onSave(record);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? context.l10n.equipment_serviceDialog_snackbar_updated
                  : context.l10n.equipment_serviceDialog_snackbar_added,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.equipment_serviceDialog_snackbar_error('$e'),
            ),
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
