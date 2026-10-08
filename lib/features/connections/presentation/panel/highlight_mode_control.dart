import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/highlight_key.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Colour the map by kind, group or recency, with the key for the chosen
/// mode underneath (the wide layout has no legend on the canvas).
class HighlightModeControl extends ConsumerWidget {
  const HighlightModeControl({super.key, this.groupCount = 0});

  final int groupCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(connectionsViewProvider.select((v) => v.highlight));
    return Column(
      key: const ValueKey('highlight-mode'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.connections_highlight_title,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        SegmentedButton<HighlightMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: HighlightMode.byKind,
              label: Text(l10n.connections_highlight_byKind),
            ),
            ButtonSegment(
              value: HighlightMode.groups,
              label: Text(l10n.connections_highlight_groups),
            ),
            ButtonSegment(
              value: HighlightMode.recency,
              label: Text(l10n.connections_highlight_recency),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) => ref
              .read(connectionsViewProvider.notifier)
              .update((v) => v.withHighlight(s.single)),
        ),
        if (mode != HighlightMode.byKind) ...[
          const SizedBox(height: 6),
          HighlightKey(mode: mode, groupCount: groupCount),
        ],
      ],
    );
  }
}
