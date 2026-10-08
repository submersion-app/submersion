import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/query/presentation/dive_query_editor.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Refine panel's Rules group (#2773): the query editor (Text and
/// Builder) over the same query the dive search row's field edits, with
/// Save, which stores the whole panel (#2989), not only the rules.
class RefineRulesGroup extends ConsumerWidget {
  const RefineRulesGroup({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.saveNode,
  });

  final DiveFilterState draft;
  final ValueChanged<DiveFilterState> onChanged;

  /// What Save stores: every group's axes lowered with the rules ANDed in,
  /// as Show would apply them (spec 5.4). Null while the panel narrows
  /// nothing, which disables Save.
  final QueryNode? saveNode;

  /// The DiveFilterState fields this group edits (read by the axis guard).
  static const fields = {'query'};

  static int activeCount(DiveFilterState f) => f.query != null ? 1 : 0;

  static String title(AppLocalizations l10n) => l10n.diveLog_refine_groupRules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DiveQueryEditor(
      value: draft.query,
      onChanged: (node) =>
          onChanged(draft.copyWith(query: node, clearQuery: node == null)),
      canSave: saveNode != null,
      onSave: () {
        final node = saveNode;
        if (node == null) return;
        ref.read(diveSearchSaverProvider)(context, ref, node);
      },
    );
  }
}
