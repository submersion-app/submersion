import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';
import 'package:submersion/features/change_log/presentation/change_log_labels.dart';
import 'package:submersion/features/change_log/presentation/change_log_value_format.dart';
import 'package:submersion/features/change_log/presentation/pages/change_log_settings_page.dart';
import 'package:submersion/features/change_log/presentation/providers/change_log_providers.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_entry_tile.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The record types the chips offer. Gear and settings each span two tables.
enum _RecordGroup {
  all({}),
  dives({'dives'}),
  sites({'dive_sites'}),
  gear({'equipment', 'equipment_sets'}),
  settings({'settings', 'diver_settings'});

  const _RecordGroup(this.tables);

  final Set<String> tables;

  String label(AppLocalizations l) => switch (this) {
    all => l.changeLog_filter_all,
    dives => l.changeLog_filter_dives,
    sites => l.changeLog_filter_sites,
    gear => l.changeLog_filter_gear,
    settings => l.changeLog_filter_settings,
  };
}

/// Settings > Data > Change log (issue #3922): every change to the active
/// diver's records, newest first, or one record's when [rootId] is set.
class ChangeLogPage extends ConsumerStatefulWidget {
  const ChangeLogPage({super.key, this.rootTable, this.rootId});

  final String? rootTable;
  final String? rootId;

  @override
  ConsumerState<ChangeLogPage> createState() => _ChangeLogPageState();
}

class _ChangeLogPageState extends ConsumerState<ChangeLogPage> {
  _RecordGroup _group = _RecordGroup.all;
  ChangeLogSource? _source;

  ChangeLogFilter get _filter => ChangeLogFilter(
    rootTables: _group.tables,
    sources: {?_source},
    rootTable: widget.rootTable,
    rootId: widget.rootId,
  );

  bool get _isRecord => widget.rootId != null;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filter = _filter;
    final feed = ref.watch(changeLogFeedProvider(filter));
    return Scaffold(
      appBar: AppBar(
        title: Text(_title(l, feed.value)),
        actions: [
          if (!_isRecord)
            PopupMenuButton<VoidCallback>(
              key: const ValueKey('change_log_menu'),
              onSelected: (action) => action(),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: () => context.push('/settings/change-log/settings'),
                  child: Text(l.changeLog_menu_settings),
                ),
                PopupMenuItem(
                  value: () => confirmClearChangeLog(context, ref),
                  child: Text(l.changeLog_clear),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_isRecord) _filters(l),
          Expanded(
            child: feed.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
              data: (state) => state.operations.isEmpty
                  ? _Empty(filtered: filter != const ChangeLogFilter())
                  : _ChangeLogList(state: state, filter: filter),
            ),
          ),
        ],
      ),
    );
  }

  String _title(AppLocalizations l, ChangeLogFeedState? state) {
    if (!_isRecord) return l.changeLog_title;
    for (final operation in state?.operations ?? const <ChangeLogOperation>[]) {
      if (operation.rootId == widget.rootId) {
        return changeLogRecordTitle(l, operation);
      }
    }
    return l.changeLog_history;
  }

  Widget _filters(AppLocalizations l) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Row(
      children: [
        for (final group in _RecordGroup.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(group.label(l)),
              selected: _group == group,
              onSelected: (_) => setState(() => _group = group),
            ),
          ),
        PopupMenuButton<ChangeLogSource?>(
          key: const ValueKey('change_log_source_filter'),
          onSelected: (source) => setState(() => _source = source),
          itemBuilder: (_) => [
            PopupMenuItem(child: Text(l.changeLog_filter_anySource)),
            for (final source in ChangeLogSource.values)
              PopupMenuItem(
                value: source,
                child: Text(changeLogSourceLabel(l, source)),
              ),
          ],
          child: Chip(
            avatar: const Icon(Icons.filter_list, size: 18),
            label: Text(
              _source == null
                  ? l.changeLog_filter_source
                  : changeLogSourceLabel(l, _source!),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              filtered ? l.changeLog_empty_filtered : l.changeLog_empty_title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (!filtered) ...[
              const SizedBox(height: 4),
              Text(
                l.changeLog_empty_body,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The list, with a heading each time the day changes. Entries run in event
/// order, so a device clock moved backwards can repeat a heading rather than
/// move an entry out of order.
class _ChangeLogList extends ConsumerWidget {
  const _ChangeLogList({required this.state, required this.filter});

  final ChangeLogFeedState state;
  final ChangeLogFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final peerNames =
        ref.watch(peerDeviceNamesProvider).value ?? const <String, String>{};
    final formatter = ChangeLogValueFormatter(
      l10n: l,
      units: units,
      references: state.references,
    );
    final rows = <Object>[];
    DateTime? day;
    for (final operation in state.operations) {
      final ended = operation.endedAt;
      final thisDay = DateTime(ended.year, ended.month, ended.day);
      if (thisDay != day) rows.add(thisDay);
      day = thisDay;
      rows.add(operation);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll.metrics.extentAfter < 400) {
          ref.read(changeLogFeedProvider(filter).notifier).loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: rows.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == rows.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final row = rows[index];
          if (row is DateTime) {
            return _DayHeader(text: _dayLabel(l, units, row));
          }
          final operation = row as ChangeLogOperation;
          return ChangeLogEntryTile(
            operation: operation,
            preview: state.previews[operation.id],
            recordCount: state.recordCounts[operation.id],
            formatter: formatter,
            units: units,
            peerNames: peerNames,
            onTap: () => context.push(
              '/settings/change-log/${Uri.encodeComponent(operation.id)}',
            ),
          );
        },
      ),
    );
  }

  String _dayLabel(AppLocalizations l, UnitFormatter units, DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return l.changeLog_day_today;
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return l.changeLog_day_yesterday;
    }
    return units.formatDate(day);
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
