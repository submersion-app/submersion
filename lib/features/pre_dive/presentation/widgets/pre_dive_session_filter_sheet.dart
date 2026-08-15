import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/domain/models/pre_dive_session_filter.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// Bottom sheet for narrowing the pre-dive checklist session history.
///
/// Edits are held locally so the list behind the sheet does not churn while
/// the diver is still choosing; the provider is written once on Apply.
class PreDiveSessionFilterSheet extends ConsumerStatefulWidget {
  const PreDiveSessionFilterSheet({super.key});

  @override
  ConsumerState<PreDiveSessionFilterSheet> createState() =>
      _PreDiveSessionFilterSheetState();
}

class _PreDiveSessionFilterSheetState
    extends ConsumerState<PreDiveSessionFilterSheet> {
  late Set<String> _templateNames;
  late Set<PreDiveSessionStatus> _statuses;
  late bool _flaggedOnly;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(preDiveSessionFilterProvider);
    _templateNames = {...filter.templateNames};
    _statuses = {...filter.statuses};
    _flaggedOnly = filter.flaggedOnly;
    _dateRange = filter.dateRange;
  }

  String _statusLabel(PreDiveSessionStatus status) {
    return switch (status) {
      PreDiveSessionStatus.inProgress =>
        context.l10n.preDive_sessions_statusInProgress,
      PreDiveSessionStatus.completed =>
        context.l10n.preDive_sessions_statusCompleted,
      PreDiveSessionStatus.aborted =>
        context.l10n.preDive_sessions_statusAborted,
    };
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dateRange,
    );
    if (range != null) setState(() => _dateRange = range);
  }

  void _clearAll() {
    setState(() {
      _templateNames = {};
      _statuses = {};
      _flaggedOnly = false;
      _dateRange = null;
    });
  }

  void _apply() {
    ref
        .read(preDiveSessionFilterProvider.notifier)
        .state = PreDiveSessionFilter(
      templateNames: _templateNames,
      statuses: _statuses,
      flaggedOnly: _flaggedOnly,
      dateRange: _dateRange,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final templateNames = ref.watch(preDiveSessionTemplateNamesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          // Transparent Material so the tiles inside paint their ink above this
          // decorated container (Flutter asserts on a ListTile whose nearest
          // decorated ancestor precedes its Material).
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          l10n.preDive_sessions_filterTitle,
                          style: theme.textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: _clearAll,
                        child: Text(l10n.preDive_sessions_filterClearAll),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (templateNames.isNotEmpty) ...[
                        _SectionLabel(l10n.preDive_sessions_filterChecklist),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final name in templateNames)
                              FilterChip(
                                label: Text(name),
                                selected: _templateNames.contains(name),
                                onSelected: (selected) => setState(() {
                                  if (selected) {
                                    _templateNames = {..._templateNames, name};
                                  } else {
                                    _templateNames = {..._templateNames}
                                      ..remove(name);
                                  }
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      _SectionLabel(l10n.preDive_sessions_filterStatus),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final status in PreDiveSessionStatus.values)
                            FilterChip(
                              label: Text(_statusLabel(status)),
                              selected: _statuses.contains(status),
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  _statuses = {..._statuses, status};
                                } else {
                                  _statuses = {..._statuses}..remove(status);
                                }
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SectionLabel(l10n.preDive_sessions_filterDateRange),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.date_range),
                        title: Text(
                          _dateRange == null
                              ? l10n.preDive_sessions_filterAnyDate
                              : '${MaterialLocalizations.of(context).formatMediumDate(_dateRange!.start)}'
                                    ' - '
                                    '${MaterialLocalizations.of(context).formatMediumDate(_dateRange!.end)}',
                        ),
                        trailing: _dateRange == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () =>
                                    setState(() => _dateRange = null),
                              ),
                        onTap: _pickDateRange,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.preDive_sessions_filterFlaggedOnly),
                        value: _flaggedOnly,
                        onChanged: (value) =>
                            setState(() => _flaggedOnly = value),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _apply,
                      child: Text(l10n.preDive_sessions_filterApply),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
