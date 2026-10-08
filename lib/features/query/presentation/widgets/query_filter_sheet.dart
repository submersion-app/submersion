import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/query/presentation/app_query_labels.dart';
import 'package:submersion/features/query/presentation/widgets/query_sheet_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/sheet_messenger_scope.dart';

/// The filter icon of a list with no filter sheet of its own (#2365): a
/// badge shows while a query is active.
class QueryFilterButton extends StatelessWidget {
  const QueryFilterButton({
    super.key,
    required this.active,
    required this.onPressed,
    this.compact = false,
  });

  final bool active;
  final VoidCallback onPressed;

  /// The 20 px icon of a master pane's compact bar.
  final bool compact;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.query_filter_tooltip,
    onPressed: onPressed,
    icon: Badge(
      isLabelVisible: active,
      child: Icon(Icons.filter_list, size: compact ? 20 : null),
    ),
  );
}

/// [QueryFilterButton] over a list whose whole filter is one query
/// [provider] (#2365): badged while it is set, and the sheet writes it.
class QueryFilterAction extends ConsumerWidget {
  const QueryFilterAction({
    super.key,
    required this.provider,
    required this.subject,
    required this.root,
    this.compact = false,
  });

  final StateProvider<QueryNode?> provider;
  final QuerySubject subject;
  final QueryEntity root;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) => QueryFilterButton(
    active: ref.watch(provider) != null,
    compact: compact,
    onPressed: () => showQueryFilterSheet(
      context,
      subject: subject,
      root: root,
      initial: ref.read(provider),
      onApply: (ref, query) => ref.read(provider.notifier).state = query,
    ),
  );
}

/// Opens [QueryFilterSheet]. [onApply] runs with the sheet's own ref (the
/// launching page may be gone by then) and the query the diver applied,
/// null when they cleared it.
Future<void> showQueryFilterSheet(
  BuildContext context, {
  required QuerySubject subject,
  required QueryEntity root,
  required QueryNode? initial,
  required void Function(WidgetRef ref, QueryNode? query) onApply,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => QueryFilterSheet(
    subject: subject,
    root: root,
    initial: initial,
    onApply: onApply,
  ),
);

/// A query-only filter sheet: the Saved row and the editor, Clear, Cancel
/// and Apply. Edits stay local until Apply.
class QueryFilterSheet extends ConsumerStatefulWidget {
  const QueryFilterSheet({
    super.key,
    required this.subject,
    required this.root,
    required this.initial,
    required this.onApply,
  });

  final QuerySubject subject;
  final QueryEntity root;
  final QueryNode? initial;
  final void Function(WidgetRef ref, QueryNode? query) onApply;

  @override
  ConsumerState<QueryFilterSheet> createState() => _QueryFilterSheetState();
}

class _QueryFilterSheetState extends ConsumerState<QueryFilterSheet> {
  late QueryNode? _query = widget.initial;

  /// Bumped by Clear so the editor starts over: a draft that never parsed
  /// left the value null already, so a null value alone would not reset it.
  int _generation = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppQueryLabels(context).entity(widget.subject),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('query_filter_sheet_clear'),
                    onPressed: () => setState(() {
                      _query = null;
                      _generation++;
                    }),
                    child: Text(context.l10n.query_filter_clear),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SheetMessengerScope(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    QuerySheetSection(
                      key: ValueKey(_generation),
                      subject: widget.subject,
                      root: widget.root,
                      value: _query,
                      onChanged: (node) => setState(() => _query = node),
                      // The query is the whole sheet.
                      saveNode: _query,
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.l10n.common_action_cancel),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          widget.onApply(ref, _query);
                          Navigator.of(context).pop();
                        },
                        child: Text(context.l10n.common_action_apply),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
