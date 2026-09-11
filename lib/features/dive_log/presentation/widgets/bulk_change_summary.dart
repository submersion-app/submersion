import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/bulk_membership_editor.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One bulk-editable collection as the confirmation sees it: its heading,
/// the delta its editor reported, and the rows that name its ids.
typedef BulkMembershipCollection = ({
  String title,
  MembershipDelta delta,
  List<BulkMembershipItem> members,
});

/// What a bulk save will do to one collection, by name.
class BulkChangeSection {
  final String title;
  final List<String> added;
  final List<String> removed;

  const BulkChangeSection({
    required this.title,
    required this.added,
    required this.removed,
  });
}

/// Names every membership change a bulk save is about to make, one section per
/// collection that changes, so the confirmation can show the diver what comes
/// off every selected dive before it happens (#1754).
///
/// Names are sorted case-insensitively so a long list can be scanned. An id
/// with no listed row falls back to the id itself rather than disappearing.
List<BulkChangeSection> summarizeBulkMembership(
  List<BulkMembershipCollection> collections,
) {
  List<String> names(List<String> ids, Map<String, String> labels) =>
      [for (final id in ids) labels[id] ?? id]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return collections.where((c) => !c.delta.isEmpty).map((c) {
    final labels = {for (final m in c.members) m.id: m.label};
    return BulkChangeSection(
      title: c.title,
      added: names(c.delta.addIds, labels),
      removed: names(c.delta.removeIds, labels),
    );
  }).toList();
}

/// The body of the bulk-edit confirmation: per collection, what is being added
/// to and removed from every selected dive. Removals use the error color.
class BulkChangeSummary extends StatelessWidget {
  const BulkChangeSummary({
    super.key,
    required this.sections,
    required this.totalDives,
  });

  final List<BulkChangeSection> sections;
  final int totalDives;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          Text(section.title, style: theme.textTheme.titleSmall),
          if (section.added.isNotEmpty) ...[
            Text(
              l10n.diveLog_bulkEdit_confirmAdding(totalDives),
              style: theme.textTheme.labelMedium,
            ),
            Text(section.added.join(', ')),
          ],
          if (section.removed.isNotEmpty) ...[
            Text(
              l10n.diveLog_bulkEdit_confirmRemoving(totalDives),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            Text(
              section.removed.join(', '),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
