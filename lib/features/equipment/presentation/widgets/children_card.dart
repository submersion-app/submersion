import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Types whose detail page shows the children card: the parents a cell
/// or a battery can be installed in (same set as the edit page's parent
/// picker).
const childHostTypes = {
  EquipmentType.rebreather,
  EquipmentType.computer,
  EquipmentType.transmitter,
  EquipmentType.light,
  EquipmentType.dpv,
};

/// The cells and batteries installed in a parent: slot, age since
/// install, worst service clock, and a one-tap replace that retires the
/// child and creates its successor in the same slot (condition phase 4a).
/// Renders nothing for a type that cannot host children.
class ChildrenCard extends ConsumerWidget {
  final EquipmentItem equipment;

  const ChildrenCard({super.key, required this.equipment});

  static const _log = LoggerService('ChildrenCard');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!childHostTypes.contains(equipment.type)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final childrenAsync = ref.watch(childEquipmentProvider(equipment.id));
    final worst = ref.watch(equipmentWorstClockProvider).value ?? const {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.equipmentCondition_children_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                // A retired or sold host cannot take a new part: the editor
                // only accepts a fitted parent and would save it loose.
                if (equipment.isFitted)
                  TextButton.icon(
                    // Already fitted to this host: without the parent the new
                    // part saved loose, and the diver had to pick it again.
                    onPressed: () =>
                        context.push('/equipment/new?parent=${equipment.id}'),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.equipmentCondition_children_add),
                  ),
              ],
            ),
            const Divider(),
            childrenAsync.when(
              loading: () => const SizedBox(height: 32),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text(l10n.common_error_tryAgain),
              ),
              data: (children) {
                if (children.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.equipmentCondition_children_empty,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final child in children)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(equipmentTypeIcon(child.type)),
                        title: Text(_title(l10n, child)),
                        subtitle: Text(_installedLine(l10n, units, child)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 10,
                              color: _dotColor(
                                theme.colorScheme,
                                worst[child.id]?.status.severity,
                              ),
                            ),
                            PopupMenuButton<_ChildAction>(
                              onSelected: (action) =>
                                  _onAction(context, ref, child, action),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: _ChildAction.open,
                                  child: Text(
                                    l10n.equipmentCondition_children_open,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: _ChildAction.replace,
                                  child: Text(
                                    l10n.equipmentCondition_children_replace,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _title(AppLocalizations l10n, EquipmentItem child) {
    final slot = child.cellSlot;
    if (slot == null) return child.name;
    return '${l10n.equipmentCondition_children_slot(slot)} · ${child.name}';
  }

  /// "Installed {date}, {age}"; days under two months, months after.
  String _installedLine(
    AppLocalizations l10n,
    UnitFormatter units,
    EquipmentItem child,
  ) {
    // The date its exposure counts from: the install date, else when the
    // part was created, as parentDivesFrom reads it.
    final installed = child.parentDivesFrom;
    if (installed == null) return child.type.localizedName(l10n);
    final now = DateTime.now();
    // Whole calendar days, both ends in the dive frame parentDivesFrom uses
    // (a local day as UTC midnight): a local instant minus it is off by the
    // device's UTC offset.
    final days = DateTime.utc(now.year, now.month, now.day)
        .difference(
          DateTime.utc(installed.year, installed.month, installed.day),
        )
        .inDays;
    // Completed calendar months: an average month length undercounts, so
    // a part installed a year ago read "11 months".
    var months = (now.year - installed.year) * 12 + now.month - installed.month;
    if (now.day < installed.day) months--;
    // Days through day 60, calendar months after (the phase plan).
    final age = days <= 60
        ? l10n.equipmentCondition_children_ageDays(days < 0 ? 0 : days)
        : l10n.equipmentCondition_children_ageMonths(months);
    return l10n.equipmentCondition_children_installed(
      units.formatDate(installed),
      age,
    );
  }

  Color _dotColor(ColorScheme scheme, ServiceClockSeverity? severity) {
    return switch (severity) {
      ServiceClockSeverity.overdue => scheme.error,
      ServiceClockSeverity.dueSoon => scheme.tertiary,
      ServiceClockSeverity.ok || null => scheme.surfaceContainerHighest,
    };
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    EquipmentItem child,
    _ChildAction action,
  ) async {
    switch (action) {
      case _ChildAction.open:
        context.push('/equipment/${child.id}');
      case _ChildAction.replace:
        await _replace(context, ref, child);
    }
  }

  Future<void> _replace(
    BuildContext context,
    WidgetRef ref,
    EquipmentItem child,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.equipmentCondition_children_replaceTitle(child.name)),
        content: Text(
          l10n.equipmentCondition_children_replaceBody(
            child.name,
            child.type.localizedName(l10n),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.equipmentCondition_children_replaceCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.equipmentCondition_children_replaceConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(equipmentRepositoryProvider).replaceChild(child);
    } catch (e, st) {
      _log.error('Replace child failed', error: e, stackTrace: st);
      // The old part is still fitted; say the replacement did not happen.
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.common_error_tryAgain)));
      }
      return;
    }
    // The diver may have left the page while the replacement saved; a
    // disposed state can no longer use ref. Both providers re-read on the
    // next visit anyway.
    if (!context.mounted) return;
    // The child list watches the equipment stream; the findings marker
    // reads the children, so a fresh child means a fresh review.
    ref.invalidate(childEquipmentProvider(equipment.id));
    ref.invalidate(equipmentConditionProvider(equipment.id));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.equipmentCondition_children_replaced(child.name)),
      ),
    );
  }
}

enum _ChildAction { open, replace }
