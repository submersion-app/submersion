import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/presentation/providers/entity_search_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A list's search icon (#3882): opens its `EntitySearchHeader` with the
/// caret in it, closes an idle open row, and wears a badge while the list
/// has a query. One icon for every list, as the Dives list has.
class EntitySearchAction extends ConsumerWidget {
  const EntitySearchAction({
    super.key,
    required this.subject,
    required this.active,
    this.tooltip,
    this.compact = false,
  });

  final QuerySubject subject;

  /// Whether the list has a query, which badges the icon.
  final bool active;

  /// Defaults to the shared "Search" tooltip.
  final String? tooltip;

  /// The 20 px icon of a master pane's compact bar.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: ValueKey('entity-search-action-${subject.name}'),
    tooltip: tooltip ?? context.l10n.search_openTooltip,
    icon: Badge(
      isLabelVisible: active,
      child: Icon(Icons.search, size: compact ? 20 : null),
    ),
    onPressed: () {
      final open = ref.read(entitySearchOpenProvider(subject).notifier);
      // An idle open row closes; otherwise open it with the caret in it.
      if (open.state && !active) {
        open.state = false;
        return;
      }
      open.state = true;
      ref.read(entitySearchFocusPendingProvider(subject).notifier).state = true;
    },
  );
}
