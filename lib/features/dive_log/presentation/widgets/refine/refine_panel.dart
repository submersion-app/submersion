import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_count_provider.dart';
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
  DiveFilterState _resolvedDraft() => _draft;

  void _close() => Navigator.of(context).pop();

  void _apply() {
    ref.read(widget.filterProvider.notifier).state = _resolvedDraft().copyWith(
      axesSuspended: false,
    );
    widget.onApplied?.call();
    _close();
  }

  List<Widget> _groups() => const [];

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
                child: Text(l10n.diveLog_filter_clearAll),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SavedQueryChipRow(
            subject: QuerySubject.dives,
            onApply: (load) {
              final notifier = ref.read(widget.filterProvider.notifier);
              // At once, keeping the other axes (PR 4 makes this the whole
              // saved search).
              notifier.state = notifier.state.copyWith(
                query: load.node,
                clearQuery: load.node == null,
                axesSuspended: false,
              );
              widget.onApplied?.call();
              _close();
            },
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              KeyedSubtree(
                key: ValueKey(_generation),
                child: Column(children: _groups()),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
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
      ],
    );
  }
}
