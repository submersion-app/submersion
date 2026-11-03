import 'dart:async';

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

/// How long Allow waits after the dialog appears. The window is raised and
/// focused over whatever the diver is doing, so a click meant for another
/// window must not land on Allow.
const kAgentWriteAllowDelay = Duration(milliseconds: 800);

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
    // Only a record with no owner is shared. A profile the list cannot name,
    // as while it loads, shows its id rather than claiming to be shared.
    String diverName(String id) =>
        id.isEmpty ? l.settings_agentAccess_confirm_shared : names[id] ?? id;
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
              for (final MapEntry(key: entity, value: kinds)
                  in request.countsByChange.entries)
                for (final MapEntry(key: kind, value: count) in kinds.entries)
                  Text(
                    l.settings_agentAccess_confirm_count(
                      '${_verb(l, kind)} \u00b7 '
                      '${changeLogTableLabel(l, entityTables[entity] ?? entity)}',
                      count,
                    ),
                    style: kind == ChangeKind.delete.name
                        ? TextStyle(color: theme.colorScheme.error)
                        : null,
                  ),
              const SizedBox(height: 8),
              for (final MapEntry(:key, :value)
                  in request.countsByDiver.entries)
                Text(
                  l.settings_agentAccess_confirm_count(diverName(key), value),
                ),
              for (final MapEntry(:key, :value)
                  in request.linkedDivesByDiver.entries)
                Text(
                  l.settings_agentAccess_confirm_linkedDives(
                    diverName(key),
                    value,
                  ),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              for (final MapEntry(:key, :value) in _alsoDeleted.entries)
                Text(
                  l.settings_agentAccess_confirm_alsoDeletes(
                    changeLogTableLabel(l, key),
                    value,
                  ),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              for (final MapEntry(:key, :value) in _alsoUnlinked.entries)
                Text(
                  l.settings_agentAccess_confirm_alsoUnlinks(
                    changeLogTableLabel(l, key),
                    value,
                  ),
                ),
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
        _AllowButton(label: l.settings_agentAccess_confirm_allow),
      ],
    );
  }

  /// Records deleted alongside the plan's own deletes, by table.
  Map<String, int> get _alsoDeleted => _sum((reach) => reach.records);

  /// Records that lose a link to the plan's own deletes, by table.
  Map<String, int> get _alsoUnlinked => _sum((reach) => reach.unlinked);

  Map<String, int> _sum(Map<String, int> Function(DeleteReach) counted) {
    final counts = <String, int>{};
    for (final item in request.items) {
      for (final MapEntry(:key, :value) in counted(item.reach).entries) {
        counts.update(key, (n) => n + value, ifAbsent: () => value);
      }
    }
    return counts;
  }

  String _clientLine(AppLocalizations l) => switch (request.clientName) {
    final client? when client.trim().isNotEmpty =>
      l.settings_agentAccess_confirm_client(client),
    _ => l.settings_agentAccess_confirm_unknownClient,
  };
}

/// Allow, live only once [kAgentWriteAllowDelay] has passed. Deny needs no
/// wait: answering no by accident changes nothing.
class _AllowButton extends StatefulWidget {
  const _AllowButton({required this.label});

  final String label;

  @override
  State<_AllowButton> createState() => _AllowButtonState();
}

class _AllowButtonState extends State<_AllowButton> {
  var _armed = false;
  late final Timer _arm;

  @override
  void initState() {
    super.initState();
    _arm = Timer(kAgentWriteAllowDelay, () {
      if (mounted) setState(() => _armed = true);
    });
  }

  @override
  void dispose() {
    _arm.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FilledButton(
    key: AgentWriteConfirmDialog.allowKey,
    onPressed: _armed ? () => Navigator.of(context).pop(true) : null,
    child: Text(widget.label),
  );
}

String _verb(AppLocalizations l, String kind) => switch (kind) {
  'create' => l.settings_agentAccess_confirm_create,
  'delete' => l.settings_agentAccess_confirm_delete,
  _ => l.settings_agentAccess_confirm_update,
};

class _PlanItemRow extends StatelessWidget {
  const _PlanItemRow({required this.item, required this.units});

  final PlanItem item;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final verb = _verb(l, item.kind.name);
    final name = item.title ?? item.id;
    final date = item.date;
    String named(String id) => item.names[id] ?? id;
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
          if (date != null)
            Text(
              units.formatDateTime(DateTime.parse(date), l10n: l),
              style: theme.textTheme.bodySmall,
            ),
          for (final MapEntry(:key, :value) in item.fields.entries)
            Text(
              '$key: ${agentValueText(l, units, key, value.oldValue)} '
              '→ ${agentValueText(l, units, key, value.newValue)}',
              style: theme.textTheme.bodySmall,
            ),
          for (final MapEntry(:key, :value) in item.relations.entries)
            Text(
              '$key: ${[for (final id in value.add) '+${named(id)}', for (final id in value.remove) '-${named(id)}'].join(', ')}',
              style: theme.textTheme.bodySmall,
            ),
          for (final MapEntry(:key, :value) in item.indirectRelations.entries)
            Text(
              '$key: ${[for (final id in value) '+${named(id)}'].join(', ')}',
              style: theme.textTheme.bodySmall,
            ),
          for (final MapEntry(:key, :value) in item.reach.parts.entries)
            Text(
              l.settings_agentAccess_confirm_alsoDeletes(
                changeLogTableLabel(l, key),
                value,
              ),
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
  if ((key == 'date_time' || key.endsWith('_time')) && value is String) {
    return units.formatDateTime(DateTime.parse(value), l10n: l);
  }
  return '$value';
}
