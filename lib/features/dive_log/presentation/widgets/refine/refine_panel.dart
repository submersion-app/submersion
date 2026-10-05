import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_custom_fields_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_conditions_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_date_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_gas_equipment_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_location_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_organization_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_people_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_rules_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_count_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_group_tile.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/query/presentation/widgets/saved_query_chip_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const kRefineApplyKey = ValueKey('refine-apply');
const kRefineClearAllKey = ValueKey('refine-clear-all');
const kRefineCancelKey = ValueKey('refine-cancel');

/// The Refine panel (#2773): every structured filter axis in collapsible
/// groups, edited as one draft and applied with "Show N dives". Replaces
/// the Filter sheet and the Advanced Search page for the dive list,
/// Insights and Connections alike, each passing its own [filterProvider].
class RefinePanel extends ConsumerStatefulWidget {
  const RefinePanel({super.key, required this.filterProvider, this.onApplied});

  final StateProvider<DiveFilterState> filterProvider;

  /// Called after the panel wrote [filterProvider].
  final VoidCallback? onApplied;

  @override
  ConsumerState<RefinePanel> createState() => _RefinePanelState();
}

class _RefinePanelState extends ConsumerState<RefinePanel> {
  late DiveFilterState _draft;

  /// Bumped by Clear all so every group rebuilds from the reset draft,
  /// re-seeding its text fields.
  var _generation = 0;

  /// The last count a draft answered, shown while the next one loads.
  int? _lastCount;

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _draft = ref.read(widget.filterProvider);
  }

  void _update(DiveFilterState next) => setState(() => _draft = next);

  void _clearAll() => setState(() {
    _draft = const DiveFilterState();
    _generation++;
  });

  /// The draft as it should be written: a group may correct a value that
  /// went stale while the panel was open.
  DiveFilterState _resolvedDraft() => RefineGasEquipmentGroup.resolveOnApply(
    _draft,
    ref.read(allDiveComputersProvider),
  );

  void _close() => Navigator.of(context).pop();

  void _apply() {
    ref.read(widget.filterProvider.notifier).state = _resolvedDraft().copyWith(
      axesSuspended: false,
    );
    widget.onApplied?.call();
    _close();
  }

  List<Widget> _groups() {
    final l10n = context.l10n;
    final d = _draft;
    // A computer deleted since the filter was set resolves to All
    // computers, as Show writes it.
    final resolved = RefineGasEquipmentGroup.resolveOnApply(
      d,
      ref.watch(allDiveComputersProvider),
    );
    Widget tile(String title, int active, Widget child) =>
        RefineGroupTile(title: title, activeCount: active, child: child);
    return [
      tile(
        RefineRulesGroup.title(l10n),
        RefineRulesGroup.activeCount(d),
        RefineRulesGroup(
          draft: d,
          onChanged: _update,
          // The whole search as Show would apply it (#2989), All dives
          // lifted: a search set only in the other groups saves too.
          saveNode: normalizeQuery(
            resolved.copyWith(axesSuspended: false).toQuery(),
          ),
        ),
      ),
      tile(
        RefineDateGroup.title(l10n),
        RefineDateGroup.activeCount(d),
        RefineDateGroup(draft: d, onChanged: _update),
      ),
      tile(
        RefineLocationGroup.title(l10n),
        RefineLocationGroup.activeCount(d),
        RefineLocationGroup(draft: d, onChanged: _update),
      ),
      tile(
        RefineConditionsGroup.title(l10n),
        RefineConditionsGroup.activeCount(d),
        RefineConditionsGroup(draft: d, onChanged: _update),
      ),
      tile(
        RefineGasEquipmentGroup.title(l10n),
        // A computer deleted since the filter was set shows as All in the
        // group, so it is not counted either.
        RefineGasEquipmentGroup.activeCount(resolved),
        RefineGasEquipmentGroup(draft: d, onChanged: _update),
      ),
      tile(
        RefinePeopleGroup.title(l10n),
        RefinePeopleGroup.activeCount(d),
        RefinePeopleGroup(draft: d, onChanged: _update),
      ),
      tile(
        RefineOrganizationGroup.title(l10n),
        RefineOrganizationGroup.activeCount(d),
        RefineOrganizationGroup(draft: d, onChanged: _update),
      ),
      tile(
        RefineCustomFieldsGroup.title(l10n),
        RefineCustomFieldsGroup.activeCount(d),
        RefineCustomFieldsGroup(draft: d, onChanged: _update),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final count = ref.watch(refineMatchCountProvider(_draft));
    if (count.hasValue) _lastCount = count.value;
    final shown = count.hasError ? null : (count.value ?? _lastCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.diveLog_refine_title,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              TextButton(
                key: kRefineClearAllKey,
                onPressed: _clearAll,
                child: Text(l10n.diveLog_filterChip_clearAll),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SavedQueryChipRow(
            subject: QuerySubject.dives,
            onApply: (load) {
              // The whole saved search (spec 5.4): the axes clear.
              ref.read(widget.filterProvider.notifier).state = DiveFilterState(
                query: load.node,
              );
              widget.onApplied?.call();
              _close();
            },
          ),
        ),
        Expanded(
          // A visible thumb: desktop draws none until a scroll starts, and
          // the groups run below the fold (#989).
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: ListView(
              controller: _scroll,
              children: [
                KeyedSubtree(
                  key: ValueKey(_generation),
                  child: Column(children: _groups()),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // Clear of the home indicator: the sheet's own safe area leaves the
        // bottom to its content.
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                TextButton(
                  key: kRefineCancelKey,
                  onPressed: _close,
                  child: Text(l10n.diveLog_search_cancel),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: kRefineApplyKey,
                    onPressed: _apply,
                    child: Text(
                      shown == null
                          ? l10n.diveLog_refine_showDivesNoCount
                          : l10n.diveLog_refine_showDives(shown),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
