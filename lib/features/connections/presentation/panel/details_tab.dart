import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/selection_details.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class DetailsTab extends ConsumerWidget {
  const DetailsTab({super.key, required this.graph});

  final ConnectionGraph graph;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(connectionsSelectionProvider);
    if (selection == null) {
      final theme = Theme.of(context);
      return Text(
        context.l10n.connections_selection_hint,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return GraphSelectionDetails(graph: graph, selection: selection);
  }
}
