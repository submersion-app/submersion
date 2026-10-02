import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/query/presentation/entity_query_editor.dart';
import 'package:submersion/features/query/presentation/widgets/save_query_flow.dart';
import 'package:submersion/features/query/presentation/widgets/saved_query_chip_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The query part of a list's filter sheet (#2365): the Saved row and the
/// editor rooted at [root]. A typed or built query is ANDed with every
/// section below it. Saves through its own ref, never the launching page's:
/// the sheet can outlive the page that opened it.
class QuerySheetSection extends ConsumerWidget {
  const QuerySheetSection({
    super.key,
    required this.subject,
    required this.root,
    required this.value,
    required this.onChanged,
  });

  final QuerySubject subject;
  final QueryEntity root;
  final QueryNode? value;
  final ValueChanged<QueryNode?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.query_sheet_sectionTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        SavedQueryChipRow(
          subject: subject,
          onApply: (load) => onChanged(load.node),
        ),
        const SizedBox(height: 8),
        EntityQueryEditor(
          root: root,
          value: query,
          onChanged: onChanged,
          onSave: query == null
              ? null
              : () => saveQueryFromEditor(
                  context,
                  ref,
                  subject: subject,
                  node: query,
                ),
        ),
      ],
    );
  }
}
