import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/presentation/formatters/incident_labels.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The near-miss log: newest first, deliberately quiet styling.
class IncidentsListPage extends ConsumerWidget {
  const IncidentsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final incidentsAsync = ref.watch(incidentsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.incidents_title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/incidents/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.incidents_add),
      ),
      body: incidentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.common_error_tryAgain,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (incidents) => incidents.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l10n.incidents_empty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: incidents.length,
                itemBuilder: (context, index) =>
                    _IncidentTile(incident: incidents[index]),
              ),
      ),
    );
  }
}

class _IncidentTile extends ConsumerWidget {
  final Incident incident;

  const _IncidentTile({required this.incident});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // occurredAt is a wall-clock UTC date; format its components directly (no
    // toLocal) so the shown day is stable across synced devices/timezones.
    final dateText = DateFormat.yMMMd().format(incident.occurredAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.flag_outlined,
          color: incident.severity == IncidentSeverity.serious
              ? theme.colorScheme.tertiary
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          incident.narrative,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            dateText,
            incidentCategoryLabel(l10n, incident.category),
            incidentSeverityLabel(l10n, incident.severity),
            if (incident.diveId != null) l10n.incidents_linkedDive,
          ].join(' - '),
        ),
        onTap: () => context.push('/incidents/${incident.id}'),
      ),
    );
  }
}
