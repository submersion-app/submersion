import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/excel/maintenance_excel_export_service.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/maintenance_history_filter.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/service_category_label.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/export_destination_sheet.dart';

/// Service History Section Widget
class ServiceHistorySection extends ConsumerStatefulWidget {
  final String equipmentId;

  const ServiceHistorySection({super.key, required this.equipmentId});

  @override
  ConsumerState<ServiceHistorySection> createState() =>
      _ServiceHistorySectionState();
}

class _ServiceHistorySectionState extends ConsumerState<ServiceHistorySection> {
  /// Local rather than a provider: the filter is a view of this page and does
  /// not need to outlive it, matching EquipmentListContent's filter dropdown.
  MaintenanceHistoryFilter _filter = const MaintenanceHistoryFilter();

  String get equipmentId => widget.equipmentId;

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(serviceRecordNotifierProvider(equipmentId));
    final totalCostAsync = ref.watch(
      serviceRecordTotalCostProvider(equipmentId),
    );
    // Indexed once here rather than per row. While the kinds are still
    // loading the map is empty and rows fall back to the service type, which
    // is the right transient state: the history is already useful without the
    // task names, so blocking it behind a spinner would be worse.
    final kindsById = {
      for (final kind
          in ref.watch(serviceKindsProvider).valueOrNull ??
              const <ServiceKind>[])
        kind.id: kind,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Expanded + ellipsis so a long translation of the title
                // ("Serviceverlauf") cannot overflow the header on a narrow
                // phone. The Add button keeps its natural width and wins the
                // space it needs.
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          context.l10n.equipment_service_historyTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showAddServiceDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.equipment_service_addButton),
                ),
                PopupMenuButton<String>(
                  key: const Key('service-history-overflow'),
                  onSelected: (value) {
                    if (value == 'export') {
                      _exportHistory(context, recordsAsync.valueOrNull ?? []);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'export',
                      child: Text(
                        context.l10n.equipment_service_exportMenuItem,
                      ),
                    ),
                  ],
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

                final visible = records.where(_filter.matches).toList();

                return Column(
                  children: [
                    if (_showFilterBar(records, kindsById))
                      _buildFilterBar(context, records, kindsById),
                    // Total cost summary, one row per currency: a history
                    // priced in more than one currency has no single total.
                    totalCostAsync.when(
                      data: (rawTotals) {
                        final totals = sumByCurrency<MapEntry<String, double>>(
                          rawTotals.entries,
                          amountOf: (e) => e.value,
                          currencyOf: (e) => e.key,
                          fallbackCode: ref.watch(defaultCurrencyProvider),
                        ).where((e) => e.value > 0).toList();
                        if (totals.isEmpty) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              for (final entry in totals)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      context
                                          .l10n
                                          .equipment_service_totalCostLabel,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    Text(
                                      formatMoney(entry.value, entry.key),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    // Service records list. "Nothing logged yet" and "your
                    // filter hides everything" are different situations and
                    // call for different actions, so they stay distinct.
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            context.l10n.equipment_service_filterNoMatches,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      )
                    else
                      ...visible.map(
                        (record) => _ServiceRecordTile(
                          record: record,
                          kindsById: kindsById,
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

  /// Exports the rows currently on screen, so a filtered view exports what
  /// the diver is actually looking at rather than the whole history.
  Future<void> _exportHistory(
    BuildContext context,
    List<ServiceRecord> records,
  ) async {
    final destination = await showExportDestinationSheet(
      context,
      title: context.l10n.equipment_service_exportMenuItem,
    );
    if (destination == null || !context.mounted) return;

    // Awaited rather than read as a snapshot: this section does not watch
    // either provider, so a plain read returns AsyncLoading and the workbook
    // would carry a blank equipment name and task column.
    final item = await ref.read(equipmentItemProvider(equipmentId).future);
    final kinds = await ref.read(serviceKindsProvider.future);
    final kindsById = {for (final k in kinds) k.id: k};
    final dateFormat = ref.read(settingsProvider).dateFormat;

    final rows = <MaintenanceLogRow>[
      for (final record in records.where(_filter.matches))
        (
          equipmentName: item?.name ?? '',
          equipmentType: item?.type.displayName ?? '',
          serviceTypeName: kindsById[record.serviceKindId]?.name ?? '',
          serviceCategory: record.serviceCategory,
          record: record,
        ),
    ];

    // Through the injectable facade rather than a bare constructor, so this
    // path is overridable in tests like every other export surface.
    final service = ref.read(exportServiceProvider);
    // No progress dialog around the save path: the native save panel must not
    // open while a modal route is up.
    if (destination == ExportDestination.share) {
      await service.exportMaintenanceLog(rows: rows, dateFormat: dateFormat);
    } else {
      await service.saveMaintenanceLogToFile(
        rows: rows,
        dateFormat: dateFormat,
      );
    }
  }

  /// Options come from the records themselves, so a diver never sees a task
  /// they have never logged and every option yields at least one row.
  /// The leading null is the "All" entry.
  /// Sorted by the NAME shown, not the id: custom kind ids are uuids, so
  /// sorting by id puts the dropdown in an order that looks random to the
  /// diver even though the labels are task names.
  List<String?> _taskOptions(
    List<ServiceRecord> records,
    Map<String, ServiceKind> kindsById,
  ) {
    final ids = <String?>{for (final r in records) r.serviceKindId};
    final tagged = ids.whereType<String>().toList()
      ..sort((a, b) {
        final an = kindsById[a]?.name ?? a;
        final bn = kindsById[b]?.name ?? b;
        return an.toLowerCase().compareTo(bn.toLowerCase());
      });
    return [
      null,
      ...tagged,
      if (ids.contains(null)) MaintenanceHistoryFilter.untaggedSentinel,
    ];
  }

  List<ServiceCategory?> _typeOptions(List<ServiceRecord> records) {
    final types = {for (final r in records) r.serviceCategory}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return [null, ...types];
  }

  List<int?> _yearOptions(List<ServiceRecord> records) {
    final years = {for (final r in records) r.serviceDate.year}.toList()
      ..sort((a, b) => b.compareTo(a));
    return [null, ...years];
  }

  /// Three controls above a short list is noise. The bar appears only once
  /// some dimension actually has a choice to make (more than "All" plus one).
  bool _showFilterBar(
    List<ServiceRecord> records,
    Map<String, ServiceKind> kindsById,
  ) =>
      _taskOptions(records, kindsById).length > 2 ||
      _typeOptions(records).length > 2 ||
      _yearOptions(records).length > 2;

  Widget _buildFilterBar(
    BuildContext context,
    List<ServiceRecord> records,
    Map<String, ServiceKind> kindsById,
  ) {
    final l10n = context.l10n;
    final visibleCount = records.where(_filter.matches).length;

    String taskLabel(String? id) {
      if (id == null) return l10n.equipment_service_filterTaskAll;
      if (id == MaintenanceHistoryFilter.untaggedSentinel) {
        return l10n.equipment_service_filterUntagged;
      }
      return kindsById[id]?.name ?? id;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap rather than Row: three dropdowns fit one line on a tablet
          // and stack on a phone instead of overflowing.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterDropdown<String?>(
                value: _filter.serviceKindId,
                options: _taskOptions(records, kindsById),
                labelOf: taskLabel,
                onChanged: (value) => setState(
                  () => _filter = _filter.copyWith(
                    serviceKindId: value,
                    serviceCategory: _filter.serviceCategory,
                    year: _filter.year,
                  ),
                ),
              ),
              _FilterDropdown<ServiceCategory?>(
                value: _filter.serviceCategory,
                options: _typeOptions(records),
                labelOf: (type) => type == null
                    ? l10n.equipment_service_filterTypeAll
                    : type.label(l10n),
                onChanged: (value) => setState(
                  () => _filter = _filter.copyWith(
                    serviceKindId: _filter.serviceKindId,
                    serviceCategory: value,
                    year: _filter.year,
                  ),
                ),
              ),
              _FilterDropdown<int?>(
                value: _filter.year,
                options: _yearOptions(records),
                labelOf: (year) => year == null
                    ? l10n.equipment_service_filterYearAll
                    : '$year',
                onChanged: (value) => setState(
                  () => _filter = _filter.copyWith(
                    serviceKindId: _filter.serviceKindId,
                    serviceCategory: _filter.serviceCategory,
                    year: value,
                  ),
                ),
              ),
            ],
          ),
          if (_filter.isActive)
            Row(
              children: [
                Text(
                  l10n.equipment_service_filterMatchCount(
                    visibleCount,
                    records.length,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(
                    () => _filter = const MaintenanceHistoryFilter(),
                  ),
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(l10n.equipment_service_filterClear),
                ),
              ],
            ),
        ],
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
            record.serviceCategory.label(context.l10n),
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

  /// Resolves [ServiceRecord.serviceKindId] to the maintenance task's name.
  /// Built once by the section rather than per row.
  final Map<String, ServiceKind> kindsById;

  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ServiceRecordTile({
    required this.record,
    required this.kindsById,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final l10n = context.l10n;
    final theme = Theme.of(context);

    // The task answers "which of my jobs was done"; the type answers "what
    // category of work". Issue #829 asks for both, and the task is the one
    // that identifies the row, so it takes the title.
    final kindName = kindsById[record.serviceKindId]?.name;
    final typeLabel = record.serviceCategory.label(l10n);

    final providerAndCost = [
      if (record.provider != null && record.provider!.isNotEmpty)
        record.provider!,
      if (record.cost != null) formatMoney(record.cost!, record.currency),
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      isThreeLine: true,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          _getServiceCategoryIcon(record.serviceCategory),
          color: theme.colorScheme.onPrimaryContainer,
          size: 20,
        ),
      ),
      // maxLines + ellipsis is a backstop: if a future change puts a
      // text-bearing widget back into trailing, the title ellipsizes instead
      // of rendering one glyph per line (issue #935).
      title: Text(
        kindName ?? typeLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kindName == null
                ? units.formatDate(record.serviceDate)
                : '$typeLabel · ${units.formatDate(record.serviceDate)}',
            style: theme.textTheme.bodySmall,
          ),
          if (providerAndCost.isNotEmpty)
            Text(providerAndCost, style: theme.textTheme.bodySmall),
          if (record.nextServiceDue != null)
            Text(
              l10n.equipment_service_nextDueLabel(
                units.formatDate(record.nextServiceDue!),
              ),
              style: theme.textTheme.bodySmall,
            ),
          if (record.notes.isNotEmpty)
            Text(
              record.notes,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
      // Only fixed-width widgets belong in trailing. _RenderListTile lays
      // trailing out against the full tile width and gives the title whatever
      // is left, clamped at zero, so a Text here starves the title (#935).
      // The cost lives in the subtitle column for that reason.
      trailing: PopupMenuButton<String>(
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
            child: Text(l10n.equipment_service_editMenuItem),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Text(
              l10n.equipment_service_deleteMenuItem,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  IconData _getServiceCategoryIcon(ServiceCategory type) {
    switch (type) {
      case ServiceCategory.annual:
        return Icons.event_repeat;
      case ServiceCategory.repair:
        return Icons.build;
      case ServiceCategory.inspection:
        return Icons.search;
      case ServiceCategory.overhaul:
        return Icons.settings_suggest;
      case ServiceCategory.replacement:
        return Icons.swap_horiz;
      case ServiceCategory.cleaning:
        return Icons.cleaning_services;
      case ServiceCategory.calibration:
        return Icons.tune;
      case ServiceCategory.warranty:
        return Icons.verified_user;
      case ServiceCategory.recall:
        return Icons.warning;
      case ServiceCategory.other:
        return Icons.handyman;
    }
  }
}

/// One compact dropdown in the maintenance history filter bar.
///
/// Bordered container with the underline suppressed, matching the filter
/// dropdown in EquipmentListContent so the two read as the same control.
class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        isDense: true,
        items: [
          for (final option in options)
            DropdownMenuItem<T>(value: option, child: Text(labelOf(option))),
        ],
        onChanged: (selected) {
          if (selected is T) onChanged(selected);
        },
      ),
    );
  }
}
