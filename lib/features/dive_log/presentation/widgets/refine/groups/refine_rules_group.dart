import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/query/presentation/dive_query_editor.dart';
import 'package:submersion/features/query/presentation/widgets/save_query_flow.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Refine panel's Rules group (#2773): the query editor (Text and
/// Builder) over the same query the dive search row's field edits, with
/// Save.
class RefineRulesGroup extends ConsumerWidget {
  const RefineRulesGroup({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final DiveFilterState draft;
  final ValueChanged<DiveFilterState> onChanged;

  /// The DiveFilterState fields this group edits (read by the axis guard).
  static const fields = {'query'};

  static int activeCount(DiveFilterState f) => f.query != null ? 1 : 0;

  static String title(AppLocalizations l10n) => l10n.diveLog_refine_groupRules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = draft.query;
    return DiveQueryEditor(
      value: query,
      onChanged: (node) =>
          onChanged(draft.copyWith(query: node, clearQuery: node == null)),
      onSave: query == null
          ? null
          : () => saveQueryFromEditor(
              context,
              ref,
              subject: QuerySubject.dives,
              node: query,
            ),
    );
  }
}
