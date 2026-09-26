import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Finds an entity of any kind by name and centres the view on it.
class EntitySearchField extends ConsumerStatefulWidget {
  const EntitySearchField({super.key});

  @override
  ConsumerState<EntitySearchField> createState() => _EntitySearchFieldState();
}

class _EntitySearchFieldState extends ConsumerState<EntitySearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = ConnectionKindColors.of(context);
    final hits = _query.isEmpty
        ? null
        : ref.watch(connectionsSearchProvider(_query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('entity-search'),
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l10n.connections_around_searchHint,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        if (hits != null)
          hits.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
            data: (nodes) => nodes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(l10n.connections_around_noResults),
                  )
                : Column(
                    children: [
                      for (final n in nodes)
                        ListTile(
                          key: ValueKey('search-hit-${n.ref.wire}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 6,
                            backgroundColor: colors.colorFor(n.ref.kind),
                          ),
                          title: Text(n.label),
                          subtitle: Text(
                            '${kindLabel(l10n, n.ref.kind)}, '
                            '${l10n.connections_selection_dives(n.diveCount)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          onTap: () {
                            ref
                                .read(connectionsViewProvider.notifier)
                                .update((s) => s.centreOn(n.ref));
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                    ],
                  ),
          ),
      ],
    );
  }
}
