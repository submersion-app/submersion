import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_revert_plan.dart';
import 'package:submersion/features/change_log/presentation/change_log_labels.dart';
import 'package:submersion/features/change_log/presentation/change_log_value_format.dart';
import 'package:submersion/features/change_log/presentation/providers/change_log_providers.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_revert_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_reference_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The most of a text value this page lays out.
const int _detailClip = 4000;

/// Where a record's own page is, or null for a record with none.
String? changeLogRecordRoute(String table, String id) => switch (table) {
  'dives' => '/dives/$id',
  'dive_sites' => '/sites/$id',
  'equipment' => '/equipment/$id',
  'equipment_sets' => '/equipment/sets/$id',
  'trips' => '/trips/$id',
  'buddies' => '/buddies/$id',
  'certifications' => '/certifications/$id',
  'courses' => '/courses/$id',
  'dive_centers' => '/dive-centers/$id',
  'documents' => '/documents/$id',
  'species' => '/species/$id',
  'gps_tracks' => '/gps-log/$id',
  'nav_tracks' => '/nav-routes/$id',
  _ => null,
};

/// One change log entry: every changed field of an edit, or for a bulk action
/// the records it touched.
class ChangeLogEntryPage extends ConsumerWidget {
  const ChangeLogEntryPage({super.key, required this.operationId});

  final String operationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final detail = ref.watch(changeLogEntryDetailProvider(operationId));
    return Scaffold(
      appBar: AppBar(title: Text(l.changeLog_detail_title)),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (detail) => detail == null
            ? Center(child: Text(l.changeLog_block_recordGone))
            : _EntryBody(detail: detail),
      ),
    );
  }
}

class _EntryBody extends ConsumerWidget {
  const _EntryBody({required this.detail});

  final ChangeLogEntryDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final peerNames =
        ref.watch(peerDeviceNamesProvider).value ?? const <String, String>{};
    final formatter = ChangeLogValueFormatter(
      l10n: l,
      units: units,
      references: detail.references,
    );
    final operation = detail.operation;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                changeLogTitle(l, operation),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                changeLogSubtitle(l, units, operation, peerNames),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (operation.isReverted) ...[
                const SizedBox(height: 4),
                Text(
                  l.changeLog_reverted,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        if (operation.isBulk)
          ..._bulkRows(context, l, units, formatter)
        else
          ..._recordRows(context, ref, l, formatter),
        if (operation.eventCount > detail.events.length)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.changeLog_detail_moreRecords(
                operation.eventCount - detail.events.length,
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
        _RevertAction(detail: detail),
        if (!operation.isBulk) _links(context, l),
      ],
    );
  }

  List<Widget> _recordRows(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    ChangeLogValueFormatter formatter,
  ) {
    final rootTable = detail.operation.rootTable;
    return [
      for (final event in detail.events) ...[
        if (event.table != rootTable)
          _ChildHeader(event: event)
        else if (event.action != ChangeLogAction.update)
          _ActionRow(
            text: _actionLabel(l, event.action),
            block: _recordBlock(event),
          ),
        if (event.action == ChangeLogAction.update)
          for (final field in event.fields)
            _FieldRow(
              field: field,
              formatter: formatter,
              trailing: _fieldRevert(context, ref, l, event, field),
            ),
      ],
    ];
  }

  ChangeLogBlock? _recordBlock(ChangeLogEvent event) => detail.plan?.items
      .where((item) => item.column == null && item.event.id == event.id)
      .firstOrNull
      ?.block;

  /// A field's Revert button, or why it has none. A field already back at
  /// its old value has neither.
  Widget? _fieldRevert(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    ChangeLogEvent event,
    ChangeLogFieldChange field,
  ) {
    final item = detail.plan?.items
        .where(
          (item) =>
              item.column == field.column &&
              item.event.table == event.table &&
              item.event.recordId == event.recordId,
        )
        .firstOrNull;
    if (item == null) return null;
    final block = item.block;
    if (block != null) {
      return Text(
        changeLogBlockText(l, block),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return TextButton(
      key: ValueKey('change_log_revert_${field.column}'),
      onPressed: () => runChangeLogRevert(
        context,
        ref,
        plan: (service) => service.planField(event.id, field.column),
      ),
      child: Text(l.changeLog_revert),
    );
  }

  List<Widget> _bulkRows(
    BuildContext context,
    AppLocalizations l,
    UnitFormatter units,
    ChangeLogValueFormatter formatter,
  ) {
    final byRoot = <ChangeLogRoot, List<ChangeLogEvent>>{};
    for (final event in detail.events) {
      (byRoot[event.root] ??= []).add(event);
    }
    return [
      for (final entry in byRoot.entries)
        ExpansionTile(
          title: Text(_rootName(l, units, entry.key, entry.value)),
          subtitle: Text(_rootSummary(l, entry.key, entry.value)),
          children: [
            for (final event in entry.value) ...[
              if (entry.value.length > 1 || event.table != entry.key.table)
                _ChildHeader(event: event),
              if (event.action == ChangeLogAction.update)
                for (final field in event.fields)
                  _FieldRow(field: field, formatter: formatter),
            ],
          ],
        ),
    ];
  }

  /// What a bulk entry's record is called: its name now, or the name in its
  /// delete copy once it has gone.
  String _rootName(
    AppLocalizations l,
    UnitFormatter units,
    ChangeLogRoot root,
    List<ChangeLogEvent> events,
  ) {
    final reference = detail.rootNames[root];
    if (reference != null && !reference.isMissing) {
      return conflictReferenceValue(l, units, reference);
    }
    for (final event in events) {
      if (event.table != root.table) continue;
      for (final field in event.fields) {
        if (const {'name', 'title'}.contains(field.column) &&
            field.oldValue is String) {
          return field.oldValue! as String;
        }
      }
    }
    return changeLogTableLabel(l, root.table);
  }

  String _rootSummary(
    AppLocalizations l,
    ChangeLogRoot root,
    List<ChangeLogEvent> events,
  ) {
    final own = events
        .where((e) => e.table == root.table && e.recordId == root.id)
        .firstOrNull;
    return _actionLabel(l, own?.action ?? ChangeLogAction.update);
  }

  Widget _links(BuildContext context, AppLocalizations l) {
    final table = detail.operation.rootTable;
    final id = detail.operation.rootId;
    if (table == null || id == null) return const SizedBox.shrink();
    final route = changeLogRecordRoute(table, id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Wrap(
        children: [
          if (route != null && detail.rootExists)
            TextButton(
              onPressed: () => context.push(route),
              child: Text(l.changeLog_detail_open),
            ),
          TextButton(
            onPressed: () =>
                openChangeLogHistory(context, rootTable: table, rootId: id),
            child: Text(l.changeLog_detail_history),
          ),
        ],
      ),
    );
  }
}

String _actionLabel(AppLocalizations l, ChangeLogAction action) =>
    switch (action) {
      ChangeLogAction.insert => l.changeLog_action_added,
      ChangeLogAction.update => l.changeLog_action_edited,
      ChangeLogAction.delete => l.changeLog_action_deleted,
    };

/// The entry-wide action: Revert all for an edit, Restore for a deleted
/// record, and Undo for a bulk action or a created record.
class _RevertAction extends ConsumerWidget {
  const _RevertAction({required this.detail});

  final ChangeLogEntryDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final operation = detail.operation;
    if (operation.isSummary || operation.isReverted) {
      return const SizedBox.shrink();
    }

    final open = detail.plan?.items.where((i) => !i.isBlocked).toList();
    if (open != null && open.isEmpty) return const SizedBox.shrink();
    final String label;
    final isImport = operation.source == ChangeLogSource.import;
    final bulk = operation.isBulk || isImport;
    if (isImport) {
      label = l.changeLog_undoImport;
    } else if (operation.isBulk) {
      label = l.changeLog_undoEntry;
    } else if (open!.any((i) => i.restoresRecord)) {
      label = l.changeLog_restore;
    } else if (open.any((i) => i.removesRecord)) {
      label = l.changeLog_undoEntry;
    } else {
      label = l.changeLog_revertAll(open.length);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () => runChangeLogRevert(
              context,
              ref,
              plan: (service) => service.planOperation(operation.id),
              bulk: bulk,
            ),
            child: Text(label),
          ),
          if (bulk) ...[
            const SizedBox(height: 8),
            Text(
              l.changeLog_undo_explain,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChildHeader extends StatelessWidget {
  const _ChildHeader({required this.event});

  final ChangeLogEvent event;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Text(
        '${changeLogTableLabel(l, event.table)} · '
        '${_actionLabel(l, event.action)}',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.text, this.block});

  final String text;

  /// Why this cannot be undone.
  final ChangeLogBlock? block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final block = this.block;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: theme.textTheme.bodyMedium),
          if (block != null)
            Text(
              changeLogBlockText(context.l10n, block),
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// A field's label, its old value struck through, and its new value.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.formatter,
    this.trailing,
  });

  final ChangeLogFieldChange field;
  final ChangeLogValueFormatter formatter;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatter.label(field.table, field.column),
                  style: theme.textTheme.labelMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: 2),
                Text(
                  formatter.value(
                    field.table,
                    field.column,
                    field.oldValue,
                    clip: _detailClip,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: muted,
                  ),
                ),
                Text(
                  formatter.value(
                    field.table,
                    field.column,
                    field.newValue,
                    clip: _detailClip,
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (trailing case final action?) ...[
            const SizedBox(width: 12),
            Flexible(child: action),
          ],
        ],
      ),
    );
  }
}
