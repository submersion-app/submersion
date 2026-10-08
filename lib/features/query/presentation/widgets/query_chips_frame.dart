import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/query/presentation/entity_query_chips.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A list body with its query's chips above it (#2365): Clear, then one
/// removable chip per top-level condition, printed in the diver's units.
/// With no query it is the body alone.
class QueryChipsFrame extends ConsumerWidget {
  const QueryChipsFrame({
    super.key,
    required this.root,
    required this.query,
    required this.onChanged,
    required this.child,
  });

  final QueryEntity root;
  final QueryNode? query;
  final ValueChanged<QueryNode?> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query == null) return child;
    final colorScheme = Theme.of(context).colorScheme;
    final chips = entityQueryChips(
      root,
      query,
      ref.watch(queryUnitPrefsProvider),
    );
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.clear_all, size: 18),
                  label: Text(context.l10n.query_filter_clear),
                  onPressed: () => onChanged(null),
                ),
                const SizedBox(width: 8),
                for (final chip in chips)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: InputChip(
                      label: Text(chip.label),
                      onDeleted: () => onChanged(chip.rest),
                      deleteIconColor: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// A list's empty state when its query hid every row (#2365): says the
/// query matched nothing rather than that the diver has no rows.
class QueryNoMatchState extends StatelessWidget {
  const QueryNoMatchState({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.query_list_noMatch,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all),
              label: Text(context.l10n.query_filter_clear),
            ),
          ],
        ),
      ),
    );
  }
}
