import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/write_confirmer.dart';
import 'package:submersion/features/change_log/presentation/change_log_labels.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Asks the diver whether a plan may run. Answers true for Allow, false for
/// Deny, and nothing when the confirmer times it out.
class AgentWriteConfirmDialog extends ConsumerWidget {
  const AgentWriteConfirmDialog({
    super.key,
    required this.request,
    required this.entityTables,
  });

  static const allowKey = ValueKey('agent-write-allow');
  static const denyKey = ValueKey('agent-write-deny');
  static const detailsKey = ValueKey('agent-write-details');

  final WriteConfirmation request;

  /// Entity name to table, for the words the change log uses for each.
  final Map<String, String> entityTables;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final divers = ref.watch(allDiversProvider).value ?? const <Diver>[];
    final names = {for (final diver in divers) diver.id: diver.name};
    return AlertDialog(
      title: Text(l.settings_agentAccess_confirm_title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_clientLine(l)),
              const SizedBox(height: 12),
              Text(request.label, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final MapEntry(:key, :value)
                  in request.countsByEntity.entries)
                Text(
                  l.settings_agentAccess_confirm_count(
                    changeLogTableLabel(l, entityTables[key] ?? key),
                    value,
                  ),
                ),
              if (request.countsByDiver.length > 1) ...[
                const SizedBox(height: 8),
                for (final MapEntry(:key, :value)
                    in request.countsByDiver.entries)
                  Text(
                    l.settings_agentAccess_confirm_count(
                      names[key] ?? l.settings_agentAccess_confirm_shared,
                      value,
                    ),
                  ),
              ] else if (names[request.countsByDiver.keys.firstOrNull]
                  case final name?)
                Text(name),
              ExpansionTile(
                key: detailsKey,
                tilePadding: EdgeInsets.zero,
                title: Text(l.settings_agentAccess_confirm_details),
                children: [
                  for (final item in request.items)
                    _PlanItemRow(item: item, units: units),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: denyKey,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.settings_agentAccess_confirm_deny),
        ),
        FilledButton(
          key: allowKey,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.settings_agentAccess_confirm_allow),
        ),
      ],
    );
  }

  String _clientLine(AppLocalizations l) => switch (request.clientName) {
    final client? when client.trim().isNotEmpty =>
      l.settings_agentAccess_confirm_client(client),
    _ => l.settings_agentAccess_confirm_unknownClient,
  };
}

class _PlanItemRow extends StatelessWidget {
  const _PlanItemRow({required this.item, required this.units});

  final PlanItem item;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final verb = switch (item.kind) {
      ChangeKind.create => l.settings_agentAccess_confirm_create,
      ChangeKind.update => l.settings_agentAccess_confirm_update,
      ChangeKind.delete => l.settings_agentAccess_confirm_delete,
    };
    final name = item.title ?? item.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name == null ? verb : '$verb: $name',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final MapEntry(:key, :value) in item.fields.entries)
            Text(
              '$key: ${agentValueText(l, units, key, value.oldValue)} '
              '→ ${agentValueText(l, units, key, value.newValue)}',
              style: theme.textTheme.bodySmall,
            ),
          for (final MapEntry(:key, :value) in item.relations.entries)
            Text(
              '$key: ${[for (final id in value.add) '+$id', for (final id in value.remove) '-$id'].join(', ')}',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// A plan value in the diver's units. A key names its metric unit, as every
/// document does.
String agentValueText(
  AppLocalizations l,
  UnitFormatter units,
  String key,
  Object? value,
) {
  if (value == null) return l.settings_agentAccess_confirm_none;
  if (value is num) {
    if (key.endsWith('_m')) return units.formatDepth(value.toDouble());
    if (key.endsWith('_c')) return units.formatTemperature(value.toDouble());
  }
  if (key == 'date_time' && value is String) {
    return units.formatDateTime(DateTime.parse(value), l10n: l);
  }
  return '$value';
}
